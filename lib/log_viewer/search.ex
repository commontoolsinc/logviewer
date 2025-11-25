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
    require Logger
    Logger.info("search_timeline called: query=#{inspect(query)}, event_count=#{length(events)}")

    if length(events) > 0 do
      first_event = List.first(events)
      msg_preview = String.slice(first_event.message, 0, 100)
      num_lines = length(String.split(first_event.message, "\n"))
      Logger.info("First event: module=#{first_event.module}, msg_lines=#{num_lines}, preview=#{msg_preview}")
    end

    cond do
      is_nil(query) or query == "" ->
        events

      true ->
        query_lower = String.downcase(query)

        result = Enum.filter(events, fn event ->
          matches_query?(event, query_lower)
        end)

        Logger.info("search_timeline result: #{length(result)} matches found")
        result
    end
  end

  @doc """
  Performs fuzzy matching - checks if pattern characters appear in text in order.

  Characters in the pattern must appear in the same order in the text, but don't
  need to be consecutive. Matching is case-insensitive.

  For multiline text, the pattern must match within a single line (does not match
  across newlines).

  ## Examples

      iex> Search.fuzzy_match?("memory-provider", "mpv")
      true

      iex> Search.fuzzy_match?("storage-transaction", "stt")
      true

      iex> Search.fuzzy_match?("storage", "tso")
      false

      iex> Search.fuzzy_match?("line1\\nline2", "l1l2")
      false
  """
  @spec fuzzy_match?(String.t(), String.t()) :: boolean()
  def fuzzy_match?(text, pattern) when is_binary(text) and is_binary(pattern) do
    text_lower = String.downcase(text)
    pattern_lower = String.downcase(pattern)

    # Split by newlines and check if pattern matches any single line
    lines = String.split(text_lower, "\n")

    # Debug logging
    require Logger
    Logger.debug("fuzzy_match? pattern=#{pattern}, text_length=#{String.length(text)}, num_lines=#{length(lines)}")

    result = Enum.any?(lines, fn line -> do_fuzzy_match?(line, pattern_lower) end)
    Logger.debug("fuzzy_match? result=#{result}")
    result
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
        # Split text into HTML tags and text content
        # HTML tags are preserved as-is, only text content is highlighted
        segments = split_html_segments(text)

        # First check if pattern matches across all text (ignoring HTML)
        combined_text =
          segments
          |> Enum.filter(fn {type, _} -> type == :text end)
          |> Enum.map(fn {:text, content} -> content end)
          |> Enum.join()

        if fuzzy_match?(combined_text, query) do
          # Pattern matches! Highlight across segments progressively
          highlight_across_segments(segments, String.downcase(query))
        else
          # No match, return original
          text
        end
    end
  end

  # Split text into HTML tags and text content segments
  @spec split_html_segments(String.t()) :: list({:tag | :text, String.t()})
  defp split_html_segments(text) do
    # Regex to match HTML tags: <...> or </...> or <.../>, including any content inside
    # We use a simple approach: anything between < and > is a tag
    parts = Regex.split(~r/(<[^>]+>)/, text, include_captures: true, trim: true)

    Enum.map(parts, fn part ->
      if String.starts_with?(part, "<") and String.ends_with?(part, ">") do
        {:tag, part}
      else
        {:text, part}
      end
    end)
  end

  # Highlight segments progressively, tracking remaining pattern across segments
  @spec highlight_across_segments(list({:tag | :text, String.t()}), String.t()) :: String.t()
  defp highlight_across_segments(segments, pattern) do
    {result, _remaining_pattern} =
      Enum.map_reduce(segments, pattern, fn segment, remaining_pattern ->
        case segment do
          {:tag, tag_text} ->
            # Keep HTML tags unchanged, pattern unchanged
            {tag_text, remaining_pattern}

          {:text, text_content} ->
            # Highlight this segment's portion of the pattern
            highlight_and_consume_pattern(text_content, remaining_pattern)
        end
      end)

    Enum.join(result)
  end

  # Highlight text segment and return remaining pattern
  @spec highlight_and_consume_pattern(String.t(), String.t()) :: {String.t(), String.t()}
  defp highlight_and_consume_pattern(text, "") do
    # No more pattern to match, return text as-is
    {text, ""}
  end

  defp highlight_and_consume_pattern(text, pattern) do
    text_lower = String.downcase(text)

    # Find how much of the pattern we can match in this text
    {positions, remaining_pattern} = consume_pattern_greedily(text_lower, pattern, 0, [])

    if positions == [] do
      # Couldn't match any of the pattern here
      {text, pattern}
    else
      # Highlight the positions we found
      highlighted = build_highlighted_string(text, Enum.reverse(positions))
      {highlighted, remaining_pattern}
    end
  end

  # Try to match as much of pattern as possible in text, return positions and remaining
  # Prefers consecutive substring matches over scattered character matches
  @spec consume_pattern_greedily(String.t(), String.t(), integer(), list(integer())) ::
          {list(integer()), String.t()}
  defp consume_pattern_greedily(_text, "", _offset, acc) do
    # No more pattern to consume
    {acc, ""}
  end

  defp consume_pattern_greedily("", remaining_pattern, _offset, acc) do
    # No more text, return what we found and remaining pattern
    {acc, remaining_pattern}
  end

  defp consume_pattern_greedily(text, pattern, offset, acc) do
    # First, try to find the longest consecutive substring of the pattern in the text
    case find_longest_substring_match(text, pattern) do
      {match_pos, match_len} when match_len > 0 ->
        # Found a consecutive match! Record all positions
        positions = Enum.map(0..(match_len - 1), fn i -> offset + match_pos + i end)
        # Continue after the match with the remaining pattern
        remaining_pattern = String.slice(pattern, match_len..-1//1)
        remaining_text = String.slice(text, (match_pos + match_len)..-1//1)
        consume_pattern_greedily(remaining_text, remaining_pattern, offset + match_pos + match_len, positions ++ acc)

      _ ->
        # No consecutive match found, fall back to single character matching
        <<char::utf8, rest_pattern::binary>> = pattern
        case String.split(text, <<char::utf8>>, parts: 2) do
          [before, after_match] ->
            # Found the character, record its position
            pos = offset + String.length(before)
            # Continue with rest of pattern and rest of text
            consume_pattern_greedily(after_match, rest_pattern, pos + 1, [pos | acc])

          [_] ->
            # Character not found in this text, stop here
            {acc, pattern}
        end
    end
  end

  # Find the longest consecutive substring of pattern that appears in text
  # Returns {position, length} or {0, 0} if no match
  @spec find_longest_substring_match(String.t(), String.t()) :: {integer(), integer()}
  defp find_longest_substring_match(text, pattern) do
    # Try matching progressively shorter prefixes of the pattern
    # Start with the full pattern and work down
    pattern_len = String.length(pattern)
    find_longest_substring_match_helper(text, pattern, pattern_len)
  end

  defp find_longest_substring_match_helper(_text, _pattern, 0), do: {0, 0}

  defp find_longest_substring_match_helper(text, pattern, try_len) do
    prefix = String.slice(pattern, 0, try_len)
    case :binary.match(text, prefix) do
      {pos, ^try_len} ->
        # Found a match of this length!
        {pos, try_len}

      _ ->
        # No match, try shorter prefix
        find_longest_substring_match_helper(text, pattern, try_len - 1)
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
    require Logger
    Logger.info("matches_query? called: query=#{query_lower}, module=#{event.module}")

    Logger.info("matches_query? calling fuzzy_match? on message (#{String.length(event.message)} chars)")

    # Use fuzzy_match? which handles newline splitting, not do_fuzzy_match?
    result = fuzzy_match?(event.message, query_lower) or
      fuzzy_match?(event.module, query_lower) or
      fuzzy_match?(event.level, query_lower)

    Logger.info("matches_query? result=#{result}")
    result
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
