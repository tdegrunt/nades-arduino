// 
//  Web.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-19.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include <Ethernet.h>
#include <Client.h>
#include <stdlib.h>

#include "PString.h"
#include "WebServer.h"
#include "Time.h"

boolean getHTTPBody(Client &clnt, char *buffer, int size);

#define HTTP_USER_AGENT "User-Agent: NADES\r\n"
#define HTTP_CONTENT_TYPE_JSON "Content-Type: application/json\r\n"
#define HTTP_CONNECTION_CLOSE "Connection: close\r\n\r\n"

#define NADES_UPDATE_INTERVAL 180000 // 3 minutes

byte NADES_SERVER_IP_ADDRESS[] = { 192, 168, 1, 8 };
int NADES_SERVER_IP_PORT = 8000;

char NADESData[256];
char dateTimeBuffer[32];
char bodyBuff[11]; 

unsigned long NADESLastUpdate = 0;

#define NAMELEN 32
#define VALUELEN 32

// ==========
// = Server =
// ==========

const unsigned int SERVER_PORT = 80;
byte MAC_ADDRESS[] = { 0x90, 0xA2, 0xDA, 0x00, 0x09, 0xBF };
byte IP_ADDRESS[] = { 192, 168, 1, 9 };
WebServer webserver("", 80);

/*
 * set
 */
void setCmd(WebServer &server, WebServer::ConnectionType type, char *url_tail, bool tail_complete) {
  URLPARAM_RESULT rc;
  char name[NAMELEN];
  int  name_len;
  char value[VALUELEN];
  int value_len;  
  
  server.httpSuccess(); 
  
  if (strlen(url_tail)) {
    while (strlen(url_tail)) {
      rc = server.nextURLparam(&url_tail, name, NAMELEN, value, VALUELEN);
      if (rc != URLPARAM_EOS) {
        Serial.print(name);
        Serial.print("=");
        Serial.print(value);
        if (strcmp(name, "mvp")==0) {
          Serial.print("match");
           config.meanValuePower = atoi(value);
           saveConfig();
        }
        if (strcmp(name, "mvg")==0) {
          Serial.print("match");
           config.meanValueGas = atoi(value);
           saveConfig();
        }
      }
    }
  }
}

/* 
 * index
 */
void indexCmd(WebServer &server, WebServer::ConnectionType type, char *url_tail, bool tail_complete) {
  server.httpSuccess("text/html");
  
  // Power
  server.print("<h1>Power: ");
  server.print(currentUsePower,4);
  server.print(" W - ");
  server.print((float)usagePower/cPower,4);
  server.print(" kWh</h1><pre>");
  // meanValuePower, sensorValuePower, statePower
  server.print(config.meanValuePower);
  server.print(",");
  server.print(sensorValuePower);
  server.print(",");
  server.print(statePower);
  server.print("</pre>");

  // Gas
  server.print("<h1>Gas: ");
  server.print(currentUseGas,3);
  server.print(" dm3 - ");
  server.print(usageGas/cGas,3);
  server.print(" m3</h1><pre>");
  server.print(config.meanValueGas);
  server.print(",");
  server.print(sensorValueGas);
  server.print(",");
  server.print(stateGas);
  server.print("</pre>");

}

void updateNADES() {
  unsigned long time = millis();

  if (time - NADESLastUpdate >= NADES_UPDATE_INTERVAL) {
    NADESLastUpdate = millis(); // reset timer
    
    Client NADESClient(NADES_SERVER_IP_ADDRESS, NADES_SERVER_IP_PORT);
    if (NADESClient.connect()) {
      
      PString dtString(dateTimeBuffer, sizeof(dateTimeBuffer));
      dtString.begin();
      dtString.print(dayShortStr(weekday()));
      dtString.print(", ");
      dtString.print(day());
      dtString.print(" ");
      dtString.print(monthShortStr(month()));
      dtString.print(" ");
      dtString.print(year()); 
      dtString.print(" ");
      dtString.print(hour());
      dtString.print(":");
      if (minute() < 10) {
        dtString.print("0");
      }
      dtString.print(minute());
      dtString.print(":");
      if (second() < 10) {
        dtString.print("0");
      }
      dtString.print(second());
      dtString.print(" GMT");
      
      // JSON for data - as short as possible
      // 
      // Keys: 
      // - n: name (values: p(ower), g(as), w(ater))
      // - t: total (float)
      // - c: current (float)
      // - a: average (float) - since last report
      // - s: stamp (date time stamp)
      // 
      // Example:
      // {"n":"p","t":83321.2031,"c":560.7267,"a":500.5327,"s":"Mon, 23 Aug 2010 21:17:46 GMT"}
      PString pstring = PString(NADESData, sizeof(NADESData));
      pstring.begin();
      pstring.print("[");
      pstring.print("{\"n\": \"p\",\"t\":");
      pstring.print((float)(usagePower/cPower),4);
      pstring.print(",\"c\":");
      pstring.print((float)(currentUsePower),4);
      pstring.print(",\"a\":");
      pstring.print((float)(averageUsePower/ticksSinceLastReportPower),4);
      pstring.print(",\"s\":\"");
      pstring.print(dtString);
      pstring.print("\"},");
      pstring.print("{\"n\": \"g\",\"t\":");
      pstring.print((usageGas/cGas),3);
      pstring.print(",\"c\":");
      pstring.print((float)(currentUseGas),3);
      pstring.print(",\"a\":");
      pstring.print((float)(averageUseGas/ticksSinceLastReportGas),3);
      pstring.print(",\"s\":\"");
      pstring.print(dtString);
      pstring.print("\"}");
      pstring.print("]");
      
      // Reset sensor ticks since last report
      resetReportedTicksAndAverages();
      
      NADESClient.print("POST /update HTTP/1.1\r\n");
      NADESClient.print(HTTP_USER_AGENT);
      NADESClient.print(HTTP_CONTENT_TYPE_JSON);
      NADESClient.print("Content-Length: ");
      NADESClient.print(pstring.length());
      NADESClient.print("\n");
      NADESClient.print(HTTP_CONNECTION_CLOSE);
      // body
      NADESClient.print(pstring);
    
      while (NADESClient.available()) {
        char c = NADESClient.read();
        Serial.print(c);
      }
      NADESClient.stop();
    } 
  }
}

time_t requestTimeSync() {
  Client NADESClient(NADES_SERVER_IP_ADDRESS, NADES_SERVER_IP_PORT);
  if (NADESClient.connect()) {
    NADESClient.print("GET /time HTTP/1.1\r\n");
    NADESClient.print(HTTP_USER_AGENT);
    NADESClient.print(HTTP_CONNECTION_CLOSE);
    delay(200);
      
    if (getHTTPBody(NADESClient, bodyBuff, 10)) {
      time_t pctime = 0;
      for(int i=0; i < 10; i++) {   
        if( bodyBuff[i] >= '0' && bodyBuff[i] <= '9') {   
          pctime = (10 * pctime) + (bodyBuff[i] - '0') ; // convert digits to a number    
        }
      } 
      setTime(pctime); 
      Serial.println("Time synched");  
    }
    NADESClient.stop();
  } else {
    Serial.println("Failed to sync time");
    return 0;
  }
}

boolean getHTTPBody(Client &clnt, char *buffer, int size) {
  int i = 0;
  int x = 0;
  boolean gotBody = false;
  while (clnt.available()) {
    if (!gotBody) {
      if(i==3) {
        for (x=0; x < 4; x++ ) {
          buffer[x] = buffer[x+1];
        }
      } else {
        i++;
      }
      buffer[i] = clnt.read();
      if (buffer[0] == '\r' && buffer[1] == '\n' && buffer[2] == '\r' && buffer[3] == '\n') {
        gotBody = true;
        i=0;
      }
    } else {
      if (i < size) {
        buffer[i] = clnt.read();
        i++;
      }
    }
  }  
  return gotBody;
}

void setupWeb() {
  Ethernet.begin(MAC_ADDRESS, IP_ADDRESS);  
  webserver.setDefaultCommand(&indexCmd);
  //webserver.setFailureCommand(&fourOhFourCmd);
  webserver.addCommand("set", &setCmd);
  webserver.addCommand("index", &indexCmd);
  
  webserver.begin();
  delay(1000); // Allow ethernet to wake up
  setSyncProvider(requestTimeSync);
}


void handleWeb() {
  char buff[64];
  int len = 64;
  webserver.processConnection(buff, &len);
  
  updateNADES();
}
