defmodule LogViewerWeb.Components.EventCard do
  use Phoenix.Component

  @doc """
  Renders a single log event card.

  ## Examples

      <.event_card event={event} />
      <.event_card event={event} search_query="error" />
  """
  attr :event, :map, required: true
  attr :search_query, :string, default: nil

  def event_card(assigns) do
    ~H"""
    <div class="border-b border-gray-200 p-4 hover:bg-gray-50">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-1">
            <span class={[
              "px-2 py-1 text-xs rounded",
              source_badge_color(@event.source)
            ]}>
              <%= @event.source %>
            </span>
            <span class={[
              "px-2 py-1 text-xs rounded",
              level_badge_color(@event.level)
            ]}>
              <%= @event.level %>
            </span>
            <span class="text-xs text-gray-500"><%= @event.module %></span>
          </div>
          <p class="text-sm font-mono text-gray-700"><%= @event.message %></p>
        </div>
        <span class="text-xs text-gray-400 ml-4">
          <%= format_timestamp(@event.timestamp) %>
        </span>
      </div>
    </div>
    """
  end

  defp source_badge_color(:client), do: "bg-blue-100 text-blue-800"
  defp source_badge_color(:server), do: "bg-green-100 text-green-800"
  defp source_badge_color(_), do: "bg-gray-100 text-gray-800"

  defp level_badge_color("error"), do: "bg-red-100 text-red-800"
  defp level_badge_color("ERROR"), do: "bg-red-100 text-red-800"
  defp level_badge_color("warn"), do: "bg-yellow-100 text-yellow-800"
  defp level_badge_color("WARN"), do: "bg-yellow-100 text-yellow-800"
  defp level_badge_color("info"), do: "bg-blue-100 text-blue-800"
  defp level_badge_color("INFO"), do: "bg-blue-100 text-blue-800"
  defp level_badge_color("debug"), do: "bg-gray-100 text-gray-800"
  defp level_badge_color("DEBUG"), do: "bg-gray-100 text-gray-800"
  defp level_badge_color(_), do: "bg-gray-100 text-gray-800"

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    datetime = DateTime.from_unix!(timestamp, :millisecond)
    Calendar.strftime(datetime, "%H:%M:%S.%f")
  end
end
