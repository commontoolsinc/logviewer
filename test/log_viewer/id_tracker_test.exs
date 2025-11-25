defmodule LogViewer.IDTrackerTest do
  use ExUnit.Case, async: true

  alias LogViewer.IDTracker

  describe "extract_clickable_ids/1" do
    test "extracts CID from JSON slash pattern" do
      text = ~s({"cause": {"/": "baedreihtj5vujraokyl7rcgibw5gcx62votukkfc3ttsy4xb56efk3offq"}})

      assert IDTracker.extract_clickable_ids(text) == [
        "baedreihtj5vujraokyl7rcgibw5gcx62votukkfc3ttsy4xb56efk3offq"
      ]
    end

    test "extracts multiple CIDs from JSON slash patterns" do
      text = ~s({"/": "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"} and {"/": "baedreig6m7rbk6troi36duxwujaue2odzvojgxkzz6akawb5xrn7tvy6gu"})

      ids = IDTracker.extract_clickable_ids(text)
      assert length(ids) == 2
      assert "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm" in ids
      assert "baedreig6m7rbk6troi36duxwujaue2odzvojgxkzz6akawb5xrn7tvy6gu" in ids
    end

    test "extracts DIDs" do
      text = "space: did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8"

      assert IDTracker.extract_clickable_ids(text) == [
        "did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8"
      ]
    end

    test "extracts both CIDs and DIDs" do
      text = ~s(space: did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8 cause: {"/": "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"})

      ids = IDTracker.extract_clickable_ids(text)
      assert length(ids) == 2
      assert "did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8" in ids
      assert "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm" in ids
    end

    test "returns empty list when no IDs found" do
      text = "just some random text with no IDs"

      assert IDTracker.extract_clickable_ids(text) == []
    end

    test "deduplicates repeated IDs" do
      text = ~s({"/": "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"} and {"/": "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"})

      assert IDTracker.extract_clickable_ids(text) == [
        "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      ]
    end

    test "handles CIDs not in JSON slash pattern (direct references)" do
      text = "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm successfully"

      assert IDTracker.extract_clickable_ids(text) == [
        "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      ]
    end

    test "extracts ba4jcb format CIDs" do
      text = ~s("ba4jcb42pnncmidswc74irsanxjqv7wvlu5csriw444whfypprbkw3rjm": { "is": { "value": {} } })

      assert IDTracker.extract_clickable_ids(text) == [
        "ba4jcb42pnncmidswc74irsanxjqv7wvlu5csriw444whfypprbkw3rjm"
      ]
    end

    test "does not match CID-like substrings within other strings" do
      # This multiline text contains a long base64-like string with "ba" + 49+ chars as a substring
      # It should NOT be extracted as a CID, only actual standalone CIDs should match
      text = """
      Processing request with token: abc123defbai3psumoa9tehllh4ugpkwxbai3psumoa9tehllh4ugpkwxyz789
      Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm successfully
      """

      # Should only extract the real CID, not the substring from the token
      assert IDTracker.extract_clickable_ids(text) == [
        "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      ]
    end
  end

  describe "make_ids_clickable/1" do
    test "wraps CID in clickable span" do
      text = "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"

      result = IDTracker.make_ids_clickable(text)

      assert result =~ ~s(<span class="clickable-id" phx-click="toggle_track" phx-value-id="baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm">)
      assert result =~ "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm</span>"
      assert result =~ "Stored doc"
    end

    test "wraps DID in clickable span" do
      text = "space: did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8"

      result = IDTracker.make_ids_clickable(text)

      assert result =~ ~s(<span class="clickable-id" phx-click="toggle_track" phx-value-id="did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8">)
      assert result =~ "did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8</span>"
    end

    test "wraps multiple IDs" do
      text = ~s(doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm space did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8)

      result = IDTracker.make_ids_clickable(text)

      # Should have two clickable spans
      assert result =~ ~s(phx-value-id="baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm")
      assert result =~ ~s(phx-value-id="did:key:z6MkrHvEHMtMVoWq5iGheNMZ5bo9bfu47Q1Hn6LUVtqN1Hz8")
      assert result =~ "doc"
      assert result =~ "space"
    end

    test "returns original text when no IDs found" do
      text = "just some random text"

      assert IDTracker.make_ids_clickable(text) == text
    end

    test "preserves text around IDs" do
      text = "Before baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm after"

      result = IDTracker.make_ids_clickable(text)

      assert result =~ "Before"
      assert result =~ "after"
      assert result =~ ~s(<span class="clickable-id")
    end
  end
end
