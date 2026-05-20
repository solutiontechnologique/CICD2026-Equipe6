defmodule MyappWeb.Plugs.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @token_salt "user_auth"

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <-
           Phoenix.Token.verify(MyappWeb.Endpoint, @token_salt, token, max_age: 60 * 60 * 24 * 7) do
      assign(conn, :current_user_id, user_id)
    else
      _ ->
        conn
        |> put_status(401)
        |> json(%{error: "Accès non autorisé"})
        |> halt()
    end
  end
end
