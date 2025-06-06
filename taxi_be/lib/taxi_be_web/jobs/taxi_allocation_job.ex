defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :step1, [:nosuspend])
    {:ok, %{request: request}}
  end

  def compute_ride_fare(request) do
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
    } = request

    {request, [70,90,120,200,250] |> Enum.random()}
  end

  def notify_customer_ride_fare({request, fare}) do
    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare}"})
  end

  def find_candidate_taxis(%{"pickup_address" => _pickup_address}) do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "pippin", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "samwise", latitude: 19.0092933, longitude: -98.2473716}
    ]
  end

  def handle_info(:step1, %{request: request} = state) do
    task = Task.async(fn ->
      compute_ride_fare(request)
      |> notify_customer_ride_fare()
    end)

    list_of_taxis = find_candidate_taxis(request)

    Task.await(task)

    IO.inspect(list_of_taxis)

    # Select a taxi
    taxi = hd(list_of_taxis)

    # Forward request to taxi driver
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request

    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_request",
      %{
        msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
        bookingId: booking_id
      })

    timer = Process.send_after(self(), :timeout, 60_000)  # 1 minuto de timeout

    {:noreply, %{request: request, contacted_taxi: taxi, candidates: tl(list_of_taxis), timer: timer}}
  end

  def handle_info(:timeout, %{candidates: []} = state) do
    # No hay más conductores disponibles
    %{request: %{"username" => customer_username}} = state
    IO.puts("No more drivers available!")
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Lo sentimos, no hay taxis disponibles en este momento"}
    )
    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    IO.puts("Time OUT!!!")
    Process.cancel_timer(state.timer)
    auxilary(state)
  end

  def handle_cast({:process_reject, _msg}, %{candidates: []} = state) do
    # No hay más conductores, notificar al cliente
    %{request: %{"username" => customer_username}} = state
    IO.puts("Last driver rejected - no more drivers available")
    Process.cancel_timer(state.timer)
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Lo sentimos, no hay taxis disponibles en este momento"}
    )
    {:stop, :normal, state}
  end

  def handle_cast({:process_reject, msg}, state) do
    IO.puts("Driver rejected the request")
    Process.cancel_timer(state.timer)
    auxilary(state)
  end

  def handle_cast({:process_accept, msg}, state) do
    %{request: %{"username" => customer_username}, contacted_taxi: taxi, timer: timer} = state
    IO.puts("Driver accepted the request!")
    Process.cancel_timer(timer)

    # Notificar al cliente
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "¡Tu taxi está en camino! Conductor: #{taxi.nickname} llegará en 5 minutos"}
    )

    # Notificar al conductor con la información del viaje
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
    } = state.request

    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_confirmed",
      %{
        msg: "Viaje confirmado",
        pickup: pickup_address,
        dropoff: dropoff_address,
        customer: customer_username
      }
    )

    {:stop, :normal, state}
  end

  def auxilary(%{candidates: []} = state) do
    # No hay más conductores disponibles
    %{request: %{"username" => customer_username}} = state
    IO.puts("No more drivers available in auxilary!")
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "Lo sentimos, no hay taxis disponibles en este momento"}
    )
    {:stop, :normal, state}
  end

  def auxilary(%{request: request, candidates: list_of_taxis} = state) do
    taxi = hd(list_of_taxis)
    IO.inspect(taxi)
    # Forward request to taxi driver
    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request

    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_request",
      %{
        msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
        bookingId: booking_id
      })

    timer = Process.send_after(self(), :timeout, 60_000)  # 1 minuto de timeout
    {:noreply, %{state | contacted_taxi: taxi, candidates: tl(list_of_taxis), timer: timer}}
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "pippin", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end
end
