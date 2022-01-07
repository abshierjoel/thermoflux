defmodule Thermoflux.TemperatureProbe do
  alias Thermoflux.Ecobee

  def init(auth) do
    refreshed_auth = Ecobee.refresh_token(auth)

    send(self(), :probe_temp)
    Process.send_after(self(), :refresh_auth, 3_000_000)
    {:ok, %{auth: refreshed_auth, temps: []}}
  end

  def handle_call(:get_temps, _from, state) do
    {:reply, state.temps, state}
  end

  def handle_info(:probe_temp, %{auth: auth, temps: temps} = state) do
    thermostats = Ecobee.thermostats(auth)

    new_temps = Enum.map(thermostats, &Thermoflux.Ecobee.Thermostat.current_temp/1)

    Process.send_after(self(), :probe_temp, 1_000)

    {:noreply, %{state | temps: temps ++ new_temps}}
  end

  def handle_info(:refresh_auth, state = %{auth: auth}) do
    Process.send_after(self(), :refresh_auth, 3_000_000)
    {:noreply, %{state | auth: Ecobee.refresh_token(auth)}}
  end
end
