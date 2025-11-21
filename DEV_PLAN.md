# LogViewer Development Plan

This document outlines the development plan for the LogViewer Phoenix LiveView application, following Test-Driven Development (TDD) practices.

## TDD Workflow

For each feature, we follow this cycle:

1. **Write Test First** - Define the expected behavior with a failing test
2. **Run Test** - Verify it fails (red)
3. **Implement Feature** - Write minimal code to make test pass
4. **Run Test** - Verify it passes (green)
5. **Refactor** - Clean up code while keeping tests green

## Phase 1: Core Data Layer

### 1.1 Parser Module - Client JSON

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

## Phase 2: LiveView UI

### 2.1 Main LiveView Component

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

### 3.1 Event Card Component

**Test File**: `test/log_viewer_web/components/event_card_test.exs`

**Test Cases**:
```elixir
describe "event_card/1" do
  test "renders timestamp"
  test "renders level with correct color (INFO=green, WARN=yellow, ERROR=red)"
  test "renders module name"
  test "renders source badge (client/server)"
  test "renders event content"
  test "highlights entity IDs in content"
end
```

**Implementation**: `lib/log_viewer_web/components/event_card.ex`
- Define function component `event_card/1`
- Use slots for flexibility
- Apply TailwindCSS styling
- Add entity ID highlighting logic

**TDD Steps**:
1. Write component tests
2. Run test - should fail
3. Create component with styling
4. Run test - should pass

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

### 4.2 Search & Filtering

**Test File**: `test/log_viewer/filter_test.exs`

**Test Cases**:
```elixir
describe "filter_events/2" do
  test "filters by search text"
  test "filters by level"
  test "filters by source"
  test "filters by module"
  test "combines multiple filters (AND logic)"
end
```

**Implementation**: `lib/log_viewer/filter.ex`
- Implement `filter_events/2`
- Support multiple filter criteria

**TDD Steps**:
1. Write filter tests
2. Run test - should fail
3. Implement filter logic
4. Run test - should pass

---

## Testing Fixtures

Create test fixtures in `test/fixtures/`:

- `test/fixtures/client_logs.json` - Sample IndexedDB export
- `test/fixtures/server_logs.txt` - Sample toolshed logs
- `test/fixtures/mixed_timeline.json` - Pre-built timeline for faster tests

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
