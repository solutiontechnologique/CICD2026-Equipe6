defmodule Myapp.Mongo do
  use GenServer

  @mongo_pool :mongo_pool

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, conn} =
      Mongo.start_link(
        hostname: "localhost",
        database: "my_database",
        pool_size: 10,
        name: @mongo_pool
      )

    {:ok, conn}
  end

  def insert_bateau(bateau) do
    Mongo.insert_one(@mongo_pool, "bateaux", bateau)
  end
end
