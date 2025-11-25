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

    test "performs fuzzy search in message", %{events: events} do
      results = Search.search_timeline(events, "storage")

      assert length(results) == 2
      assert Enum.any?(results, &(&1.message =~ "storage layer"))
      assert Enum.any?(results, &(&1.module == "storage"))
    end

    test "performs fuzzy search in module", %{events: events} do
      results = Search.search_timeline(events, "memory")

      # Fuzzy search may find more matches than substring
      assert length(results) >= 1
      assert Enum.any?(results, &(&1.module == "memory-provider"))
    end

    test "performs fuzzy search in level", %{events: events} do
      results = Search.search_timeline(events, "error")

      # Fuzzy search may find more matches (e.g., "Server" contains e,r,r,e,r)
      assert length(results) >= 1
      assert Enum.any?(results, &(&1.level == "error"))
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

    test "should not match across newlines in multiline log messages" do
      # This test demonstrates the bug where matches_query? bypasses fuzzy_match?'s
      # newline-splitting logic by calling do_fuzzy_match? directly
      multiline_event = %LogEvent{
        timestamp: 5_000_000,
        level: "info",
        module: "memory-provider",
        message: """
        First line with ABC
        Second line with DEF
        Third line with GHI
        """,
        source: :server,
        raw_entry: %{}
      }

      events = [multiline_event]

      # "adg" matches across lines: A from line 1, D from line 2, G from line 3
      # This SHOULD return no results (single-line matching should prevent cross-line matches)
      # But currently FAILS because matches_query? calls do_fuzzy_match? directly
      results = Search.search_timeline(events, "adg")

      # This assertion will FAIL, exposing the bug
      assert results == [], "Expected no matches for cross-line fuzzy pattern 'adg', but got #{length(results)} matches"
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

      # Fuzzy matching finds first occurrence and highlights all matching characters
      # Should have one highlighted segment for "storage"
      assert result =~ ~s(<mark class="bg-yellow-200">storage</mark>)
      # The first "storage" should be highlighted
      assert result =~ "reading <mark"
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

    test "skips HTML tags when highlighting" do
      # Text with HTML tags (like after make_ids_clickable)
      text = ~s(Document <span class="clickable-id" phx-click="toggle_track" phx-value-id="ba4jcb123">ba4jcb123</span> stored)
      query = "ba4"

      result = Search.highlight_text(text, query)

      # Should only highlight the visible text "ba4jcb123", not inside HTML attributes
      assert result =~ ~s(phx-value-id="ba4jcb123">)  # Attribute unchanged
      assert result =~ ~s(<mark class="bg-yellow-200">ba4</mark>)  # Visible text highlighted

      # Should NOT have marks inside the attribute value
      refute result =~ ~s(phx-value-id="<mark)
    end

    test "skips multiple HTML tags when highlighting" do
      text = ~s(Found <span class="id">ba4jcb123</span> and <span class="id">ba4jcb456</span>)
      query = "ba4"

      result = Search.highlight_text(text, query)

      # Should highlight inside both spans
      assert result =~ ~s(<span class="id"><mark class="bg-yellow-200">ba4</mark>)

      # Should NOT modify the span tags themselves
      assert result =~ ~s(<span class="id">)
      refute result =~ ~s(<mark class="bg-yellow-200">span)
    end

    test "skips self-closing HTML tags" do
      text = ~s(Line 1<br/>Line 2 with ba4jcb123)
      query = "ba4"

      result = Search.highlight_text(text, query)

      # Should keep <br/> intact
      assert result =~ "<br/>"
      refute result =~ ~s(<mark class="bg-yellow-200">br)

      # Should highlight the visible text
      assert result =~ ~s(<mark class="bg-yellow-200">ba4</mark>)
    end

    test "handles nested HTML tags" do
      text = ~s(<div><span class="outer"><span class="inner">ba4jcb123</span></span></div>)
      query = "ba4"

      result = Search.highlight_text(text, query)

      # All tags should remain unchanged
      assert result =~ ~s(<div><span class="outer"><span class="inner">)
      assert result =~ "</span></span></div>"

      # Only the innermost text should be highlighted
      assert result =~ ~s(<mark class="bg-yellow-200">ba4</mark>)
    end

    test "handles HTML with attributes containing search query" do
      # This is the key test - query appears in both attribute and visible text
      text = ~s(<span data-id="csriw444">Text with csriw444 inside</span>)
      query = "csriw444"

      result = Search.highlight_text(text, query)

      # Attribute should NOT be modified
      assert result =~ ~s(data-id="csriw444")
      refute result =~ ~s(data-id="<mark)

      # Only visible text should be highlighted
      assert result =~ ~s(Text with <mark class="bg-yellow-200">csriw444</mark>)
    end

    test "handles empty HTML tags" do
      text = ~s(<span></span>ba4jcb123)
      query = "ba4"

      result = Search.highlight_text(text, query)

      # Empty tags should remain unchanged
      assert result =~ "<span></span>"

      # Text after tags should be highlighted
      assert result =~ ~s(<mark class="bg-yellow-200">ba4</mark>)
    end

    test "fuzzy match across HTML boundaries (DID with trailing quote)" do
      # This simulates searching for a DID with trailing quote after make_ids_clickable()
      # Original: "did:key:z6MkmcNT8nApM6ncb55zBbbsxWxbai3PSuoMA9tEHLH4UGPk": "OWNER"
      # After make_ids_clickable: "<span>did:key:z6MkmcNT8nApM6ncb55zBbbsxWxbai3PSuoMA9tEHLH4UGPk</span>": "OWNER"
      text = ~s("<span class="clickable-id">did:key:z6MkmcNT8nApM6ncb55zBbbsxWxbai3PSuoMA9tEHLH4UGPk</span>": "OWNER")
      query = ~s(did:key:z6MkmcNT8nApM6ncb55zBbbsxWxbai3PSuoMA9tEHLH4UGPk")

      result = Search.highlight_text(text, query)

      # Should highlight the DID inside the span
      assert result =~ ~s(<mark class="bg-yellow-200">did:key:z6MkmcNT8nApM6ncb55zBbbsxWxbai3PSuoMA9tEHLH4UGPk</mark>)
      # Should highlight the quote after the span
      assert result =~ ~s(</span><mark class="bg-yellow-200">"</mark>:)
      # Should NOT have marks inside HTML attributes
      refute result =~ ~s(class="<mark)
    end

    test "fuzzy highlights non-consecutive characters" do
      text = "runner"
      query = "rnr"

      result = Search.highlight_text(text, query)

      # Should highlight: r, n, r (fuzzy match finds first occurrence of each)
      assert result =~ ~s(<mark class="bg-yellow-200">r</mark>)
      assert result =~ ~s(n</mark>)
      # The pattern matches: r at 0, n at 2, r at 5
      assert result == ~s(<mark class="bg-yellow-200">r</mark>u<mark class="bg-yellow-200">n</mark>ne<mark class="bg-yellow-200">r</mark>)
    end

    test "fuzzy highlights with adjacent characters combined" do
      text = "memory-provider"
      query = "mpv"

      result = Search.highlight_text(text, query)

      # Should highlight: m, p, v
      assert result == ~s(<mark class="bg-yellow-200">m</mark>emory-<mark class="bg-yellow-200">p</mark>ro<mark class="bg-yellow-200">v</mark>ider)
    end

    test "fuzzy highlights scattered characters" do
      text = "storage-transaction"
      query = "stt"

      result = Search.highlight_text(text, query)

      # Should highlight: s, t (from storage), t (from transaction)
      assert result == ~s(<mark class="bg-yellow-200">st</mark>orage-<mark class="bg-yellow-200">t</mark>ransaction)
    end

    test "fuzzy highlighting is case-insensitive" do
      text = "StorageTransaction"
      query = "stt"

      result = Search.highlight_text(text, query)

      # Should preserve original case
      assert result == ~s(<mark class="bg-yellow-200">St</mark>orage<mark class="bg-yellow-200">T</mark>ransaction)
    end

    test "consecutive substring still works with fuzzy" do
      text = "error message"
      query = "error"

      result = Search.highlight_text(text, query)

      # Should highlight as one block since they're consecutive
      assert result =~ ~s(<mark class="bg-yellow-200">error</mark>)
    end

    test "fuzzy highlighting with no match returns original" do
      text = "runner"
      query = "xyz"

      result = Search.highlight_text(text, query)

      assert result == text
      refute result =~ "<mark"
    end
  end

  describe "fuzzy_match?/2" do
    test "matches characters in order: 'kep' matches 'kefoijsdofijpm'" do
      assert Search.fuzzy_match?("kefoijsdofijpm", "kep")
    end

    test "matches characters in order: 'stt' matches 'storage-transaction'" do
      assert Search.fuzzy_match?("storage-transaction", "stt")
    end

    test "matches characters in order: 'mpv' matches 'memory-provider'" do
      assert Search.fuzzy_match?("memory-provider", "mpv")
    end

    test "case-insensitive fuzzy matching" do
      assert Search.fuzzy_match?("StorageTransaction", "stt")
      assert Search.fuzzy_match?("storage-transaction", "STT")
      assert Search.fuzzy_match?("MEMORY-PROVIDER", "mpv")
    end

    test "returns false when characters not in order" do
      refute Search.fuzzy_match?("storage", "tso")
      refute Search.fuzzy_match?("memory", "yem")
    end

    test "returns false when characters missing" do
      refute Search.fuzzy_match?("storage", "xyz")
      refute Search.fuzzy_match?("memory", "abc")
    end

    test "empty query matches everything" do
      assert Search.fuzzy_match?("any text here", "")
      assert Search.fuzzy_match?("", "")
    end

    test "handles single character queries" do
      assert Search.fuzzy_match?("storage", "s")
      assert Search.fuzzy_match?("memory", "m")
      refute Search.fuzzy_match?("storage", "x")
    end

    test "consecutive characters still work" do
      assert Search.fuzzy_match?("storage error", "storage")
      assert Search.fuzzy_match?("memory-provider", "memory")
    end

    test "should not match across newlines in multiline messages" do
      # Multiline stack trace - characters are on different lines
      multiline_message = """
      First line with ABC
      Second line with DEF
      Third line with GHI
      """

      # "adg" would match across lines: A from line 1, D from line 2, G from line 3
      # but these are on different lines, so it should NOT match
      refute Search.fuzzy_match?(multiline_message, "adg")

      # "beh" would match across lines: B from line 1, E from line 2, H from line 3
      # but these are on different lines, so it should NOT match
      refute Search.fuzzy_match?(multiline_message, "beh")

      # However, "abc" on the same first line SHOULD still match
      assert Search.fuzzy_match?(multiline_message, "abc")

      # And "def" on the same line SHOULD still match
      assert Search.fuzzy_match?(multiline_message, "def")

      # "ghi" on the third line SHOULD also match
      assert Search.fuzzy_match?(multiline_message, "ghi")
    end
  end
end
