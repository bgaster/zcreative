// audio-worklet-processor.js
// This code runs in a dedicated AudioWorklet thread (separate from the main JavaScript thread)

// Constants (must match server and main script)
const SAMPLE_RATE = 48000;
const CHANNELS = 1;
// This determines how much audio to buffer BEFORE the worklet starts outputting sound.
// It's crucial for smooth playback.
const INITIAL_BUFFER_DURATION_MS = 500; 
const INITIAL_BUFFER_SAMPLE_COUNT = (SAMPLE_RATE / 1000) * INITIAL_BUFFER_DURATION_MS;

// How often to send buffer status messages back to the main thread (in samples)
const STATUS_MESSAGE_INTERVAL_SAMPLES = SAMPLE_RATE / 10; // Every 100ms (4800 samples at 48kHz)

class PCMPlayerProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.buffers = []; // A queue to store incoming ArrayBuffers of PCM data
        this.currentBufferOffset = 0; // Tracks the current read position within the first buffer in the queue
        this.isBufferingInitial = true; // Flag to indicate if we're still filling the initial buffer
        this.totalBufferedSamples = 0; // Total samples currently in the queue

        this.lastStatusMessageTime = 0; // To control message frequency in process()

        // Listen for messages from the main thread (from the AudioWorkletNode)
        this.port.onmessage = (event) => {
            // event.data is the raw ArrayBuffer of Float32 PCM received from the WebSocket
            this.buffers.push(event.data);
            this.totalBufferedSamples += event.data.byteLength / 4; // Each Float32 is 4 bytes

            // If we've gathered enough initial buffer, signal the main thread
            if (this.isBufferingInitial && this.totalBufferedSamples >= INITIAL_BUFFER_SAMPLE_COUNT) {
                this.isBufferingInitial = false;
                this.port.postMessage({ type: 'initialBufferReady' });
            }
        };
    }

    // Called when the processor is destroyed (no explicit destroy method needed here, no setInterval)
    // static get parameterDescriptors() is not needed if no custom params

    // The process method is called by the Web Audio API at a fixed rate (e.g., every 128 samples)
    process(inputs, outputs, parameters) {
        const output = outputs[0]; // Get the first output array (for playback to speakers)
        const outputChannel = output[0]; // Assuming mono, get the first channel of the output (a Float32Array of 128 samples)
        const frameSize = outputChannel.length; // Typically 128 samples for an AudioWorklet frame

        // --- Outputting Silence if Not Ready ---
        if (this.isBufferingInitial || this.buffers.length === 0) {
            for (let i = 0; i < frameSize; i++) {
                outputChannel[i] = 0; // Output silence
            }
            // Send status even when silent to show buffering progress
            if (this.totalBufferedSamples === 0) { // If truly empty, indicate buffering
                 this.port.postMessage({
                    type: 'bufferStatus',
                    bufferedSamples: 0
                });
            } else if (this.currentFrame - this.lastStatusMessageTime >= STATUS_MESSAGE_INTERVAL_SAMPLES) {
                this.port.postMessage({
                    type: 'bufferStatus',
                    bufferedSamples: this.totalBufferedSamples
                });
                this.lastStatusMessageTime = this.currentFrame;
            }
            return true; // Keep processor alive
        }

        let samplesFilled = 0;

        // --- Filling the Output Frame ---
        while (samplesFilled < frameSize && this.buffers.length > 0) {
            const rawBuffer = this.buffers[0];
            // View the raw ArrayBuffer as a Float32Array (since server sends this)
            const pcmFloat32 = new Float32Array(rawBuffer);

            // Determine how many samples to copy from the current source buffer to the output frame
            const samplesToCopy = Math.min(frameSize - samplesFilled, pcmFloat32.length - this.currentBufferOffset);

            // Copy samples
            for (let i = 0; i < samplesToCopy; i++) {
                outputChannel[samplesFilled + i] = pcmFloat32[this.currentBufferOffset + i];
            }

            samplesFilled += samplesToCopy;
            this.currentBufferOffset += samplesToCopy;
            this.totalBufferedSamples -= samplesToCopy; // Decrement total buffered samples

            // If we have consumed the entire current buffer, remove it from the queue
            if (this.currentBufferOffset >= pcmFloat32.length) {
                this.buffers.shift(); // Remove the consumed buffer
                this.currentBufferOffset = 0; // Reset offset for the next buffer
            }
        }

        // --- Handling Underrun (if output frame couldn't be fully filled) ---
        for (let i = samplesFilled; i < frameSize; i++) {
            outputChannel[i] = 0; // Fill the rest with silence
        }

        // --- Send Periodic Buffer Status Message ---
        // `currentTime` is available in AudioWorklet. It's an internal counter of samples processed.
        // It's part of the AudioWorkletGlobalScope.
        if (currentTime - this.lastStatusMessageTime >= STATUS_MESSAGE_INTERVAL_SAMPLES) {
            this.port.postMessage({
                type: 'bufferStatus',
                bufferedSamples: this.totalBufferedSamples
            });
            this.lastStatusMessageTime = currentTime;
        }

        // Return true to keep the AudioWorkletNode alive and continue processing audio
        return true;
    }
}

// Register the processor with the AudioWorkletGlobalScope, giving it a unique name
registerProcessor('pcm-player-processor', PCMPlayerProcessor);
