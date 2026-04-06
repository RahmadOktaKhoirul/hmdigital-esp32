#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>
#include "time.h"

// ================= KONFIGURASI JARINGAN & MQTT =================
const char* ssid        = "Digital Innovation Guest";
const char* password    = "greatgiantfoods";
const char* mqtt_server = "192.168.100.107";
const int   mqtt_port   = 1883;

// ================= KONFIGURASI WAKTU (NTP) =================
const char* ntpServer       = "pool.ntp.org";
const long  gmtOffset_sec   = 25200; // WIB (UTC+7)
const int   daylightOffset_sec = 0;

// ================= TOPIK MQTT =================
const char* topic_data       = "factory/machine1/hm/data";
const char* topic_log        = "factory/machine1/hm/log";
const char* topic_reset_cmd  = "factory/machine1/cmd/reset";
const char* topic_adjust_cmd = "factory/machine1/cmd/adjust";
const char* topic_speed_cmd  = "factory/machine1/cmd/speed";

// ================= KONFIGURASI PIN =================
const int ENGINE_PIN = 32;
const int RESET_PIN  = 33;

// ================= OBJEK GLOBAL =================
WiFiClient        espClient;
PubSubClient      client(espClient);
LiquidCrystal_I2C lcd(0x27, 20, 4);
Preferences       preferences;

// ================= VARIABEL VOLATILE (ISR) =================
volatile bool isEngineRunning = false;
volatile bool flagResetButton = false;

// ================= VARIABEL SISTEM =================
unsigned long hm_seconds      = 0;
// prev_hm_seconds = nilai HM terakhir sebelum reset/adjust (bukan detik sebelumnya)
unsigned long prev_hm_seconds = 0;
unsigned long last_save_seconds = 0;
unsigned int  hm_interval_ms  = 1000;
unsigned long previousMillis  = 0;
unsigned long lastPublishMillis = 0;
unsigned long lastMqttAttempt = 0;
unsigned long lastWifiAttempt = 0;
bool isTimeSynced  = false;
bool bootLogSent   = false;       // [FIX] kirim BOOT log sekali saat pertama connect
bool prevEngineState = false;     // [FIX] deteksi transisi RUNNING→STOPPED untuk save NVS

// ================= CUSTOM CHARACTERS =================
byte barTop[8] = {B11111,B11111,B11111,B00000,B00000,B00000,B00000,B00000};
byte barBot[8] = {B00000,B00000,B00000,B00000,B00000,B00000,B11111,B11111};
byte barMid[8] = {B11111,B11111,B11111,B00000,B00000,B00000,B11111,B11111};
byte wifiOn[8]  = {B00000,B01110,B10001,B00100,B01010,B00000,B00100,B00000};
byte wifiOff[8] = {B00000,B01110,B10101,B01110,B01010,B00100,B01010,B00000};
byte mqttOn[8]  = {B00000,B01110,B11111,B10101,B11111,B01110,B00000,B00000};
byte mqttOff[8] = {B00000,B01110,B11011,B10101,B11011,B01110,B00000,B00000};
byte engRun[8]  = {B00000,B01000,B01100,B01110,B01100,B01000,B00000,B00000};

const char top_seg[10][3] = { {255,0,255},{0,255,32},{2,2,255},{0,2,255},{255,1,255},{255,2,0},{255,2,0},{0,0,255},{255,2,255},{255,2,255} };
const char bot_seg[10][3] = { {255,1,255},{1,255,1},{255,1,1},{1,1,255},{32,32,255},{1,1,255},{255,1,255},{32,32,255},{255,1,255},{1,1,255} };

// ================= ISR =================
void IRAM_ATTR engineISR() {
  isEngineRunning = (digitalRead(ENGINE_PIN) == LOW);
}

void IRAM_ATTR resetISR() {
  static unsigned long lastInterruptTime = 0;
  unsigned long interruptTime = millis();
  if (interruptTime - lastInterruptTime > 500) {
    flagResetButton = true;
    lastInterruptTime = interruptTime;
  }
}

// ================= LCD HELPERS =================
void printBigDigit(int digit, int col) {
  lcd.setCursor(col, 1);
  for (int i = 0; i < 3; i++) lcd.write(top_seg[digit][i]);
  lcd.setCursor(col, 2);
  for (int i = 0; i < 3; i++) lcd.write(bot_seg[digit][i]);
}

void printBigHM(String text) {
  int width = 0;
  for (int i = 0; i < text.length(); i++) width += (text[i] == '.') ? 2 : 4;
  int col = (20 - (width - 1)) / 2;
  if (col < 0) col = 0;
  lcd.setCursor(0, 1); lcd.print("                    ");
  lcd.setCursor(0, 2); lcd.print("                    ");
  for (int i = 0; i < text.length(); i++) {
    if (text[i] >= '0' && text[i] <= '9') { printBigDigit(text[i] - '0', col); col += 4; }
    else if (text[i] == '.') { lcd.setCursor(col, 2); lcd.print("."); col += 2; }
  }
}

// ================= NVS SAVE =================
void saveToNVS() {
  preferences.putULong("total_sec",  hm_seconds);
  preferences.putULong("prev_sec",   prev_hm_seconds); // [FIX] simpan prev_hm_sec
  last_save_seconds = hm_seconds;
}

// ================= TIMESTAMP =================
void getTimestamp(char* buf, size_t len) {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    strftime(buf, len, "%Y-%m-%d %H:%M:%S", &timeinfo);
  } else {
    unsigned long s = millis() / 1000;
    snprintf(buf, len, "UP+%02lu:%02lu:%02lu", s / 3600, (s % 3600) / 60, s % 60);
  }
}

// ================= MQTT PUBLISH =================
void publishData() {
  if (!client.connected()) return;
  char buf[96];
  // [FIX] tambah prev_hm_sec agar Flutter bisa tampilkan prevHmHours
  snprintf(buf, sizeof(buf),
    "{\"hm_sec\":%lu,\"prev_hm_sec\":%lu,\"status\":\"%s\"}",
    hm_seconds, prev_hm_seconds,
    isEngineRunning ? "RUNNING" : "STOPPED"
  );
  client.publish(topic_data, buf, true); // retained agar Flutter langsung dapat data saat connect
}

void publishLog(const char* eventType, unsigned long oldSec) {
  if (!client.connected()) return;
  char ts[25];
  getTimestamp(ts, sizeof(ts));
  char buf[128];
  // [FIX] event name "ADJUST" sesuai yang diexpect Flutter (bukan "CALIBRATION")
  snprintf(buf, sizeof(buf),
    "{\"event\":\"%s\",\"prev_hm_hours\":%.2f,\"timestamp\":\"%s\"}",
    eventType, oldSec / 3600.0, ts
  );
  client.publish(topic_log, buf);
}

// ================= RESET & KALIBRASI =================
void resetHourMeter() {
  unsigned long old = hm_seconds;
  prev_hm_seconds = hm_seconds; // simpan nilai sebelum reset
  hm_seconds = 0;
  saveToNVS();
  publishLog("RESET", old);
  publishData();
  lcd.clear();
  lcd.setCursor(4, 1); lcd.print("DATA RESET!");
  delay(1500);
  lcd.clear();
}

void calibrateHourMeter(float newHours) {
  unsigned long old = hm_seconds;
  prev_hm_seconds = hm_seconds; // simpan nilai sebelum adjust
  hm_seconds = (unsigned long)(newHours * 3600.0);
  saveToNVS();
  publishLog("ADJUST", old);
  publishData();
  lcd.clear();
  lcd.setCursor(3, 1); lcd.print("HM ADJUSTED TO:");
  lcd.setCursor(6, 2); lcd.print(String(newHours, 2) + " H");
  delay(2000);
  lcd.clear();
}

// ================= MQTT CALLBACK =================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (unsigned int i = 0; i < length; i++) message += (char)payload[i];
  message.trim();

  if (String(topic) == topic_reset_cmd && message == "RESET") {
    resetHourMeter();
  } else if (String(topic) == topic_adjust_cmd) {
    float newVal = message.toFloat();
    if (newVal >= 0) calibrateHourMeter(newVal);
  } else if (String(topic) == topic_speed_cmd) {
    int newInterval = message.toInt();
    if (newInterval >= 500 && newInterval <= 2000) {
      hm_interval_ms = newInterval;
      preferences.putUInt("tick_ms", hm_interval_ms);
      lcd.clear();
      lcd.setCursor(1, 1); lcd.print("TICK RATE CHANGED:");
      lcd.setCursor(6, 2); lcd.print(String(hm_interval_ms) + " ms");
      delay(2000);
      lcd.clear();
    }
  }
}

// ================= MQTT CONNECT =================
void connectMQTT() {
  String clientId = "ESP32_HM_" + String(random(0xffff), HEX);
  if (client.connect(clientId.c_str())) {
    client.subscribe(topic_reset_cmd);
    client.subscribe(topic_adjust_cmd);
    client.subscribe(topic_speed_cmd);
    // [FIX] kirim BOOT log sekali saat pertama connect
    if (!bootLogSent) {
      publishLog("BOOT", hm_seconds);
      bootLogSent = true;
    }
    publishData(); // kirim data langsung saat connect
    Serial.println("[MQTT] Connected");
  } else {
    Serial.printf("[MQTT] Failed rc=%d\n", client.state());
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  pinMode(ENGINE_PIN, INPUT_PULLUP);
  pinMode(RESET_PIN,  INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENGINE_PIN), engineISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(RESET_PIN),  resetISR,  FALLING);

  isEngineRunning  = (digitalRead(ENGINE_PIN) == LOW);
  prevEngineState  = isEngineRunning;

  lcd.init(); lcd.backlight();
  lcd.createChar(0, barTop); lcd.createChar(1, barBot); lcd.createChar(2, barMid);
  lcd.createChar(3, wifiOn);  lcd.createChar(4, wifiOff);
  lcd.createChar(5, mqttOn);  lcd.createChar(6, mqttOff);
  lcd.createChar(7, engRun);

  preferences.begin("hm_app", false);
  hm_seconds      = preferences.getULong("total_sec", 0);
  prev_hm_seconds = preferences.getULong("prev_sec",  0); // [FIX] load prev_hm_sec
  hm_interval_ms  = preferences.getUInt("tick_ms",    1000);
  last_save_seconds = hm_seconds;

  Serial.printf("[NVS] hm=%.2fh prev=%.2fh tick=%dms\n",
    hm_seconds / 3600.0, prev_hm_seconds / 3600.0, hm_interval_ms);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
  client.setKeepAlive(20);
}

// ================= LOOP =================
void loop() {
  unsigned long currentMillis = millis();

  // 1. CEK BENDERA RESET
  if (flagResetButton) {
    flagResetButton = false;
    resetHourMeter();
  }

  // 2. WIFI & MQTT RECONNECT
  if (WiFi.status() != WL_CONNECTED) {
    if (currentMillis - lastWifiAttempt > 10000) {
      lastWifiAttempt = currentMillis;
      WiFi.disconnect();
      WiFi.reconnect();
    }
  } else {
    if (!client.connected()) {
      if (currentMillis - lastMqttAttempt > 5000) {
        lastMqttAttempt = currentMillis;
        connectMQTT();
      }
    } else {
      client.loop();
    }
  }

  // 3. HOUR METER TICK
  bool currentEngine = isEngineRunning;

  // [FIX] save NVS saat engine berhenti (RUNNING → STOPPED) agar data tidak hilang
  if (prevEngineState && !currentEngine) {
    saveToNVS();
    Serial.printf("[NVS] Saved on stop: %.2fh\n", hm_seconds / 3600.0);
  }
  prevEngineState = currentEngine;

  if (currentEngine && (currentMillis - previousMillis >= hm_interval_ms)) {
    previousMillis += hm_interval_ms;
    hm_seconds++;
    // periodic save setiap 300 detik sebagai backup
    if (hm_seconds - last_save_seconds >= 300) {
      saveToNVS();
      Serial.printf("[NVS] Saved periodic: %.2fh\n", hm_seconds / 3600.0);
    }
  } else if (!currentEngine) {
    previousMillis = currentMillis;
  }

  // 4. PUBLISH DATA (setiap 1 detik)
  if (currentMillis - lastPublishMillis >= 1000 && client.connected()) {
    lastPublishMillis = currentMillis;
    publishData();
  }

  // 5. UPDATE LCD (setiap 1 detik)
  static unsigned long lastLcdUpdate = 0;
  if (currentMillis - lastLcdUpdate >= 1000) {
    lastLcdUpdate = currentMillis;

    lcd.setCursor(0, 0);
    lcd.write((uint8_t)(WiFi.status() == WL_CONNECTED ? 3 : 4));
    lcd.setCursor(1, 0);
    lcd.write((uint8_t)(client.connected() ? 5 : 6));

    struct tm timeinfo;
    isTimeSynced = getLocalTime(&timeinfo);
    lcd.setCursor(2, 0);
    if (isTimeSynced) {
      char timeStr[20];
      strftime(timeStr, sizeof(timeStr), "          %H:%M:%S", &timeinfo);
      lcd.print(timeStr);
    } else {
      lcd.print("  SYNC TIME...    ");
    }

    printBigHM(String(hm_seconds / 3600.0, 2));

    lcd.setCursor(0, 3);
    lcd.print(currentEngine ? "    [>] RUNNING     " : "    [ ] STOPPED     ");
  }
}
