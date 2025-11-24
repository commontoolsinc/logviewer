defmodule LogViewerWeb.Components.EventCard do
  use Phoenix.Component

  alias LogViewer.Search
  alias Phoenix.HTML

  @doc """
  Renders a single log event card.

  ## Examples

      <.event_card event={event} />
      <.event_card event={event} search_query="error" />
      <.event_card event={event} search_query="error" is_current_match={true} id="event-0" />
  """
  attr :event, :map, required: true
  attr :search_query, :string, default: nil
  attr :is_current_match, :boolean, default: false
  attr :id, :string, default: nil

  def event_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "border-b border-gray-200 p-4",
        @is_current_match && "ring-2 ring-blue-500 bg-blue-50",
        !@is_current_match && "hover:bg-gray-50"
      ]}
    >
      <%= if @is_current_match do %>
        <div class="text-lg font-bold text-blue-600 mb-2">⭐ CURRENT MATCH ⭐</div>
      <% end %>
      <div class="flex items-center gap-2 mb-1">
        <span class="text-xs text-gray-500 font-mono">
          <%= format_timestamp(@event.timestamp) %>
        </span>
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
      <p class="text-sm font-mono text-gray-700">
        <%= HTML.raw(Search.highlight_text(@event.message, @search_query)) %>
      </p>
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
