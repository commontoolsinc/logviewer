defmodule LogViewer.ParserTest do
  use ExUnit.Case, async: true

  alias LogViewer.Parser
  alias LogViewer.Parser.{ClientLogEntry, ServerLogEntry}

  @client_fixture_path Path.join([__DIR__, "..", "fixtures", "client_logs.json"])
  @server_fixture_path Path.join([__DIR__, "..", "fixtures", "server_logs.log"])

  describe "parse_client_json/1" do
    test "parses valid client JSON export" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      # Real production format uses exportedTimestamp
      assert export.exported_at == 1_763_755_382_416
      assert is_list(export.logs)
      assert length(export.logs) == 8
    end

    test "extracts timestamp, level, module, key, messages" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      [first_log | _] = export.logs

      # Real production log data
      assert first_log.timestamp == 1_763_753_972_077
      assert first_log.level == "error"
      assert first_log.module == "extended-storage-transaction"
      assert first_log.key == "storage-error"
      assert is_list(first_log.messages)
      assert length(first_log.messages) == 4
      assert List.first(first_log.messages) == "read Error"
    end

    test "handles multiple log entries" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      assert length(export.logs) == 8

      # Check different log levels are preserved (real data has error, info, and debug)
      levels = Enum.map(export.logs, & &1.level)
      assert "info" in levels
      assert "error" in levels
      assert "debug" in levels
    end

    test "returns error for invalid JSON" do
      invalid_json = "{this is not valid json"

      assert {:error, reason} = Parser.parse_client_json(invalid_json)
      assert reason =~ "Invalid JSON"
    end

    test "returns error for missing required fields" do
      # Missing 'logs' field
      invalid_export = ~s({"exportedTimestamp": 123456789})

      assert {:error, reason} = Parser.parse_client_json(invalid_export)
      assert reason =~ "Invalid data"
      assert reason =~ "can't be blank"
    end

    test "handles messages with mixed types" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)

      # Real production data has messages with strings, objects, and null
      [first_log | _] = export.logs
      assert is_list(first_log.messages)
      # Messages contain: string, empty map, object, null
      assert length(first_log.messages) == 4
      assert is_binary(Enum.at(first_log.messages, 0))  # "read Error"
      assert is_map(Enum.at(first_log.messages, 1))     # {}
      assert is_map(Enum.at(first_log.messages, 2))     # storage address object
      assert is_nil(Enum.at(first_log.messages, 3))     # null
    end

    test "handles messages with nested objects" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)

      # Real production data has complex nested objects in messages
      [first_log | _] = export.logs
      # Third message is a storage address object with nested structure
      storage_obj = Enum.at(first_log.messages, 2)
      assert is_map(storage_obj)
      assert Map.has_key?(storage_obj, "id")
      assert Map.has_key?(storage_obj, "path")
      assert is_list(storage_obj["path"])
    end

    test "parses real client logs with exportedTimestamp format" do
      # Real production format with exportedTimestamp instead of exportedAt
      json = ~s({
        "exported": "2025-11-21T20:03:02.416Z",
        "exportedTimestamp": 1763755382416,
        "dbName": "ct-client-logs",
        "storeName": "entries",
        "totalEntries": 2,
        "sessionInfo": {
          "userAgent": "Mozilla/5.0",
          "url": "http://localhost:5173",
          "platform": "Linux x86_64"
        },
        "logs": [
          {
            "timestamp": 1763753972077,
            "level": "error",
            "module": "storage",
            "key": "read-error",
            "messages": ["Error reading", "doc123"]
          },
          {
            "timestamp": 1763753972100,
            "level": "info",
            "module": "cache",
            "key": "hit",
            "messages": ["Cache hit", "key456"]
          }
        ]
      })

      assert {:ok, export} = Parser.parse_client_json(json)
      assert export.exported_at == 1763755382416
      assert length(export.logs) == 2
      assert List.first(export.logs).level == "error"
    end

    test "rejects when exportedTimestamp is missing" do
      # Missing exportedTimestamp field
      json = ~s({
        "dbName": "ct-client-logs",
        "logs": [
          {
            "timestamp": 123,
            "level": "info",
            "module": "test",
            "key": "key",
            "messages": ["msg"]
          }
        ]
      })

      assert {:error, reason} = Parser.parse_client_json(json)
      assert reason =~ "Invalid data"
      assert reason =~ "exportedTimestamp"
    end

    test "accepts production format with all metadata fields" do
      json = ~s({
        "exportedTimestamp": 1763755382416,
        "exported": "2025-11-21T20:03:02.416Z",
        "dbName": "ct-client-logs",
        "storeName": "entries",
        "totalEntries": 1,
        "sessionInfo": {
          "userAgent": "Mozilla/5.0",
          "url": "http://localhost:5173",
          "platform": "Linux x86_64"
        },
        "logs": [
          {
            "timestamp": 123,
            "level": "info",
            "module": "test",
            "key": "key",
            "messages": ["msg"]
          }
        ]
      })

      assert {:ok, export} = Parser.parse_client_json(json)
      assert export.exported_at == 1763755382416
      assert length(export.logs) == 1
    end
  end

  describe "parse_server_logs/1" do
    test "parses toolshed format [LEVEL][module::HH:MM:SS.mmm] message" do
      text = File.read!(@server_fixture_path)

      logs = Parser.parse_server_logs(text)
      assert is_list(logs)
      assert length(logs) == 7  # 7 valid log lines (1 malformed line skipped)

      [first | _] = logs
      assert first.level == "INFO"
      assert first.module == "toolshed"
      assert first.message == "Server started on port 8000"
      assert is_integer(first.timestamp)
    end

    test "handles multiple lines" do
      text = File.read!(@server_fixture_path)

      logs = Parser.parse_server_logs(text)
      assert length(logs) == 7

      # Check different log levels
      levels = Enum.map(logs, & &1.level)
      assert "INFO" in levels
      assert "DEBUG" in levels
      assert "ERROR" in levels
      assert "WARN" in levels
    end

    test "constructs full timestamp from time-of-day" do
      text = "[INFO][test::14:30:45.123] Test message"

      [log] = Parser.parse_server_logs(text)

      # Timestamp should be today's date + the time
      assert is_integer(log.timestamp)
      # Should be in milliseconds (13 digits)
      assert log.timestamp > 1_000_000_000_000
    end

    test "skips malformed lines gracefully" do
      text = """
      [INFO][test::14:30:45.123] Valid line
      This is not a valid log line
      [ERROR][test::14:30:45.456] Another valid line
      """

      logs = Parser.parse_server_logs(text)
      assert length(logs) == 2
      assert Enum.at(logs, 0).message == "Valid line"
      assert Enum.at(logs, 1).message == "Another valid line"
    end

    test "handles empty file" do
      logs = Parser.parse_server_logs("")
      assert logs == []
    end

    test "extracts module and message correctly" do
      text = File.read!(@server_fixture_path)

      logs = Parser.parse_server_logs(text)

      # Find the memory log
      memory_log = Enum.find(logs, fn log -> log.module == "memory" end)
      assert memory_log != nil
      assert memory_log.message =~ "Stored doc"
    end
  end

  describe "detect_and_parse/1" do
    test "detects and parses client JSON logs" do
      content = File.read!(@client_fixture_path)

      assert {:ok, :client, logs} = Parser.detect_and_parse(content)
      assert is_list(logs)
      assert length(logs) > 0
      assert %ClientLogEntry{} = List.first(logs)
    end

    test "detects and parses server text logs" do
      content = File.read!(@server_fixture_path)

      assert {:ok, :server, logs} = Parser.detect_and_parse(content)
      assert is_list(logs)
      assert length(logs) > 0
      assert %ServerLogEntry{} = List.first(logs)
    end

    test "returns error for invalid JSON" do
      content = "{invalid json]"

      assert {:error, :unknown_format} = Parser.detect_and_parse(content)
    end

    test "returns error for plain text that doesn't match server format" do
      content = "Just some random text\nwith no log structure"

      assert {:error, :unknown_format} = Parser.detect_and_parse(content)
    end

    test "returns error for empty string" do
      assert {:error, :unknown_format} = Parser.detect_and_parse("")
    end
  end
end
