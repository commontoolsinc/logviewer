defmodule LogViewer.Repo do
  use Ecto.Repo,
    otp_app: :log_viewer,
    adapter: Ecto.Adapters.SQLite3
end
