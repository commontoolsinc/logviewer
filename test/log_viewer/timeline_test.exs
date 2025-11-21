defmodule LogViewer.TimelineTest do
  use ExUnit.Case, async: true

  alias LogViewer.Parser
  alias LogViewer.Parser.{ClientLogEntry, ServerLogEntry}
  alias LogViewer.Timeline
  alias LogViewer.Timeline.LogEvent

  describe "from_client_entry/1" do
    test "converts ClientLogEntry to LogEvent" do
      entry = %ClientLogEntry{
        timestamp: 1_732_204_800_100,
        level: "info",
        module: "memory",
        key: "storage",
        messages: ["Stored doc", "baedreic7dvj..."]
      }

      event = Timeline.from_client_entry(entry)

      assert event.timestamp == 1_732_204_800_100
      assert event.level == "info"
      assert event.module == "memory"
      assert event.message == "Stored doc baedreic7dvj..."
      assert event.source == :client
      assert event.raw_entry == entry
    end

    test "handles empty messages list" do
      entry = %ClientLogEntry{
        timestamp: 1_732_204_800_100,
        level: "debug",
        module: "test",
        key: "empty",
        messages: []
      }

      event = Timeline.from_client_entry(entry)

      assert event.message == ""
    end

    test "handles messages with mixed types" do
      entry = %ClientLogEntry{
        timestamp: 1_732_204_800_100,
        level: "warn",
        module: "scheduler",
        key: "delay",
        messages: ["Task delayed by", 150, "ms"]
      }

      event = Timeline.from_client_entry(entry)

      assert event.message == "Task delayed by 150 ms"
    end
  end

  describe "from_server_entry/1" do
    test "converts ServerLogEntry to LogEvent" do
      entry = %ServerLogEntry{
        timestamp: 1_732_204_800_500,
        level: "INFO",
        module: "toolshed",
        message: "Server started on port 8000"
      }

      event = Timeline.from_server_entry(entry)

      assert event.timestamp == 1_732_204_800_500
      assert event.level == "INFO"
      assert event.module == "toolshed"
      assert event.message == "Server started on port 8000"
      assert event.source == :server
      assert event.raw_entry == entry
    end
  end

  describe "build_timeline/2" do
    test "merges client and server logs" do
      client_logs = [
        %ClientLogEntry{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          key: "storage",
          messages: ["Stored doc"]
        }
      ]

      server_logs = [
        %ServerLogEntry{
          timestamp: 1_732_204_800_200,
          level: "INFO",
          module: "memory",
          message: "Retrieved doc"
        }
      ]

      timeline = Timeline.build_timeline(client_logs, server_logs)

      assert length(timeline) == 2
      assert Enum.at(timeline, 0).source == :client
      assert Enum.at(timeline, 1).source == :server
    end

    test "sorts events by timestamp" do
      client_logs = [
        %ClientLogEntry{
          timestamp: 1_732_204_800_300,
          level: "info",
          module: "memory",
          key: "storage",
          messages: ["Third"]
        },
        %ClientLogEntry{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          key: "storage",
          messages: ["First"]
        }
      ]

      server_logs = [
        %ServerLogEntry{
          timestamp: 1_732_204_800_200,
          level: "INFO",
          module: "memory",
          message: "Second"
        }
      ]

      timeline = Timeline.build_timeline(client_logs, server_logs)

      assert length(timeline) == 3
      assert Enum.at(timeline, 0).message == "First"
      assert Enum.at(timeline, 1).message == "Second"
      assert Enum.at(timeline, 2).message == "Third"
    end

    test "preserves source (client vs server)" do
      client_logs = [
        %ClientLogEntry{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          key: "storage",
          messages: ["Client log"]
        }
      ]

      server_logs = [
        %ServerLogEntry{
          timestamp: 1_732_204_800_200,
          level: "INFO",
          module: "memory",
          message: "Server log"
        }
      ]

      timeline = Timeline.build_timeline(client_logs, server_logs)

      client_event = Enum.find(timeline, fn e -> e.source == :client end)
      server_event = Enum.find(timeline, fn e -> e.source == :server end)

      assert client_event != nil
      assert server_event != nil
      assert client_event.message == "Client log"
      assert server_event.message == "Server log"
    end

    test "handles empty client logs" do
      server_logs = [
        %ServerLogEntry{
          timestamp: 1_732_204_800_200,
          level: "INFO",
          module: "memory",
          message: "Server log"
        }
      ]

      timeline = Timeline.build_timeline([], server_logs)

      assert length(timeline) == 1
      assert Enum.at(timeline, 0).source == :server
    end

    test "handles empty server logs" do
      client_logs = [
        %ClientLogEntry{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          key: "storage",
          messages: ["Client log"]
        }
      ]

      timeline = Timeline.build_timeline(client_logs, [])

      assert length(timeline) == 1
      assert Enum.at(timeline, 0).source == :client
    end

    test "handles both empty" do
      timeline = Timeline.build_timeline([], [])

      assert timeline == []
    end
  end
end
