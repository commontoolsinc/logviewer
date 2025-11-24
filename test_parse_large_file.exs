#!/usr/bin/env elixir

# Quick script to test parsing large client log files
# Usage: elixir test_parse_large_file.exs [path/to/file.json]

# Add the lib directory to the code path
Code.prepend_path("_build/dev/lib/log_viewer/ebin")
Code.prepend_path("_build/dev/lib/jason/ebin")
Code.prepend_path("_build/dev/lib/ecto/ebin")

# File to test
file_path =
  case System.argv() do
    [path] -> path
    [] -> "/home/ellyse/Downloads/client-logs-2025-11-21T20-03-02-519Z.json"
  end

IO.puts("Testing parser with file: #{file_path}")
IO.puts("File size: #{File.stat!(file_path).size} bytes\n")

# Read the file
IO.puts("Reading file...")
content = File.read!(file_path)
IO.puts("File read successfully (#{byte_size(content)} bytes)\n")

# Try to parse as JSON first to see the structure
IO.puts("Parsing JSON...")
start_time = System.monotonic_time(:millisecond)

case Jason.decode(content) do
  {:ok, data} ->
    parse_time = System.monotonic_time(:millisecond) - start_time
    IO.puts("✓ JSON parsed successfully in #{parse_time}ms")

    IO.puts("\nJSON structure:")
    IO.puts("  Keys: #{inspect(Map.keys(data))}")

    if Map.has_key?(data, "exportedAt") do
      IO.puts("  ✓ Has 'exportedAt': #{data["exportedAt"]}")
    else
      IO.puts("  ✗ Missing 'exportedAt'")
    end

    if Map.has_key?(data, "exportedTimestamp") do
      IO.puts("  ✓ Has 'exportedTimestamp': #{data["exportedTimestamp"]}")
    else
      IO.puts("  ✗ Missing 'exportedTimestamp'")
    end

    if Map.has_key?(data, "logs") do
      logs_count = length(data["logs"])
      IO.puts("  ✓ Has 'logs' array: #{logs_count} entries")

      if logs_count > 0 do
        IO.puts("\nFirst log entry:")
        IO.inspect(Enum.at(data["logs"], 0), pretty: true, limit: 10)
      end
    else
      IO.puts("  ✗ Missing 'logs'")
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Testing LogViewer.Parser.detect_and_parse/1")
    IO.puts(String.duplicate("=", 60) <> "\n")

    # Now try the actual parser
    start_time = System.monotonic_time(:millisecond)

    case LogViewer.Parser.detect_and_parse(content) do
      {:ok, :client, logs} ->
        parse_time = System.monotonic_time(:millisecond) - start_time
        IO.puts("✓ Parser SUCCESS!")
        IO.puts("  Type: client logs")
        IO.puts("  Count: #{length(logs)} entries")
        IO.puts("  Parse time: #{parse_time}ms")

        if length(logs) > 0 do
          IO.puts("\nFirst parsed log entry:")
          IO.inspect(Enum.at(logs, 0), pretty: true)
        end

      {:ok, :server, logs} ->
        parse_time = System.monotonic_time(:millisecond) - start_time
        IO.puts("✓ Parser SUCCESS!")
        IO.puts("  Type: server logs")
        IO.puts("  Count: #{length(logs)} entries")
        IO.puts("  Parse time: #{parse_time}ms")

      {:error, :unknown_format} ->
        parse_time = System.monotonic_time(:millisecond) - start_time
        IO.puts("✗ Parser FAILED: unknown format (#{parse_time}ms)")
        IO.puts("\nThis means the parser couldn't recognize the file format.")
        IO.puts("Likely causes:")
        IO.puts("  - Schema validation failed (missing required fields)")
        IO.puts("  - Empty logs array")
        IO.puts("  - Unexpected JSON structure")

        # Try to get more details by calling parse_client_json directly
        IO.puts("\nTrying LogViewer.Parser.parse_client_json/1 for details...")
        case LogViewer.Parser.parse_client_json(content) do
          {:ok, parsed} ->
            IO.puts("✓ parse_client_json succeeded:")
            IO.inspect(parsed, pretty: true, limit: 5)

          {:error, reason} ->
            IO.puts("✗ parse_client_json failed:")
            IO.puts("  Reason: #{reason}")
        end
    end

  {:error, error} ->
    IO.puts("✗ JSON parsing failed:")
    IO.inspect(error)
end
