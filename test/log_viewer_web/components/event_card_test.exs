defmodule LogViewerWeb.Components.EventCardTest do
  use LogViewerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LogViewer.Timeline.LogEvent
  alias LogViewerWeb.Components.EventCard

  describe "event_card/1" do
    test "renders client log event with all fields" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "error",
        module: "storage",
        message: "Failed to read document",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)

      assert html =~ "client"
      assert html =~ "error"
      assert html =~ "storage"
      assert html =~ "Failed to read document"
      assert html =~ "bg-blue-100 text-blue-800"
      assert html =~ "bg-red-100 text-red-800"
    end

    test "renders server log event with all fields" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "INFO",
        module: "toolshed",
        message: "Server started on port 8000",
        source: :server,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)

      assert html =~ "server"
      assert html =~ "INFO"
      assert html =~ "toolshed"
      assert html =~ "Server started on port 8000"
      assert html =~ "bg-green-100 text-green-800"
      assert html =~ "bg-blue-100 text-blue-800"
    end

    test "formats timestamp correctly" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: "test message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)

      # Should contain formatted time (HH:MM:SS.mmm format)
      assert html =~ ~r/\d{2}:\d{2}:\d{2}\.\d+/
    end

    test "applies correct color for error level" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "error",
        module: "test",
        message: "error message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-red-100 text-red-800"
    end

    test "applies correct color for ERROR level (uppercase)" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "ERROR",
        module: "test",
        message: "error message",
        source: :server,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-red-100 text-red-800"
    end

    test "applies correct color for warn level" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "warn",
        module: "test",
        message: "warning message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-yellow-100 text-yellow-800"
    end

    test "applies correct color for info level" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: "info message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-blue-100 text-blue-800"
    end

    test "applies correct color for debug level" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "debug",
        module: "test",
        message: "debug message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-gray-100 text-gray-800"
    end

    test "applies correct badge color for client source" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: "test message",
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-blue-100 text-blue-800"
    end

    test "applies correct badge color for server source" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: "test message",
        source: :server,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ "bg-green-100 text-green-800"
    end

    test "handles long messages" do
      long_message = String.duplicate("a", 500)

      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: long_message,
        source: :client,
        raw_entry: %{}
      }

      html = render_component(&EventCard.event_card/1, event: event)
      assert html =~ long_message
    end

    test "renders with search_query attribute" do
      event = %LogEvent{
        timestamp: 1_763_753_972_077,
        level: "info",
        module: "test",
        message: "test message",
        source: :client,
        raw_entry: %{}
      }

      # Should highlight matching text when search_query is provided
      html = render_component(&EventCard.event_card/1, event: event, search_query: "test")
      assert html =~ ~s(<mark class="bg-yellow-200">test</mark>)
      assert html =~ "message"
    end
  end
end
