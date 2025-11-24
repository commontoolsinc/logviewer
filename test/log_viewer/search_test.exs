defmodule LogViewer.SearchTest do
  use ExUnit.Case, async: true

  alias LogViewer.Search
  alias LogViewer.Timeline.LogEvent

  describe "search_timeline/2" do
    setup do
      events = [
        %LogEvent{
          timestamp: 1_000_000,
          level: "error",
          module: "storage",
          message: "Failed to read document baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm",
          source: :client,
          raw_entry: %{}
        },
        %LogEvent{
          timestamp: 2_000_000,
          level: "info",
          module: "memory-provider",
          message: "Server started on port 8000",
          source: :server,
          raw_entry: %{}
        },
        %LogEvent{
          timestamp: 3_000_000,
          level: "warn",
          module: "cache",
          message: "Cache miss for key user:123",
          source: :client,
          raw_entry: %{}
        },
        %LogEvent{
          timestamp: 4_000_000,
          level: "debug",
          module: "storage",
          message: "Reading from storage layer",
          source: :server,
          raw_entry: %{}
        }
      ]

      %{events: events}
    end

    test "performs substring search in message", %{events: events} do
      results = Search.search_timeline(events, "storage")

      assert length(results) == 2
      assert Enum.any?(results, &(&1.message =~ "storage layer"))
      assert Enum.any?(results, &(&1.module == "storage"))
    end

    test "performs substring search in module", %{events: events} do
      results = Search.search_timeline(events, "memory")

      assert length(results) == 1
      assert List.first(results).module == "memory-provider"
    end

    test "performs substring search in level", %{events: events} do
      results = Search.search_timeline(events, "error")

      assert length(results) == 1
      assert List.first(results).level == "error"
    end

    test "search is case-insensitive", %{events: events} do
      results_lower = Search.search_timeline(events, "server")
      results_upper = Search.search_timeline(events, "SERVER")
      results_mixed = Search.search_timeline(events, "SeRvEr")

      # "Server" appears in message "Server started on port 8000"
      assert length(results_lower) == 1
      assert length(results_upper) == 1
      assert length(results_mixed) == 1
    end

    test "empty query returns all events", %{events: events} do
      results = Search.search_timeline(events, "")

      assert length(results) == 4
    end

    test "nil query returns all events", %{events: events} do
      results = Search.search_timeline(events, nil)

      assert length(results) == 4
    end

    test "returns empty list when no matches", %{events: events} do
      results = Search.search_timeline(events, "nonexistent")

      assert results == []
    end

    test "matches partial words", %{events: events} do
      results = Search.search_timeline(events, "port")

      assert length(results) == 1
      assert List.first(results).message =~ "port 8000"
    end

    test "matches across multiple fields", %{events: events} do
      # "storage" appears in both module and message fields
      results = Search.search_timeline(events, "storage")

      assert length(results) == 2
    end
  end

  describe "highlight_text/2" do
    test "wraps matched text in mark tags" do
      text = "Failed to read document"
      query = "read"

      result = Search.highlight_text(text, query)

      assert result =~ ~s(<mark class="bg-yellow-200">)
      assert result =~ "</mark>"
      assert result =~ "read"
    end

    test "handles multiple matches in same string" do
      text = "Error reading storage, storage unavailable"
      query = "storage"

      result = Search.highlight_text(text, query)

      # Should have two mark tags
      mark_count = length(String.split(result, "<mark")) - 1
      assert mark_count == 2
    end

    test "case-insensitive matching" do
      text = "Server Started Successfully"
      query = "server"

      result = Search.highlight_text(text, query)

      assert result =~ ~s(<mark class="bg-yellow-200">Server</mark>)
    end

    test "returns original text when no matches" do
      text = "No matches here"
      query = "xyz"

      result = Search.highlight_text(text, query)

      assert result == text
      refute result =~ "<mark"
    end

    test "returns original text for empty query" do
      text = "Some text"
      result = Search.highlight_text(text, "")

      assert result == text
    end

    test "returns original text for nil query" do
      text = "Some text"
      result = Search.highlight_text(text, nil)

      assert result == text
    end

    test "handles special regex characters" do
      text = "Error: $100.00 (USD)"
      query = "$100"

      result = Search.highlight_text(text, query)

      assert result =~ ~s(<mark class="bg-yellow-200">$100</mark>)
    end

    test "preserves HTML entities" do
      text = "Storage &amp; Memory"
      query = "storage"

      result = Search.highlight_text(text, query)

      assert result =~ ~s(<mark class="bg-yellow-200">Storage</mark>)
      assert result =~ "&amp;"
    end
  end
end
