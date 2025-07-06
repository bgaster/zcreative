import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 8080 });

const wsClients = [];

var nextUserId = 0;

// controllers
// type: num 
// id: num
// name: string
// values: [ nums ]
//
// slider = type 1 with values [ min, max, value, step ]

const controls = [
  { type: 1, id: 0, name: "slider1", values: [ 0, 100, 50, 1 ] },
  { type: 1, id: 1, name: "slider2", values: [ 0, 100, 23, 1 ] }
];

var nextSliderId = 2;

function broadcast_users() {
  const users = [];
  wsClients.forEach(user => {
    if (user !== undefined) { users.push(user.username); }
  });
  const msg = {
  type: "users",
    "data": users
  };

  wsClients.forEach(user => { 
    if (user !== undefined) { user.ws.send(JSON.stringify(msg)); }
  });
}

function send_controls(ws) {
  const msg = {
    type: "controls",
    data: controls
  };
  ws.send(JSON.stringify(msg));
}

function add_user(ws) {
  // add new user
  ws.id = nextUserId;
  wsClients[ws.id] = { ws: ws, username: 'user' + ws.id };
  nextUserId = nextUserId + 1;
}

function set_username(ws, username) {
  wsClients[ws.id].username = username;
  broadcast_users();
}

function set_controller(ws, type, id, values) {
  if (type === 0) {
    // slider
    if (id < nextSliderId) {
      controls[id].values[2] = values[0];
      // send updated slider to all other clients
      wsClients.forEach(client => { 
        if (client !== undefined && client.ws.id !== ws.id) { 
          const msg = {
            type: "control",
            header: id,
            values: values,
          };
          client.ws.send(JSON.stringify(msg)); 
        }
      });
    }
  }
}

function handle_message(ws, data) {
    const msg = JSON.parse(data);
  
    switch (msg.type) {
    case "username":
      set_username(ws, msg.header);
      break;
    case "get_controls":
      send_controls(ws);
      break;
    case "control":
      set_controller(ws, msg.header, msg.uid, msg.values);
      break;
    }
}


wss.on('connection', function connection(ws) {
  // add client to list
  add_user(ws);
  broadcast_users();

  ws.on('error', console.error);

  ws.on('message', function message(data) {
    handle_message(ws, data);
  });

  ws.on('close', (code, data) => {
    wsClients[ws.id] = undefined;
  });
});

console.log("ws-server! localhost:8080");
