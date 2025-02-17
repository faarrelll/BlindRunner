#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// Pin definitions for HC-SR04
const int trigPin = 5;
const int echoPin = 18;

// Sound speed in cm/uS
#define SOUND_SPEED 0.034

// Inisialisasi sensor
MAX30105 particleSensor;

// Variabel untuk MAX30105
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

// Timer untuk pembacaan detak nadi
unsigned long lastHeartRateRead = 0;
const int HEART_RATE_INTERVAL = 5; // Interval pembacaan detak nadi (ms)

// Timer untuk pembacaan HC-SR04
unsigned long lastDistanceRead = 0;
const int DISTANCE_INTERVAL = 100; // Interval pembacaan jarak (ms)

// Variabel untuk menyimpan data
float latestDistance = 0;
int latestHeartRate = 80;
long irValue = 0;
long duration;

void setup() {
  Serial.begin(115200);
  
  // Inisialisasi pin HC-SR04
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  // Inisialisasi MAX30105
  initMAX30105();
}

void loop() {
  // Membaca jarak dari HC-SR04 sensor dengan interval tertentu
  if (millis() - lastDistanceRead >= DISTANCE_INTERVAL) {
    lastDistanceRead = millis();
    latestDistance = readDistance();
  }

  // Membaca denyut nadi dengan interval tertentu
  if (millis() - lastHeartRateRead >= HEART_RATE_INTERVAL) {
    lastHeartRateRead = millis();
    latestHeartRate = readHeartRate();
  }

  // Menyesuaikan data yang akan dikirim berdasarkan irValue
  float distanceToSend = (irValue > 40000) ? -1 : latestDistance;
  int heartRateToSend = (irValue > 40000) ? latestHeartRate : -1;

  // Mengirimkan data dalam format JSON
  String jsonData = createJSONData(distanceToSend, heartRateToSend);
  Serial.println(irValue);
  Serial.println(jsonData);
}

// Inisialisasi MAX30105
void initMAX30105() {
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST, 87)) {
    Serial.println("MAX30105 not detected. Check wiring!");
    while (1);  // MAX30105 tidak ditemukan, berhenti di sini
  }
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x9F);   // Red LED nyala rendah
  particleSensor.setPulseAmplitudeGreen(0x00); // Green LED mati
}

// Membaca jarak dari sensor HC-SR04
float readDistance() {
  // Clears the trigPin
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  
  // Sets the trigPin on HIGH state for 10 micro seconds
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  // Reads the echoPin, returns the sound wave travel time in microseconds
  duration = pulseIn(echoPin, HIGH);
  
  // Calculate the distance in cm
  return duration * SOUND_SPEED/2;
}

// Membaca detak jantung dari sensor MAX30105
int readHeartRate() {
  irValue = particleSensor.getIR();

  if (checkForBeat(irValue) == true)
  {
    //We sensed a beat!
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 20)
    {
      rates[rateSpot++] = (byte)beatsPerMinute; //Store this reading in the array
      rateSpot %= RATE_SIZE; //Wrap variable

      //Take average of readings
      beatAvg = 0;
      for (byte x = 0 ; x < RATE_SIZE ; x++)
        beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }
  return beatAvg;
}

// Membuat data dalam format JSON
String createJSONData(float distance, int heartRate) {
  return "{\"distance\": " + String(distance) + 
         ", \"heartRate\": " + String(heartRate) + "}";
}
