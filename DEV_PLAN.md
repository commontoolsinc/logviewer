# LogViewer Development Plan

This document outlines the development plan for the LogViewer Phoenix LiveView application, following Test-Driven Development (TDD) practices.

## Current Status

### ✅ Completed
- **Phase 1: Core Data Layer** - All parsers, entity extraction, and timeline building complete
- **Phase 2: LiveView UI** - File upload and basic rendering working
- **Phase 3.1: Event Card Component** - Separate, testable component with full test coverage

### 🚧 In Progress
- **Phase 4.2c: Improved Fuzzy Matching Algorithm** - Prefer shorter spans and consecutive characters (like Helix)

### ✅ Recently Completed
- **Phase 4.2d: Line-Bounded Fuzzy Highlighting** - Fixed highlighting to respect line boundaries (no cross-line matches)
- **Phase 4.2b: True Fuzzy Search** - Upgraded from substring to fuzzy matching (characters in order)
- **Phase 4.2a: Substring Search** - Case-insensitive substring search with highlighting implemented and tested

### 📋 Next Steps
1. ~~Complete true fuzzy search implementation (characters in order, not consecutive)~~ ✅
2. Improve fuzzy matching algorithm to prefer shorter spans (like Helix)
3. ~~Fix search highlighting to not break HTML structure and respect line boundaries~~ ✅
4. Add entity list and detail components
5. Build statistics dashboard

## TDD Workflow

For each feature, we follow this cycle:

1. **Write Test First** - Define the expected behavior with a failing test
2. **Run Test** - Verify it fails (red)
3. **Implement Feature** - Write minimal code to make test pass
4. **Run Test** - Verify it passes (green)
5. **Refactor** - Clean up code while keeping tests green

## Phase 1: Core Data Layer ✅ COMPLETE

All parsers, timeline building, and entity extraction fully implemented and tested.

### 1.1 Parser Module - Client JSON ✅

**Test File**: `test/log_viewer/parser_test.exs`

**Test Cases**:
```elixir
describe "parse_client_json/1" do
  test "parses valid client JSON export"
  test "extracts timestamp, level, module, key, messages"
  test "handles multiple log entries"
  test "returns error for invalid JSON"
  test "returns error for missing required fields"
end
```

**Implementation**: `lib/log_viewer/parser.ex`
- Define `ClientLogEntry` struct
- Define `ClientExport` struct
- Implement `parse_client_json/1` function

**TDD Steps**:
1. Write test with sample JSON fixture
2. Run `mix test test/log_viewer/parser_test.exs` - should fail
3. Create structs and parser function
4. Run test - should pass

---

### 1.2 Parser Module - Server Text Logs

**Test File**: `test/log_viewer/parser_test.exs`

**Test Cases**:
```elixir
describe "parse_server_logs/1" do
  test "parses toolshed format [LEVEL][module::HH:MM:SS.mmm] message"
  test "handles multiple lines"
  test "constructs full timestamp from time-of-day"
  test "skips malformed lines gracefully"
  test "handles empty file"
end
```

**Implementation**: `lib/log_viewer/parser.ex`
- Define `ServerLogEntry` struct
- Implement `parse_server_logs/1` function
- Regex pattern for log format
- Timestamp reconstruction logic

**TDD Steps**:
1. Write test with sample log text fixture
2. Run test - should fail
3. Implement parser with regex
4. Run test - should pass

---

### 1.3 Entity Extractor

**Test File**: `test/log_viewer/entity_extractor_test.exs`

**Test Cases**:
```elixir
describe "extract_entities/1" do
  test "extracts docIDs from text"
  test "extracts charmIDs from text"
  test "extracts spaceIDs (DIDs) from text"
  test "returns empty lists when no entities found"
  test "handles multiple entities of same type"
  test "deduplicates repeated entity IDs"
end

describe "extract_entity_info/2" do
  test "builds entity metadata with first/last seen"
  test "counts total events mentioning entity"
  test "returns list of events for entity"
end
```

**Implementation**: `lib/log_viewer/entity_extractor.ex`
- Define `EntityInfo` struct
- Regex patterns for docID, charmID, spaceID
- Implement `extract_entities/1`
- Implement `extract_entity_info/2`

**TDD Steps**:
1. Write tests with sample text containing CIDs/DIDs
2. Run test - should fail
3. Implement extraction with regex
4. Run test - should pass
5. Refactor regex patterns if needed

---

### 1.4 Timeline Builder

**Test File**: `test/log_viewer/timeline_test.exs`

**Test Cases**:
```elixir
describe "build_timeline/2" do
  test "merges client and server logs"
  test "sorts events by timestamp"
  test "preserves source (client vs server)"
  test "handles empty client logs"
  test "handles empty server logs"
  test "handles both empty"
end

describe "build_entity_index/1" do
  test "creates map of entity ID -> events"
  test "calculates first_seen timestamp"
  test "calculates last_seen timestamp"
  test "counts total events per entity"
  test "groups by entity type (docID, charmID, spaceID)"
end
```

**Implementation**: `lib/log_viewer/timeline.ex` and `lib/log_viewer/entity_extractor.ex`
- Define `LogEvent` struct ✅
- Implement `build_timeline/2` ✅
- Define `EntityIndex` struct ✅
- Implement `build_entity_index/1` ✅
- Note: Entity-based correlation already provided by EntityIndex

**TDD Steps**:
1. Write comprehensive tests with mixed log data
2. Run test - should fail
3. Implement timeline merge logic
4. Run test - should pass
5. Refactor for performance if needed

---

## Phase 2: LiveView UI ✅ MOSTLY COMPLETE

File upload and basic rendering working. Search and filtering UI pending (see Phase 4.2).

### 2.1 Main LiveView Component ✅

**Test File**: `test/log_viewer_web/live/timeline_live_test.exs`

**Test Cases**:
```elixir
describe "mount/3" do
  test "initializes empty state"
  test "sets default tab to :timeline"
  test "initializes empty search query"
end

describe "file upload" do
  test "accepts JSON file upload"
  test "accepts text file upload"
  test "parses uploaded files"
  test "updates assigns with timeline"
  test "shows error for invalid files"
end

describe "tab switching" do
  test "switches to timeline tab"
  test "switches to docids tab"
  test "switches to charms tab"
  test "switches to spaces tab"
end

describe "search" do
  test "filters events by search query"
  test "search is case-insensitive"
  test "empty query shows all events"
end
```

**Implementation**: `lib/log_viewer_web/live/timeline_live.ex`
- Define initial assigns in `mount/3`
- Implement file upload handling
- Implement tab switching with `handle_event/3`
- Implement search filtering

**TDD Steps**:
1. Write LiveView tests using `Phoenix.LiveViewTest`
2. Run test - should fail
3. Implement LiveView callbacks
4. Run test - should pass

---

### 2.2 Upload Handler

**Test File**: `test/log_viewer_web/live/timeline_live_test.exs` (continued)

**Test Cases**:
```elixir
describe "handle_event upload_client" do
  test "stores client logs in state"
  test "triggers timeline rebuild"
  test "shows success message"
end

describe "handle_event upload_server" do
  test "stores server logs in state"
  test "triggers timeline rebuild"
  test "shows success message"
end

describe "handle_event upload_both" do
  test "processes both files simultaneously"
  test "builds correlated timeline"
  test "extracts all entities"
end
```

**Implementation**: Add to `lib/log_viewer_web/live/timeline_live.ex`
- `handle_event("upload_client", ...)`
- `handle_event("upload_server", ...)`
- Helper function for rebuilding timeline

**TDD Steps**:
1. Write upload event tests
2. Run test - should fail
3. Implement upload handlers
4. Run test - should pass

---

## Phase 3: Visualization Components

### 3.1 Event Card Component ✅ COMPLETE

**Status**: Implemented and tested with 12 passing tests

**Test File**: `test/log_viewer_web/components/event_card_test.exs` ✅

**Completed Tests**:
- ✅ Renders client and server log events with all fields
- ✅ Formats timestamps correctly (HH:MM:SS.mmm)
- ✅ Applies correct colors for all log levels (error, warn, info, debug)
- ✅ Applies correct badge colors for client/server sources
- ✅ Handles long messages
- ✅ Accepts search_query attribute for future highlighting

**Implementation**: `lib/log_viewer_web/components/event_card.ex` ✅
- Function component with proper typespecs
- Color-coded level badges (red=error, yellow=warn, blue=info, gray=debug)
- Color-coded source badges (blue=client, green=server)
- TailwindCSS styling with hover effects
- Ready for search query highlighting

---

### 3.2 Entity List Component

**Test File**: `test/log_viewer_web/components/entity_list_test.exs`

**Test Cases**:
```elixir
describe "entity_list/1" do
  test "renders list of entities"
  test "shows entity ID"
  test "shows first seen timestamp"
  test "shows last seen timestamp"
  test "shows event count"
  test "clickable to open details"
end
```

**Implementation**: `lib/log_viewer_web/components/entity_list.ex`
- Define function component `entity_list/1`
- Add click handlers for entity selection
- Format timestamps nicely

**TDD Steps**:
1. Write component tests
2. Run test - should fail
3. Implement component
4. Run test - should pass

---

### 3.3 Entity Detail Modal

**Test File**: `test/log_viewer_web/components/entity_modal_test.exs`

**Test Cases**:
```elixir
describe "entity_modal/1" do
  test "renders when entity is selected"
  test "shows entity ID in header"
  test "displays entity stats"
  test "lists all events mentioning entity"
  test "has close button"
  test "hides when no entity selected"
end
```

**Implementation**: `lib/log_viewer_web/components/entity_modal.ex`
- Define function component `entity_modal/1`
- Modal overlay with backdrop
- Event list within modal
- Close handler

**TDD Steps**:
1. Write modal tests
2. Run test - should fail
3. Build modal component
4. Run test - should pass

---

## Phase 4: Polish & Features

### 4.1 Statistics Dashboard

**Test File**: `test/log_viewer/statistics_test.exs`

**Test Cases**:
```elixir
describe "calculate_stats/1" do
  test "counts total events"
  test "counts events by level"
  test "counts entities by type"
  test "calculates time range"
  test "identifies most mentioned entities"
end
```

**Implementation**: `lib/log_viewer/statistics.ex`
- Implement `calculate_stats/1`
- Return struct with all metrics

**TDD Steps**:
1. Write statistics tests
2. Run test - should fail
3. Implement calculation functions
4. Run test - should pass

---

### 4.2a Substring Search & Filtering ✅ COMPLETE

**Status**: Implemented with 17 passing tests

**Test File**: `test/log_viewer/search_test.exs` ✅

**Completed Test Cases**:
```elixir
describe "search_timeline/2" do
  test "performs fuzzy substring search across message, module, level"
  test "search is case-insensitive"
  test "empty query returns all events"
  test "returns empty list when no matches"
  test "orders results by relevance (exact > substring > fuzzy)"
end

describe "highlight_matches/2" do
  test "wraps matched text in highlight spans"
  test "handles multiple matches in same string"
  test "case-insensitive matching"
  test "returns original text when no matches"
end
```

**Implementation**:
- `lib/log_viewer/search.ex` - Core search logic
- Update `lib/log_viewer_web/components/event_card.ex` - Add highlight rendering
- Update `lib/log_viewer_web/live/timeline_live.ex` - Add search input and event handler

**Features**:
- Real-time search as user types
- Fuzzy matching (substring search)
- Search across: message content, module name, log level
- Highlight matching text in yellow background
- Display match count ("Showing 15 of 1,234 events")
- Clear button to reset search

**LiveView UI Changes**:
```elixir
# Add to assigns
assign(:search_query, "")
assign(:filtered_timeline, [])

# Add search event handler
def handle_event("search", %{"query" => query}, socket) do
  filtered = Search.search_timeline(socket.assigns.timeline, query)
  {:noreply, assign(socket, search_query: query, filtered_timeline: filtered)}
end
```

**Component Updates**:
```elixir
# event_card.ex - Add highlighting
def event_card(assigns) do
  ~H"""
  <div>
    <!-- existing badges -->
    <p><%= highlight_text(@event.message, @search_query) %></p>
  </div>
  """
end

defp highlight_text(text, nil), do: text
defp highlight_text(text, ""), do: text
defp highlight_text(text, query) do
  # Wrap matches in <mark class="bg-yellow-200">...</mark>
end
```

**TDD Steps**:
1. Write search tests
2. Run test - should fail
3. Implement fuzzy search logic
4. Write highlight tests
5. Implement highlight function
6. Update LiveView for search input
7. Update event_card to use highlighting
8. Run all tests - should pass

---

### 4.2b True Fuzzy Search ✅ COMPLETE

**Goal**: Upgrade from substring matching to true fuzzy matching like Helix editor, where "kep" matches "k**e**fo**p**m" (characters in order, not necessarily consecutive).

**Completed**:
- ✅ RED PHASE: Added 9 failing tests for fuzzy_match?/2
- ✅ GREEN PHASE: Implemented recursive fuzzy matching algorithm
- ✅ All 92 tests passing (updated 2 existing tests for fuzzy behavior)
- ✅ Playwright tested: "rnr" successfully matches "runner" module in browser

**Test File**: `test/log_viewer/search_test.exs` (add new tests)

**New Test Cases**:
```elixir
describe "fuzzy_match?/2" do
  test "matches characters in order: 'kep' matches 'kefoijsdofijm'"
  test "matches characters in order: 'stt' matches 'storage-transaction'"
  test "matches characters in order: 'mpv' matches 'memory-provider'"
  test "case-insensitive fuzzy matching"
  test "returns false when characters not in order"
  test "returns false when characters missing"
  test "empty query matches everything"
  test "handles single character queries"
end

describe "fuzzy_search_timeline/2" do
  test "finds events with fuzzy matches in message"
  test "finds events with fuzzy matches in module"
  test "finds events with fuzzy matches in level"
  test "returns all events for empty query"
  test "returns empty list when no fuzzy matches"
  test "case-insensitive across all fields"
end
```

**Implementation**: Update `lib/log_viewer/search.ex`
- Add `fuzzy_match?/2` private function for fuzzy matching algorithm
- Update `matches_query?/2` to use fuzzy matching instead of substring
- Keep highlighting working with fuzzy matches
- Maintain backward compatibility with existing tests

**Fuzzy Match Algorithm**:
```elixir
@spec fuzzy_match?(String.t(), String.t()) :: boolean()
defp fuzzy_match?(text, pattern) when is_binary(text) and is_binary(pattern) do
  text_lower = String.downcase(text)
  pattern_lower = String.downcase(pattern)

  do_fuzzy_match?(text_lower, pattern_lower)
end

defp do_fuzzy_match?(_text, ""), do: true
defp do_fuzzy_match?("", _pattern), do: false
defp do_fuzzy_match?(text, <<char::utf8, rest::binary>>) do
  case String.split(text, <<char::utf8>>, parts: 2) do
    [_before, after_match] -> do_fuzzy_match?(after_match, rest)
    [_] -> false
  end
end
```

**TDD Steps**:
1. Write fuzzy_match?/2 tests - **RED PHASE**
2. Run tests - should fail
3. Implement fuzzy_match?/2 - **GREEN PHASE**
4. Run tests - should pass
5. Update matches_query?/2 to use fuzzy matching
6. Run all existing tests - should still pass
7. Test with Playwright - verify fuzzy search works in browser

**Examples**:
- `"mpv"` should match "**m**emory-**p**ro**v**ider"
- `"stt"` should match "**s**torage-**t**ransac**t**ion"
- `"z6mkr"` should match "did:key:**z**6**Mkr**HvEHMtM..."
- `"err"` should match "**err**or", "st**o**r**a**g**e**-**err**or", etc.

---

### 4.2c Improved Fuzzy Matching Algorithm (Better Match Quality)

**Goal**: Upgrade fuzzy matching to prefer shorter spans and consecutive characters, like Helix editor does.

**Current Behavior** (Greedy Left-to-Right):
```
Search: "la"
Text:   "lib/log_viewer_web/components/layouts.ex"
Match:  "lib" (first 'l') + "layouts" (first 'a' after 'l')
         └─┘                 └─┘
         Span: ~28 characters
```

**Desired Behavior** (Shortest Span / Best Match):
```
Search: "la"
Text:   "lib/log_viewer_web/components/layouts.ex"
Match:  "layouts" (consecutive 'la')
                   └──┘
         Span: 2 characters (consecutive!)
```

**Problem with Current Algorithm**:
Our current implementation in `lib/log_viewer/search.ex` uses a simple greedy algorithm:
```elixir
defp do_fuzzy_match?(text, <<char::utf8, rest::binary>>) do
  case String.split(text, <<char::utf8>>, parts: 2) do
    [_before, after_match] -> do_fuzzy_match?(after_match, rest)
    [_] -> false
  end
end
```

This finds the **first occurrence** of each character, which can result in:
- Long spans with characters far apart
- Less intuitive matches
- Poor user experience when searching

**Proposed Solution**:
Implement a "best match" algorithm that:
1. Finds **all possible matches** in the text
2. Scores each match by:
   - **Span length** (shorter is better)
   - **Consecutiveness** (adjacent chars score higher)
   - **Word boundaries** (matches at start of words score higher)
3. Returns the **best scoring match**
4. Uses that match for highlighting

**Algorithm Options**:

**Option A: Shortest Span** (Simple)
- Find all possible matches
- Calculate span length for each
- Choose the match with shortest span
- Time complexity: O(n*m) where n=text length, m=pattern length

**Option B: Weighted Scoring** (More sophisticated)
- Score based on multiple factors:
  - Span length: shorter = better
  - Consecutiveness: adjacent chars = bonus points
  - Word boundaries: match at word start = bonus points
  - Case match: exact case match = bonus points
- Choose highest scoring match
- Time complexity: O(n*m)

**Implementation Strategy**:

```elixir
# Keep existing fuzzy_match?/2 for simple yes/no matching
@spec fuzzy_match?(String.t(), String.t()) :: boolean()
def fuzzy_match?(text, pattern) do
  # Current greedy implementation - fast, works for filtering
end

# New function for finding best match positions
@spec find_best_match(String.t(), String.t()) :: {:ok, list(integer())} | :no_match
defp find_best_match(text, pattern) do
  # Find all possible matches
  # Score each match
  # Return positions of best match for highlighting
end

# Update highlight_text/2 to use find_best_match/2
def highlight_text(text, query) do
  case find_best_match(text, query) do
    {:ok, positions} -> build_highlighted_string(text, positions)
    :no_match -> text
  end
end
```

**Test Cases**:
```elixir
describe "find_best_match/2" do
  test "prefers consecutive characters over distant ones" do
    # "la" in "lib/log_viewer/layouts.ex" should match "layouts" not "lib...la"
    assert find_best_match("lib/log_viewer/layouts.ex", "la") == {:ok, [20, 21]}
  end

  test "prefers shorter spans when multiple matches exist" do
    assert find_best_match("babel labrador", "la") == {:ok, [2, 3]}  # "babel"
  end

  test "prefers word boundary matches" do
    # "la" should prefer "layouts" over "bilateral"
    assert find_best_match("bilateral layouts", "la") == {:ok, [10, 11]}
  end

  test "handles no match case" do
    assert find_best_match("example", "xyz") == :no_match
  end
end
```

**TDD Steps**:
1. **RED**: Write tests for `find_best_match/2` (should fail)
2. **RED**: Update `highlight_text/2` tests to expect better matches
3. **GREEN**: Implement `find_best_match/2` with shortest span algorithm
4. **GREEN**: Update `highlight_text/2` to use new algorithm
5. **REFACTOR**: Optimize if needed
6. **TEST**: Verify with Playwright that "la" now matches "layouts" not "lib"

**Performance Considerations**:
- Current greedy algorithm: O(n) - very fast
- Shortest span algorithm: O(n*m) - still acceptable for typical log messages
- Can optimize by:
  - Early termination when perfect match found (consecutive chars)
  - Caching results for repeated searches
  - Limiting search to first N matches if too many possibilities

**References**:
- See Helix editor's fuzzy matching behavior (screenshot in `~/Pictures/Screenshots/Screenshot_20251125_030218.png`)
- See ISSUE.md for related highlighting problems

---

### 4.2d Line-Bounded Fuzzy Highlighting ✅ COMPLETE

**Status**: Implemented with 44 passing tests (including 1 new test for cross-line highlighting)

**Problem**:
The fuzzy search was correctly matching patterns only within single lines (via `fuzzy_match?/2`), but the highlighting implementation (`highlight_text/2`) was highlighting matches across multiple lines. This created a mismatch where search behavior was line-bounded but highlighting was not.

**Root Cause**:
The original implementation processed HTML segments progressively with `Enum.map_reduce`, carrying the `remaining_pattern` from one segment to the next. Since HTML segments are divided by tags (not newlines), this allowed pattern matching to span across multiple lines.

**Example Bug**:
```elixir
# Searching for "ba4jcb" in multiline text:
"""
Line with word beginning    # 'b' from "beginning" incorrectly highlighted
Another line with an apple   # 'a' from "an" incorrectly highlighted
The pattern ba4jcb exists here  # Actual match on this line
"""

# Result: Scattered characters on lines 1-2 were highlighted
# even though the pattern only exists on line 3
```

**Solution**:
Redesigned `highlight_text/2` to process each line independently:

1. Split text by newlines
2. For each line:
   - Check if pattern matches that line (using `fuzzy_match?/2`)
   - If yes, try to highlight it
   - Only use highlighted version if full pattern was consumed (`remaining_pattern == ""`)
   - Otherwise keep original line unchanged
3. Join lines back together

**Implementation**: `lib/log_viewer/search.ex:111-183`

**Key Changes**:
```elixir
# New approach: line-bounded highlighting
def highlight_text(text, query) do
  lines = String.split(text, "\n", trim: false)

  highlighted_lines = Enum.map(lines, fn line ->
    if fuzzy_match?(line, query) do
      segments = split_html_segments(line)
      {highlighted_line, remaining_pattern} =
        highlight_across_segments_with_remaining(segments, String.downcase(query))

      # Only use highlighted version if full pattern matched
      if remaining_pattern == "" do
        highlighted_line
      else
        line
      end
    else
      line
    end
  end)

  Enum.join(highlighted_lines, "\n")
end

# New helper: returns both highlighted text AND remaining pattern
defp highlight_across_segments_with_remaining(segments, pattern) do
  {result, remaining_pattern} =
    Enum.map_reduce(segments, pattern, fn segment, remaining_pattern ->
      # ... highlight logic ...
    end)

  {Enum.join(result), remaining_pattern}
end
```

**Test Coverage**:

**New Test** (`test/log_viewer/search_test.exs:384-410`):
```elixir
test "should not highlight scattered characters on other lines" do
  text = """
  Line with word beginning
  Another line with an apple
  The pattern ba4jcb exists here
  """

  query = "ba4jcb"
  result = Search.highlight_text(text, query)

  # Should ONLY highlight on line 3 where pattern exists
  assert result =~ ~s(The pattern <mark class="bg-yellow-200">ba4jcb</mark> exists here)

  # Should NOT highlight scattered characters on other lines
  refute result =~ ~s(<mark class="bg-yellow-200">b</mark>eginning)
  refute result =~ ~s(with <mark class="bg-yellow-200">a</mark>n apple)
end
```

**All Existing Tests**: 44 tests pass, including:
- Fuzzy matching tests
- Highlighting tests with HTML preservation
- Search timeline tests
- Edge cases (empty queries, no matches, etc.)

**Benefits**:
- ✅ Highlighting now matches search behavior (both are line-bounded)
- ✅ More accurate and intuitive highlighting for users
- ✅ HTML structure still preserved correctly
- ✅ Fuzzy matching still works across segments within a line
- ✅ No performance degradation

**Related Files**:
- `lib/log_viewer/search.ex:111-183` - Line-bounded highlighting implementation
- `test/log_viewer/search_test.exs:384-410` - Test for cross-line highlighting bug
- `ISSUE_LINES.md` - Detailed analysis of the bug and architecture
- `ISSUE.md` - Original bug report

**TDD Steps Taken**:
1. **RED**: Created failing test showing 'b' from "beginning" incorrectly highlighted
2. **GREEN**: Implemented line-bounded highlighting (test now passes)
3. **REFACTOR**: Removed unused function, verified no warnings
4. **VERIFY**: All 44 tests pass ✅

---

## Testing Fixtures

Create test fixtures in `test/fixtures/`:

- `test/fixtures/client_logs.json` - Sample IndexedDB export ✅
- `test/fixtures/server_logs.log` - Sample toolshed logs ✅
- `test/fixtures/mixed_timeline.json` - Pre-built timeline for faster tests (optional)

**Sample Client JSON**:
```json
{
  "exportedAt": 1700000000000,
  "logs": [
    {
      "timestamp": 1700000000000,
      "level": "info",
      "module": "memory",
      "key": "storage",
      "messages": ["Stored doc", "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"]
    }
  ]
}
```

**Sample Server Log**:
```
[INFO][toolshed::14:30:45.123] Processing request for space did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK
[ERROR][memory::14:30:45.456] Failed to read doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm
```

---

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/log_viewer/parser_test.exs

# Run with coverage
mix test --cover

# Run in watch mode (requires mix_test_watch)
mix test.watch
```

---

## Development Workflow Summary

For each feature:

1. **Create test file** with `describe` blocks and test cases
2. **Write failing tests** that define expected behavior
3. **Run tests** and verify they fail: `mix test path/to/test.exs`
4. **Implement feature** with minimal code to pass tests
5. **Run tests** and verify they pass (green)
6. **Refactor** code while keeping tests green
7. **Commit** with message like "feat: add client log parser with tests"
8. **Move to next feature**

---

## Optional Future Phases

### Database Persistence
- Tests for saving/loading sessions
- Tests for querying historical data
- Schema migrations

### Real-time Streaming
- Tests for WebSocket connections
- Tests for file watching
- Tests for incremental updates

### Advanced Analysis
- Tests for pattern detection
- Tests for relationship graphs
- Tests for performance metrics

---

## Elixir Code Style & Best Practices

### Type Safety

- **All functions must have `@spec` typespecs** (both public and private)
- **One `@spec` per function** - covers all clauses, not one per clause
- **Use specific types** where possible: `list(map())` instead of `list()`
- **Run `mix dialyzer`** on every change to verify types

### Guards

- **Add guards to all functions** that accept specific types
- **Use `is_binary()` for strings** (strings are binaries in Elixir)
- **Use `is_map()` for maps**, `is_list()` for lists, etc.
- **Prefer pattern matching failure** over catch-all clauses with error returns
  - Let functions fail with `FunctionClauseError` for invalid input types
  - Only use explicit error returns for business logic errors

### Data Validation

- **Use Ecto embedded schemas** for validating external data (JSON, etc.)
- **Use changesets** for validation with `cast/3` and `validate_required/2`
- **Pattern match on structs** to extract validated fields
- **Use `struct!/2`** to convert maps to structs with automatic atom key conversion

### Examples

**Good:**
```elixir
@spec parse_log(String.t()) :: {:ok, Log.t()} | {:error, String.t()}
def parse_log(text) when is_binary(text) do
  # Implementation
end

@spec parse_entries(list(map())) :: {:ok, list(Entry.t())}
defp parse_entries(entries) when is_list(entries) do
  Enum.map(entries, fn entry ->
    struct!(Entry, Map.new(entry, fn {k, v} -> {String.to_atom(k), v} end))
  end)
end
```

**Bad:**
```elixir
# Missing guards, no typespec
def parse_log(text) do
  # Implementation
end

# Multiple specs for one function
@spec parse_entries(list()) :: {:ok, list(Entry.t())}
defp parse_entries(entries) when is_list(entries) do
  # ...
end

@spec parse_entries(any()) :: {:error, String.t()}
defp parse_entries(_), do: {:error, "Invalid input"}
```

### Testing Workflow

1. **Write tests first** (TDD)
2. **Run `mix test`** to verify tests fail
3. **Implement feature**
4. **Run `mix test`** to verify tests pass
5. **Run `mix dialyzer`** to verify types
6. **Refactor** if needed, keeping tests green

---

## Notes

- Use ExUnit for all testing
- Follow Elixir naming conventions (snake_case)
- Keep tests isolated (no shared state)
- Use `setup` blocks for common test data
- Mock external dependencies if needed
- Aim for >80% test coverage
