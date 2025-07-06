'use strict';

// i know we should not use globals, but ...
let webSocket;
let userListUl;
let connectButton;
let addSliderButton;
let slidersContainer;
let controlsContainer;
let sliderCount;
const activeSliders = new Map();

//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', () => {
    connectButton = document.getElementById('connectButton');
    addSliderButton = document.getElementById('addSliderButton');
    slidersContainer = document.getElementById('slidersContainer');
    controlsContainer = document.getElementById('controlsContainer');
    sliderCount = 0; // To keep track of the number of sliders for unique IDs
    userListUl = document.getElementById('userList');

    // addSliderButton.addEventListener('click', () => {
    //     sliderCount++; // Increment count for each new slider
    //
    //     // 1. Create a container for the slider and its value display
    //     const sliderGroup = document.createElement('div');
    //     sliderGroup.classList.add('slider-group');
    //     sliderGroup.id = `sliderGroup-${sliderCount}`; // Unique ID for each group
    //
    //     // 2. Create the label
    //     const label = document.createElement('label');
    //     label.setAttribute('for', `rangeSlider-${sliderCount}`);
    //     label.textContent = `Name ${sliderCount}:`;
    //
    //     // 3. Create the input range slider
    //     const rangeSlider = document.createElement('input');
    //     rangeSlider.setAttribute('type', 'range');
    //     rangeSlider.setAttribute('min', '0');     // Minimum value
    //     rangeSlider.setAttribute('max', '100');    // Maximum value
    //     rangeSlider.setAttribute('value', '50');   // Initial value
    //     rangeSlider.setAttribute('step', '1');     // Step increment
    //     rangeSlider.id = `rangeSlider-${sliderCount}`; // Unique ID
    //
    //     // 4. Create the span to display the slider's value
    //     const sliderValueDisplay = document.createElement('span');
    //     sliderValueDisplay.classList.add('slider-value');
    //     sliderValueDisplay.textContent = rangeSlider.value; // Display initial value
    //
    //     // 5. Create the Remove Button
    //     const removeButton = document.createElement('button');
    //     removeButton.textContent = 'Remove';
    //     removeButton.classList.add('remove-slider-button'); // Add a class for styling
    //
    //     // 6. Add an event listener to the Remove Button
    //     removeButton.addEventListener('click', () => {
    //         // Traverse up the DOM to find the parent .slider-group and remove it
    //         sliderGroup.remove(); // This is the simplest way to remove an element
    //     });
    //
    //
    //     // 7. Add an event listener to update the display when the slider value changes
    //     rangeSlider.addEventListener('input', () => {
    //         sliderValueDisplay.textContent = rangeSlider.value;
    //     });
    //
    //     // 8. Append all created elements to the slider group
    //     sliderGroup.appendChild(label);
    //     sliderGroup.appendChild(rangeSlider);
    //     sliderGroup.appendChild(sliderValueDisplay);
    //     sliderGroup.appendChild(removeButton); // Append the remove button
    //
    //     // 9. Append the new slider group to the main container
    //     slidersContainer.appendChild(sliderGroup);
    // });

    
    connectButton.addEventListener('click', () => {
      connectWS();
    });
});

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
            header: 0,
            uid: control.id,
            values: [rangeSlider.value]
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
