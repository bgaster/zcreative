import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 8080 });

//-----------------------------------------------------------------------------
// audio globals and so on.
//-----------------------------------------------------------------------------

// --- Audio Parameters (MUST MATCH CLIENT'S DECODER) ---
const SAMPLE_RATE = 48000;       // Standard sample rate for Web Audio
const CHANNELS = 1;              // Mono audio
const FRAME_DURATION_MS = 20;    // How often to send a new chunk (e.g., 20ms)
const SAMPLES_PER_FRAME = (SAMPLE_RATE / 1000) * FRAME_DURATION_MS; // 960 samples for 20ms at 48kHz

// --- Sine Wave Parameters ---
const FREQUENCY = 440; // Hz (A4 note)
const AMPLITUDE = 0.5; // Max 1.0 (for Float32Array)

let timerId = null;
let phase = 0; // To keep sine wave continuous across frames

//-----------------------------------------------------------------------------
// control globals and so on.
//-----------------------------------------------------------------------------

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

console.log("control server! localhost:8080");

//-----------------------------------------------------------------------------
// audio stuff
//-----------------------------------------------------------------------------

const wss_audio = new WebSocketServer({ port: 6080 });
console.log('audio server! localhost:6080');

// Generates a chunk of 32-bit floating-point PCM sine wave data (Float32Array)
// This format is directly compatible with Web Audio API's AudioBuffer.
function generateSineWavePCM(samplesCount, frequency, amplitude, sampleRate) {
    const pcm = new Float32Array(samplesCount * CHANNELS);

    for (let i = 0; i < samplesCount; i++) {
        const value = amplitude * Math.sin(phase);
        pcm[i * CHANNELS] = value; // For mono

        phase += 2 * Math.PI * frequency / sampleRate;
        if (phase > 2 * Math.PI) { // Keep phase within 0 to 2PI
            phase -= 2 * Math.PI;
        }
    }
    return Buffer.from(pcm.buffer); // Convert Float32Array's underlying ArrayBuffer to Node.js Buffer
}

function startStreaming() {
    if (timerId) {
        console.log("Streaming already active.");
        return;
    }

    console.log('Starting sine wave PCM generation...');

    timerId = setInterval(() => {
        const pcmData = generateSineWavePCM(SAMPLES_PER_FRAME, FREQUENCY, AMPLITUDE, SAMPLE_RATE);

        // Send PCM data to all connected clients
        wss_audio.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(pcmData); // pcmData is a Node.js Buffer
            }
        });
    }, FRAME_DURATION_MS); // Send a frame every FRAME_DURATION_MS
}

function stopStreaming() {
    if (timerId) {
        console.log('Stopping sine wave stream and cleaning up...');
        clearInterval(timerId);
        timerId = null;
    }
    phase = 0; // Reset phase
}

// Keep track of connected clients to manage stream lifecycle
const activeConnections = new Set();

wss_audio.on('connection', ws => {
    console.log('Client connected');
    activeConnections.add(ws);

    // Start streaming only when the first client connects
    if (activeConnections.size === 1) {
        startStreaming();
    }

    ws.on('close', () => {
        console.log('Client disconnected');
        activeConnections.delete(ws);
        // Stop streaming if no clients are connected
        if (activeConnections.size === 0) {
            stopStreaming();
        }
    });

    ws.on('error', error => {
        console.error('WebSocket error:', error);
        activeConnections.delete(ws);
        if (activeConnections.size === 0) {
            stopStreaming();
        }
    });
});

// Ensure clean shutdown when Node.js process exits
process.on('exit', () => {
    stopStreaming();
});
