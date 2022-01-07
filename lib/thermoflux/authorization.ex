defmodule Thermoflux.Ecobee.Authorization do
  defstruct access_token: "",
            expires_in: 0,
            refresh_token: "",
            token_type: "Bearer"
end
