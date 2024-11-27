
// Dummy data variables
float dummyDistance = 2.5;  // Jarak dalam meter
int dummyHeartRate = 72;    // Detak jantung dalam bpm

void setup() {
    Serial.begin(115200); // Inisialisasi komunikasi serial
    delay(2000); // Tunggu agar serial dapat terhubung
}

void loop() {
    // Kirim data dummy sebagai JSON
    String data = createDummyData();
    Serial.println(data); // Mengirimkan data ke serial
    delay(1000); // Kirim data setiap 5 detik
}

// Fungsi untuk membuat data dummy dalam format JSON
String createDummyData() {
    String data = "{\"distance\": " + String(dummyDistance, 2) +
                  ", \"heartRate\": " + String(dummyHeartRate) + "}";

    // Ubah data dummy untuk pengiriman berikutnya
    dummyDistance += 0.1;  // Meningkatkan jarak setiap kali
    dummyHeartRate = random(60, 100);  // Ubah detak jantung secara acak

    return data;
}
