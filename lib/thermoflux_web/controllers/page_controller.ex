defmodule ThermofluxWeb.PageController do
  use ThermofluxWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
