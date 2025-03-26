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

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value = std::string(pCharacteristic->getValue().c_str());

        if (value == "ON") {
            Serial.println("Motor ON");
        } else if (value == "OFF") {
            Serial.println("Motor OFF");
        }
    }
};

const int motor_f = A0;
const int motor_b = A1;

void setup() {
  // declare the ledPin as an OUTPUT:
  pinMode(motor_f, OUTPUT);
  pinMode(motor_b, OUTPUT);
  Serial.begin(921600);

    BLEDevice::init("ESP32 Motor Controller");
    BLEServer *pServer = BLEDevice::createServer();
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

void loop() {
  int v[8];
   v[0] = analogRead(A2);
   v[1] = analogRead(A3);
   v[2] = analogRead(A4);
   v[3] = analogRead(A5);
   v[4] = analogRead(A6);
   v[5] = analogRead(A7);
   v[6] = analogRead(A8);
   v[7] = analogRead(A9);
  // turn the ledPin on
  Serial.print("2");
  Serial.print("\t");
  Serial.print("3");
  Serial.print("\t");
  Serial.print("4");
  Serial.print("\t");
  Serial.print("5");
  Serial.print("\t");
  Serial.print("6");
  Serial.print("\t");
  Serial.print("7");
  Serial.print("\t");
  Serial.print("8");
  Serial.print("\t");
  Serial.print("9");
  Serial.println();

  Serial.print(v[0]);
  Serial.print("\t");
  Serial.print(v[1]);
  Serial.print("\t");
  Serial.print(v[2]);
  Serial.print("\t");
  Serial.print(v[3]);
  Serial.print("\t");
  Serial.print(v[4]);
  Serial.print("\t");
  Serial.print(v[5]);
  Serial.print("\t");
  Serial.print(v[6]);
  Serial.print("\t");
  Serial.print(v[7]);
  Serial.println();
  Serial.println();

  std::string data = "";
  for (int i =0 ; i< 8; i++) {
    data += std::to_string(v[i]) + ",";
  }
  // std::string data = std::to_string(v_2) + "\n";
  pCharacteristic->setValue((uint8_t*)data.c_str(), data.length());
  pCharacteristic->notify();

  delay(250);
}
