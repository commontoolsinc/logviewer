defmodule LogViewer.Search do
  @moduledoc """
  Provides search functionality for log timeline events.
  """

  alias LogViewer.Timeline.LogEvent

  @doc """
  Searches through a timeline of log events based on a query string.

  Performs case-insensitive substring search across message, module, and level fields.
  Returns all events if query is nil or empty string.

  ## Examples

      iex> events = [%LogEvent{message: "Error in storage", ...}]
      iex> Search.search_timeline(events, "storage")
      [%LogEvent{...}]

      iex> Search.search_timeline(events, "")
      [%LogEvent{...}]
  """
  @spec search_timeline(list(LogEvent.t()), String.t() | nil) :: list(LogEvent.t())
  def search_timeline(events, query)
      when is_list(events) and (is_binary(query) or is_nil(query)) do
    cond do
      is_nil(query) or query == "" ->
        events

      true ->
        query_lower = String.downcase(query)

        Enum.filter(events, fn event ->
          matches_query?(event, query_lower)
        end)
    end
  end

  @doc """
  Performs fuzzy matching - checks if pattern characters appear in text in order.

  Characters in the pattern must appear in the same order in the text, but don't
  need to be consecutive. Matching is case-insensitive.

  ## Examples

      iex> Search.fuzzy_match?("memory-provider", "mpv")
      true

      iex> Search.fuzzy_match?("storage-transaction", "stt")
      true

      iex> Search.fuzzy_match?("storage", "tso")
      false
  """
  @spec fuzzy_match?(String.t(), String.t()) :: boolean()
  def fuzzy_match?(text, pattern) when is_binary(text) and is_binary(pattern) do
    text_lower = String.downcase(text)
    pattern_lower = String.downcase(pattern)

    do_fuzzy_match?(text_lower, pattern_lower)
  end

  @doc """
  Highlights matching text in a string by wrapping it in HTML mark tags using fuzzy matching.

  Finds characters that match the query in order (fuzzy matching) and highlights them.
  Adjacent matched characters are grouped into single mark tags.
  Returns original text if query is nil, empty, or no match found.

  ## Examples

      iex> Search.highlight_text("runner", "rnr")
      "<mark class=\\"bg-yellow-200\\">r</mark>u<mark class=\\"bg-yellow-200\\">nn</mark>e<mark class=\\"bg-yellow-200\\">r</mark>"

      iex> Search.highlight_text("memory-provider", "mpv")
      "<mark class=\\"bg-yellow-200\\">m</mark>emory-<mark class=\\"bg-yellow-200\\">p</mark>ro<mark class=\\"bg-yellow-200\\">v</mark>ider"

      iex> Search.highlight_text("Some text", "")
      "Some text"
  """
  @spec highlight_text(String.t(), String.t() | nil) :: String.t()
  def highlight_text(text, query) when is_binary(text) and (is_binary(query) or is_nil(query)) do
    cond do
      is_nil(query) or query == "" ->
        text

      true ->
        text_lower = String.downcase(text)
        query_lower = String.downcase(query)

        # Find positions of matched characters
        case find_fuzzy_positions(text_lower, query_lower, 0, []) do
          [] ->
            # No match found
            text

          positions ->
            # Group adjacent positions and build highlighted string
            build_highlighted_string(text, positions)
        end
    end
  end

  # Find positions of characters that match the fuzzy pattern
  @spec find_fuzzy_positions(String.t(), String.t(), integer(), list(integer())) ::
          list(integer())
  defp find_fuzzy_positions(_text, "", _offset, acc), do: Enum.reverse(acc)
  defp find_fuzzy_positions("", _pattern, _offset, _acc), do: []

  defp find_fuzzy_positions(text, <<char::utf8, rest_pattern::binary>>, offset, acc) do
    case String.split(text, <<char::utf8>>, parts: 2) do
      [before, after_match] ->
        # Found the character, record its position
        pos = offset + String.length(before)
        find_fuzzy_positions(after_match, rest_pattern, pos + 1, [pos | acc])

      [_] ->
        # Character not found, no match
        []
    end
  end

  # Build highlighted string with mark tags around matched positions
  @spec build_highlighted_string(String.t(), list(integer())) :: String.t()
  defp build_highlighted_string(text, positions) do
    # Group adjacent positions
    groups = group_adjacent_positions(positions)

    # Convert string to grapheme list for position-based access
    graphemes = String.graphemes(text)

    # Build result by iterating through positions
    build_with_marks(graphemes, groups, 0, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  # Group consecutive positions together
  # Note: This function is only called with non-empty lists due to the case
  # statement in highlight_text that filters out empty positions
  @spec group_adjacent_positions([integer(), ...]) :: list({integer(), integer()})
  defp group_adjacent_positions(positions) do
    sorted = Enum.sort(positions)

    sorted
    |> Enum.chunk_while(
      nil,
      fn pos, acc ->
        case acc do
          nil -> {:cont, {pos, pos}}
          {start, last} when pos == last + 1 -> {:cont, {start, pos}}
          {start, last} -> {:cont, {start, last}, {pos, pos}}
        end
      end,
      fn
        nil -> {:cont, []}
        acc -> {:cont, acc, []}
      end
    )
  end

  # Build the final string with mark tags
  @spec build_with_marks(list(String.t()), list({integer(), integer()}), integer(), iodata()) ::
          iodata()
  defp build_with_marks([], _groups, _pos, acc), do: acc
  defp build_with_marks(graphemes, [], pos, acc) do
    # No more groups, append remaining text
    remaining = Enum.drop(graphemes, pos)
    [remaining | acc]
  end

  defp build_with_marks(graphemes, [{start, finish} | rest_groups], pos, acc) when pos < start do
    # Add unmatched text before next group
    unmatched = Enum.slice(graphemes, pos, start - pos)
    build_with_marks(graphemes, [{start, finish} | rest_groups], start, [unmatched | acc])
  end

  defp build_with_marks(graphemes, [{start, finish} | rest_groups], pos, acc) when pos == start do
    # Add marked text
    matched = Enum.slice(graphemes, start, finish - start + 1)
    mark_open = ~s(<mark class="bg-yellow-200">)
    mark_close = "</mark>"

    build_with_marks(graphemes, rest_groups, finish + 1, [
      mark_close,
      matched,
      mark_open | acc
    ])
  end

  # Private helper to check if an event matches the query using fuzzy matching
  @spec matches_query?(LogEvent.t(), String.t()) :: boolean()
  defp matches_query?(event, query_lower) when is_binary(query_lower) do
    message_lower = String.downcase(event.message)
    module_lower = String.downcase(event.module)
    level_lower = String.downcase(event.level)

    do_fuzzy_match?(message_lower, query_lower) or
      do_fuzzy_match?(module_lower, query_lower) or
      do_fuzzy_match?(level_lower, query_lower)
  end

  # Recursive fuzzy matching implementation
  @spec do_fuzzy_match?(String.t(), String.t()) :: boolean()
  defp do_fuzzy_match?(_text, ""), do: true
  defp do_fuzzy_match?("", _pattern), do: false

  defp do_fuzzy_match?(text, <<char::utf8, rest::binary>>) do
    case String.split(text, <<char::utf8>>, parts: 2) do
      [_before, after_match] -> do_fuzzy_match?(after_match, rest)
      [_] -> false
    end
  end
end
