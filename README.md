# log viewer

a phoenix liveview app for viewing and analyzing client and server logs from commontools.

## features

- unified timeline view merging client and server logs by timestamp
- automatic log format detection (client json export or server text logs)
- entity extraction for doc ids, charm ids, and space ids
- drag and drop file upload supporting multiple files up to 100mb each
- real-time parsing and display with phoenix liveview

## log formats

### client logs

to download client logs from commontools:

1. open a pattern in your browser
2. click the bug button (🪲) in the top right header to open the debugger
3. if logging is not enabled, click "DB Log OFF" to turn it on (it will change to "DB Log ON")
4. interact with the pattern to generate logs
5. click the "💾 Export DB" button to download the logs as a json file

expected json format:

```json
{
  "exportedTimestamp": 1763755382416,
  "logs": [
    {
      "timestamp": 1763753972077,
      "level": "error",
      "module": "extended-storage-transaction",
      "key": "storage-error",
      "messages": ["read Error", {}, null]
    }
  ]
}
```

### server logs

toolshed text format:

```
[INFO][toolshed::14:30:45.123] server started on port 8000
[ERROR][memory::14:30:46.456] failed to store doc
```

## prerequisites

### install elixir

**macos:**
```bash
brew install elixir
```

**linux (ubuntu/debian):**
```bash
sudo apt-get update
sudo apt-get install elixir
```

**other platforms:**
see https://elixir-lang.org/install.html

### install phoenix

```bash
mix local.hex
mix archive.install hex phx_new
```

## setup

install dependencies:

```bash
mix setup
```

start the phoenix server:

```bash
mix phx.server
```

visit http://localhost:4000 and upload your log files.

## running tests

```bash
mix test
```

## architecture

- `LogViewer.Parser` - detects and parses client json and server text logs
- `LogViewer.Timeline` - builds unified timeline from parsed logs
- `LogViewer.EntityExtractor` - extracts and indexes doc ids, charm ids, and space ids
- `LogViewerWeb.TimelineLive` - phoenix liveview component for file upload and timeline display
