/**
*
* If you have not downloaded the driver required for ESP32 please do so first.
* Add the esp32 by Espressif Systems from Boards Manager and choose
* "Adafruit ESP32 Feather" as your board.
*
**/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
BLEServer *pServer;

bool deviceConnected = false;

const int motorFront = A0;
const int motorBack = A1;

bool calibrating = false;
unsigned long calibrationStartTime = 0;
int calibratedMaxValues[8] = {0, 0, 0, 0, 0, 0, 0, 0};

void turnMotorOn(int motor) {
  digitalWrite(motor, HIGH);
}

void turnMotorOff(int motor) {
  digitalWrite(motor, LOW);
}

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = std::string(pCharacteristic->getValue().c_str());

        if (value == "FRONT") {
            Serial.println("FRONT Motor ON");
            turnMotorOn(motorFront);
            turnMotorOff(motorBack);
        } else if (value == "BACK") {
            Serial.println("BACK Motor ON");
            turnMotorOn(motorBack);
            turnMotorOff(motorFront);
        } else if (value == "OFF") {
            Serial.println("Motor OFF");
            turnMotorOff(motorFront);
            turnMotorOff(motorBack);
        } else if (value == "CALIBRATE") {
          Serial.println("Calibrating!");
          calibrating = true;
          calibrationStartTime = millis();
          for (int i = 0; i < 8; i++) {
            calibratedMaxValues[i] = 0;
          }
        }

        else {
            Serial.println("Invalid Command");
        }

    }
};

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Device Connected");
    }

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Device Disconnected, Restarting Advertising...");
        BLEDevice::startAdvertising();
    }
};

void setup() {
  // declare the ledPin as an OUTPUT:
  pinMode(motorFront, OUTPUT);
  pinMode(motorBack, OUTPUT);
  Serial.begin(921600);

    BLEDevice::init("ESP32 Motor Controller");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
    );

    pCharacteristic->setCallbacks(new MyCallbacks());
    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    turnMotorOff(motorFront);
    turnMotorOn(motorBack);
}


int cnt = 0;
int v[8];
void loop() {

   v[0] = analogRead(A2);
   v[1] = analogRead(A3);
   v[2] = analogRead(A4);
   v[3] = analogRead(A5);
   v[4] = analogRead(A6);
   v[5] = analogRead(A7);
   v[6] = analogRead(A8);
   v[7] = analogRead(A9);
  // turn the ledPin on
  Serial.println("2\t3\t4\t5\t6\t7\t8\t9");
    for (int i = 0; i < 8; i++) {
        Serial.print(v[i]);
        Serial.print("\t");
    }
    Serial.println();
    Serial.println();

  if (deviceConnected) {
    std::string data = "";
    for (int i =0 ; i< 8; i++) {
      data += std::to_string(v[i]) + ",";
    }
    pCharacteristic->setValue((uint8_t*)data.c_str(), data.length());
    pCharacteristic->notify();
  }

  if (calibrating) {
    // Update calibration for each sensor channel
    for (int i = 0; i < 8; i++) {
      if (v[i] > calibratedMaxValues[i]) {
        calibratedMaxValues[i] = v[i];
      }
    }

    // Check if 5 seconds have elapsed since calibration started
    if (millis() - calibrationStartTime >= 5000) {
      calibrating = false;
      Serial.println("Calibration Completed. Calibrated max values:");
      for (int i = 0; i < 8; i++) {
        Serial.print("Sensor ");
        Serial.print(i + 2); 
        Serial.print(": ");
        Serial.println(calibratedMaxValues[i]);
      }
      if (deviceConnected) {
        std::string calMessage = "CAL_COMPLETE:";
        for (int i = 0; i < 8; i++) {
          calMessage += std::to_string(calibratedMaxValues[i]);
          if (i < 7) {
            calMessage += ",";
          }
        }
        pCharacteristic->setValue((uint8_t*)calMessage.c_str(), calMessage.length());
        pCharacteristic->notify();
      }
    }
  }
  
  delay(250);
}
