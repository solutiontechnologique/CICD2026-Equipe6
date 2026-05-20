defmodule MyappWeb.PageController do
  use MyappWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/swagger")
  end
end
