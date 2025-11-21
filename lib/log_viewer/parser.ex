defmodule LogViewer.Parser do
  @moduledoc """
  Parses client and server log files into structured data.
  """

  defmodule ClientLogEntry do
    @moduledoc """
    Represents a single log entry from the client (IndexedDB export).
    """
    @enforce_keys [:timestamp, :level, :module, :key, :messages]
    defstruct [:timestamp, :level, :module, :key, :messages]

    @type t :: %__MODULE__{
            timestamp: integer(),
            level: String.t(),
            module: String.t(),
            key: String.t(),
            messages: list()
          }
  end

  defmodule ClientExport do
    @moduledoc """
    Represents the full export from the client's IndexedDB.
    """
    @enforce_keys [:exported_at, :logs]
    defstruct [:exported_at, :logs]

    @type t :: %__MODULE__{
            exported_at: integer(),
            logs: list(ClientLogEntry.t())
          }
  end

  @doc """
  Parses a JSON string containing client logs from IndexedDB export.

  ## Examples

      iex> json = ~s({"exportedAt": 123456789, "logs": []})
      iex> LogViewer.Parser.parse_client_json(json)
      {:ok, %LogViewer.Parser.ClientExport{exported_at: 123456789, logs: []}}

      iex> LogViewer.Parser.parse_client_json("{invalid json")
      {:error, "Invalid JSON: " <> _}
  """
  @spec parse_client_json(String.t()) :: {:ok, ClientExport.t()} | {:error, String.t()}
  def parse_client_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        parse_client_data(data)

      {:error, error} ->
        {:error, "Invalid JSON: #{inspect(error)}"}
    end
  end

  defp parse_client_data(data) when is_map(data) do
    with {:ok, exported_at} <- get_required_field(data, "exportedAt"),
         {:ok, logs_data} <- get_required_field(data, "logs"),
         {:ok, logs} <- parse_log_entries(logs_data) do
      export = %ClientExport{
        exported_at: exported_at,
        logs: logs
      }

      {:ok, export}
    end
  end

  defp parse_client_data(_), do: {:error, "Invalid data format"}

  defp get_required_field(map, field) do
    case Map.fetch(map, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Missing required field: #{field}"}
    end
  end

  defp parse_log_entries(logs) when is_list(logs) do
    entries =
      Enum.map(logs, fn log ->
        %ClientLogEntry{
          timestamp: Map.get(log, "timestamp"),
          level: Map.get(log, "level"),
          module: Map.get(log, "module"),
          key: Map.get(log, "key"),
          messages: Map.get(log, "messages", [])
        }
      end)

    {:ok, entries}
  end

  defp parse_log_entries(_), do: {:error, "logs must be an array"}
end
