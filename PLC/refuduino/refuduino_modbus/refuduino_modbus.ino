/*
  Ethernet Modbus TCP Server LED

  This sketch creates a Modbus TCP Server with a simulated coil.
  The value of the simulated coil is set on the LED

  Circuit:
   - Any Arduino MKR Board
   - MKR ETH Shield

  created 16 July 2018
  by Sandeep Mistry
*/

#include <SPI.h>
#include <NativeEthernet.h>

#include <ArduinoRS485.h> // ArduinoModbus depends on the ArduinoRS485 library
#include <ArduinoModbus.h>

#define FEATURE_RECORD_TO_REGISTER 0x501
#define FEATURE_RECORD_TO_SD 0x502
#define FEATURE_RECORD_PASSTHROUGH 0x503


// Enter a MAC address for your controller below.
// Newer Ethernet shields have a MAC address printed on a sticker on the shield
// The IP address will be dependent on your local network:
byte mac[] = {
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED
};
IPAddress ip(192, 168, 1, 177);

EthernetServer ethServer(502);

ModbusTCPServer modbusTCPServer;

const int ledPin = LED_BUILTIN;

int ix_pins[5] = {2,3,4,5,6};
int ixpin_base=2;
int donepin = 12;
int feature_register_base=0x500;
int feature_register_dump=0x501;
int feature_register_sd=0x502;
int feature_register_example_1=0x503;
int feature_register_example_2=0x504;
int feature_register_example_3=0x505;

void setup() {
  // You can use Ethernet.init(pin) to configure the CS pin
  //Ethernet.init(10);  // Most Arduino shields
  //Ethernet.init(5);   // MKR ETH shield
  //Ethernet.init(0);   // Teensy 2.0
  //Ethernet.init(20);  // Teensy++ 2.0
  //Ethernet.init(15);  // ESP8266 with Adafruit Featherwing Ethernet
  //Ethernet.init(33);  // ESP32 with Adafruit Featherwing Ethernet

  // Open serial communications and wait for port to open:
  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  Serial.println("Ethernet Modbus TCP Example");

  // start the Ethernet connection and the server:
  //Ethernet.begin(mac, ip);
    Ethernet.begin(mac);
  // Check for Ethernet hardware present
  if (Ethernet.hardwareStatus() == EthernetNoHardware) {
    Serial.println("Ethernet shield was not found.  Sorry, can't run without hardware. :(");
    while (true) {
      delay(1); // do nothing, no point running without Ethernet hardware
    }
  }
  if (Ethernet.linkStatus() == LinkOFF) {
    Serial.println("Ethernet cable is not connected.");
  } else {
     Serial.print("Server is running on:");
     Serial.println(Ethernet.localIP());
  }

  // start the server
  ethServer.begin();
  
  // start the Modbus TCP server
  if (!modbusTCPServer.begin()) {
    Serial.println("Failed to start Modbus TCP Server!");
    while (1);
  }

  // configure the LED
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);

  // configure a single coil at address 0x00
  modbusTCPServer.configureCoils(0x100, 5);
  modbusTCPServer.configureHoldingRegisters(0x10F,1);
  modbusTCPServer.configureHoldingRegisters(0x500,5);

  for(int i=0; i < 5;i++) { 
      pinMode(ixpin_base+i,OUTPUT);
      digitalWrite(ixpin_base+i,HIGH);
      delay(100);
      digitalWrite(ixpin_base+i,LOW);
  }
  
  pinMode(donepin,OUTPUT);
  digitalWrite(donepin,LOW);
}

void loop() {
  // listen for incoming clients
  EthernetClient client = ethServer.available();
  
  if (client) {
    // a new client connected
    Serial.println("new client");

    // let the Modbus TCP accept the connection 
    modbusTCPServer.accept(client);

    while (client.connected()) {
      // poll for Modbus TCP requests, while client connected
      modbusTCPServer.poll();

      // update the LED
      //updateLED();
        updateIX();

     int feature_state=modbusTCPServer.holdingRegisterRead(0x500);
     
     if (feature_state == 1) {
           int feature_flags[] = modbusTCPServer.holdingRegisterRead(0x500,5);
         proc_features(feature_flags);
     }
     
     int donestate=modbusTCPServer.holdingRegisterRead(0x10f);
     Serial.println("Holding Register after updateIX:");
     Serial.println(donestate);
     
     if (donestate == 1) { 
         digitalWrite(donepin,HIGH); 
         delay(1000);
         digitalWrite(donepin,LOW);
     }

    }

    Serial.println("client disconnected");
  }
}

void updateIX() {
int coilpos=0x100;
  for (int i=0x0; i < 0x5;i++) { 

      coilpos=0x100+i;
      int coilValue=modbusTCPServer.coilRead(coilpos);
      digitalWrite(ixpin_base+i,coilValue);
      Serial.print(" ");
      Serial.print(coilpos);
      Serial.print(" " );
      Serial.print(coilValue);
      delay(100);
  }
  Serial.println();
}

void proc_features( int *features) {
  
/*proc feature flags like passthrough mode, */
/*record-to-sd, record-to-registers, etc. */


     
}

void updateLED() {
  // read the current value of the coil
  int coilValue = modbusTCPServer.coilRead(0x00);

  if (coilValue) {
    // coil value set, turn LED on
    digitalWrite(ledPin, HIGH);
  } else {
    // coild value clear, turn LED off
    digitalWrite(ledPin, LOW);
  }
}
