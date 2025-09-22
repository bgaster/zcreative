'use strict';

// i know we should not use globals, but ...
let webSocket;
let userListUl;
let connectButton;
let closeButton;
let addSliderButton;
let slidersContainer;
let controlsContainer;
let sliderCount;
const activeSliders = new Map();

// audio globlas
let connectionStatusSpan;
let audioStatusSpan;
let togglePlayButton;

const websocketAddress = 'ws://localhost:6080';
let ws = null;

// --- Audio Context and Playback State ---
let audioContext = null;
let audioWorkletNode = null; // Our AudioWorkletNode instance

// --- Audio Parameters (MUST MATCH SERVER'S GENERATION PARAMETERS) ---
const SAMPLE_RATE = 48000;
const CHANNELS = 1;


//--------------------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
    // control global init
    connectButton = document.getElementById('connectButton');
    closeButton = document.getElementById('closeButton');
    addSliderButton = document.getElementById('addSliderButton');
    slidersContainer = document.getElementById('slidersContainer');
    controlsContainer = document.getElementById('controlsContainer');
    sliderCount = 0; // To keep track of the number of sliders for unique IDs
    userListUl = document.getElementById('userList');

    // audio global init
    connectionStatusSpan = document.getElementById('connectionStatus');
    audioStatusSpan = document.getElementById('audioStatus');
    togglePlayButton = document.getElementById('togglePlayButton');

    // control stuff
    connectButton.addEventListener('click', () => {
      connectWS();
    });

    closeButton.addEventListener('click', () => {
      closeWS();
    })

  
    // audio stuff (this is receive only, the server generates all audio)
    togglePlayButton.addEventListener('click', async () => {
        if (ws && ws.readyState === WebSocket.OPEN) {
            disconnectWebSocket();
        } else {
            // Ensure AudioContext is initialized and resumed by user gesture
            if (!audioContext || audioContext.state !== 'running') {
                await initAudio();
            }

            // Only connect if initAudio was successful and context is running
            if (audioContext && audioContext.state === 'running') {
                connectWebSocket();
            } else {
                console.error('AudioContext not running, cannot connect WebSocket.');
                updateStatus(null, 'Cannot connect: Audio not ready.');
            }
        }
    });

    // Initial state on page load
    updateStatus('Disconnected', 'Idle');
});

// audio stuff

function updateStatus(connectionState, audioState) {
    if (connectionState) {
        connectionStatusSpan.textContent = connectionState;
        connectionStatusSpan.className = ''; // Clear existing classes
        if (connectionState === 'Connected') {
            connectionStatusSpan.classList.add('connected');
        } else if (connectionState === 'Disconnected' || connectionState === 'Error') {
            connectionStatusSpan.classList.add('disconnected');
        }
    }
    if (audioState) {
        audioStatusSpan.textContent = audioState;
    }
}

async function initAudio() {
  // If AudioContext already exists, ensure it's in a 'running' state
  if (audioContext) {
      if (audioContext.state === 'suspended') {
          await audioContext.resume();
          console.log('Audio Context Resumed.');
      }
      return; // Already initialized
  }

  // Create a new AudioContext
  audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: SAMPLE_RATE,
      channelCount: CHANNELS // Set preferred channel count
  });
  console.log(`AudioContext created with sample rate: ${audioContext.sampleRate}`);
  await audioContext.resume();

  // AudioContext often starts in 'suspended' state; resume it with user gesture
  if (audioContext.state === 'suspended') {
      await audioContext.resume();
      console.log('Initial Audio Context Resume triggered.');
  }

  if (!audioContext.audioWorklet) {
    console.warn("AudioWorklet is not supported on this browser. Falling back to a different method if needed.");
    // You could call a fallback function here.
    // return;
  }


  try {
    // Add the AudioWorkletProcessor module
    // This path is relative to where index.html is served from
    await audioContext.audioWorklet.addModule('js/audio-worklet-processor.js');
    console.log('AudioWorklet module added successfully.');

    // Create an instance of our AudioWorkletNode
    // The first argument is the name registered in audio-worklet-processor.js
    audioWorkletNode = new AudioWorkletNode(audioContext, 'pcm-player-processor', {
      outputChannelCount: [CHANNELS] // Ensure the worklet outputs the correct number of channels
    });
    console.log('AudioWorkletNode created.');

    // Connect the AudioWorkletNode to the AudioContext's destination (speakers)
    audioWorkletNode.connect(audioContext.destination);
    console.log('AudioWorkletNode connected to destination.');

    // Listen for messages FROM the AudioWorkletProcessor (e.g., for buffer status)
    audioWorkletNode.port.onmessage = (event) => {
      // console.log('Message from AudioWorklet:', event.data);
      if (event.data.type === 'bufferStatus') {
        const bufferedDurationMs = (event.data.bufferedSamples / SAMPLE_RATE) * 1000;
        if (ws && ws.readyState === WebSocket.OPEN) {
          if (bufferedDurationMs < 100 && bufferedDurationMs > 0) { // Arbitrary low buffer threshold for warning
              updateStatus(null, `Low buffer: ${bufferedDurationMs.toFixed(0)}ms. Receiving...`);
          } else if (bufferedDurationMs === 0) {
            updateStatus(null, 'Buffering initial audio...'); // or 'Audio Underrun!'
          }
          else {
            updateStatus(null, `Playing... Buffer: ${bufferedDurationMs.toFixed(0)}ms`);
          }
        } else {
          updateStatus(null, 'Idle'); // If WebSocket isn't open, reflect idle state
        }
        } else if (event.data.type === 'initialBufferReady') {
          // The worklet has enough initial buffer, we can update status
          updateStatus(null, `Initial buffer ready. Playing...`);
        }
      };
            
      // Listen for errors from the AudioWorkletProcessor
      audioWorkletNode.port.onmessageerror = (event) => {
          console.error('Error from AudioWorklet port:', event);
          updateStatus(null, 'Audio processing error!');
          disconnectWebSocket();
      };
  } catch (e) {
    console.error('Error initializing AudioWorklet:', e);
    updateStatus('Error', `Audio setup failed: ${e.message}`);
    // Clean up if initialization fails
    if (audioContext) {
        audioContext.close();
        audioContext = null;
    }
  }
}

function connectWebSocket() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    console.log('WebSocket already open.');
    return;
  }
  var endpoint_audio = document.getElementById("endpoint_audio").value;


  ws = new WebSocket(endpoint_audio);
  // ws = new WebSocket(websocketAddress);
  ws.binaryType = 'arraybuffer'; // Crucial for receiving binary data

  ws.onopen = async () => {
    console.log('WebSocket connected.\n');
    updateStatus('Connected', 'Waiting for audio...');
    togglePlayButton.textContent = 'Stop Audio';
    togglePlayButton.disabled = false;
    
    // Ensure audio context is ready
    if (!audioContext || audioContext.state !== 'running') {
        await initAudio(); // This will also resume if suspended
    }
  };

  ws.onmessage = (event) => {
    if (event.data instanceof ArrayBuffer) {
      if (audioWorkletNode) {
          // Send the raw ArrayBuffer to the AudioWorkletNode's port
          // Use [event.data] as the transferable list for efficiency.
          audioWorkletNode.port.postMessage(event.data, [event.data]);
      } else {
        console.warn('Received audio data but AudioWorkletNode is not ready.');
      }
    } else {
      console.warn('Received non-binary data:', event.data);
    }
  };

  ws.onclose = (event) => {
    console.log('WebSocket disconnected:', event);
    updateStatus('Disconnected', 'Idle');
    togglePlayButton.textContent = 'Connect & Play Audio';
    
    // Clean up audio resources
    if (audioContext && audioContext.state !== 'closed') {
      audioContext.close().then(() => {
        console.log('AudioContext closed.');
      }).catch(e => console.error('Error closing AudioContext:', e));
    }
    audioContext = null;
    audioWorkletNode = null;
  };

  ws.onerror = (error) => {
    console.error('WebSocket error:', error);
    updateStatus('Error', 'Idle');
    if (ws && ws.readyState === WebSocket.OPEN) { // Check state before closing
      ws.close(); // Force close to trigger onclose handler for cleanup
    }
  };
}

function disconnectWebSocket() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.close();
  } else if (ws) {
    // If WS is not open (e.g., closing or closed), still ensure cleanup
    ws.onclose(); // Manually trigger onclose for state update
  }
}

// control stuff
//

function closeWS() {
  if (webSocket !== undefined) {
      webSocket.close()
  }
  userListUl.innerHTML = '';  
}

function connectWS() {
  var endpoint = document.getElementById("endpoint").value;
  if (webSocket !== undefined) {
      webSocket.close()
  }

  webSocket = new WebSocket(endpoint);

  webSocket.onmessage = function(event) {
    var len;
    if (event.data.size === undefined) {
        len = event.data.length
    } else {
        len = event.data.size
    }

    try {
      const msg = JSON.parse(event.data);
  
      switch (msg.type) {
        case "users":
          const usernames = msg.data;
          if (Array.isArray(msg.data)) {
            updateUserList(usernames);
          } else {
              console.warn('Received non-array data from WebSocket:', usernames);
              userListUl.innerHTML = '<li>Error: Invalid data received.</li>';
          }
          break;
        case "controls": 
          const controls = msg.data;
          if (Array.isArray(msg.data)) {
            updateControls(controls);
          } else {
            console.warn('Received non-array data from WebSocket:', controls);
              // userListUl.innerHTML = '<li>Error: Invalid data received.</li>';
          }
          break;
        case "control": //TODO: rename so not to similar above
          const id = msg.header;
          const sliderValue = msg.values[0];
          const targetSlider = activeSliders.get(id);
          if (targetSlider) {
            // Ensure value is within slider's min/max
            const min = parseInt(targetSlider.min);
            const max = parseInt(targetSlider.max);
            let constrainedValue = Math.max(min, Math.min(max, sliderValue));

            targetSlider.value = constrainedValue;

            // Also update the associated number input and display span
            const numberInput = document.getElementById(`numberInput-${id}`);
            const sliderValueDisplay = targetSlider.nextElementSibling; // The span after the range input

            if (numberInput) {
                numberInput.value = constrainedValue;
            }
            if (sliderValueDisplay && sliderValueDisplay.classList.contains('slider-value')) {
                sliderValueDisplay.textContent = constrainedValue;
            }
          }
          break;
      }
    } catch (error) {
      console.error('Error parsing WebSocket message:', error);
      userListUl.innerHTML = '<li>Error: Could not parse message.</li>';
    }
  }



  webSocket.onopen = function(evt) {
    // request current list of controls
    webSocket.send(JSON.stringify({ type: "get_controls" }));
  }

  webSocket.onclose = function(evt) {
    console.log("onclose.");
  }

  webSocket.onerror = function(evt) {
      console.log("Error!");
  }

  console.log('connect');
}

function updateUserList(usernames) {
  userListUl.innerHTML = ''; // Clear previous list items
  if (usernames.length === 0) {
      const li = document.createElement('li');
      li.textContent = 'No active users.';
      userListUl.appendChild(li);
  } else {
    usernames.forEach(username => {
        const li = document.createElement('li');
        li.textContent = username;
        userListUl.appendChild(li);
    });
  }
}


//-----------------------------------------------------------------------------

function updateControls(controls) {
  controlsContainer.innerHTML = '';  
  if (controls.length === 0) {
      const label = document.createElement('label');
      // label.setAttribute('for', `rangeSlider-${sliderCount}`);
      label.textContent = `No active controls.`;
      constrolsContainer.appendChild(label);
  }
  else {
    activeSliders.clear();
    for (const control of controls){
      if (control.type === 1) {
        
        // Create a container for the slider and its value display
        const sliderGroup = document.createElement('div');
        sliderGroup.classList.add('slider-group');
        sliderGroup.id = `sliderGroup-${control.id}`; // Unique ID for each group
        sliderGroup.uid = control.id; // used to communicate with server

        // Create the label
        const label = document.createElement('label');
        label.setAttribute('for', `rangeSlider-${control.id}`);
        label.textContent = `${control.name}:`;
        
        const values = control.values;
        //TODO: add check for length here

        // Create the input range slider
        const rangeSlider = document.createElement('input');
        rangeSlider.setAttribute('type', 'range');
        rangeSlider.setAttribute('min', `${values[0]}`);     // Minimum value
        rangeSlider.setAttribute('max', `${values[1]}`);    // Maximum value
        rangeSlider.setAttribute('value', `${values[2]}`);   // Initial value
        rangeSlider.setAttribute('step', `${values[3]}`);     // Step increment
        rangeSlider.id = `rangeSlider-${control.id}`; // Unique ID
        rangeSlider.uid = control.id; // used to communicate with server

        activeSliders.set(control.id, rangeSlider);

        // Create the span to display the slider's value
        const sliderValueDisplay = document.createElement('span');
        sliderValueDisplay.classList.add('slider-value');
        sliderValueDisplay.textContent = rangeSlider.value; // Display initial value
        
        // Add an event listener to update the display when the slider value changes
        rangeSlider.addEventListener('input', () => {
          sliderValueDisplay.textContent = rangeSlider.value;
          const msg = {
            type: 'control',
            header: 1,
            uid: control.id,
            values: [parseInt(rangeSlider.value)]
          };
          webSocket.send(JSON.stringify(msg));
        });

        // Append all created elements to the slider group
        sliderGroup.appendChild(label);
        sliderGroup.appendChild(rangeSlider);
        sliderGroup.appendChild(sliderValueDisplay);

        // Append the new slider group to the main container
        controlsContainer.appendChild(sliderGroup);
      }
    }
  }
}

//-----------------------------------------------------------------------------
