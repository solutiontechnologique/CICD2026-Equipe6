defmodule MyappWeb.BackupController do
  use MyappWeb, :controller

  @mongo_pool :mongo

  def download(conn, _params) do
    collections =
      Mongo.show_collections(@mongo_pool)

    data =
      collections
      |> Enum.map(fn collection ->
        docs =
          Mongo.find(@mongo_pool, collection, %{})
          |> Enum.map(&serialize/1)

        {collection, docs}
      end)
      |> Enum.into(%{})

    json = Jason.encode!(data, pretty: true)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"backup.json\""
    )
    |> send_resp(200, json)
  end

  # BSON ObjectId
  defp serialize(%BSON.ObjectId{} = id) do
    BSON.ObjectId.encode!(id)
  end

  # DateTime
  defp serialize(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  # Maps
  defp serialize(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {k, serialize(v)}
    end)
    |> Enum.into(%{})
  end

  # Lists
  defp serialize(list) when is_list(list) do
    Enum.map(list, &serialize/1)
  end

  # Other values
  defp serialize(value), do: value
end
