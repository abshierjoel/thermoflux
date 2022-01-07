defmodule Thermoflux.Ecobee do
  use Tesla, only: [:get, :post], docs: false
  alias Thermoflux.Ecobee.{Authorization, Thermostat}

  plug(Tesla.Middleware.BaseUrl, "https://api.ecobee.com")
  plug(Tesla.Middleware.Headers)
  plug(Tesla.Middleware.JSON)

  @api_key Application.get_env(:thermoflux, :ecobee_api_key)
  # @access_token %{
  #   "access_token" => "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlJFWXhNVEpDT0Rnek9UaERRelJHTkRCRlFqZEdNVGxETnpaR1JUZzRNalEwTmtWR01UQkdPQSJ9.eyJpc3MiOiJodHRwczovL2F1dGguZWNvYmVlLmNvbS8iLCJzdWIiOiJhdXRoMHwxNDVmMzEwZS1jYjY4LTQ5MGEtOTdmOS1iMjU2MzIwODgyMmYiLCJhdWQiOlsiaHR0cHM6Ly9kZXZlbG9wZXItYXBwcy5lY29iZWUuY29tL2FwaS92MSIsImh0dHBzOi8vZWNvYmVlLXByb2QuYXV0aDAuY29tL3VzZXJpbmZvIl0sImlhdCI6MTY0MTQyMjc3NSwiZXhwIjoxNjQxNDI2Mzc1LCJhenAiOiJ4NVkyeHBRYUpvRmpLQUFCd0RTMW9JcXhUcEhZOTR1WiIsInNjb3BlIjoib3BlbmlkIHNtYXJ0V3JpdGUgb2ZmbGluZV9hY2Nlc3MifQ.UJwvMxATW4nTW3cPZIubACRDzmR9e6-VGN5e3cb0d5shMdnNo8lzcbKorJkKTIPiDphO_LbDXHcFdP3gP2shHqZVwr3zXGfZFwgZYN4O8Ggutoeb17HIzdlH8OATet-Dh39vUi2s-3q1e4QgxNIL6JGyr7LookFX4HyTDA5NQFC_kI86TBnn33fh_Nk_kf3RskGAWvq6qtCGTVEo2mKRvl8LGqf3c9JpuE4gSWMdr5TeG0T4esIE03Cn3J2oBNt8TNRT-O48N3-QO97dRt_m6AAlBaGkH3WTclm6QO-ikXcV1yQUHu02v5uCcW6SETJO9ptg8l0bMrqmLKeUJp5vWQ",
  #   "expires_in" => 3600,
  #   "refresh_token" => "knaJ6QnaJaP06idHRWPFWfZ4y-oyPCle3tT3KMlwOtoMN",
  #   "scope" => "openid,smartWrite,offline_access",
  #   "token_type" => "Bearer"
  # }

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
