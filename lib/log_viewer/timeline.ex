defmodule LogViewer.Timeline do
  @moduledoc """
  Builds unified timelines from client and server logs.
  """

  alias LogViewer.Parser.{ClientLogEntry, ServerLogEntry}

  defmodule LogEvent do
    @moduledoc """
    A normalized log event from either client or server.
    """
    @enforce_keys [:timestamp, :level, :module, :message, :source]
    defstruct [:timestamp, :level, :module, :message, :source, :raw_entry]

    @type t :: %__MODULE__{
            timestamp: integer(),
            level: String.t(),
            module: String.t(),
            message: String.t(),
            source: :client | :server,
            raw_entry: ClientLogEntry.t() | ServerLogEntry.t()
          }
  end

  @doc """
  Converts a ClientLogEntry to a LogEvent.

  ## Examples

      iex> entry = %LogViewer.Parser.ClientLogEntry{
      ...>   timestamp: 1732204800100,
      ...>   level: "info",
      ...>   module: "memory",
      ...>   key: "storage",
      ...>   messages: ["Stored doc", "baedreic7dvj..."]
      ...> }
      iex> event = LogViewer.Timeline.from_client_entry(entry)
      iex> event.message
      "Stored doc baedreic7dvj..."
      iex> event.source
      :client
  """
  @spec from_client_entry(ClientLogEntry.t()) :: LogEvent.t()
  def from_client_entry(%ClientLogEntry{} = entry) do
    %LogEvent{
      timestamp: entry.timestamp,
      level: entry.level,
      module: entry.module,
      message: messages_to_string(entry.messages),
      source: :client,
      raw_entry: entry
    }
  end

  @doc """
  Converts a ServerLogEntry to a LogEvent.

  ## Examples

      iex> entry = %LogViewer.Parser.ServerLogEntry{
      ...>   timestamp: 1732204800200,
      ...>   level: "INFO",
      ...>   module: "toolshed",
      ...>   message: "Server started"
      ...> }
      iex> event = LogViewer.Timeline.from_server_entry(entry)
      iex> event.message
      "Server started"
      iex> event.source
      :server
  """
  @spec from_server_entry(ServerLogEntry.t()) :: LogEvent.t()
  def from_server_entry(%ServerLogEntry{} = entry) do
    %LogEvent{
      timestamp: entry.timestamp,
      level: entry.level,
      module: entry.module,
      message: entry.message,
      source: :server,
      raw_entry: entry
    }
  end

  @doc """
  Builds a unified timeline from client and server logs.

  Merges both log sources and sorts by timestamp.

  ## Examples

      iex> client_logs = [%LogViewer.Parser.ClientLogEntry{
      ...>   timestamp: 100,
      ...>   level: "info",
      ...>   module: "test",
      ...>   key: "key",
      ...>   messages: ["First"]
      ...> }]
      iex> server_logs = [%LogViewer.Parser.ServerLogEntry{
      ...>   timestamp: 200,
      ...>   level: "INFO",
      ...>   module: "test",
      ...>   message: "Second"
      ...> }]
      iex> timeline = LogViewer.Timeline.build_timeline(client_logs, server_logs)
      iex> length(timeline)
      2
      iex> Enum.at(timeline, 0).message
      "First"
  """
  @spec build_timeline(list(ClientLogEntry.t()), list(ServerLogEntry.t())) ::
          list(LogEvent.t())
  def build_timeline(client_logs, server_logs)
      when is_list(client_logs) and is_list(server_logs) do
    client_events = Enum.map(client_logs, &from_client_entry/1)
    server_events = Enum.map(server_logs, &from_server_entry/1)

    (client_events ++ server_events)
    |> Enum.sort_by(& &1.timestamp)
  end

  @spec messages_to_string(list()) :: String.t()
  defp messages_to_string(messages) when is_list(messages) do
    messages
    |> Enum.map(&message_part_to_string/1)
    |> Enum.join(" ")
  end

  # Convert a message part to string, handling maps/lists as JSON and nil as empty string
  defp message_part_to_string(nil), do: ""
  defp message_part_to_string(part) when is_map(part), do: Jason.encode!(part)
  defp message_part_to_string(part) when is_list(part), do: Jason.encode!(part)
  defp message_part_to_string(part), do: to_string(part)
end
