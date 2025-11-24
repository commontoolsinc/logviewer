defmodule LogViewerWeb.TimelineLive do
  use LogViewerWeb, :live_view

  alias LogViewer.Parser
  alias LogViewer.Timeline
  alias LogViewer.EntityExtractor
  alias LogViewer.Search
  alias LogViewerWeb.Components.EventCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:timeline, [])
     |> assign(:entity_index, nil)
     |> assign(:search_query, "")
     |> assign(:current_match_index, 0)
     |> assign(:filtered_timeline, [])
     |> allow_upload(:log_files,
       accept: ~w(.json .log),
       max_entries: 10,
       max_file_size: 100_000_000,
       auto_upload: true,
       progress: &__MODULE__.handle_progress/3
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :log_files, ref)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered = Search.search_timeline(socket.assigns.timeline, query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_timeline, filtered)
     |> assign(:current_match_index, 0)}
  end

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    filtered = Search.search_timeline(socket.assigns.timeline, value)

    {:noreply,
     socket
     |> assign(:search_query, value)
     |> assign(:filtered_timeline, filtered)
     |> assign(:current_match_index, 0)}
  end

  @impl true
  def handle_event("next_match", _params, socket) do
    total_matches = length(socket.assigns.filtered_timeline)

    new_index =
      if total_matches > 0 do
        rem(socket.assigns.current_match_index + 1, total_matches)
      else
        0
      end

    {:noreply,
     socket
     |> assign(:current_match_index, new_index)
     |> push_event("scroll_to_match", %{id: "event-#{new_index}"})}
  end

  @impl true
  def handle_event("prev_match", _params, socket) do
    total_matches = length(socket.assigns.filtered_timeline)

    new_index =
      if total_matches > 0 do
        rem(socket.assigns.current_match_index - 1 + total_matches, total_matches)
      else
        0
      end

    {:noreply,
     socket
     |> assign(:current_match_index, new_index)
     |> push_event("scroll_to_match", %{id: "event-#{new_index}"})}
  end

  # Note: handle_progress is not a LiveView callback, it's passed to allow_upload
  # so it doesn't need @impl true
  def handle_progress(:log_files, entry, socket) do
    require Logger

    if entry.done? do
      Logger.info("Entry done, consuming: #{entry.client_name}")

      content =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          file_size = File.stat!(path).size
          Logger.info("Reading file from path: #{path}, size: #{file_size} bytes")
          {:ok, File.read!(path)}
        end)

      Logger.info("File consumed, content size: #{byte_size(content)} bytes, parsing...")
      updated_socket = process_uploaded_file(socket, content)
      Logger.info("File processed, timeline length: #{length(updated_socket.assigns.timeline)}")

      {:noreply, updated_socket}
    else
      {:noreply, socket}
    end
  end

  @spec process_uploaded_file(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp process_uploaded_file(socket, content) when is_binary(content) do
    require Logger
    Logger.info("Starting parser detection for #{byte_size(content)} bytes...")
    start_time = System.monotonic_time(:millisecond)

    case Parser.detect_and_parse(content) do
      {:ok, :client, client_logs} ->
        parse_time = System.monotonic_time(:millisecond) - start_time
        Logger.info("Parsed #{length(client_logs)} client log entries in #{parse_time}ms")
        add_logs_to_timeline(socket, client_logs, [])

      {:ok, :server, server_logs} ->
        parse_time = System.monotonic_time(:millisecond) - start_time
        Logger.info("Parsed #{length(server_logs)} server log entries in #{parse_time}ms")
        add_logs_to_timeline(socket, [], server_logs)

      {:error, :unknown_format} ->
        Logger.warning("Unknown log format detected")
        # Invalid format - keep current state
        socket
    end
  end

  @spec add_logs_to_timeline(
          Phoenix.LiveView.Socket.t(),
          list(Parser.ClientLogEntry.t()),
          list(Parser.ServerLogEntry.t())
        ) :: Phoenix.LiveView.Socket.t()
  defp add_logs_to_timeline(socket, new_client_logs, new_server_logs)
       when is_list(new_client_logs) and is_list(new_server_logs) do
    # Get existing logs from current timeline
    existing_timeline = socket.assigns.timeline

    # Extract existing client and server logs
    existing_client_events =
      existing_timeline
      |> Enum.filter(&(&1.source == :client))
      |> Enum.map(& &1.raw_entry)

    existing_server_events =
      existing_timeline
      |> Enum.filter(&(&1.source == :server))
      |> Enum.map(& &1.raw_entry)

    # Combine with new logs
    all_client_logs = existing_client_events ++ new_client_logs
    all_server_logs = existing_server_events ++ new_server_logs

    # Rebuild timeline with all logs
    timeline = Timeline.build_timeline(all_client_logs, all_server_logs)

    # Build entity index
    entity_index = EntityExtractor.build_entity_index(timeline)

    socket
    |> assign(:timeline, timeline)
    |> assign(:entity_index, entity_index)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8">
      <h1 class="text-3xl font-bold mb-8">Log Viewer</h1>

      <div class="mb-8">
        <h2 class="text-xl font-semibold mb-4">Upload Log Files</h2>

        <form id="upload-form" phx-submit="save" phx-change="validate">
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
            <.live_file_input upload={@uploads.log_files} class="hidden" />
            <label
              for={@uploads.log_files.ref}
              class="cursor-pointer inline-block bg-blue-500 text-white px-6 py-3 rounded-lg hover:bg-blue-600"
            >
              Choose Files
            </label>
            <p class="mt-4 text-gray-600">
              Upload .json or .log files
            </p>
          </div>

          <%= for entry <- @uploads.log_files.entries do %>
            <div class="mt-4 flex items-center justify-between bg-gray-50 p-3 rounded">
              <span class="text-sm"><%= entry.client_name %></span>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="text-red-500 hover:text-red-700"
              >
                ✕
              </button>
            </div>
          <% end %>
        </form>
      </div>

      <%= if length(@timeline) > 0 do %>
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold">
              Timeline
              <%= if @search_query != "" do %>
                - Showing <%= length(@filtered_timeline) %> of <%= length(@timeline) %> events
              <% else %>
                (<%= length(@timeline) %> events)
              <% end %>
            </h2>
          </div>

          <div class="sticky top-0 bg-white border-b z-10 pb-4 mb-4">
            <form phx-change="search" class="flex gap-2 items-center">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search logs..."
                class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="search"
                  phx-value-query=""
                  class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
                >
                  Clear
                </button>
              <% end %>
              <%= if @search_query != "" and length(@filtered_timeline) > 0 do %>
                <div class="flex items-center gap-2 ml-4">
                  <span class="text-sm text-gray-600 whitespace-nowrap">
                    Match <%= @current_match_index + 1 %> of <%= length(@filtered_timeline) %>
                  </span>
                  <button
                    type="button"
                    phx-click="prev_match"
                    class="px-3 py-1 border border-gray-300 rounded hover:bg-gray-100"
                    title="Previous match"
                  >
                    ↑
                  </button>
                  <button
                    type="button"
                    phx-click="next_match"
                    class="px-3 py-1 border border-gray-300 rounded hover:bg-gray-100"
                    title="Next match"
                  >
                    ↓
                  </button>
                </div>
              <% end %>
            </form>
          </div>

          <div class="bg-white shadow rounded-lg pb-96">
            <%= if @search_query != "" do %>
              <%= for {event, index} <- Enum.with_index(Enum.take(@filtered_timeline, 50)) do %>
                <EventCard.event_card
                  event={event}
                  search_query={@search_query}
                  is_current_match={index == @current_match_index}
                  id={"event-#{index}"}
                />
              <% end %>
            <% else %>
              <%= for event <- Enum.take(@timeline, 50) do %>
                <EventCard.event_card event={event} search_query={@search_query} />
              <% end %>
            <% end %>
            <%= if @search_query != "" and length(@filtered_timeline) > 50 do %>
              <div class="p-4 text-center text-gray-500 bg-gray-50">
                Showing first 50 of <%= length(@filtered_timeline) %> matching events
              </div>
            <% end %>
            <%= if @search_query == "" and length(@timeline) > 50 do %>
              <div class="p-4 text-center text-gray-500 bg-gray-50">
                Showing first 50 of <%= length(@timeline) %> events
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @entity_index && map_size(@entity_index.entities) > 0 do %>
        <div class="mb-8">
          <h2 class="text-xl font-semibold mb-4">
            Entities (<%= map_size(@entity_index.entities) %>)
          </h2>
          <div class="grid grid-cols-3 gap-4">
            <div class="bg-white shadow rounded-lg p-4">
              <h3 class="font-semibold mb-2">DocIDs (<%= length(@entity_index.by_type.doc_ids) %>)</h3>
              <div class="text-xs text-gray-600">
                <%= for doc_id <- Enum.take(@entity_index.by_type.doc_ids, 5) do %>
                  <div class="truncate mb-1" title={doc_id}><%= doc_id %></div>
                <% end %>
              </div>
            </div>
            <div class="bg-white shadow rounded-lg p-4">
              <h3 class="font-semibold mb-2">
                CharmIDs (<%= length(@entity_index.by_type.charm_ids) %>)
              </h3>
              <div class="text-xs text-gray-600">
                <%= for charm_id <- Enum.take(@entity_index.by_type.charm_ids, 5) do %>
                  <div class="truncate mb-1" title={charm_id}><%= charm_id %></div>
                <% end %>
              </div>
            </div>
            <div class="bg-white shadow rounded-lg p-4">
              <h3 class="font-semibold mb-2">
                SpaceIDs (<%= length(@entity_index.by_type.space_ids) %>)
              </h3>
              <div class="text-xs text-gray-600">
                <%= for space_id <- Enum.take(@entity_index.by_type.space_ids, 5) do %>
                  <div class="truncate mb-1" title={space_id}><%= space_id %></div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
