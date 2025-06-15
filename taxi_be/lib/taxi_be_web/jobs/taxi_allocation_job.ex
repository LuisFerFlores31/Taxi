defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :step1, [:nosuspend])
    {:ok, %{request: request,
            accepted_taxi: nil}}
  end

def compute_ride_fare(request) do
  %{
    "pickup_address" => pickup_address,
    "dropoff_address" => dropoff_address
   } = request

  # coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
  # coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
  # {distance, _duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
  {request, [70,90,120,200,250] |> Enum.random() } # Float.ceil(distance/300)}
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
      "booking_id" => booking_id,
      "username" => customer_username
    } = request

    # Notificar al cliente con el booking_id
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{
        msg: "Solicitud de viaje creada",
        bookingId: booking_id
      }
    )

    Enum.each(list_of_taxis, fn taxi ->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
        %{
          msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
          bookingId: booking_id
        }
      )
    end)

    timer = Process.send_after(self(), TimeOut, 10000) # 10 segundos

    {:noreply, %{
      request: request,
      contacted_taxi: taxi,
      candidates: tl(list_of_taxis),
      timer: timer,
      grace_time: nil,
      grace_expired: false,
      all_taxis: list_of_taxis,
      accepted_taxi: nil
    }}
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

    {:noreply, %{state | contacted_taxi: taxi, candidates: tl(list_of_taxis)}}
  end

  # Caso de que los taxis no aceptenS

  def handle_info(TimeOut, %{request: request, all_taxis: taxis} = state) do

    IO.puts("Ningun taxi ha aceptado el viaje")
    %{request: %{"username" => customer_username}} = state

    # Avisar al cliente que no hay taxis disponibles
    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "No hay taxis disponibles"}
    )

    # Notificar de la cancelacion por no responder
    Enum.each(taxis, fn taxi ->
      TaxiBeWeb.Endpoint.broadcast(
        "driver:" <> taxi.nickname,
        "booking_request",
        %{msg: "Solicitud rechazada por inactividad"}
      )
    end)

    {:stop, :normal, %{state | timer: nil}}
  end

  # Caso de que se rechazen a todos los taxis
  def handle_cast({:process_reject, _msg}, %{candidates: []} = state) do
    %{request: %{"username" => customer_username}} = state

    IO.puts("Todos los taxis han sido rechazados")

    if state.timer, do: Process.cancel_timer(state.timer)
    if state.grace_time, do: Process.cancel_timer(state.grace_time)

    TaxiBeWeb.Endpoint.broadcast(
      "customer:" <> customer_username,
      "booking_request",
      %{msg: "No hay taxis disponibles"}
    )
    {:stop, :normal, state}
  end

  def handle_cast({:process_reject, _msg}, state) do
    IO.puts("ENTERED REJECTION")
    auxilary(state)
  end

  def handle_cast({:process_accept, msg}, state) do
    %{request: %{"username" => customer_username}} = state
    %{"username" => accepting_driver} = msg

    IO.puts("Aceptado, timeOut cancelado")

    if state.timer, do: Process.cancel_timer(state.timer)

    Enum.each(state.all_taxis, fn taxi ->
      if taxi.nickname != accepting_driver do
        TaxiBeWeb.Endpoint.broadcast(
          "driver:" <> taxi.nickname,
          "booking_request",
          %{msg: "Solicitud tomada"}
        )
      end
    end)

    grace_time = Process.send_after(self(), GraceTime, 15000)

    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer_username, "booking_request", %{msg: "Tu taxi esta en camino y llegara 5 minutos"})

    IO.inspect(accepting_driver)
    {:noreply, %{state | timer: nil,
      accepted_taxi: %{nickname: accepting_driver},
      grace_time: grace_time,
      grace_expired: false
    }}

  end

  def handle_info(GraceTime, state) do
    IO.puts("Período de gracia terminado")
    {:noreply, %{state | grace_expired: true}}
  end


  # Caso de que se rechazen a todos los taxis

  def handle_cast({:process_cancel, msg}, state) do
    %{request: %{"username" => customer_username}} = state
    IO.puts("Solicitud cancelada por el cliente")

    if state.accepted_taxi != nil do
      if state.grace_expired do
        IO.puts("Se cobra cargo de $20")
          TaxiBeWeb.Endpoint.broadcast(
            "customer:" <> customer_username,
            "booking_request",
            %{msg: "Tu solicitud ha sido cancelada con cargo de $20"}
          )

        {:stop, :normal, state}

      else

        if state.grace_time, do: Process.cancel_timer(state.grace_time)
        if state.timer, do: Process.cancel_timer(state.timer)

        IO.puts("Se cancela sin cargo")
          TaxiBeWeb.Endpoint.broadcast(
            "customer:" <> customer_username,
            "booking_request",
            %{msg: "Tu solicitud ha sido cancelada sin cargo"}
          )

        {:stop, :normal, state}

      end
    else

      if state.timer, do: Process.cancel_timer(state.timer)

        # Notificar al cliente
      TaxiBeWeb.Endpoint.broadcast(
        "customer:" <> customer_username,
        "booking_request",
        %{msg: "Tu solicitud ha sido cancelada"}
      )

      # Notificar a todos los conductores
      Enum.each(state.all_taxis, fn taxi ->
        TaxiBeWeb.Endpoint.broadcast(
          "driver:" <> taxi.nickname,
          "booking_request",
          %{msg: "Solicitud cancelada por el cliente"}
        )
      end)

      {:stop, :normal, state}
    end
  end

  def handle_cast({:ok, msg}, state) do
    IO.puts("ENTERED OK")
    if state.timer, do: Process.cancel_timer(state.timer)
    {:stop, :normal, state}
  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "pippin", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end
end
