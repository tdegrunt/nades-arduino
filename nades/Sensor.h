// 
//  Sensor.h
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-28.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include "WProgram.h"
#import "PString.h"

class Sensor {
private:

  int c;

  int state;
  int lastState;

  unsigned long lastTick;

  int sensorPin;
  const char *name;
  int tickOnLowOrHigh;
  unsigned long usage;
  float currentUse;
  float averageUse;
  unsigned long ticksSinceLastReport;
  unsigned long lastRotationTime;
  int reportFactor;
  int reportDigits;
  
  int increment;
  
  void tick();
public:
  Sensor();
  void setup(int aSensorPin, const char *aName, int aTickOnLowOrHigh, int aC, int aReportFactor, int aReportDigits, unsigned long aUsage, int aIncrement);
  void check();
  void resetForReporting();
  int toJSON(char *jsonBuffer, int bufferSize);
};

/*
 * Constructor
 */
Sensor::Sensor() {
}

/*
 * setup
 *
 * aSensorPin - which (digital) pin to use
 * aName - name of the sensor (power, gas, water)
 * aTickOnLowOrHigh - whether the sensor should tick on a LOW or a HIGH
 * aC - turns per kWh / m3
 * aReportFactor - multiplication factor for the current and average usage (to report in Watts or dm3, etc)
 * aReportDigits - precision when reporting
 * aUsage - current usage of the unit in turns
 * aIncrement - increment with what if the sensor ticks
 */
void Sensor::setup(int aSensorPin, const char *aName, int aTickOnLowOrHigh, int aC, int aReportFactor, int aReportDigits, unsigned long aUsage, int aIncrement) {
  sensorPin = aSensorPin;
  name = aName;
  tickOnLowOrHigh = aTickOnLowOrHigh;
  c = aC;
  reportFactor = aReportFactor;
  reportDigits = aReportDigits;
  usage = aUsage;
  increment = aIncrement;

  pinMode(sensorPin, INPUT);
  state = lastState = digitalRead(sensorPin);
}

/*
 * check - checks the sensor
 */
void Sensor::check() {
  int state = digitalRead(sensorPin);
  if (state == tickOnLowOrHigh && lastState != state) {
    tick();
    Serial.print(name);
    Serial.println(": tick!");
  }
  lastState = state;
}

/*
 * tick - records a tick
 */
void Sensor::tick() {
  unsigned long time = millis(); // Record tick time!
  usage+=increment;
  ticksSinceLastReport+=increment;
  if (lastRotationTime > 0) {
    // 3600000.0 is the number of miliseconds in an hour
    currentUse = (float)reportFactor * ((3600000.0 / (float)(time-lastRotationTime)) / (float)c);
    averageUse += currentUse;
  }
  lastRotationTime = time;
}

void Sensor::resetForReporting() {
  ticksSinceLastReport = 0;
  averageUse = 0;
}

/*
 * JSON for data - as short as possible
 * Example: {"name":"power","total":83321.2031,"current":560.7267,"average":500.5327}
 */ 
int Sensor::toJSON(char *jsonBuffer, int bufferSize) {
  PString pstring = PString(jsonBuffer, 128);
  
  pstring.begin();
  pstring.print("{\"name\":\"");
  pstring.print(name);
  pstring.print("\",\"total\":");
  pstring.print((float)((float)usage/(float)c),reportDigits);
  pstring.print(",\"current\":");
  pstring.print((float)(currentUse),reportDigits);
  pstring.print(",\"average\":");
  pstring.print((float)((float)averageUse/(float)ticksSinceLastReport),reportDigits);
  pstring.print("}");
  
  return pstring.length();
}
