defmodule LogViewer.IDTracker do
  @moduledoc """
  Tracks and manages clickable IDs (CIDs and DIDs) in log messages.
  """

  # Regex patterns for entity IDs
  # CIDs start with "ba" followed by alphanumeric characters (49+ chars, 51+ total)
  # This matches various CID formats: baedrei..., ba4jcb..., bafyrei..., etc.
  @cid_pattern ~r/ba[a-z0-9]{49,}/
  # DIDs follow the format: did:key:z6Mk followed by base58 characters
  @did_pattern ~r/did:key:z6Mk[A-HJ-NP-Za-km-z1-9]+/

  @doc """
  Extracts all clickable IDs from text.

  Finds:
  - CIDs from JSON slash patterns like `{"/": "baedrei..."}`
  - CIDs from direct references
  - DIDs in the format `did:key:z6Mk...`

  Returns a unique list of all found IDs.

  ## Examples

      iex> text = ~s({"cause": {"/": "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"}})
      iex> LogViewer.IDTracker.extract_clickable_ids(text)
      ["baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"]

      iex> text = "space: did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8"
      iex> LogViewer.IDTracker.extract_clickable_ids(text)
      ["did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8"]
  """
  @spec extract_clickable_ids(String.t()) :: list(String.t())
  def extract_clickable_ids(text) when is_binary(text) do
    # Extract all CIDs (from both JSON slash patterns and direct references)
    cids =
      Regex.scan(@cid_pattern, text)
      |> Enum.map(fn [match] -> match end)

    # Extract all DIDs
    dids =
      Regex.scan(@did_pattern, text)
      |> Enum.map(fn [match] -> match end)

    # Combine and deduplicate
    (cids ++ dids)
    |> Enum.uniq()
  end

  @doc """
  Wraps all IDs in text with clickable spans.

  Each ID becomes: `<span class="clickable-id" phx-click="toggle_track" phx-value-id="...">ID</span>`

  Returns original text if no IDs found.

  ## Examples

      iex> text = "doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      iex> result = LogViewer.IDTracker.make_ids_clickable(text)
      iex> result =~ ~s(phx-click="toggle_track")
      true
  """
  @spec make_ids_clickable(String.t()) :: String.t()
  def make_ids_clickable(text) when is_binary(text) do
    ids = extract_clickable_ids(text)

    case ids do
      [] ->
        # No IDs found, return original text
        text

      _ ->
        # Replace each ID with clickable span
        Enum.reduce(ids, text, fn id, acc ->
          replacement = ~s(<span class="clickable-id" phx-click="toggle_track" phx-value-id="#{id}">#{id}</span>)
          String.replace(acc, id, replacement)
        end)
    end
  end
end
