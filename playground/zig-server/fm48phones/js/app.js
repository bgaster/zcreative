const slide1 = document.getElementById('slide1');
const slide2 = document.getElementById('slide2');
const startBtn = document.getElementById('startBtn');
const controlsContainer = document.getElementById('sliderContainer');

let webSocket;
const activeSliders = new Map();

startBtn.addEventListener('click', () => {
  connectWS();
  // for (let i = 0; i < 6; i++) {
  //   const wrapper = document.createElement('div');
  //   wrapper.className = 'slider-wrapper';
  //
  //   const slider = document.createElement('input');
  //   slider.type = 'range';
  //   slider.min = '0';
  //   slider.max = '100';
  //   slider.value = '50';
  //
  //   wrapper.appendChild(slider);
  //   sliderContainer.appendChild(wrapper);
  // }

  // Switch slides
  slide1.classList.add('hidden');
  slide2.classList.remove('hidden');

  // Enter fullscreen
  setTimeout(() => {
    if (document.documentElement.requestFullscreen) {
      document.documentElement.requestFullscreen();
    }
  }, 100);
});

// websocket stuff

function closeWS() {
  if (webSocket !== undefined) {
      webSocket.close()
  }
}

function connectWS() {
  if (webSocket !== undefined) {
      webSocket.close()
  }

  // var endpoint = "wss://192.168.1.14:8080"
  var endpoint = "wss://S-FET-HQKRX90VWR.local:8080";

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
        case "controls": 
          const controls = msg.data;
          if (Array.isArray(msg.data)) {
            updateControls(controls);
          } else {
            console.warn('Received non-array data from WebSocket:', controls);
          }
          break;
      }
    } catch (error) {
      console.error('Error parsing WebSocket message:', error);
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
        sliderGroup.classList.add('slider-wrapper');
        sliderGroup.id = `sliderGroup-${control.id}`; // Unique ID for each group
        sliderGroup.uid = control.id; // used to communicate with server

        // Create the label
        const label = document.createElement('label');
        label.setAttribute('for', `rangeSlider-${control.id}`);
        // label.textContent = `${control.name}:`;
        
        const values = control.values;
        //TODO: add check for length here

        // Create the input range slider
        const rangeSlider = document.createElement('input');
        // rangeSlider.classList.add('cm-thick-slider');
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
        // sliderValueDisplay.classList.add('slider-value');
        // sliderValueDisplay.textContent = rangeSlider.value; // Display initial value
        
        // Add an event listener to update the display when the slider value changes
        rangeSlider.addEventListener('input', () => {
          // sliderValueDisplay.textContent = rangeSlider.value;
          const msg = {
            type: 'control',
            header: 1,
            uid: control.id,
            values: [parseInt(rangeSlider.value)]
          };
          webSocket.send(JSON.stringify(msg));
        });

        // Append all created elements to the slider group
        // sliderGroup.appendChild(label);
        sliderGroup.appendChild(rangeSlider);
        // sliderGroup.appendChild(sliderValueDisplay);

        // Append the new slider group to the main container
        controlsContainer.appendChild(sliderGroup);
      }
    }
  }
}
