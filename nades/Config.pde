// 
//  Config.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-19.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include <EEPROM.h>

#define CONFIG_VERSION "N002"
#define CONFIG_START 0

// Example settings structure
struct ConfigStruct {
  // This is for mere detection if they are your settings
  char version[5];
  // The variables of your settings
  int meanValuePower;
  int meanValueGas;
  int meanValueWater;
} config = {
  CONFIG_VERSION,
  // The default values
  850, 800, 512
};

void loadConfig() {
  if (EEPROM.read(CONFIG_START + 0) == CONFIG_VERSION[0] &&
      EEPROM.read(CONFIG_START + 1) == CONFIG_VERSION[1] &&
      EEPROM.read(CONFIG_START + 2) == CONFIG_VERSION[2] &&
      EEPROM.read(CONFIG_START + 3) == CONFIG_VERSION[3] &&
      EEPROM.read(CONFIG_START + 4) == CONFIG_VERSION[4] &&
      EEPROM.read(CONFIG_START + 5) == CONFIG_VERSION[5] ) {
        
    for (unsigned int t=0; t<sizeof(config); t++) {
      *((char*)&config + t) = EEPROM.read(CONFIG_START + t);
    }
  } else {
    saveConfig();
  }
}

void saveConfig() {
  for (unsigned int t=0; t<sizeof(config); t++) {
    EEPROM.write(CONFIG_START + t, *((char*)&config + t));
  }
}
