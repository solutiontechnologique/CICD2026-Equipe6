import Config

if System.get_env("PHX_SERVER") do
  config :myapp, MyappWeb.Endpoint, server: true
end

config :myapp, :mongo,
  url: System.get_env("MONGO_URL") || "mongodb://localhost:27017/my_database",
  pool_size: String.to_integer(System.get_env("MONGO_POOL_SIZE") || "5")

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :myapp, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :myapp, MyappWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
