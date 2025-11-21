defmodule LogViewer.ParserTest do
  use ExUnit.Case, async: true

  alias LogViewer.Parser

  @fixture_path Path.join([__DIR__, "..", "fixtures", "client_logs.json"])

  describe "parse_client_json/1" do
    test "parses valid client JSON export" do
      json = File.read!(@fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)
      assert export.exported_at == 1_732_204_800_000
      assert is_list(export.logs)
      assert length(export.logs) == 4
    end

    test "extracts timestamp, level, module, key, messages" do
      json = File.read!(@fixture_path)

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
      json = File.read!(@fixture_path)

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
      assert reason =~ "Missing required field"
    end

    test "handles messages with mixed types" do
      json = File.read!(@fixture_path)

      assert {:ok, export} = Parser.parse_client_json(json)

      # Find the log with mixed message types (string and number)
      warn_log = Enum.find(export.logs, fn log -> log.level == "warn" end)
      assert warn_log.messages == ["Task delayed by", 150, "ms"]
    end

    test "handles messages with nested objects" do
      json = File.read!(@fixture_path)

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
end
