// 
//  Sensors.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-19.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

/* Total crap at the moment, needs a Sensor class
 *
 * Gas is measured is m3
 * Electricity is measured in kWh
 */

const unsigned int SENSOR_PIN_POWER = 0;
const unsigned int SENSOR_PIN_GAS   = 1;
const unsigned int SENSOR_PIN_WATER = 2;

const unsigned int STATE_UNKNOWN     = 0;
const unsigned int STATE_CALIBRATING = 1;
const unsigned int STATE_NORMAL      = 2;
const unsigned int STATE_TICK        = 3;

// =========
// = Power =
// =========

unsigned int lastStatePower = STATE_UNKNOWN;
unsigned int statePower     = STATE_CALIBRATING;

int sensorValuePower = 0;

float currentUsePower               = 0;            // Current power usage (in Watt!)
float averageUsePower               = 0;
unsigned long ticksSinceLastReportPower = 0;
unsigned long lastRotationTimePower = 0;
unsigned long usagePower            = 10002000;      // Total kW/h in rotations

float cPower                        = 120;          // C = 120 (120 rotations per kWh)
float cGas                          = 1000;         // C = 1000 (1000 rotations per m3)

// =======
// = Gas =
// =======

unsigned int lastStateGas = STATE_UNKNOWN;
unsigned int stateGas     = STATE_CALIBRATING;

int sensorValueGas = 0;

float currentUseGas                 = 0;            // Current power usage
float averageUseGas                 = 0;
unsigned long ticksSinceLastReportGas = 0;
unsigned long lastRotationTimeGas   = 0;
unsigned long usageGas              = 86772015;    // m3 in rotations, ie total d3

void setupSensors(void) {
  pinMode(SENSOR_PIN_POWER, INPUT);
  pinMode(SENSOR_PIN_GAS, INPUT);
}

void checkSensors(void) {
  checkPowerSensor(); 
  checkGasSensor(); 
}

void increaseTickPower(void) {
  unsigned long time = millis(); // Record tick time!
  usagePower++;
  ticksSinceLastReportPower++;
  if (lastRotationTimePower > 0) {
    // Calculate use
    // 3600000 is number of miliseconds in an hour, multiplied by 1000 because we want to know Watt, not kWatt
    currentUsePower = (3600000000.0 / (time-lastRotationTimePower)) / cPower;
    averageUsePower += currentUsePower;
  }
  lastRotationTimePower = time;
}

void resetReportedTicksAndAverages(void) {
  ticksSinceLastReportPower = 0;
  averageUsePower = 0;

  ticksSinceLastReportGas = 0;
  averageUseGas = 0;
}

void increaseTickGas(void) {
  unsigned long time = millis();
  usageGas++;
  ticksSinceLastReportGas++;
  if (lastRotationTimeGas > 0) {
    // Calculate use, see Power for more info
    // We want to report on dm3, not m3
    currentUseGas = (3600000000.0 / (time-lastRotationTimeGas)) / cGas;
    averageUseGas += currentUseGas;
  }
  lastRotationTimeGas = time;
}

/*
 * Power sensor - a tick is measured when a less-reflective element passes the sensor
 */
void checkPowerSensor() {
  sensorValuePower = analogRead(SENSOR_PIN_POWER);
  switch (statePower) {
    case STATE_CALIBRATING:
      if (config.meanValuePower > 0) {
        statePower = (sensorValuePower > config.meanValuePower) ? STATE_TICK : STATE_NORMAL;
      }
      break;
    case STATE_TICK:
    case STATE_NORMAL:
      statePower = (sensorValuePower > config.meanValuePower) ? STATE_TICK : STATE_NORMAL;
      if (statePower == STATE_TICK && lastStatePower != STATE_TICK) {
        increaseTickPower();
      }
      lastStatePower = statePower;
      break;
  }
}

/*
 * Gas sensor - works the other way around than the power sensor
 * a tick is measured when a reflective element passes the sensor
 */
void checkGasSensor() {
  sensorValueGas = analogRead(SENSOR_PIN_GAS);
  switch (stateGas) {
    case STATE_CALIBRATING:
      if (config.meanValueGas > 0) {
        stateGas = (sensorValueGas < config.meanValueGas) ? STATE_TICK : STATE_NORMAL;
      }
      break;
    case STATE_TICK:
    case STATE_NORMAL:
      stateGas = (sensorValueGas < config.meanValueGas) ? STATE_TICK : STATE_NORMAL;
      if (stateGas == STATE_TICK && lastStateGas != STATE_TICK) {
        increaseTickGas();
      }
      lastStateGas = stateGas;
      break;
  }
}

