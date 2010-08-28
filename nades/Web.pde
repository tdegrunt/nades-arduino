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

char jsonBuffer[128];
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
  server.print("{");
  server.print("\"created_at\":\"");
  
  server.print(dayShortStr(weekday()));
  server.print(", ");
  server.print(day());
  server.print(" ");
  server.print(monthShortStr(month()));
  server.print(" ");
  server.print(year()); 
  server.print(" ");
  server.print(hour());
  server.print(":");
  if (minute() < 10) {
    server.print("0");
  }
  server.print(minute());
  server.print(":");
  if (second() < 10) {
    server.print("0");
  }
  server.print(second());
  server.print(" GMT");      
  
  server.print("\",");
  server.print("\"data\":[");
  
  for(int i = 0; i < TOTAL_SENSORS; i++) {
    sensors[i].toJSON(jsonBuffer,sizeof(jsonBuffer));
    server.print(jsonBuffer);
    if (i < TOTAL_SENSORS-1) {
      server.print(",");
    }
  }
  
  server.print("]}");  
}

void updateNADES() {
  unsigned long time = millis();

  if (time - NADESLastUpdate >= NADES_UPDATE_INTERVAL) {
    
    Client NADESClient(NADES_SERVER_IP_ADDRESS, NADES_SERVER_IP_PORT);
    if (NADESClient.connect()) {
      
      int contentLength = 56;  // 56 for {"created_at":"Wed, Aug 25 2010 23:27:18 GMT","data":[]}
      for(int i = 0; i < TOTAL_SENSORS; i++) {
        contentLength += sensors[i].toJSON(jsonBuffer,sizeof(jsonBuffer));
        if (i < TOTAL_SENSORS-1) {
          contentLength += 1;
        }
      }
      
      NADESClient.print("POST /update HTTP/1.1\r\n");
      NADESClient.print(HTTP_USER_AGENT);
      NADESClient.print(HTTP_CONTENT_TYPE_JSON);
      NADESClient.print("Content-Length: ");
      NADESClient.print(contentLength);
      NADESClient.print("\n");
      NADESClient.print(HTTP_CONNECTION_CLOSE);
      // body
      
      NADESClient.print("{");
      NADESClient.print("\"created_at\":\"");
      
      NADESClient.print(dayShortStr(weekday()));
      NADESClient.print(", ");
      NADESClient.print(day());
      NADESClient.print(" ");
      NADESClient.print(monthShortStr(month()));
      NADESClient.print(" ");
      NADESClient.print(year()); 
      NADESClient.print(" ");
      NADESClient.print(hour());
      NADESClient.print(":");
      if (minute() < 10) {
        NADESClient.print("0");
      }
      NADESClient.print(minute());
      NADESClient.print(":");
      if (second() < 10) {
        NADESClient.print("0");
      }
      NADESClient.print(second());
      NADESClient.print(" GMT");      
      
      NADESClient.print("\",");
      NADESClient.print("\"data\":[");

      for(int i = 0; i < TOTAL_SENSORS; i++) {
        sensors[i].toJSON(jsonBuffer,128);
        NADESClient.print(jsonBuffer);
        if (i < TOTAL_SENSORS-1) {
          NADESClient.print(",");
        }
      }

      NADESClient.print("]}");

      delay(20);
      
      if (getHTTPBody(NADESClient, bodyBuff, 10)) {
        if (bodyBuff[0] == 'O' && bodyBuff[1] == 'K') {
          // Reset sensor ticks since last report
          for(int i = 0; i < TOTAL_SENSORS; i++) {
            sensors[i].resetForReporting();        
          }
          NADESLastUpdate = time; // reset timer
        }
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
    delay(20);
      
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
