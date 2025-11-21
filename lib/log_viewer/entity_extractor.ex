defmodule LogViewer.EntityExtractor do
  @moduledoc """
  Extracts and indexes entities (docIDs, charmIDs, spaceIDs) from log messages.
  """

  alias LogViewer.Timeline.LogEvent

  @type entity_type :: :doc_id | :charm_id | :space_id

  defmodule Entities do
    @moduledoc """
    Collection of extracted entity IDs grouped by type.
    """
    @enforce_keys [:doc_ids, :charm_ids, :space_ids]
    defstruct [:doc_ids, :charm_ids, :space_ids]

    @type t :: %__MODULE__{
            doc_ids: list(String.t()),
            charm_ids: list(String.t()),
            space_ids: list(String.t())
          }
  end

  defmodule EntityInfo do
    @moduledoc """
    Metadata about a specific entity found in logs.
    """
    @enforce_keys [:id, :type, :first_seen, :last_seen, :event_count, :events]
    defstruct [:id, :type, :first_seen, :last_seen, :event_count, :events]

    @type t :: %__MODULE__{
            id: String.t(),
            type: LogViewer.EntityExtractor.entity_type(),
            first_seen: integer(),
            last_seen: integer(),
            event_count: integer(),
            events: list(LogEvent.t())
          }
  end

  defmodule EntityIndex do
    @moduledoc """
    Index of all entities found in a timeline with quick lookup by type.
    """
    @enforce_keys [:entities, :by_type]
    defstruct [:entities, :by_type]

    @type t :: %__MODULE__{
            entities: %{String.t() => EntityInfo.t()},
            by_type: %{
              doc_ids: list(String.t()),
              charm_ids: list(String.t()),
              space_ids: list(String.t())
            }
          }
  end

  # Regex patterns for entity IDs
  # CIDs (both docIDs and charmIDs) start with "baedrei" followed by alphanumeric characters
  # In practice this would be base32, but tests use fake IDs with other characters
  @cid_pattern ~r/baedrei[a-z0-9]{50,}/
  # DIDs follow the format: did:key:z6Mk followed by base58 characters
  @did_pattern ~r/did:key:z6Mk[A-HJ-NP-Za-km-z1-9]+/

  @doc """
  Extracts all entity IDs from a text string.

  Returns a struct with lists of docIDs, charmIDs, and spaceIDs (DIDs).

  ## Examples

      iex> text = "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      iex> entities = LogViewer.EntityExtractor.extract_entities(text)
      iex> length(entities.doc_ids)
      1
  """
  @spec extract_entities(String.t()) :: Entities.t()
  def extract_entities(text) when is_binary(text) do
    # Extract all CIDs
    cids =
      Regex.scan(@cid_pattern, text)
      |> Enum.map(fn [match] -> match end)
      |> Enum.uniq()

    # Classify CIDs based on context (look for "doc" or "charm" before the CID)
    {doc_ids, charm_ids} =
      Enum.reduce(cids, {[], []}, fn cid, {docs, charms} ->
        # Check if "charm" appears immediately before this specific CID in the text
        if String.contains?(text, "charm #{cid}") do
          {docs, [cid | charms]}
        else
          # Default to doc_id
          {[cid | docs], charms}
        end
      end)

    # Extract DIDs (spaceIDs)
    dids =
      Regex.scan(@did_pattern, text)
      |> Enum.map(fn [match] -> match end)
      |> Enum.uniq()

    %Entities{
      doc_ids: Enum.reverse(doc_ids),
      charm_ids: Enum.reverse(charm_ids),
      space_ids: dids
    }
  end

  @doc """
  Builds an entity index from a timeline of events.

  Scans all events, extracts entities, and builds metadata for each entity
  including first/last seen timestamps and the list of events mentioning it.

  ## Examples

      iex> events = [
      ...>   %LogViewer.Timeline.LogEvent{
      ...>     timestamp: 100,
      ...>     level: "info",
      ...>     module: "memory",
      ...>     message: "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm",
      ...>     source: :client,
      ...>     raw_entry: nil
      ...>   }
      ...> ]
      iex> index = LogViewer.EntityExtractor.build_entity_index(events)
      iex> Map.keys(index.entities) |> length()
      1
  """
  @spec build_entity_index(list(LogEvent.t())) :: EntityIndex.t()
  def build_entity_index(events) when is_list(events) do
    # Build a map of entity_id => {type, list of {event, timestamp}}
    entity_events =
      Enum.reduce(events, %{}, fn event, acc ->
        entities = extract_entities(event.message)

        # Process each entity type separately to preserve classification
        acc
        |> add_entities_with_type(entities.doc_ids, :doc_id, event)
        |> add_entities_with_type(entities.charm_ids, :charm_id, event)
        |> add_entities_with_type(entities.space_ids, :space_id, event)
      end)

    # Build EntityInfo for each entity
    entities_map =
      entity_events
      |> Enum.map(fn {entity_id, {entity_type, event_timestamp_pairs}} ->
        timestamps = Enum.map(event_timestamp_pairs, fn {_event, ts} -> ts end)
        events_list = Enum.map(event_timestamp_pairs, fn {event, _ts} -> event end)

        entity_info = %EntityInfo{
          id: entity_id,
          type: entity_type,
          first_seen: Enum.min(timestamps),
          last_seen: Enum.max(timestamps),
          event_count: length(event_timestamp_pairs),
          events: Enum.reverse(events_list)
        }

        {entity_id, entity_info}
      end)
      |> Map.new()

    # Group by type
    by_type = %{
      doc_ids:
        entities_map
        |> Enum.filter(fn {_id, info} -> info.type == :doc_id end)
        |> Enum.map(fn {id, _info} -> id end),
      charm_ids:
        entities_map
        |> Enum.filter(fn {_id, info} -> info.type == :charm_id end)
        |> Enum.map(fn {id, _info} -> id end),
      space_ids:
        entities_map
        |> Enum.filter(fn {_id, info} -> info.type == :space_id end)
        |> Enum.map(fn {id, _info} -> id end)
    }

    %EntityIndex{
      entities: entities_map,
      by_type: by_type
    }
  end

  @spec add_entities_with_type(map(), list(String.t()), atom(), LogEvent.t()) :: map()
  defp add_entities_with_type(acc, entity_ids, entity_type, event)
       when is_map(acc) and is_list(entity_ids) and is_atom(entity_type) do
    Enum.reduce(entity_ids, acc, fn entity_id, inner_acc ->
      Map.update(
        inner_acc,
        entity_id,
        {entity_type, [{event, event.timestamp}]},
        fn {type, pairs} ->
          {type, [{event, event.timestamp} | pairs]}
        end
      )
    end)
  end
end
