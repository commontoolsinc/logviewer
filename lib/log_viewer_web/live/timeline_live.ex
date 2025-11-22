defmodule LogViewerWeb.TimelineLive do
  use LogViewerWeb, :live_view

  alias LogViewer.Parser
  alias LogViewer.Timeline
  alias LogViewer.EntityExtractor

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:timeline, [])
     |> assign(:entity_index, nil)
     |> allow_upload(:log_files,
       accept: ~w(.json .txt),
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
              Upload client.json and/or server.txt files
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
          <h2 class="text-xl font-semibold mb-4">
            Timeline (<%= length(@timeline) %> events)
          </h2>
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <%= for event <- Enum.take(@timeline, 50) do %>
              <div class="border-b border-gray-200 p-4 hover:bg-gray-50">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <span class={[
                        "px-2 py-1 text-xs rounded",
                        if(event.source == :client,
                          do: "bg-blue-100 text-blue-800",
                          else: "bg-green-100 text-green-800"
                        )
                      ]}>
                        <%= event.source %>
                      </span>
                      <span class={[
                        "px-2 py-1 text-xs rounded",
                        level_color(event.level)
                      ]}>
                        <%= event.level %>
                      </span>
                      <span class="text-xs text-gray-500"><%= event.module %></span>
                    </div>
                    <p class="text-sm font-mono text-gray-700"><%= event.message %></p>
                  </div>
                  <span class="text-xs text-gray-400 ml-4">
                    <%= format_timestamp(event.timestamp) %>
                  </span>
                </div>
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

  defp level_color("error"), do: "bg-red-100 text-red-800"
  defp level_color("ERROR"), do: "bg-red-100 text-red-800"
  defp level_color("warn"), do: "bg-yellow-100 text-yellow-800"
  defp level_color("WARN"), do: "bg-yellow-100 text-yellow-800"
  defp level_color("info"), do: "bg-blue-100 text-blue-800"
  defp level_color("INFO"), do: "bg-blue-100 text-blue-800"
  defp level_color("debug"), do: "bg-gray-100 text-gray-800"
  defp level_color("DEBUG"), do: "bg-gray-100 text-gray-800"
  defp level_color(_), do: "bg-gray-100 text-gray-800"

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    datetime = DateTime.from_unix!(timestamp, :millisecond)
    Calendar.strftime(datetime, "%H:%M:%S.%f")
  end
end
