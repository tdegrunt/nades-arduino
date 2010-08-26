// 
//  nades.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-17.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include "Time.h"

// ===========
// = Generic =
// ===========

const unsigned int DELAY = 200; // miliseconds

// ================
// = Setup & Loop =
// ================

void setup() {
  loadConfig();
  Serial.begin(9600);
  Serial.println("[nades]");
  Serial.println("");

  setupWeb();
  setupSensors();
}

void loop() {
  checkSensors(); 
  handleWeb();
  delay(DELAY);
}

