
let webSocket;
let slidersContainer;
const activeSliders = new Map();

document.addEventListener('DOMContentLoaded', () => {
    const slides = document.querySelectorAll('.slide');
    const slideshowContainer = document.querySelector('.slideshow-container');
    let currentSlideIndex = 0;
    let touchStartX = 0; // Tracks where the touch started
    let touchEndX = 0;   // Tracks where the touch ended
    const nextBtn = document.getElementById('nextBtn'); // Get the Next button
    const prevBtn = document.getElementById('prevBtn'); // Get the Previous button
    const connectBtn = document.getElementById('connectBtn'); // Get the Previous button
    slidersContainer = document.getElementById('slidersContainer');

    /**
     * Updates the display to show the slide at the specified index.
     * @param {number} index - The index of the slide to display.
     */
    function showSlide(index) {
        // Ensure the index is within the bounds of the slides array
        if (index >= 0 && index < slides.length) {
            // 1. Remove 'active' class from the currently active slide
            slides[currentSlideIndex].classList.remove('active');

            // 2. Update the current slide index
            currentSlideIndex = index;

            // 3. Add 'active' class to the new slide
            slides[currentSlideIndex].classList.add('active');
        }
    }

    // Set the first slide to be visible initially
    showSlide(currentSlideIndex);

    // --- NEW: Button Click Navigation ---

    nextBtn.addEventListener('click', (e) => {
        showSlide(currentSlideIndex + 1);
        e.currentTarget.blur();
    });

    connectBtn.addEventListener('click', (e) => {
        connectWS();
        showSlide(currentSlideIndex + 1);
        e.currentTarget.blur();
    });

    prevBtn.addEventListener('click', (e) => {
        showSlide(currentSlideIndex - 1);
        e.currentTarget.blur();
    });

    /**
     * Handles key press events for navigation.
     * @param {KeyboardEvent} event - The keyboard event object.
     */
    document.addEventListener('keydown', (event) => {
        // Right arrow key
        if (event.key === 'ArrowRight') {
            showSlide(currentSlideIndex + 1);
        }
        // Left arrow key
        else if (event.key === 'ArrowLeft') {
            showSlide(currentSlideIndex - 1);
        }
    });

    // --- TOUCH NAVIGATION (New for mobile) ---

    // 1. Record the starting X position when the user touches the screen
    document.addEventListener('touchstart', (event) => {
        // Get the X coordinate of the first touch point
        touchStartX = event.touches[0].clientX;
    });

    // 2. Record the ending X position when the user lifts their finger
    document.addEventListener('touchend', (event) => {
        // Get the X coordinate of the last recorded touch point
        touchEndX = event.changedTouches[0].clientX;
        // handleSwipeGesture();
    });

    // 3. Process the recorded start and end positions
    function handleSwipeGesture() {
        // Define a minimum distance for a valid swipe
        const swipeThreshold = 20; 
        
        // Calculate the difference in horizontal movement
        const swipeDistance = touchStartX - touchEndX;

        // Swipe Left (Go to next slide)
        if (swipeDistance > swipeThreshold) {
            // User swiped from right-to-left
            showSlide(currentSlideIndex + 1); 
        }

        // Swipe Right (Go to previous slide)
        else if (swipeDistance < -swipeThreshold) {
            // User swiped from left-to-right
            showSlide(currentSlideIndex - 1);
        }
        
        // Reset values after processing the swipe
        touchStartX = 0;
        touchEndX = 0;
    }
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

  var endpoint = "wss://192.168.1.14:8080"

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
        sliderGroup.appendChild(label);
        sliderGroup.appendChild(rangeSlider);
        sliderGroup.appendChild(sliderValueDisplay);

        // Append the new slider group to the main container
        controlsContainer.appendChild(sliderGroup);
      }
    }
  }
}
