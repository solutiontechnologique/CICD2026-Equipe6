defmodule MyappWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :myapp

  @session_options [
    store: :cookie,
    key: "_myapp_key",
    signing_salt: "change_me"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/swagger",
    from: {:phoenix_swagger, "priv/static"},
    gzip: false,
    only: ~w(
    swagger-ui.css
    swagger-ui-bundle.js
    swagger-ui-standalone-preset.js
    favicon-16x16.png
    favicon-32x32.png
    oauth2-redirect.html
  )

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :myapp
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug CORSPlug,
    origin: ["http://localhost:5173"],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Content-Type", "Authorization", "Accept"],
    max_age: 86400

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MyappWeb.Router
end
