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

  # Private helper to check if an event matches the query
  @spec matches_query?(LogEvent.t(), String.t()) :: boolean()
  defp matches_query?(event, query_lower) when is_binary(query_lower) do
    message_lower = String.downcase(event.message)
    module_lower = String.downcase(event.module)
    level_lower = String.downcase(event.level)

    String.contains?(message_lower, query_lower) or
      String.contains?(module_lower, query_lower) or
      String.contains?(level_lower, query_lower)
  end
end
