#!/usr/bin/env elixir

# Test script to parse server logs and build timeline
# This ensures we catch any issues that only show up during timeline rendering

Mix.install([
  {:jason, "~> 1.4"},
  {:ecto, "~> 3.11"}
])

Code.require_file("lib/log_viewer/parser.ex", __DIR__)
Code.require_file("lib/log_viewer/timeline.ex", __DIR__)

log_file_path = "/home/ellyse/projects/labs/packages/toolshed/local-dev-toolshed.log"

IO.puts("=" <> String.duplicate("=", 79))
IO.puts("Testing Server Log Parsing with Timeline Building")
IO.puts("=" <> String.duplicate("=", 79))
IO.puts("")

# Check file exists
unless File.exists?(log_file_path) do
  IO.puts("❌ Error: Log file not found at #{log_file_path}")
  System.halt(1)
end

file_size = File.stat!(log_file_path).size
IO.puts("📄 Reading log file: #{log_file_path}")
IO.puts("📊 File size: #{file_size} bytes (#{Float.round(file_size / 1024, 2)} KB)")
IO.puts("")

# Read file
content = File.read!(log_file_path)
IO.puts("✓ File read successfully")
IO.puts("")

# Parse logs
IO.puts("🔍 Parsing server logs...")
start_time = System.monotonic_time(:millisecond)

case LogViewer.Parser.detect_and_parse(content) do
  {:ok, :server, server_logs} ->
    parse_time = System.monotonic_time(:millisecond) - start_time
    IO.puts("✓ Parsed #{length(server_logs)} server log entries in #{parse_time}ms")
    IO.puts("")

    # Show first few entries
    IO.puts("📋 First 3 log entries:")
    Enum.take(server_logs, 3)
    |> Enum.with_index(1)
    |> Enum.each(fn {log, idx} ->
      IO.puts("  #{idx}. [#{log.level}][#{log.module}] #{log.message}")
    end)
    IO.puts("")

    # Build timeline (this is where we might hit errors!)
    IO.puts("🏗️  Building timeline (testing message serialization)...")
    timeline_start = System.monotonic_time(:millisecond)

    timeline = LogViewer.Timeline.build_timeline([], server_logs)

    timeline_time = System.monotonic_time(:millisecond) - timeline_start
    IO.puts("✓ Built timeline with #{length(timeline)} events in #{timeline_time}ms")
    IO.puts("")

    # Test that we can convert messages to strings (this is what failed before)
    IO.puts("🧪 Testing message serialization for first 5 events...")
    Enum.take(timeline, 5)
    |> Enum.with_index(1)
    |> Enum.each(fn {event, idx} ->
      try do
        # The message field has already been serialized by from_server_entry
        message_preview = String.slice(event.message, 0, 60)
        IO.puts("  #{idx}. [#{event.level}] #{message_preview}...")
      rescue
        e ->
          IO.puts("  #{idx}. ❌ Error serializing message: #{inspect(e)}")
          IO.puts("       Raw entry: #{inspect(event.raw_entry)}")
      end
    end)
    IO.puts("")

    IO.puts("=" <> String.duplicate("=", 79))
    IO.puts("✅ SUCCESS - Full parsing and timeline building completed!")
    IO.puts("=" <> String.duplicate("=", 79))

  {:ok, :client, _} ->
    IO.puts("❌ Error: File was detected as client logs, not server logs")
    System.halt(1)

  {:error, reason} ->
    IO.puts("❌ Error parsing logs: #{inspect(reason)}")
    System.halt(1)
end
