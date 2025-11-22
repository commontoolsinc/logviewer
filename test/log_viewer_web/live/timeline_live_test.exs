defmodule LogViewerWeb.TimelineLiveTest do
  use LogViewerWeb.ConnCase

  import Phoenix.LiveViewTest

  @client_fixture_path Path.join([__DIR__, "..", "..", "fixtures", "client_logs.json"])
  @server_fixture_path Path.join([__DIR__, "..", "..", "fixtures", "server_logs.log"])

  describe "mount/3" do
    test "initializes with empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Access socket state to check assigns
      socket = :sys.get_state(view.pid).socket
      assert socket.assigns.timeline == []
      assert socket.assigns.entity_index == nil
    end

    test "renders upload form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Upload Log Files"
    end
  end

  describe "file upload" do
    test "uploads and parses client JSON log file", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      client_content = File.read!(@client_fixture_path)

      # Upload client log file
      file =
        file_input(view, "#upload-form", :log_files, [
          %{
            name: "client.json",
            content: client_content
          }
        ])

      render_upload(file, "client.json")

      # Trigger validate event to process the upload
      render_change(view, "validate", %{})

      # Verify timeline was built
      socket = :sys.get_state(view.pid).socket
      assert length(socket.assigns.timeline) > 0

      # Verify ALL events are from client
      assert Enum.all?(socket.assigns.timeline, fn event ->
               event.source == :client
             end)
    end

    test "uploads and parses server text log file", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      server_content = File.read!(@server_fixture_path)

      # Upload server log file
      file =
        file_input(view, "#upload-form", :log_files, [
          %{
            name: "server.log",
            content: server_content
          }
        ])

      render_upload(file, "server.log")

      # Trigger validate event to process the upload
      render_change(view, "validate", %{})

      # Verify timeline was built
      socket = :sys.get_state(view.pid).socket
      assert length(socket.assigns.timeline) > 0

      # Verify ALL events are from server
      assert Enum.all?(socket.assigns.timeline, fn event ->
               event.source == :server
             end)
    end

    test "uploads multiple files at once", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      client_content = File.read!(@client_fixture_path)
      server_content = File.read!(@server_fixture_path)

      # Upload both files using single file_input but separate uploads
      client_file =
        file_input(view, "#upload-form", :log_files, [
          %{name: "client.json", content: client_content}
        ])

      render_upload(client_file, "client.json")
      render_change(view, "validate", %{})

      server_file =
        file_input(view, "#upload-form", :log_files, [
          %{name: "server.log", content: server_content}
        ])

      render_upload(server_file, "server.log")
      render_change(view, "validate", %{})

      # Verify timeline contains both client and server events
      socket = :sys.get_state(view.pid).socket
      timeline = socket.assigns.timeline

      assert length(timeline) > 0
      assert Enum.any?(timeline, fn event -> event.source == :client end)
      assert Enum.any?(timeline, fn event -> event.source == :server end)

      # Verify timeline is sorted by timestamp
      timestamps = Enum.map(timeline, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)
    end

    test "builds entity index from uploaded files", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      client_content = File.read!(@client_fixture_path)

      file =
        file_input(view, "#upload-form", :log_files, [
          %{name: "client.json", content: client_content}
        ])

      render_upload(file, "client.json")

      # Trigger validate event to process the upload
      render_change(view, "validate", %{})

      # Verify entity index was built
      socket = :sys.get_state(view.pid).socket
      assert socket.assigns.entity_index != nil
      assert map_size(socket.assigns.entity_index.entities) > 0
    end

    test "handles invalid file format gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      invalid_content = "This is not a valid log file"

      file =
        file_input(view, "#upload-form", :log_files, [
          %{name: "invalid.txt", content: invalid_content}
        ])

      # Upload should complete but timeline remains empty
      render_upload(file, "invalid.txt")

      # Trigger validate event
      render_change(view, "validate", %{})

      socket = :sys.get_state(view.pid).socket
      assert socket.assigns.timeline == []
    end

    @tag :skip
    test "handles empty file", %{conn: conn} do
      # Skip: LiveView test harness has ArithmeticError with zero-byte files
      # This is a known issue in phoenix_live_view 1.1.17
      {:ok, view, _html} = live(conn, "/")

      file =
        file_input(view, "#upload-form", :log_files, [
          %{name: "empty.json", content: ""}
        ])

      render_upload(file, "empty.json")
      render_change(view, "validate", %{})

      socket = :sys.get_state(view.pid).socket
      assert socket.assigns.timeline == []
    end
  end
end
