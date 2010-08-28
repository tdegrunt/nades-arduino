// 
//  nades.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-17.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include "Sensor.h"
#include "Time.h"

const unsigned int TOTAL_SENSORS = 2;
Sensor sensors[TOTAL_SENSORS];

// ===========
// = Generic =
// ===========

const unsigned int DELAY = 200; // miliseconds

// ================
// = Setup & Loop =
// ================

void setup() {
  //loadConfig();
  Serial.begin(9600);
  Serial.println("[nades]");
  Serial.println("");

  // Place to setup sensors (possibly do through web-interface?)
  sensors[0].setup(7, "power", HIGH, 120, 1000, 4, (unsigned long)10003690); 
  sensors[1].setup(6, "gas", LOW, 1000, 1000, 3, (unsigned long)86774455);
  //sensors[2].setup(5, "water", HIGH, 0, 0, 0);

  setupWeb();
}

void loop() {
  for( int i = 0; i < TOTAL_SENSORS; i++ ) {
    sensors[i].check();
  }

  handleWeb();
  delay(DELAY);
}

