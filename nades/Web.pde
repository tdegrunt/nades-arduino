// 
//  Web.pde
//  NADES
//  
//  Created by Tom de Grunt on 2010-08-19.
//  Copyright 2010 Tom de Grunt. All rights reserved.
// 

#include <Ethernet.h>
#include <Client.h>

#include "PString.h"
#include "Time.h"

boolean getHTTPBody(Client &clnt, char *buffer, int size);

#define HTTP_USER_AGENT "User-Agent: NADES"
#define HTTP_CONTENT_TYPE_JSON "Content-Type: application/json"
#define HTTP_POST_UPDATE "POST /update HTTP/1.1"
#define HTTP_GET_TIME "GET /time HTTP/1.1"
#define HTTP_CONNECTION_CLOSE "Connection: close"

#define NADES_UPDATE_INTERVAL 180000 // 3 minutes

byte NADES_SERVER_IP_ADDRESS[] = { 192, 168, 1, 8 };
int NADES_SERVER_IP_PORT = 8000;

char jsonBuffer[128];
char bodyBuff[11]; 

unsigned long NADESLastUpdate = 0;

// ============
// = Ethernet =
// ============

byte MAC_ADDRESS[] = { 0x90, 0xA2, 0xDA, 0x00, 0x09, 0xBF };
byte IP_ADDRESS[] = { 192, 168, 1, 9 };

void updateNADES() {
  unsigned long time = millis();

  if (time - NADESLastUpdate >= NADES_UPDATE_INTERVAL) {
    NADESLastUpdate = time; // reset timer
    
    Client NADESClient(NADES_SERVER_IP_ADDRESS, NADES_SERVER_IP_PORT);
    if (NADESClient.connect()) {
      
      int contentLength = 56;  // 56 for {"created_at":"Wed, Aug 25 2010 23:27:18 GMT","data":[]}
      for(int i = 0; i < TOTAL_SENSORS; i++) {
        contentLength += sensors[i].toJSON(jsonBuffer,sizeof(jsonBuffer));
        if (i < TOTAL_SENSORS-1) {
          contentLength += 1;
        }
      }
      
      NADESClient.println(HTTP_POST_UPDATE);
      NADESClient.println(HTTP_USER_AGENT);
      NADESClient.println(HTTP_CONTENT_TYPE_JSON);
      NADESClient.print("Content-Length: ");
      NADESClient.println(contentLength);
      NADESClient.println(HTTP_CONNECTION_CLOSE);
      NADESClient.println();
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
      delay(50);
      
      if (getHTTPBody(NADESClient, bodyBuff, 2)) {
        if (bodyBuff[0] == 'O' && bodyBuff[1] == 'K') {
          // Reset sensor ticks since last report
          for(int i = 0; i < TOTAL_SENSORS; i++) {
            sensors[i].resetForReporting();        
          }
          NADESLastUpdate = time; // reset timer
          Serial.println("Updated NADES");
        }
      }
      NADESClient.stop();
    } 
  }
}

time_t requestTimeSync() {
  Client NADESClient(NADES_SERVER_IP_ADDRESS, NADES_SERVER_IP_PORT);
  if (NADESClient.connect()) {
    NADESClient.println(HTTP_GET_TIME);
    NADESClient.println(HTTP_USER_AGENT);
    NADESClient.println(HTTP_CONNECTION_CLOSE);
    NADESClient.println();
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

  delay(1000); // Allow ethernet to wake up
  setSyncProvider(requestTimeSync);
}


void handleWeb() {
  updateNADES();
}
