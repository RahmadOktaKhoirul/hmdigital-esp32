/*
 * Machine 1 Hour Meter - ESP32 Firmware (Optimized)
 *
 * MQTT Publish:
 *   factory/machine1/hm/data → {"hm_sec":int,"prev_hm_sec":int,"status":"RUNNING"|"STOPPED"}
 *   factory/machine1/hm/log  → {"event":"BOOT"|"RESET"|"ADJUST","prev_hm_hours":float,"timestamp":"YYYY-MM-DD HH:MM:SS"}
 *
 * MQTT Subscribe:
 *   factory/machine1/cmd/reset   → "RESET"
 *   factory/machine1/cmd/adjust  → "1250.50"
 *   factory/machine1/cmd/speed   → "1000" (ms, 500–2000)
 *
 * Libraries: PubSubClient, ArduinoJson, LiquidCrystal I2C
 */

#include <WiFi.h>
#include <WebServer.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>
#include "time.h"

// ── KONFIGURASI ───────────────────────────────────────────────────────────────
static const char* MQTT_HOST    = "192.168.100.107";
static const int   MQTT_PORT    = 1883;
static const char* AP_SSID      = "ESP32-HM-Setup";
static const char* AP_PASS      = "12345678"; // min 8 karakter
static const char* NTP_SERVER   = "pool.ntp.org";
static const long  GMT_OFFSET   = 25200; // WIB UTC+7
static const int   DST_OFFSET   = 0;
static const int   ENGINE_PIN   = 32;
static const int   RESET_PIN    = 33;

// ── TOPIK (PROGMEM untuk hemat RAM) ──────────────────────────────────────────
static const char TOPIC_DATA[]       PROGMEM = "factory/machine1/hm/data";
static const char TOPIC_LOG[]        PROGMEM = "factory/machine1/hm/log";
static const char TOPIC_CMD_RESET[]  PROGMEM = "factory/machine1/cmd/reset";
static const char TOPIC_CMD_ADJUST[] PROGMEM = "factory/machine1/cmd/adjust";
static const char TOPIC_CMD_SPEED[]  PROGMEM = "factory/machine1/cmd/speed";

// ── NVS ───────────────────────────────────────────────────────────────────────
static const char NVS_NS[]       = "hm_app";
static const char NVS_HM_SEC[]   = "total_sec";
static const char NVS_PREV_SEC[] = "prev_sec";
static const char NVS_TICK_MS[]  = "tick_ms";
static const char NVS_WIFI_NS[]  = "wifi_cfg";
static const char NVS_SSID[]     = "ssid";
static const char NVS_PASS[]     = "pass";

// ── OBJEK GLOBAL ──────────────────────────────────────────────────────────────
WiFiClient        espClient;
PubSubClient      mqttClient(espClient);
LiquidCrystal_I2C lcd(0x27, 20, 4);
Preferences       prefs;
WebServer         portalServer(80);

static bool _apMode = false;

// ── CRITICAL SECTION untuk multi-core ESP32 ───────────────────────────────────
static portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

// ── VARIABEL ISR (akses via critical section) ─────────────────────────────────
volatile bool _engineRunning = false;
volatile bool _flagReset     = false;

// ── VARIABEL SISTEM ───────────────────────────────────────────────────────────
static unsigned long hmSec       = 0;
static unsigned long prevHmSec   = 0;
static unsigned long lastSaveSec = 0;
static unsigned int  tickMs      = 1000;

static unsigned long prevMillis      = 0;
static unsigned long lastPublishMs   = 0;
static unsigned long lastMqttMs      = 0;
static unsigned long lastWifiMs      = 0;
static unsigned long lastLcdMs       = 0;
static unsigned long lcdMsgUntilMs   = 0; // non-blocking LCD message timer

static bool bootLogSent  = false;
static bool isTimeSynced = false;

// ── CUSTOM CHARACTERS ─────────────────────────────────────────────────────────
static byte barTop[8] = {B11111,B11111,B11111,B00000,B00000,B00000,B00000,B00000};
static byte barBot[8] = {B00000,B00000,B00000,B00000,B00000,B00000,B11111,B11111};
static byte barMid[8] = {B11111,B11111,B11111,B00000,B00000,B00000,B11111,B11111};
static byte wifiOn[8]  = {B00000,B01110,B10001,B00100,B01010,B00000,B00100,B00000};
static byte wifiOff[8] = {B00000,B01110,B10101,B01110,B01010,B00100,B01010,B00000};
static byte mqttOn[8]  = {B00000,B01110,B11111,B10101,B11111,B01110,B00000,B00000};
static byte mqttOff[8] = {B00000,B01110,B11011,B10101,B11011,B01110,B00000,B00000};

static const char TOP_SEG[10][3] = { {255,0,255},{0,255,32},{2,2,255},{0,2,255},{255,1,255},{255,2,0},{255,2,0},{0,0,255},{255,2,255},{255,2,255} };
static const char BOT_SEG[10][3] = { {255,1,255},{1,255,1},{255,1,1},{1,1,255},{32,32,255},{1,1,255},{255,1,255},{32,32,255},{255,1,255},{1,1,255} };

// ── ISR ───────────────────────────────────────────────────────────────────────
void IRAM_ATTR engineISR() {
  portENTER_CRITICAL_ISR(&mux);
  _engineRunning = (digitalRead(ENGINE_PIN) == LOW);
  portEXIT_CRITICAL_ISR(&mux);
}

void IRAM_ATTR resetISR() {
  static unsigned long lastT = 0;
  unsigned long t = millis();
  if (t - lastT > 500) {
    portENTER_CRITICAL_ISR(&mux);
    _flagReset = true;
    portEXIT_CRITICAL_ISR(&mux);
    lastT = t;
  }
}

// ── SAFE READ dari ISR variables ──────────────────────────────────────────────
static inline bool engineRunning() {
  portENTER_CRITICAL(&mux);
  bool v = _engineRunning;
  portEXIT_CRITICAL(&mux);
  return v;
}

static inline bool takeFlagReset() {
  portENTER_CRITICAL(&mux);
  bool v = _flagReset;
  if (v) _flagReset = false;
  portEXIT_CRITICAL(&mux);
  return v;
}

// ── LCD HELPERS ───────────────────────────────────────────────────────────────
static void printBigDigit(int digit, int col) {
  lcd.setCursor(col, 1);
  for (int i = 0; i < 3; i++) lcd.write(TOP_SEG[digit][i]);
  lcd.setCursor(col, 2);
  for (int i = 0; i < 3; i++) lcd.write(BOT_SEG[digit][i]);
}

// Use char buf instead of String to avoid heap allocation
static void printBigHM(unsigned long seconds) {
  char text[10];
  dtostrf(seconds / 3600.0, 1, 2, text); // e.g. "1250.25"
  int len = strlen(text);
  int width = 0;
  for (int i = 0; i < len; i++) width += (text[i] == '.') ? 2 : 4;
  int col = (20 - (width - 1)) / 2;
  if (col < 0) col = 0;
  lcd.setCursor(0, 1); lcd.print("                    ");
  lcd.setCursor(0, 2); lcd.print("                    ");
  for (int i = 0; i < len; i++) {
    if (text[i] >= '0' && text[i] <= '9') { printBigDigit(text[i] - '0', col); col += 4; }
    else if (text[i] == '.') { lcd.setCursor(col, 2); lcd.print('.'); col += 2; }
  }
}

// Non-blocking LCD message: sets message and auto-clears after durationMs
static void lcdMsg(const char* line1, const char* line2, unsigned long durationMs) {
  lcd.clear();
  lcd.setCursor(0, 1); lcd.print(line1);
  lcd.setCursor(0, 2); lcd.print(line2);
  lcdMsgUntilMs = millis() + durationMs;
}

// ── NVS ───────────────────────────────────────────────────────────────────────
static void saveToNVS() {
  prefs.begin(NVS_NS, false);
  prefs.putULong(NVS_HM_SEC,   hmSec);
  prefs.putULong(NVS_PREV_SEC, prevHmSec);
  prefs.end();
  lastSaveSec = hmSec;
}

// ── TIMESTAMP (no heap allocation) ───────────────────────────────────────────
static void getTimestamp(char* buf, size_t len) {
  struct tm ti;
  if (getLocalTime(&ti)) {
    strftime(buf, len, "%Y-%m-%d %H:%M:%S", &ti);
  } else {
    unsigned long s = millis() / 1000;
    snprintf(buf, len, "UP+%02lu:%02lu:%02lu", s / 3600, (s % 3600) / 60, s % 60);
  }
}

// ── MQTT PUBLISH (stack-only buffers) ─────────────────────────────────────────
static void publishData() {
  if (!mqttClient.connected()) return;
  char buf[96];
  StaticJsonDocument<96> doc;
  doc["hm_sec"]      = hmSec;
  doc["prev_hm_sec"] = prevHmSec;
  doc["status"]      = engineRunning() ? "RUNNING" : "STOPPED";
  serializeJson(doc, buf, sizeof(buf));
  mqttClient.publish(TOPIC_DATA, buf, true); // retained
}

static void publishLog(const char* event, unsigned long oldSec) {
  if (!mqttClient.connected()) return;
  char ts[25];
  getTimestamp(ts, sizeof(ts));
  char buf[128];
  StaticJsonDocument<128> doc;
  doc["event"]         = event;
  doc["prev_hm_hours"] = oldSec / 3600.0;
  doc["timestamp"]     = ts;
  serializeJson(doc, buf, sizeof(buf));
  mqttClient.publish(TOPIC_LOG, buf);
}

// ── RESET & KALIBRASI (non-blocking LCD) ──────────────────────────────────────
static void resetHourMeter() {
  unsigned long old = hmSec;
  prevHmSec = hmSec;
  hmSec = 0;
  saveToNVS();
  publishLog("RESET", old);
  publishData();
  lcdMsg("    DATA RESET!     ", "", 1500);
  Serial.println("[CMD] RESET");
}

static void calibrateHourMeter(float newHours) {
  unsigned long old = hmSec;
  prevHmSec = hmSec;
  hmSec = (unsigned long)(newHours * 3600.0f);
  saveToNVS();
  publishLog("ADJUST", old);
  publishData();
  char line2[21];
  snprintf(line2, sizeof(line2), "     %.2f H", newHours);
  lcdMsg("  HM ADJUSTED TO:   ", line2, 2000);
  Serial.printf("[CMD] ADJUST → %.2f h\n", newHours);
}

// ── MQTT CALLBACK (no String allocation) ──────────────────────────────────────
static void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Use fixed stack buffer — max expected payload is ~10 chars
  char msg[32];
  unsigned int copyLen = (length < sizeof(msg) - 1) ? length : sizeof(msg) - 1;
  memcpy(msg, payload, copyLen);
  msg[copyLen] = '\0';
  // trim trailing whitespace
  for (int i = copyLen - 1; i >= 0 && (msg[i] == ' ' || msg[i] == '\r' || msg[i] == '\n'); i--) msg[i] = '\0';

  if (strcmp(topic, TOPIC_CMD_RESET) == 0 && strcmp(msg, "RESET") == 0) {
    resetHourMeter();

  } else if (strcmp(topic, TOPIC_CMD_ADJUST) == 0) {
    float v = atof(msg);
    if (v >= 0.0f) calibrateHourMeter(v);

  } else if (strcmp(topic, TOPIC_CMD_SPEED) == 0) {
    int v = atoi(msg);
    if (v >= 500 && v <= 2000) {
      tickMs = (unsigned int)v;
      prefs.begin(NVS_NS, false);
      prefs.putUInt(NVS_TICK_MS, tickMs);
      prefs.end();
      char line2[21];
      snprintf(line2, sizeof(line2), "      %d ms", tickMs);
      lcdMsg(" TICK RATE CHANGED: ", line2, 2000);
      Serial.printf("[CMD] SPEED → %d ms\n", tickMs);
    }
  }
}

// ── WIFI PROVISIONING PORTAL ─────────────────────────────────────────────────
static const char PORTAL_HTML[] PROGMEM = R"(
<!DOCTYPE html><html><head><meta charset='utf-8'>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<title>ESP32 WiFi Setup</title>
<style>body{font-family:sans-serif;max-width:360px;margin:40px auto;padding:16px}
input{width:100%;padding:10px;margin:8px 0;box-sizing:border-box;border:1px solid #ccc;border-radius:6px}
button{width:100%;padding:12px;background:#2196F3;color:#fff;border:none;border-radius:6px;font-size:16px;cursor:pointer}
h2{color:#333}</style></head>
<body><h2>&#x1F4F6; WiFi Setup</h2>
<form method='POST' action='/save'>
<label>SSID</label><input name='ssid' placeholder='Nama WiFi' required>
<label>Password</label><input name='pass' type='password' placeholder='Password WiFi'>
<button type='submit'>Simpan &amp; Konek</button>
</form></body></html>
)";

static void startProvisioningAP() {
  _apMode = true;
  WiFi.disconnect(true);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.printf("[AP] Hotspot: %s  IP: %s\n", AP_SSID, WiFi.softAPIP().toString().c_str());
  lcdMsg(" WIFI SETUP MODE    ", "  192.168.4.1       ", 0); // 0 = permanent

  portalServer.on("/", HTTP_GET, []() {
    portalServer.send_P(200, "text/html", PORTAL_HTML);
  });
  portalServer.on("/save", HTTP_POST, []() {
    String ssid = portalServer.arg("ssid");
    String pass = portalServer.arg("pass");
    if (ssid.length() == 0) {
      portalServer.send(400, "text/plain", "SSID kosong");
      return;
    }
    // Simpan ke NVS
    prefs.begin(NVS_WIFI_NS, false);
    prefs.putString(NVS_SSID, ssid);
    prefs.putString(NVS_PASS, pass);
    prefs.end();
    portalServer.send(200, "text/html",
      "<h2>Tersimpan!</h2><p>ESP32 akan restart dan konek ke <b>" + ssid + "</b></p>");
    Serial.printf("[AP] Saved SSID: %s\n", ssid.c_str());
    delay(1500);
    ESP.restart();
  });
  portalServer.begin();
}

static void connectWiFiFromNVS() {
  prefs.begin(NVS_WIFI_NS, true);
  String ssid = prefs.getString(NVS_SSID, "");
  String pass = prefs.getString(NVS_PASS, "");
  prefs.end();

  if (ssid.length() == 0) {
    Serial.println("[WiFi] No credentials saved, starting AP");
    startProvisioningAP();
    return;
  }

  Serial.printf("[WiFi] Connecting to %s ...\n", ssid.c_str());
  lcdMsg(" CONNECTING WIFI... ", ssid.c_str(), 0);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  unsigned long t = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t < 15000) delay(200);

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] Connected, IP: %s\n", WiFi.localIP().toString().c_str());
    lcdMsgUntilMs = 0;
  } else {
    Serial.println("[WiFi] Failed, starting AP");
    startProvisioningAP();
  }
}

// ── MQTT CONNECT ──────────────────────────────────────────────────────────────
static void connectMQTT() {
  char clientId[24];
  snprintf(clientId, sizeof(clientId), "ESP32_HM_%04X", (unsigned)esp_random() & 0xFFFF);
  if (mqttClient.connect(clientId)) {
    mqttClient.subscribe(TOPIC_CMD_RESET);
    mqttClient.subscribe(TOPIC_CMD_ADJUST);
    mqttClient.subscribe(TOPIC_CMD_SPEED);
    if (!bootLogSent) {
      publishLog("BOOT", hmSec);
      bootLogSent = true;
    }
    publishData();
    Serial.println("[MQTT] Connected");
  } else {
    Serial.printf("[MQTT] Failed rc=%d\n", mqttClient.state());
  }
}

// ── SETUP ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  pinMode(ENGINE_PIN, INPUT_PULLUP);
  pinMode(RESET_PIN,  INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENGINE_PIN), engineISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(RESET_PIN),  resetISR,  FALLING);

  portENTER_CRITICAL(&mux);
  _engineRunning = (digitalRead(ENGINE_PIN) == LOW);
  portEXIT_CRITICAL(&mux);

  lcd.init(); lcd.backlight();
  lcd.createChar(0, barTop); lcd.createChar(1, barBot); lcd.createChar(2, barMid);
  lcd.createChar(3, wifiOn);  lcd.createChar(4, wifiOff);
  lcd.createChar(5, mqttOn);  lcd.createChar(6, mqttOff);

  prefs.begin(NVS_NS, true);
  hmSec    = prefs.getULong(NVS_HM_SEC,   0);
  prevHmSec = prefs.getULong(NVS_PREV_SEC, 0);
  tickMs   = prefs.getUInt(NVS_TICK_MS,   1000);
  prefs.end();
  lastSaveSec = hmSec;
  Serial.printf("[NVS] hm=%.2fh prev=%.2fh tick=%dms\n",
    hmSec / 3600.0, prevHmSec / 3600.0, tickMs);

  connectWiFiFromNVS();
  configTime(GMT_OFFSET, DST_OFFSET, NTP_SERVER);

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(20);
  mqttClient.setSocketTimeout(5);

  unsigned long now = millis();
  prevMillis = lastPublishMs = lastMqttMs = lastWifiMs = lastLcdMs = now;
}

// ── LOOP ──────────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // 1. RESET FLAG
  if (takeFlagReset()) resetHourMeter();

  // 2. AP PORTAL / WIFI RECONNECT
  if (_apMode) {
    portalServer.handleClient();
    return;
  }
  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastWifiMs > 15000) {
      lastWifiMs = now;
      WiFi.disconnect();
      WiFi.reconnect();
      // Jika masih gagal setelah 3 menit, masuk AP mode
      static unsigned long firstFailMs = 0;
      if (firstFailMs == 0) firstFailMs = now;
      if (now - firstFailMs > 180000) { firstFailMs = 0; startProvisioningAP(); }
    }
  } else {
    // 3. MQTT RECONNECT (non-blocking)
    if (!mqttClient.connected()) {
      if (now - lastMqttMs > 5000) {
        lastMqttMs = now;
        connectMQTT();
      }
    } else {
      mqttClient.loop();
    }
  }

  // 4. HM TICK
  bool running = engineRunning();
  if (running && (now - prevMillis >= tickMs)) {
    prevMillis += tickMs;
    prevHmSec = hmSec;
    hmSec++;
    if (hmSec - lastSaveSec >= 300) {
      saveToNVS();
      Serial.printf("[NVS] Saved %.2fh\n", hmSec / 3600.0);
    }
  } else if (!running) {
    prevMillis = now;
  }

  // 5. PUBLISH (every 5s)
  if (now - lastPublishMs >= 5000 && mqttClient.connected()) {
    lastPublishMs = now;
    publishData();
  }

  // 6. LCD UPDATE (every 1s, skip if showing temp message)
  if (now - lastLcdMs >= 1000) {
    lastLcdMs = now;

    if (now < lcdMsgUntilMs) return; // temp message still showing
    if (now >= lcdMsgUntilMs && lcdMsgUntilMs != 0) {
      lcdMsgUntilMs = 0;
      lcd.clear(); // clear temp message
    }

    // Row 0: WiFi + MQTT icons + time
    lcd.setCursor(0, 0);
    lcd.write((uint8_t)(WiFi.status() == WL_CONNECTED ? 3 : 4));
    lcd.setCursor(1, 0);
    lcd.write((uint8_t)(mqttClient.connected() ? 5 : 6));

    struct tm ti;
    isTimeSynced = getLocalTime(&ti);
    lcd.setCursor(2, 0);
    if (isTimeSynced) {
      char ts[20];
      strftime(ts, sizeof(ts), "          %H:%M:%S", &ti);
      lcd.print(ts);
    } else {
      lcd.print("  SYNC TIME...    ");
    }

    // Row 1–2: big HM digits
    printBigHM(hmSec);

    // Row 3: engine status
    lcd.setCursor(0, 3);
    lcd.print(running ? "    [>] RUNNING     " : "    [ ] STOPPED     ");
  }
}
