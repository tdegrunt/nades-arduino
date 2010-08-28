// 
//  Sensor.h
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-19.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

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
  
  void tick();
public:
  Sensor();
  void setup(int aSensorPin, const char *aName, int aTickOnLowOrHigh, int aC, int aReportFactor, int aReportDigits, unsigned long aUsage);
  void check();
  void resetForReporting();
  int toJSON(char *jsonBuffer, int bufferSize);
};

Sensor::Sensor() {
}

void Sensor::setup(int aSensorPin, const char *aName, int aTickOnLowOrHigh, int aC, int aReportFactor, int aReportDigits, unsigned long aUsage) {
  sensorPin = aSensorPin;
  name = aName;
  tickOnLowOrHigh = aTickOnLowOrHigh;
  c = aC;
  reportFactor = aReportFactor;
  reportDigits = aReportDigits;
  usage = aUsage;

  state = lastState = -1;
}

void Sensor::check() {
  int state = digitalRead(sensorPin);

  if (state == HIGH && lastState != state) {
    tick();
  }
  lastState = state;
}

void Sensor::tick() {
  unsigned long time = millis(); // Record tick time!
  usage++;
  ticksSinceLastReport++;
  if (lastRotationTime > 0) {
    currentUse = reportFactor * ((3600000.0 / (time-lastRotationTime)) / (float)c);
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
