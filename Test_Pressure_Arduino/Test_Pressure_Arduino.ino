/**
*
* If you have not downloaded the driver required for ESP32 please do so first.
* Add the esp32 by Espressif Systems from Boards Manager and choose
* "Adafruit ESP32 Feather" as your board.
*
**/


#include <string.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define VBATPIN A13

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

int v[8];
const int motorFront = A0;
const int motorBack = A1;
bool motorTestActive = false;

BLECharacteristic *pCharacteristic;
BLEServer *pServer;
bool deviceConnected = false;

bool calibrating = false, calibrated = false;
unsigned long calibrationStartTime = 0;
int calibratedMaxValues[8] = {0};
int calibratedMinValues[8] = {4095};
int frontThreshold = 0, backThreshold = 0;

const int historySize = 5;
int pressureHistory[historySize] = {0};
int historyIndex = 0;
bool isStationary = false;


void turnMotorOn(int motor) {
  digitalWrite(motor, HIGH);
}

void turnMotorOff(int motor) {
  digitalWrite(motor, LOW);
}

void readSensors() {
  v[0] = analogRead(A2);
  v[1] = analogRead(A3);
  v[2] = analogRead(A4);
  v[3] = analogRead(A5);
  v[4] = analogRead(A6);
  v[5] = analogRead(A7);
  v[6] = analogRead(A8);
  v[7] = analogRead(A9);

  Serial.println("2\t3\t4\t5\t6\t7\t8\t9");
    for (int i = 0; i < 8; i++) {
        Serial.print(v[i]);
        Serial.print("\t");
    }
    Serial.println();
    Serial.println();
}

int calculateTotalPressure() {
  int total = 0;
  for (int i = 0; i < 8; i++) total += v[i];
  return total;
}

bool checkStationary() {
  int minP = pressureHistory[0], maxP = pressureHistory[0];
  for (int i = 1; i < historySize; i++) {
    if (pressureHistory[i] < minP) minP = pressureHistory[i];
    if (pressureHistory[i] > maxP) maxP = pressureHistory[i];
  }
  return (maxP - minP < 100);
}

void updatePressureHistory(int totalPressure) {
  pressureHistory[historyIndex] = totalPressure;
  historyIndex = (historyIndex + 1) % historySize;
  isStationary = checkStationary();
}

void sendStringBLE(std::string str) {
  pCharacteristic->setValue((uint8_t *)str.c_str(), str.length());
  pCharacteristic->notify();
}

void updateCalibration() {
  for (int i = 0; i < 8; i++) {
    if (v[i] > calibratedMaxValues[i]) calibratedMaxValues[i] = v[i];
    if (v[i] < calibratedMinValues[i]) calibratedMinValues[i] = v[i];
  }

  if (millis() - calibrationStartTime >= 5000) {
    calibrating = false;
    calibrated  = true;

    Serial.println("Calibration done:");
    for (int i = 0; i < 8; i++) {
      Serial.print("Sensor "); Serial.print(i); Serial.print(": Max = ");
      Serial.print(calibratedMaxValues[i]);
      Serial.print(", Min = "); Serial.println(calibratedMinValues[i]);
    }
  }

  // TODO: send calibrated values to app
}

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = std::string(pCharacteristic->getValue().c_str());
        Serial.print("RECEIVED: ");
        Serial.println(value.c_str());

        if (value == "FRONT") {
            Serial.println("FRONT Motor ON");
            turnMotorOn(motorFront);
            turnMotorOff(motorBack);
            motorTestActive = true;
        } else if (value == "BACK") {
            Serial.println("BACK Motor ON");
            turnMotorOn(motorBack);
            turnMotorOff(motorFront);
            motorTestActive = true;
        } else if (value == "OFF") {
            Serial.println("Motor OFF");
            turnMotorOff(motorFront);
            turnMotorOff(motorBack);
            motorTestActive = false;
        } else if (value == "CALIBRATE") {
          Serial.println("Calibrating!");
          calibrating = true;
          calibrated = false;
          calibrationStartTime = millis();
          for (int i = 0; i < 8; i++) {
            calibratedMaxValues[i] = 0;
          }
        } else if (value.find("SENSITIVITY") == 0) {
          // Split by commas
          int index1 = value.find(",");
          int index2 = value.find(",", index1 + 1);
          
          if (index1 != std::string::npos && index2 != std::string::npos) {
              std::string type = value.substr(index1 + 1, index2 - index1 - 1);
              std::string valStr = value.substr(index2 + 1);                    

              float val = atoi(valStr.c_str());

              if (type == "FORWARD") {
                  frontThreshold = val;
                  Serial.printf("🔧 Forward threshold set to %d\n", frontThreshold);
              } else if (type == "BACKWARD") {
                  backThreshold = val;
                  Serial.printf("🔧 Backward threshold set to %d\n", backThreshold);
              } 
          }
          return;
        }

        else {
            Serial.println("Invalid Command");
        }

    }
};

void detectLean() {
  // if (!isStationary) {
  //   Serial.println("NOT STATIONARY");
  //   return;
  // }

  if (calculateTotalPressure() < 1000) {
    turnMotorOff(motorFront);
    turnMotorOff(motorBack);
  }

  float heelPressure = (v[0] + v[1]) / 2.0;
  float toePressure = (v[2] + v[4] + v[6]) / 3.0;
  float leanRatio = toePressure / (heelPressure + toePressure + 1e-5);

  float frontMultiplier = 1.15 + (0.2 * frontThreshold / 50.0);
  float backMultiplier = 1.15 + (0.2 * backThreshold / 50.0);

  bool toePressed = (v[2] > calibratedMaxValues[2] * frontMultiplier) ||
                    (v[4] > calibratedMaxValues[4] * frontMultiplier) ||
                    (v[6] > calibratedMaxValues[6] * frontMultiplier);
  bool heelDropped = (v[0] < calibratedMaxValues[0] * 0.4) &&
                     (v[1] < calibratedMaxValues[1] * 0.4);

  bool heelPressed = (v[0] > calibratedMaxValues[0] * backMultiplier) &&
                     (v[1] > calibratedMaxValues[1] * backMultiplier);
  bool toeDropped = (v[2] <= calibratedMaxValues[2] * 0.5) &&
                    (v[4] <= calibratedMaxValues[4] * 0.5) &&
                    (v[6] <= calibratedMaxValues[6] * 0.5);

  if ((toePressed && heelDropped)) {
    Serial.println("Leaning Forward !!!");
    turnMotorOn(motorFront);
    turnMotorOff(motorBack);

    sendStringBLE("Leaning Forward");
  } else if ((heelPressed && toeDropped)) {
    Serial.println("Leaning Backward !!!");
    turnMotorOn(motorBack);
    turnMotorOff(motorFront);

    sendStringBLE("Leaning Backward");
  } else {
    turnMotorOff(motorFront);
    turnMotorOff(motorBack);
  }
}

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

}

void checkBattery () {
  float measuredvbat = analogRead(VBATPIN);
  measuredvbat = (measuredvbat * 2 * 3.3) / 4096;  // voltage calculation

  char batteryMessage[32];
  snprintf(batteryMessage, sizeof(batteryMessage), "Batterylevel %.2f", measuredvbat);

  sendStringBLE(batteryMessage);  // Send formatted string over BLE
  Serial.printf("VBat: %.1f V\n", measuredvbat);  // Print to serial for debug
}

void loop() {
  readSensors();
  if (deviceConnected) checkBattery();

  std::string sensorData = "";
  for (int i = 0; i < 8; i++) {
    sensorData += std::to_string(v[i]) + ",";
  }

  if (deviceConnected) sendStringBLE(sensorData);

  if (calibrating) updateCalibration();
  
  if (calibrated && !motorTestActive) detectLean();

  delay(250);
}
