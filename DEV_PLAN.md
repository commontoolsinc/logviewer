# LogViewer Development Plan

This document outlines the development plan for the LogViewer Phoenix LiveView application, following Test-Driven Development (TDD) practices.

## Current Status

### ✅ Completed
- **Phase 1: Core Data Layer** - All parsers, entity extraction, and timeline building complete
- **Phase 2: LiveView UI** - File upload and basic rendering working
- **Phase 3.1: Event Card Component** - Separate, testable component with full test coverage

### 🚧 In Progress
- **Phase 3.2-3.3: Additional UI Components** - Entity lists and modals not yet implemented
- **Phase 4: Polish & Features** - Statistics and search features pending

### 📋 Next Steps
1. Implement fuzzy search with text highlighting
2. Add entity list and detail components
3. Build statistics dashboard

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

### 4.2 Fuzzy Search & Filtering

**Test File**: `test/log_viewer/search_test.exs`

**Test Cases**:
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
