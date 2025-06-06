import React, {useEffect, useState} from 'react';
import Button from '@mui/material/Button';
import { Card, CardContent, Typography } from '@mui/material';

import socket from '../services/taxi_socket';

function Driver(props) {
  const [message, setMessage] = useState();
  const [bookingId, setBookingId] = useState();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const channel = socket.channel("driver:" + props.username, {token: "123"});

    channel.on("booking_request", data => {
      console.log("Received", data);
 
      setMessage(data.msg);
      setBookingId(data.bookingId);
      setVisible(true);
    });

    // no sirve

    // channel.on("booking_no_accepted", data => {
    //   console.log("Received", data);
 
    //   setMessage(data.msg);
    //   setVisible(false);
    // });

    channel.on("somebody_took_ride", data => {
      console.log("Received", data);
      setMessage(data.msg);
      setVisible(false); // oculta si otro conductor fue asignado
    });

    channel.join();
  }, [props]);

  const reply = (decision) => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: decision, username: props.username})
    }).then(() => {
      setVisible(false);
      setMessage(null);
      setBookingId(null);
    });
  };

  if (!visible) return null;

  return (
    <div style={{textAlign: "center", borderStyle: "solid"}}>
      Driver: {props.username}
      <div style={{backgroundColor: "lavender", height: "100px"}}>
        <Card variant="outlined" style={{margin: "auto", width: "600px"}}>
          <CardContent>
            <Typography>{message}</Typography>
          </CardContent>
            <>
              <Button onClick={() => reply("accept")} variant="outlined" color="primary">Accept</Button>
              <Button onClick={() => reply("reject")} variant="outlined" color="secondary">Reject</Button>
            </>
        </Card>
      </div>
    </div>
  );
}

export default Driver;
