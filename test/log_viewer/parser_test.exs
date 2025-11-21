defmodule LogViewer.ParserTest do
  use ExUnit.Case, async: true

  alias LogViewer.Parser

  @client_fixture_path Path.join([__DIR__, "..", "fixtures", "client_logs.json"])
  @server_fixture_path Path.join([__DIR__, "..", "fixtures", "server_logs.txt"])

  describe "parse_client_json/1" do
    test "parses valid client JSON export" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      assert export.exported_at == 1_732_204_800_000
      assert is_list(export.logs)
      assert length(export.logs) == 4
    end

    test "extracts timestamp, level, module, key, messages" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      [first_log | _] = export.logs

      assert first_log.timestamp == 1_732_204_800_100
      assert first_log.level == "info"
      assert first_log.module == "memory"
      assert first_log.key == "storage"
      assert first_log.messages == [
        "Stored doc",
        "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      ]
    end

    test "handles multiple log entries" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      assert length(export.logs) == 4

      # Check different log levels are preserved
      levels = Enum.map(export.logs, & &1.level)
      assert "info" in levels
      assert "debug" in levels
      assert "error" in levels
      assert "warn" in levels
    end

    test "returns error for invalid JSON" do
      invalid_json = "{this is not valid json"

      assert {:error, reason} = Parser.parse_client_json(invalid_json)
      assert reason =~ "Invalid JSON"
    end

    test "returns error for missing required fields" do
      # Missing 'logs' field
      invalid_export = ~s({"exportedAt": 123456789})

      assert {:error, reason} = Parser.parse_client_json(invalid_export)
      assert reason =~ "Invalid data"
      assert reason =~ "can't be blank"
    end

    test "handles messages with mixed types" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)

      # Find the log with mixed message types (string and number)
      warn_log = Enum.find(export.logs, fn log -> log.level == "warn" end)
      assert warn_log.messages == ["Task delayed by", 150, "ms"]
    end

    test "handles messages with nested objects" do
      json = File.read!(@client_fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)

      # Find the log with object in messages
      debug_log = Enum.find(export.logs, fn log -> log.level == "debug" end)
      assert is_list(debug_log.messages)
      assert length(debug_log.messages) == 2

      # Second message should be a map with charmId
      [_first, second] = debug_log.messages
      assert is_map(second)
      assert Map.has_key?(second, "charmId")
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
end
