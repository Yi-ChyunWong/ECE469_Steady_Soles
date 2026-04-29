/**
*
* If you have not downloaded the driver required for ESP32 please do so first.
* Add the esp32 by Espressif Systems from Boards Manager and choose
* "Adafruit ESP32 Feather" as your board.
*
**/

const int motor_f = A0;
const int motor_b = A1;

void setup() {
  // declare the ledPin as an OUTPUT:
  pinMode(motor_f, OUTPUT);
  pinMode(motor_b, OUTPUT);
  Serial.begin(921600);
}

void loop() {
  int v_2 = analogRead(A2);
  int v_3 = analogRead(A3);
  int v_4 = analogRead(A4);
  int v_5 = analogRead(A5);
  int v_6 = analogRead(A6);
  int v_7 = analogRead(A7);
  int v_8 = analogRead(A8);
  int v_9 = analogRead(A9);
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

  Serial.print(v_2);
  Serial.print("\t");
  Serial.print(v_3);
  Serial.print("\t");
  Serial.print(v_4);
  Serial.print("\t");
  Serial.print(v_5);
  Serial.print("\t");
  Serial.print(v_6);
  Serial.print("\t");
  Serial.print(v_7);
  Serial.print("\t");
  Serial.print(v_8);
  Serial.print("\t");
  Serial.print(v_9);
  Serial.println();
  Serial.println();
  delay(100);

  digitalWrite(motor_f, HIGH);
  digitalWrite(motor_b, HIGH);
}
