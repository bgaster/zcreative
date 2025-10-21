//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////
 /*
 *  USB-MIDI high resolution (14-bit) SC1000-style controller.
 *  OPC-Sensor: IMU and capacitive touch controller for use on a cymbal.
 *  by Benedict R. Gaster, https://cuberoo.uk
 *     based on code kindly provided by Rodrigo Constanzo, http://www.rodrigoconstanzo.com // rodrigo.constanzo@gmail.com
 *      uses example code from STMicroelectronics's LSM6DSV16X library (copyright notice below)
 * 
 *  coded for
 *     ESP32S3: https://www.seeedstudio.com/XIAO-ESP32S3-p-5627.html
 *     LSM6DSV16X: https://www.sparkfun.com/products/21336
 *  
 *  EXPLANATION
 *  -----------
 *  The code takes sensor readings from the LSM6DSV16X and outputs them as MIDI data. 
 
 
 * This also
 *  includes capacitive touch when physical touching the cymbal allowing for "choke" gestures. 
 *  By default it will send the pitch axis as 14-bit MIDI pitchbend data as well as a 7-bit CC 
 *  but you can adjust this via flags near the top of the code.
 *
 *  The code will always Tare the starting position when powered up, so you should plug in the USB
 *  cable once the cymbal is in its performance/stable position. You can also trigger the Tare
 *  function manually with the onboard button (D1) or by sending a MIDI Program Change message of
 *  13.
 *  
 *  You can also run a Calibration routine to set the minimum/maxmimum for the range of motion of
 *  the IMU. You can trigger the Calibration function with the onboard button (D2) or by sending
 *  a MIDI Program Change message of 10. The calibration gets stored on the onboard memory. You
 *  only need to do this if you find the full range isn't being used after calibration as the
 *  calibration is normalized to the results of the Tare function.
 *  
 *  You can also reset the user Calibration to default settings by sending a MIDI Program Change
 *  Change message of 55.
 *  
 *  (example Max/MSP code below)
 *  
 *  TODO:
 *  
 *  last update on 24/7/2025
 */
//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////

// required libraries
#include <WiFi.h>
#include <WiFiMulti.h>
#include <WiFiClientSecure.h>

#include <WebSocketsClient.h>

#include <LSM6DSV16XSensor.h> // installed via "Manage Libraries", it is the one called "STM32duino LSM6DSV16X by SRA", *not* the one from SparkFun
//#include <ISM330DHCXSensor.h>// installed via "Manage Libraries", it is the one called "STM32duino LSM6DSV16X by SRA", *not* the one from SparkFun
#include <ResponsiveAnalogRead.h> // installed via "Manage Libraries"
#include <Preferences.h>
#include <USB.h>
#include <USBMIDI.h>

// Enable/Disable stuff

#define USE_WEBSOCKETS 1

// PI constant
#define PI 3.1415926535897932384626433832795

// sensor fusion definitions for IMU
#define ALGO_FREQ  120U /* Algorithm frequency 120Hz */
#define ALGO_PERIOD  (1000U / ALGO_FREQ) /* Algorithm period [ms] */
unsigned long startTime, elapsedTime;

/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////
/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////
/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////

// define MIDI channel for all messages
const int midi_channel = 4;

// define CC for pitch, roll, and yaw
const int cc_pitch = 1;
const int cc_roll = 2;
const int cc_yaw = 3;

// what kind of message to send for pitch axis of IMU
// (pitchbend messages are double the resolution of normal CC messages)
// (if you plan on using automatic MIDI mapping anywhere you should only enable one of these)
const int midi_cc_pitch = 1;
const int midi_pitchbend_pitch = 1;

// define CC for touch (64 = default sustain pedal CC)
const int cc_touch = 64;

// invert IMU orientation
const int invert_pitch = 1;
const int invert_roll = 0;
const int invert_yaw = 0;

// set activity threshold for IMU pitch axis (default is 4.0)
// (this defines how little activity is required to "wake" the pitch axis)
const double activity_threshold = 6.;

// calibration duration time (in ms)
// (amount of time the calibration function will run)
unsigned long calibration_duration = 10000;

// apply crude drift compensation to yaw axis
// (when no movement is registered on the pitch axis for 5 seconds, re-Tare yaw axis)
const int drift_compensation = 1;

// drift compensation duration time (in ms)
// (amount of time the pitch axis needs to be idle in order to re-tare the yaw axis)
unsigned long drift_compensation_duration = 8000;

/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////
/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////
/////////////////////////// ADJUST THESE SETTINGS IF NEEDED ///////////////////////////

// define touch pin
// const int touchPin = T1;

// // define button pins
// const int tareButtonPin = D1;
// const int calibrateButtonPin = D2;

// internal LED for calibration/reset status
const int led = LED_BUILTIN;

// set output range (14-bit = 16383)
const int output_range = 16383;

// ints for filtering repeats
int current_pitch = 0;
int smoothed_pitch = 0;
int previous_pitch = 0;
int smoothed_pitch_midi = 0;
int previous_pitch_midi = 0;
int current_roll = 0;
int smoothed_roll = 0;
int previous_roll = 0;
int current_yaw = 0;
int smoothed_yaw = 0;
int previous_yaw = 0;
int current_touch = 0;
int smoothed_touch = 0;
int previous_touch = 0;

// variables for storing tare offsets
double tare_pitch = 0;
double tare_roll = 0;
double tare_yaw = 0;

// variables for storing quaternions
double w = 0;
double x = 0;
double y = 0;
double z = 0;

// variables for storing Euler angles
double pitch = 0;
double roll = 0;
double yaw = 0;

// default calibration range values
double calibrate_min_pitch = -0.5;
double calibrate_max_pitch = 0.5;
double calibrate_min_roll = -0.5;
double calibrate_max_roll = 0.5;
double calibrate_min_yaw = -0.5;
double calibrate_max_yaw = 0.5;
double calibrate_min_touch = 30000;
double calibrate_max_touch = 250000;

// variables for smoothing of drift compensation
double temp_current_yaw = 0;
double temp_previous_yaw = 0;

// start counting down for drift calibration
unsigned long drift_timer = millis();

// flag to check if in calibration mode
int calibrate_flag = 0;
int calibrate_startup = 0;

// flat to check if sensor has been calibrated
int is_calibrated = 0;

// initialize MIDI
USBMIDI MIDI;

// initialize Preferences memory storage
Preferences preferences;

// initialize smoothing library
ResponsiveAnalogRead responsive_pitch(0, true);
ResponsiveAnalogRead responsive_roll(0, true);
ResponsiveAnalogRead responsive_yaw(0, true);
ResponsiveAnalogRead responsive_touch(0, true);

// initialize IMU
LSM6DSV16XSensor AccGyr(&Wire);
// ISM330DHCXSensor AccGyr(&Wire);
uint8_t status = 0;
uint32_t k = 0;
uint8_t tag = 0;
float quaternions[4] = {0};

// PINs for I2C (currently set for QT Py ESP32-S2)
#define SCL 40
#define SDA 41


/////////////////////////// websocket stuff ///////////////////////////

#if defined USE_WEBSOCKETS && USE_WEBSOCKETS == 1

WiFiMulti WiFiMulti;
WebSocketsClient webSocket;

#define USE_SERIAL Serial

// There is a direct mapping between the PEBBLE_UID below and 
// the controls.json, which is used to initialize the sliders (i.e. pebble controls).
// For each physical pebble there needs to be a unique mapping into the controls.json, 
// which means that for each pebble the define must be set.
#define PEBBLE_UID "0"
#define PEBBLE_MK(uid) "{ \"type\": \"imu\", \"uid\": " uid ", \"values\": [%d]}"
#define PEBBLE_OSC PEBBLE_MK(PEBBLE_UID)

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            USE_SERIAL.printf("[WSc] Disconnected!\n");
            break;
        case WStype_CONNECTED:
            {
                USE_SERIAL.printf("[WSc] Connected to url: %s\n",  payload);
			          // send message to server when Connected
				        webSocket.sendTXT("{ \"type\": \"imu_connect\"}");
            }
            break;
        case WStype_TEXT:
            USE_SERIAL.printf("[WSc] get text: %s\n", payload);

			// send message to server
			// webSocket.sendTXT("message here");
            break;
        case WStype_BIN:
            USE_SERIAL.printf("[WSc] get binary length: %u\n", length);
            //hexdump(payload, length);

            // send data to server
            // webSocket.sendBIN(payload, length);
            break;
		case WStype_ERROR:			
		case WStype_FRAGMENT_TEXT_START:
		case WStype_FRAGMENT_BIN_START:
		case WStype_FRAGMENT:
		case WStype_FRAGMENT_FIN:
			break;
    }

}

#endif // USE_WEBSOCKETS

/////////////////////////// SETUP ///////////////////////////

void setup()
{
  // initialize serial for debugging
  Serial.begin(115200);

  unsigned long t0 = millis();
  while (!Serial && millis() - t0 < 3000) {
    delay(10);
  }
  //}

#if defined USE_WEBSOCKETS && USE_WEBSOCKETS == 1
  WiFiMulti.addAP("TP-Link_9D14", "23056459");
  //WiFiMulti.addAP("RaspAP", "ChangeMe");
  //WiFiMulti.addAP("gideon", "cloudysky326");

  while(WiFiMulti.run() != WL_CONNECTED) {
        delay(100);
  }

  webSocket.beginSSL("192.168.0.100", 8080);
  //webSocket.beginSSL("10.3.141.98", 8080);
  //webSocket.beginSSL("192.168.1.14", 8080);

  webSocket.onEvent(webSocketEvent);

#endif // USE_WEBSOCKETS

  // initialize USB and MIDI for ESP32
  MIDI.begin();
  USB.begin();

  // set required pin modes
  pinMode(led, OUTPUT);
  // pinMode(tareButtonPin, INPUT_PULLUP);
  // pinMode(calibrateButtonPin, INPUT_PULLUP);

  // set smoothing library resolution and threshold
  responsive_pitch.setAnalogResolution(output_range + 1);
  responsive_roll.setAnalogResolution(output_range + 1);
  responsive_yaw.setAnalogResolution(128);
  responsive_touch.setAnalogResolution(output_range + 1);
  responsive_pitch.setActivityThreshold(activity_threshold);

  // define and open Preferences namespace
  preferences.begin("opc", false);

  // reset calibration manually
  //preferences.clear();

  is_calibrated = preferences.getInt("is_calibrated");

  // if the device has been calibrated, use the stored settings instead of default settings
  if (is_calibrated == 1) {
    calibrate_min_pitch = preferences.getDouble("min_pitch");
    calibrate_max_pitch = preferences.getDouble("max_pitch");
    calibrate_min_roll = preferences.getDouble("min_roll");
    calibrate_max_roll = preferences.getDouble("max_roll");
    calibrate_min_yaw = preferences.getDouble("min_yaw");
    calibrate_max_yaw = preferences.getDouble("max_yaw");
    calibrate_max_touch = preferences.getDouble("max_touch");
    Serial.println("Calibration data found. Loading calibration values.");
    Serial.print("Calibration values: ");
  } else {
    Serial.println("No calibration found. Loading default values.");
    Serial.print("Deafult values: ");
  }

    Serial.print(calibrate_min_pitch, 4);
    Serial.print(" ");
    Serial.print(calibrate_max_pitch, 4);
    Serial.print(" ");
    Serial.print(calibrate_min_roll, 4);
    Serial.print(" ");
    Serial.print(calibrate_max_pitch, 4);
    Serial.print(" ");
    Serial.print(calibrate_min_roll, 4);
    Serial.print(" ");
    Serial.print(calibrate_max_roll, 4);
    Serial.print(" ");
    Serial.print(calibrate_min_touch, 4);
    Serial.print(" ");
    Serial.println(calibrate_max_touch, 4);

  // initialize LSM6DSV16X
  //Wire.begin();
  Wire.begin(SDA,SCL);
  AccGyr.begin();
  AccGyr.Enable_X();
  AccGyr.Enable_G();

  // enable LSM6DSV16X sensor fusion
  status |= AccGyr.Set_X_FS(4); // linear acceleration sensitivity (options are 2, 4, 8, 16) (lower means more sensitive)
  status |= AccGyr.Set_G_FS(2000); // angular rate sensitivity (options are 125, 250, 500, 1000, 2000, 4000)
  status |= AccGyr.Set_X_ODR(120.0f); // linear acceleratoin output data rate (options are 1.875, 7.5, 15, 30, 60, 120, 240, 480, 960, 1.92k, 3.84k, 7.68k)
  status |= AccGyr.Set_G_ODR(120.0f); // angular rate output data rate (options are 1.875, 7.5, 15, 30, 60, 120, 240, 480, 960, 1.92k, 3.84k, 7.68k)
  status |= AccGyr.Set_SFLP_ODR(120.0f); 
  status |= AccGyr.Enable_Rotation_Vector();
  status |= AccGyr.FIFO_Set_Mode(LSM6DSV16X_STREAM_MODE);

  // check to see LSM6DSV16X sensor is working properly
  if (status != LSM6DSV16X_OK) {
    Serial.println("LSM6DSV16X Sensor failed to init/configure");
    while (1);
  }

  digitalWrite(led, LOW);
  delay(500);
  digitalWrite(led, HIGH);
}


/////////////////////////// LOOP ///////////////////////////

void loop()
{

  // read incoming MIDI messages
  midiEventPacket_t midi_packet_in = {0};
  if (MIDI.readPacket(&midi_packet_in)) {
    //Serial.print(programChange(midi_packet_in));
  }

  // read LSM6DSV16X quaternions and convert to Euler angles
  readSensors();
  
  // tare (physical or program change)
  //if (debounceTare(tareButtonPin) | (programChange(midi_packet_in) == 13)) {
  if ((programChange(midi_packet_in) == 13)) {
    digitalWrite(led, LOW);
    tare_pitch = pitch;
    tare_roll = roll;
    tare_yaw = yaw;
    //calibrate_min_touch = touchRead(touchPin) + (touchRead(touchPin) * 0.1);
    delay(10);
    digitalWrite(led, HIGH);
  }

  // calibration (physical or program change)
  //if (debounceCalibrate(calibrateButtonPin) | (programChange(midi_packet_in) == 10)) {
  if ((programChange(midi_packet_in) == 10)) {
    calibrate_flag = 1;
    // enable LED notification of status
    digitalWrite(led, LOW);
    
    while (calibrate_flag == 1) {
      calibration();
      calibrate_flag = 0;      
    }

    // add a little buffer at each extreme to ensure the values can achieve the full range with normal motion
    calibrate_min_pitch -= (calibrate_min_pitch * 0.05);
    calibrate_max_pitch -= (calibrate_max_pitch * 0.05);
    calibrate_min_roll -= (calibrate_min_roll * 0.05);
    calibrate_max_roll -= (calibrate_max_roll * 0.05);
    calibrate_min_yaw -= (calibrate_min_yaw * 0.05);
    calibrate_max_yaw -= (calibrate_max_yaw * 0.05);
    calibrate_max_touch -= (calibrate_max_touch * 0.05);
    
    // open preferences memory space
    preferences.begin("opc", false);

    // write min/max values to memory
    preferences.putDouble("min_pitch", calibrate_min_pitch);
    preferences.putDouble("max_pitch", calibrate_max_pitch);
    preferences.putDouble("min_roll", calibrate_min_roll);
    preferences.putDouble("max_roll", calibrate_max_roll);
    preferences.putDouble("min_yaw", calibrate_min_yaw);
    preferences.putDouble("max_yaw", calibrate_max_yaw);
    preferences.putDouble("max_touch", calibrate_max_touch);

    // write the fact that device has been calibrated to memory
    preferences.putInt("is_calibrated", 1);

    // close preferences
    preferences.end();

    // turn off notification LED
    delay(10);
    digitalWrite(led, HIGH);

  }

  // reset calibration
  if (programChange(midi_packet_in) == 55) {
    digitalWrite(led, LOW);

    // open preferences memory space
    preferences.begin("opc", false);

    // reset calibration
    preferences.clear();

    // write the fact that device has been reset to memory
    preferences.putInt("is_calibrated", 0);

    // close preferences
    preferences.end();

    delay(10);
    digitalWrite(led, HIGH);

    // restart device for changes to take place
    ESP.restart();
  }

  // compute IMU and touch axes
  // pitch axis
  current_pitch = splitScale(pitch, tare_pitch, -1.5, 1.5, 0., 16383., calibrate_min_pitch, calibrate_max_pitch);
  responsive_pitch.update(current_pitch);
  smoothed_pitch = responsive_pitch.getValue();
  smoothed_pitch_midi = map(smoothed_pitch, 0, 16383, 0, 127);

  // send pitchbend message for pitch axis
  if ((midi_pitchbend_pitch == 1) && (smoothed_pitch != previous_pitch)) {
      int16_t temp_pitch = map(smoothed_pitch, 0, 16383, -8192, 8191);
      int16_t temp_pitch_inverted = map(smoothed_pitch, 0, 16383, 8191, -8192);
    if (invert_pitch == 0) {
#if defined USE_WEBSOCKETS && USE_WEBSOCKETS == 1      
      char buffer[256];
      //sprintf(buffer, "{ \"type\": \"imu\", \"uid\": 2, \"values\": [%d]}", smoothed_pitch);
      sprintf(buffer, PEBBLE_OSC, smoothed_pitch);
      webSocket.sendTXT(buffer);
#endif // USE_WEBSOCKETS
      MIDI.pitchBend(temp_pitch , midi_channel);
    } else {
#if defined USE_WEBSOCKETS && USE_WEBSOCKETS == 1
      char buffer[256];
      //sprintf(buffer, "{ \"type\": \"imu\", \"uid\": 2, \"values\": [%d]}", smoothed_pitch);
      sprintf(buffer, PEBBLE_OSC, smoothed_pitch);
      webSocket.sendTXT(buffer);
#endif // USE_WEBSOCKETS
      MIDI.pitchBend(temp_pitch_inverted, midi_channel);
    }
    previous_pitch = smoothed_pitch;
  }

  // send CC message for pitch axis
  if (smoothed_pitch_midi != previous_pitch_midi) {
    drift_timer = millis(); // reset countdown for yaw drift calibration
    if (midi_cc_pitch == 1) { 
      if (invert_pitch == 0) {
        MIDI.controlChange(cc_pitch, smoothed_pitch_midi, midi_channel);
      } else {
        MIDI.controlChange(cc_pitch, 127 - smoothed_pitch_midi, midi_channel);
      }
    }
    previous_pitch_midi = smoothed_pitch_midi;
  }

  // roll axis
  current_roll = splitScale(roll, tare_roll, -PI, PI, 0, 127., calibrate_min_roll, calibrate_max_roll);
  responsive_roll.update(current_roll);
  smoothed_roll = responsive_roll.getRawValue();

  if (smoothed_roll != previous_roll) {
    if (invert_roll == 1) {
      MIDI.controlChange(cc_roll, smoothed_roll, midi_channel);
    } else {
      MIDI.controlChange(cc_roll, 127 - smoothed_roll, midi_channel);
    }
    previous_roll = smoothed_roll;
  }

  // yaw axis
  current_yaw = splitScale(yaw, tare_yaw, -PI, PI, 0, 127., calibrate_min_yaw, calibrate_max_yaw);
  responsive_yaw.update(current_yaw);
  smoothed_yaw = responsive_yaw.getValue();

  if (current_yaw != previous_yaw) {
    if (invert_yaw == 1) {
      MIDI.controlChange(cc_yaw, current_yaw, midi_channel);
    } else {
      MIDI.controlChange(cc_yaw, 127 - current_yaw, midi_channel);
    }
    previous_yaw = current_yaw;
  }

  // drift compensation function for yaw axis
  if (millis() - drift_timer > drift_compensation_duration) {   
    temp_current_yaw = (yaw * 0.5) + (temp_previous_yaw * 0.5); // apply smoothing to incoming value
    tare_yaw = temp_current_yaw;
    temp_previous_yaw = tare_yaw;
    drift_timer = millis();
  }

  // capacitive touch
  //current_touch = constrain(map(constrain(touchRead(touchPin), calibrate_min_touch, calibrate_max_touch), calibrate_min_touch, calibrate_max_touch, 0, 1000), 0, 127);
  //responsive_touch.update(current_touch);
  //smoothed_touch = responsive_touch.getValue();

  // if (smoothed_touch != previous_touch) {
  //   MIDI.controlChange(cc_touch, smoothed_touch, midi_channel);
  //   previous_touch = smoothed_touch;
  // }

#if defined USE_WEBSOCKETS && USE_WEBSOCKETS == 1
  webSocket.loop();
#endif // USE_WEBSOCKETS
}


/////////////////////////// FUNCTIONS ///////////////////////////

// version of map() that works on floats
float mapFloat(float x, float in_min, float in_max, float out_min, float out_max) {
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

// scale and wrap values when tare-ing
float tareFunction(double axis, double tare, double range_min, double range_max) {
  return fmod((axis - tare) + range_max, (abs(range_min) + abs(range_max))) - range_max;
}

// read IMU data and convert to Euler angles
void readSensors() {
  // get start time of loop cycle
  uint16_t fifo_samples;
  startTime = millis();

  // check the number of samples inside FIFO
  if (AccGyr.FIFO_Get_Num_Samples(&fifo_samples) != LSM6DSV16X_OK) {
    Serial.println("LSM6DSV16X Sensor failed to get number of samples inside FIFO");
    while (1);
  }

  // read the FIFO if there is one stored sample
  if (fifo_samples > 0) {
    for (int i = 0; i < fifo_samples; i++) {
      AccGyr.FIFO_Get_Tag(&tag);
      if (tag == 0x13u) {
        AccGyr.FIFO_Get_Rotation_Vector(&quaternions[0]);

        // change order of quaternion elements from XZYW to WXYZ so it works with quaternion to euler translation
        w = quaternions[3];
        x = quaternions[0];
        y = quaternions[1];
        z = quaternions[2];
    
        // pitch (y-axis rotation)
        pitch = -asin(2.0f * (x * z - w * y));
    
        // roll (x-axis rotation)
        roll = atan2(2.0f * (w * x + y * z), w * w - x * x - y * y + z * z);

        // yaw (z-axis rotation)
        yaw = atan2(2.0f * (x * y + w * z), w * w + x * x - y * y - z * z);
        // compute the elapsed time within loop cycle and wait
        elapsedTime = millis() - startTime;

        // tare once on startup
        tareOnce();

        if ((long)(ALGO_PERIOD - elapsedTime) > 0) {
          delay(ALGO_PERIOD - elapsedTime);
        }
      }  
    }
  }
}

// tare routine that runs on startup only
void tareOnce() {
  if (calibrate_startup == 0) {
    tare_pitch = pitch;
    tare_roll = roll;
    tare_yaw = yaw;
    //calibrate_min_touch = touchRead(touchPin) + (touchRead(touchPin) * 0.2);
    calibrate_startup = 1;
  }
}

// calibration function
void calibration() {
  // declare variables to use in calibration routine
  unsigned long startTime = millis();
  double temp_pitch = 0;
  double temp_roll = 0;
  double temp_yaw = 0;
  double temp_touch = 0;

  // set minimum and maximum to absurd values
  calibrate_min_pitch = 9999;
  calibrate_max_pitch = -9999;
  calibrate_min_roll = 9999;
  calibrate_max_roll = -9999;
  calibrate_min_yaw = 9999;
  calibrate_max_yaw = -9999;
  calibrate_max_touch = -9999;
  
  while (millis() - startTime < calibration_duration) {    
    // read LSM6DSV16X quaternions and convert to Euler angles
    readSensors();

    // store (normalized) temporary values for setting the minimum and maximum range
    temp_pitch = tareFunction(pitch, tare_pitch, -1.5, 1.5);
    temp_roll = tareFunction(roll, tare_roll, -PI, PI);
    temp_yaw = tareFunction(yaw, tare_yaw, -PI, PI);
    // temp_touch = touchRead(touchPin);

    // print values as they come in
    Serial.print("Current calibration values. pitch:");
    Serial.print(temp_pitch);
    Serial.print(" roll:");
    Serial.print(temp_roll);
    Serial.print(" yaw:");
    Serial.print(temp_yaw);
    Serial.print(" touch:");
    Serial.println(temp_touch);
    Serial.print("Time remaining: ");
    Serial.println(calibration_duration + ((startTime + 10) - millis()));

    // update the minimum and maximum values for pitch
    if (temp_pitch < calibrate_min_pitch) {
      calibrate_min_pitch = temp_pitch;
    }
    if(temp_pitch > calibrate_max_pitch) {
      calibrate_max_pitch = temp_pitch;
    }

    // update the minimum and maximum values for roll
    if (temp_roll < calibrate_min_roll) {
      calibrate_min_roll = temp_roll;
    }
    if(temp_roll > calibrate_max_roll) {
      calibrate_max_roll = temp_roll;
    }

    // update the minimum and maximum values for yaw
    if (temp_yaw < calibrate_min_yaw) {
      calibrate_min_yaw = temp_yaw;
    }
    if(temp_yaw > calibrate_max_yaw) {
      calibrate_max_yaw = temp_yaw;
    }

    // update the maximum value for touch (minimum is set by the tare function)
    if(temp_touch > calibrate_max_touch) {
      calibrate_max_touch = temp_touch;
    }
  }

  // print calibration results
  Serial.print("Calibration values: ");
  Serial.print(calibrate_min_pitch);
  Serial.print(" ");
  Serial.print(calibrate_max_pitch);
  Serial.print(" ");
  Serial.print(calibrate_min_roll);
  Serial.print(" ");
  Serial.print(calibrate_max_pitch);
  Serial.print(" ");
  Serial.print(calibrate_min_roll);
  Serial.print(" ");
  Serial.print(calibrate_max_roll);
  Serial.print(" ");
  Serial.print(calibrate_min_touch);
  Serial.print(" ");
  Serial.println(calibrate_max_touch);
}

// function for having separate scaling above and below zero (in case of asymmetrical calibration data)
double splitScale (double x, double tare, double in_min, double in_max, double out_min, double out_max, double& calibrate_min, double& calibrate_max) {
  double results = 0;
  if (tareFunction(x, tare, in_min, in_max) >= 0.) {
    results = mapFloat(constrain(tareFunction(x, tare, in_min, in_max), 0., calibrate_max), 0., calibrate_max, (out_max * 0.5), out_max);
  } else {
    results = mapFloat(constrain(tareFunction(x, tare, in_min, in_max), calibrate_min, 0.), calibrate_min, 0., out_min, (out_max * 0.5));
  }
  return results;
}

// functions for library-less debouncing of the two buttons
// (See also: https://tinyurl.com/simple-debounce)
bool debounceTare(const int& btn) {
  static uint16_t state = 0;
  state = (state<<1) | (1 - digitalRead(btn)) | 0xfe00;
  return (state == 0xff00);
}

bool debounceCalibrate(const int& btn) {
  static uint16_t state = 0;
  state = (state<<1) | (1 - digitalRead(btn)) | 0xfe00;
  return (state == 0xff00);
}

// function for checking incoming MIDI messages (for tare and calibration)
int programChange(midiEventPacket_t &midi_packet_in) {
  // See Chapter 4: USB-MIDI Event Packets (page 16) of the spec.
  uint8_t cable_num = MIDI_EP_HEADER_CN_GET(midi_packet_in.header);
  midi_code_index_number_t code_index_num = MIDI_EP_HEADER_CIN_GET(midi_packet_in.header);

  if (code_index_num == MIDI_CIN_PROGRAM_CHANGE) {
    return (midi_packet_in.byte2 + 1);
  }
}

/////////////////////////// EXAMPLE MAX CODE ///////////////////////////

/*
code
*/




















/*
 *******************************************************************************
   Copyright (c) 2022, STMicroelectronics
   All rights reserved.

   This software component is licensed by ST under BSD 3-Clause license,
   the "License"; You may not use this file except in compliance with the
   License. You may obtain a copy of the License at:
                          opensource.org/licenses/BSD-3-Clause

 *******************************************************************************
*/