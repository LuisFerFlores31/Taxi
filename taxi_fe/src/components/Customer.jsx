import React, {useEffect, useState, useCallback} from 'react';
import Button from '@mui/material/Button'
import socket from '../services/taxi_socket';
import { TextField, Box } from '@mui/material';

function Customer(props) {
  let [pickupAddress, setPickupAddress] = useState("Tecnologico de Monterrey, campus Puebla, Mexico");
  let [dropOffAddress, setDropOffAddress] = useState("Triangulo Las Animas, Puebla, Mexico");
  let [msg, setMsg] = useState("");
  let [msg1, setMsg1] = useState("");
  let [bookingId, setBookingId] = useState(null);

  // Debug effect to monitor bookingId changes
  useEffect(() => {
    console.log("bookingId changed:", bookingId);
  }, [bookingId]);

  const updateBookingId = useCallback((id) => {
    console.log("Updating bookingId to:", id);
    setBookingId(id);
  }, []);

  useEffect(() => {
    console.log("Setting up socket connection for user:", props.username);
    let channel = socket.channel("customer:" + props.username, {token: "123"});
    
    channel.on("greetings", data => {
      console.log("Greetings received:", data);
    });

    channel.on("booking_request", dataFromPush => {
      console.log("Received socket message:", dataFromPush);
      console.log("Received socket message:", dataFromPush);
      setMsg1(dataFromPush.msg);
      
      // Establecer bookingId si viene en el mensaje
      if (dataFromPush.bookingId) {
        console.log("Setting bookingId from socket:", dataFromPush.bookingId);
        updateBookingId(dataFromPush.bookingId);
      }

      if (dataFromPush.msg.includes("Tu solicitud ha sido cancelada") || dataFromPush.msg.includes("No hay taxis disponibles")){
        console.log("Booking completed - resetting bookingId");
        updateBookingId(null);
      }
    
    });

    channel.join()
      .receive("ok", resp => {
        console.log("Joined channel successfully:", resp);
      })
      .receive("error", resp => {
        console.error("Failed to join channel:", resp);
      });

    return () => {
      console.log("Cleaning up socket connection");
      channel.leave();
    };
  }, [props.username, updateBookingId]);

  let submit = async () => {
    console.log("Submitting new booking request...");
    try {
      const response = await fetch(`http://localhost:4000/api/bookings`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          pickup_address: pickupAddress, 
          dropoff_address: dropOffAddress, 
          username: props.username
        })
      });

      console.log("Response status:", response.status);
      
      const data = await response.json();
      console.log("Response data:", data);
      setMsg(data.msg);
      
      // Usar bookingId del JSON response
      if (data.booking_id) {
        console.log("Setting bookingId from response:", data.booking_id);
        updateBookingId(data.booking_id);
      }
    } catch (error) {
      console.error("Error submitting booking:", error);
      setMsg("Error al crear la reserva");
    }
  };

  let cancelBooking = async () => {
    console.log("Attempting to cancel booking. Current bookingId:", bookingId);
    if (!bookingId) {
      console.log("No active booking found");
      setMsg1("No hay viaje activo para cancelar.");
      return;
    }
    
    try {
      console.log("Sending cancel request for bookingId:", bookingId);
      const response = await fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          action: "cancel", 
          username: props.username, 
          id: bookingId
        })
      });
  
      const data = await response.json();
      console.log("Cancel response:", data);
      setMsg(data.msg);
      
    } catch (error) {
      console.error("Error canceling booking:", error);
      setMsg("Error al cancelar la reserva");
    }
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid", backgroundColor: "white"}}>
      Customer: {props.username}
      <div>
        <TextField id="outlined-basic" label="Pickup address"
          fullWidth
          onChange={ev => setPickupAddress(ev.target.value)}
          value={pickupAddress}/>
        <TextField id="outlined-basic" label="Drop off address"
          fullWidth
          onChange={ev => setDropOffAddress(ev.target.value)}
          value={dropOffAddress}/>
      
        <Button onClick={submit} variant="outlined" color="primary">Submit</Button>
        <Button onClick={cancelBooking} variant="outlined" color="secondary" style={{marginLeft: "10px"}}>Cancel</Button>
      </div>
      <div style={{backgroundColor: "lightcyan", height: "50px", color: 'black'}}>
        {msg}
      </div>
      <div style={{backgroundColor: "lightblue", height: "50px", color: 'black'}}>
        {msg1}
      </div>
      <div style={{fontSize: "12px", color: "gray"}}>
        Booking ID: {bookingId || "No active booking"}
      </div>
    </div>
  );
}
export default Customer;