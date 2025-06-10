import React, {useEffect, useState} from 'react';
import Button from '@mui/material/Button'

import socket from '../services/taxi_socket';
import { TextField } from '@mui/material';

function Customer(props) {
  let [pickupAddress, setPickupAddress] = useState("Tecnologico de Monterrey, campus Puebla, Mexico");
  let [dropOffAddress, setDropOffAddress] = useState("Triangulo Las Animas, Puebla, Mexico");
  let [msg, setMsg] = useState("");
  let [msg1, setMsg1] = useState("");
  let [currentBookingId, setCurrentBookingId] = useState(null);
  let [isBookingActive, setIsBookingActive] = useState(false);

  useEffect(() => {
    let channel = socket.channel("customer:" + props.username, {token: "123"});
    channel.on("greetings", data => console.log(data));
    channel.on("booking_request", dataFromPush => {
      console.log("Received", dataFromPush);
      setMsg1(dataFromPush.msg);
    });
    channel.join();
  },[props]);

  let submit = () => {
    fetch(`http://localhost:4000/api/bookings`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({pickup_address: pickupAddress, dropoff_address: dropOffAddress, username: props.username})
    })
    .then(
    // Aqui se esta extrae el bookingId( se usa para cancelar)
     resp => {
      const location = resp.headers.get("location");
      if (location) {
        const bookingId = location.split("/").pop();
        setCurrentBookingId(bookingId);
        setIsBookingActive(true);
      }
      return resp.json();
     }
    )
    .then(dataFromPOST => setMsg(dataFromPOST.msg));
  };

  let cancel = () => {
    if (!currentBookingId) {
      return;
    }
    fetch(`http://localhost:4000/api/bookings/${currentBookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: "cancel", username: props.username, id: currentBookingId})
    })
    .then(resp => resp.json())
    .then(data => {
      setMsg(data.msg);
      setIsBookingActive(false);
      setCurrentBookingId(null);
      setMsg1("");
    });
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid"}}>
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
        <Button onClick={cancel} variant="outlined" color="primary">Cancel</Button>
      </div>
      <div style={{backgroundColor: "lightcyan", height: "50px"}}>
        {msg}
      </div>
      <div style={{backgroundColor: "lightblue", height: "50px"}}>
        {msg1}
      </div>
    </div>
  );
}

export default Customer;
