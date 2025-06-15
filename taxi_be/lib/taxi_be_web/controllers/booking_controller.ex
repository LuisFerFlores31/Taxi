defmodule TaxiBeWeb.BookingController do
  use TaxiBeWeb, :controller
  alias TaxiBeWeb.TaxiAllocationJob

  def create(conn, req) do
    IO.inspect(req)
    booking_id = UUID.uuid1()
    IO.puts("Created booking_id: #{booking_id}")

    TaxiAllocationJob.start_link(
      req |> Map.put("booking_id", booking_id),
      String.to_atom(booking_id)
    )

    conn
    |> put_resp_header("Location", "/api/bookings/" <> booking_id)
    |> put_status(:created)
    |> json(%{msg: "We are processing your request ... don't be hasty!", bookingId: booking_id})
  end
  def update(conn, %{"action" => "accept", "username" => username, "id" => id} = msg) do
    GenServer.cast(String.to_atom(id), {:process_accept, msg})
    IO.inspect("'#{username}' is accepting a booking request")
    json(conn, %{msg: "We will process your acceptance"})
  end
  def update(conn, %{"action" => "reject", "username" => username, "id" => id} = msg) do
    GenServer.cast(String.to_atom(id), {:process_reject, msg})
    IO.inspect("'#{username}' is rejecting a booking request")
    json(conn, %{msg: "We will process your rejection"})
  end

  def update(conn, %{"action" => "cancel", "username" => username, "id" => id} = msg) do
    IO.puts("Processing cancel request for booking_id: #{id}")
    GenServer.cast(String.to_atom(id), {:process_cancel, msg})
    IO.inspect("'#{username}' is cancelling a booking request")
    json(conn, %{msg: "We will process your cancelation"})
  end

  def update(conn, %{"action" => "decision", "mensaje" => mensaje, "id" => id} = msg) do

    cond do
      mensaje == "accept" ->
        GenServer.cast(String.to_atom(id), {:process_accept, msg})

      mensaje == "reject" ->
        GenServer.cast(String.to_atom(id), {:process_reject, msg})

      true ->
        GenServer.cast(String.to_atom(id), {:ok, msg})
    end

    json(conn, %{msg: "We will process your desicion"})
  end

end
