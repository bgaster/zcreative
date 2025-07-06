import WebSocket from 'ws';

const ws = new WebSocket('ws://localhost:8080');

ws.on('error', console.error);

ws.on('open', function open() {
  const msg = {
    type: 'username',
    header: 'foo'
  };
  ws.send(JSON.stringify(msg));
});

ws.on('message', function message(data) {
  const msg = JSON.parse(data);
  
  switch (msg.type) {
    case "users":
      msg.data.forEach(user => console.log(user));
    break;
  }
});

