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
  Highlights matching text in a string by wrapping it in HTML mark tags.

  Performs case-insensitive matching and escapes special regex characters.
  Returns original text if query is nil or empty.

  ## Examples

      iex> Search.highlight_text("Error in storage", "storage")
      "Error in <mark class=\\"bg-yellow-200\\">storage</mark>"

      iex> Search.highlight_text("Some text", "")
      "Some text"
  """
  @spec highlight_text(String.t(), String.t() | nil) :: String.t()
  def highlight_text(text, query) when is_binary(text) and (is_binary(query) or is_nil(query)) do
    cond do
      is_nil(query) or query == "" ->
        text

      true ->
        # Escape special regex characters
        escaped_query = Regex.escape(query)

        # Create case-insensitive regex
        regex = Regex.compile!(escaped_query, "i")

        # Replace all matches with highlighted version
        Regex.replace(regex, text, fn match ->
          ~s(<mark class="bg-yellow-200">#{match}</mark>)
        end)
    end
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
