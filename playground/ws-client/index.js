import WebSocket from 'ws';

// const ws = new WebSocket('wss://localhost:8080');
const ws = new WebSocket(`wss://localhost:8080`, {
    rejectUnauthorized: false
});

ws.on('error', console.error);

ws.on('open', function open() {
  console.log('opened')
  ws.send('hello');
});

ws.on('message', function message(data) {
  console.log(data);
});

