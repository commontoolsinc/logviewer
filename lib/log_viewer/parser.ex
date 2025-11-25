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

  defmodule ClientJSONData do
    @moduledoc """
    Raw JSON data structure from Jason.decode/1 before parsing.
    Uses Ecto for validation and type casting.
    Maps directly to the JSON structure with camelCase field names.

    Matches the production client log export format.
    """
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      # Timestamp from production format
      field :exportedTimestamp, :integer

      # Additional metadata from real client logs
      field :exported, :string
      field :dbName, :string
      field :storeName, :string
      field :totalEntries, :integer
      field :sessionInfo, :map

      # Log entries (required)
      field :logs, {:array, :map}
    end

    @type t :: %__MODULE__{
            exportedTimestamp: integer(),
            exported: String.t() | nil,
            dbName: String.t() | nil,
            storeName: String.t() | nil,
            totalEntries: integer() | nil,
            sessionInfo: map() | nil,
            logs: list(map())
          }

    @spec changeset(map()) :: Ecto.Changeset.t()
    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:exportedTimestamp, :exported, :dbName, :storeName, :totalEntries, :sessionInfo, :logs])
      |> validate_required([:exportedTimestamp, :logs])
    end
  end

  defmodule ClientParsedData do
    @moduledoc """
    Fully parsed client log export with validated and structured data.
    Uses Elixir naming conventions (snake_case).
    """
    @enforce_keys [:exported_at, :logs]
    defstruct [:exported_at, :logs]

    @type t :: %__MODULE__{
            exported_at: integer(),
            logs: list(ClientLogEntry.t())
          }
  end

  defmodule ServerLogEntry do
    @moduledoc """
    Represents a single log entry from the server (toolshed text format).
    """
    @enforce_keys [:timestamp, :level, :module, :message]
    defstruct [:timestamp, :level, :module, :message]

    @type t :: %__MODULE__{
            timestamp: integer(),
            level: String.t(),
            module: String.t(),
            message: String.t()
          }
  end

  @doc """
  Parses a JSON string containing client logs from IndexedDB export.

  ## Examples

      iex> json = ~s({"exportedTimestamp": 123456789, "logs": []})
      iex> LogViewer.Parser.parse_client_json(json)
      {:ok, %LogViewer.Parser.ClientParsedData{exported_at: 123456789, logs: []}}

      iex> LogViewer.Parser.parse_client_json("{invalid json")
      {:error, "Invalid JSON: " <> _}
  """
  @spec parse_client_json(String.t()) :: {:ok, ClientParsedData.t()} | {:error, String.t()}
  def parse_client_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        parse_client_data(data)

      {:error, error} ->
        {:error, "Invalid JSON: #{inspect(error)}"}
    end
  end

  @spec parse_client_data(map()) :: {:ok, ClientParsedData.t()} | {:error, String.t()}
  defp parse_client_data(data) when is_map(data) do
    changeset = ClientJSONData.changeset(data)

    case changeset do
      %{valid?: true} ->
        # Pattern match to extract validated fields
        %ClientJSONData{exportedTimestamp: exported_timestamp, logs: logs_data} =
          Ecto.Changeset.apply_changes(changeset)

        # Parse log entries
        {:ok, logs} = parse_log_entries(logs_data)
        {:ok, %ClientParsedData{exported_at: exported_timestamp, logs: logs}}

      %{valid?: false} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        {:error, "Invalid data: #{inspect(errors)}"}
    end
  end

  @spec parse_log_entries(list(map())) :: {:ok, list(ClientLogEntry.t())}
  defp parse_log_entries(logs) when is_list(logs) do
    entries =
      Enum.map(logs, fn log ->
        struct!(ClientLogEntry, Map.new(log, fn {k, v} -> {String.to_atom(k), v} end))
      end)

    {:ok, entries}
  end

  @doc """
  Parses server logs in multiple formats.

  Supports two formats:
  1. Toolshed: [LEVEL][module::HH:MM:SS.mmm] message
  2. Pino: [HH:MM:SS.mmm] LEVEL (pid): message

  Multi-line messages are supported - lines that don't match either pattern
  are appended to the previous log entry's message.

  ## Examples

      iex> text = "[INFO][test::14:30:45.123] Test message"
      iex> [log] = LogViewer.Parser.parse_server_logs(text)
      iex> log.level
      "INFO"
      iex> log.module
      "test"
      iex> log.message
      "Test message"
  """
  @spec parse_server_logs(String.t()) :: list(ServerLogEntry.t())
  def parse_server_logs(text) when is_binary(text) do
    # Toolshed pattern: [LEVEL][module::HH:MM:SS.mmm] message
    toolshed_pattern = ~r/^\[([A-Z]+)\]\[([^:]+)::(\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s*(.*)$/
    # Pino pattern: [HH:MM:SS.mmm] LEVEL (pid): message
    pino_pattern = ~r/^\[(\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s+([A-Z]+)\s+\(\d+\):\s*(.*)$/

    text
    |> String.split("\n", trim: true)
    |> Enum.reduce([], fn line, acc ->
      case parse_server_log_line(line, toolshed_pattern, pino_pattern) do
        %ServerLogEntry{} = entry ->
          # New log entry - add to accumulator
          [entry | acc]

        nil ->
          # Continuation line - append to previous entry if one exists
          case acc do
            [prev | rest] ->
              updated = %{prev | message: prev.message <> "\n" <> line}
              [updated | rest]

            [] ->
              # No previous entry, skip this line
              acc
          end
      end
    end)
    |> Enum.reverse()
  end

  @spec parse_server_log_line(String.t(), Regex.t(), Regex.t()) :: ServerLogEntry.t() | nil
  defp parse_server_log_line(line, toolshed_pattern, pino_pattern) when is_binary(line) do
    # Try toolshed format first
    case Regex.run(toolshed_pattern, line) do
      [_, level, module, hours, minutes, seconds, millis, message] ->
        timestamp = build_timestamp(hours, minutes, seconds, millis)

        %ServerLogEntry{
          timestamp: timestamp,
          level: level,
          module: module,
          message: message
        }

      nil ->
        # Try pino format
        case Regex.run(pino_pattern, line) do
          [_, hours, minutes, seconds, millis, level, message] ->
            timestamp = build_timestamp(hours, minutes, seconds, millis)

            %ServerLogEntry{
              timestamp: timestamp,
              level: level,
              module: "pino",
              message: message
            }

          nil ->
            # No match - this is a continuation line
            nil
        end
    end
  end

  @spec build_timestamp(String.t(), String.t(), String.t(), String.t()) :: integer()
  defp build_timestamp(hours, minutes, seconds, millis)
      when is_binary(hours) and is_binary(minutes) and is_binary(seconds) and is_binary(millis) do
    # Get today's date
    today = Date.utc_today()

    # Build time from string parts
    {:ok, time} =
      Time.new(
        String.to_integer(hours),
        String.to_integer(minutes),
        String.to_integer(seconds),
        String.to_integer(millis) * 1000
      )

    # Combine date and time into DateTime
    {:ok, datetime} = DateTime.new(today, time, "Etc/UTC")

    # Return as Unix milliseconds
    DateTime.to_unix(datetime, :millisecond)
  end

  @doc """
  Detects log format and parses the content automatically.

  Tries to parse as JSON client logs first, then as text server logs.
  Returns the log type along with parsed entries.

  ## Examples

      iex> json = ~s({"exportedTimestamp": 123, "logs": []})
      iex> {:ok, :client, logs} = LogViewer.Parser.detect_and_parse(json)
      iex> is_list(logs)
      true
  """
  @spec detect_and_parse(String.t()) ::
          {:ok, :client, list(ClientLogEntry.t())}
          | {:ok, :server, list(ServerLogEntry.t())}
          | {:error, :unknown_format}
  def detect_and_parse(content) when is_binary(content) do
    cond do
      # Try parsing as JSON client log
      json_result = try_parse_client(content) ->
        json_result

      # Try parsing as server text log
      text_result = try_parse_server(content) ->
        text_result

      # Unknown format
      true ->
        {:error, :unknown_format}
    end
  end

  # Attempt to parse as client JSON logs
  @spec try_parse_client(String.t()) ::
          {:ok, :client, list(ClientLogEntry.t())} | false
  defp try_parse_client(content) when is_binary(content) do
    case parse_client_json(content) do
      {:ok, %ClientParsedData{logs: logs}} when is_list(logs) and length(logs) > 0 ->
        {:ok, :client, logs}

      _ ->
        false
    end
  end

  # Attempt to parse as server text logs
  @spec try_parse_server(String.t()) ::
          {:ok, :server, list(ServerLogEntry.t())} | false
  defp try_parse_server(content) when is_binary(content) do
    case parse_server_logs(content) do
      logs when is_list(logs) and length(logs) > 0 ->
        {:ok, :server, logs}

      _ ->
        false
    end
  end
end
