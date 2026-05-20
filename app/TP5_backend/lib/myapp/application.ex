defmodule Myapp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    mongo_config = Application.get_env(:myapp, :mongo)

    IO.inspect(mongo_config, label: "MONGO CONFIG UTILISÉE")

    children = [
      {Mongo,
       [
         name: :mongo,
         url: mongo_config[:url],
         pool_size: mongo_config[:pool_size]
       ]},
      MyappWeb.Telemetry,
      Myapp.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:myapp, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:myapp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Myapp.PubSub},
      MyappWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Myapp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MyappWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    System.get_env("RELEASE_NAME") == nil
  end
end
