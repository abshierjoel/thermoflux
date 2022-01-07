defmodule Thermoflux.Ecobee do
  use Tesla, only: [:get, :post], docs: false
  alias Thermoflux.Ecobee.{Authorization, Thermostat}

  plug(Tesla.Middleware.BaseUrl, "https://api.ecobee.com")
  plug(Tesla.Middleware.Headers)
  plug(Tesla.Middleware.JSON)

  @api_key Application.get_env(:thermoflux, :ecobee_api_key)

  def authorization do
    query = [response_type: "ecobeePin", client_id: @api_key, scope: "smartWrite"]
    {:ok, %{body: body}} = get("/authorize", query: query)

    {body["ecobeePin"], body["code"]}
  end

  def access_token(auth_code) do
    query = [
      grant_type: "ecobeePin",
      code: auth_code,
      client_id: @api_key
    ]

    {:ok, %{body: response}} = post("/token", %{}, query: query)

    response
  end

  def refresh_token(%Authorization{refresh_token: refresh_token}) do
    query = [
      grant_type: "refresh_token",
      code: refresh_token,
      client_id: @api_key
    ]

    {:ok, %{body: response}} = post("/token", %{}, query: query)

    response
    |> to_atom_keys
    |> to_authorization
  end

  def thermostats(%Authorization{access_token: access_token}) do
    headers = [{"content-type", "text/json"}, {"authorization", "Bearer #{access_token}"}]
    query = thermostat_selection()

    with {:ok, %Tesla.Env{body: body, status: 200}} <-
           get("/1/thermostat", headers: headers, query: query),
         response <- to_atom_keys(body),
         thermostats <- response[:thermostatList] do
      thermostats
      |> Enum.map(&to_thermostat/1)
    else
      _ ->
        :error
    end
  end

  defp to_atom_keys(map), do: Enum.map(map, fn {k, v} -> {String.to_atom(k), v} end)
  defp to_authorization(map), do: struct(Authorization, map)
  defp to_thermostat(map), do: struct(Thermostat, map)

  defp thermostat_selection do
    with {:ok, string} <-
           Jason.encode(%{
             selection: %{
               selectionType: "registered",
               selectionMatch: "",
               includeRuntime: true
             }
           }) do
      [
        format: "json",
        body: string
      ]
    end
  end
end
