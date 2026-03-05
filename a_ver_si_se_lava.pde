import java.time.*;

// -  intenta sacar ubicación aproximada por IP sino usa los de SANTA FE vieja y peluda

final float DEFAULT_LAT = -31.6333;
final float DEFAULT_LON = -60.7000;
final String TZ = "America/Argentina/Cordoba";

float LAT = DEFAULT_LAT;
float LON = DEFAULT_LON;

String ubicacionCorta = "SF"; // se pisa si conseguimos ubi

float temp = 0;
float cloud = 0;
float wind = 0;
float precipProb = 0;
float rainMm = 0;

boolean convieneLavar = true;
String conditionText = "cargando";
String promptClima = "";

int lastFetchMs = -999999;
int fetchEveryMs = 60 * 1000;

void setup() {
  size(440, 220, P2D);

  // ventanita pero que no se como sacarle el borde de arriba (mejora)
  int x = displayWidth - 80;
  int y = displayHeight - 90;
  surface.setLocation(x, y);
  surface.setTitle("");  // ← título de la ventana
  surface.setAlwaysOnTop(true);

  smooth(4);
 
  textFont(createFont("Monospaced", 16, true));
 
  tryFetchLocationByIP();

  fetchWeather();
}

void draw() {
  if (millis() - lastFetchMs > fetchEveryMs) fetchWeather();

  float hourNow = getLocalHour();
  float day = getDayFactor(hourNow); // 0 noche, 1 día

  drawCozySky(day, hourNow);
  drawSeaWithWaves(day);
  drawRainIfNeeded();
  drawPanel(day);
}

float getDayFactor(float hourNow) {
  if (hourNow >= 7 && hourNow <= 19) return 1;
  if (hourNow > 6 && hourNow < 7) return map(hourNow, 6, 7, 0, 1);
  if (hourNow > 19 && hourNow < 20) return map(hourNow, 19, 20, 1, 0);
  return 0;
}

void drawCozySky(float day, float hourNow) {
  // gradiente día/noche con cambios segun la nubosidaad
  //  el cielo cambia pero sin usar imagenes en processing 
  
  color dayTop = color(255, 214, 190);
  color dayBottom = color(255, 175, 160);
  color nightTop = color(38, 34, 72);
  color nightBottom = color(82, 72, 120);

  // desatura hacia gris-lila si esta nublado
  color overcastTop = color(185, 170, 185);
  color overcastBottom = color(150, 145, 175);

  color top = lerpColor(nightTop, dayTop, day);
  color bottom = lerpColor(nightBottom, dayBottom, day);
  top = lerpColor(top, overcastTop, cloud * 0.5);
  bottom = lerpColor(bottom, overcastBottom, cloud * 0.5);

  for (int y = 0; y < height; y++) {
    float t = y / float(height);
    stroke(lerpColor(top, bottom, t));
    line(0, y, width, y);
  }

  drawSunMoonGlow(day, hourNow);
  drawNightStars(day);
}

void drawSunMoonGlow(float day, float hourNow) {
  // da sensación de tiempo sin cálculos pesados  
  boolean esDia = day > 0.5;

  float tArc;
  if (esDia) tArc = map(hourNow, 7, 19, 0, 1);
  else {
    float h = hourNow;
    if (h < 7) h += 24;
    tArc = map(h, 19, 31, 0, 1);
  }
  tArc = constrain(tArc, 0, 1);

  float x = lerp(width * 0.1, width * 0.9, tArc);
  float y = lerp(height * 0.65, height * 0.2, 4 * tArc * (1 - tArc));

  color c = esDia ? color(255, 240, 210) : color(220, 235, 255);
  float a = (esDia ? 95 : 60) * (1.0 - cloud * 0.55);

  noStroke();
  fill(red(c), green(c), blue(c), a * 0.35);
  ellipse(x, y, 140, 140);
  fill(red(c), green(c), blue(c), a * 0.55);
  ellipse(x, y, 90, 90);
  fill(red(c), green(c), blue(c), a * 0.95);
  ellipse(x, y, 44, 44);
}

void drawNightStars(float day) {
  if (day > 0.25) return;

  float alpha = map(day, 0.25, 0, 0, 170);
  stroke(255, 255, 235, alpha);
  strokeWeight(2);

  // Estrellas  NO parpadean ni cambian de lugar  
  for (int i = 0; i < 35; i++) {
    float x = (i * 73) % width;
    float y = ((i * 41) % int(height * 0.55));
    point(x, y);
  }

  strokeWeight(1);
}

void drawSeaWithWaves(float day) {
  int yH = int(height * 0.68);

  color seaDay = color(85, 148, 192);
  color seaNight = color(32, 60, 105);
  color sea = lerpColor(seaNight, seaDay, day);

  noStroke();
  fill(sea);
  rect(0, yH, width, height - yH);

  // olas
  float t = frameCount * 0.03;
  drawWaveLayer(yH + 12, 4.5, 0.030, t * 1.1, color(210, 235, 245), 70, day);
  drawWaveLayer(yH + 21, 3.2, 0.024, t * 0.8 + 1.3, color(190, 220, 238), 55, day);
  drawWaveLayer(yH + 32, 2.4, 0.019, t * 0.6 + 2.1, color(170, 205, 228), 40, day);

  // brillito cute
  float shine = lerp(20, 65, day) * (1.0 - cloud * 0.45);
  stroke(255, 235, 210, shine);
  for (int i = 0; i < 8; i++) {
    float yy = yH + 8 + i * 4;
    float dx = sin(t + i) * 8;
    line(40 + dx, yy, width - 40 + dx, yy);
  }
}

void drawWaveLayer(float yBase, float amp, float freq, float phase, color c, float alphaBase, float day) {
  noFill();
  stroke(red(c), green(c), blue(c), alphaBase * lerp(0.55, 1.0, day));
  strokeWeight(2);

  beginShape();
  for (int x = 0; x <= width; x += 8) {
    float y = yBase + sin(x * freq + phase) * amp
                    + sin(x * freq * 0.55 - phase * 0.7) * (amp * 0.5);
    vertex(x, y);
  }
  endShape();
}

void drawRainIfNeeded() {
  if (precipProb < 0.35) return;

  stroke(220, 230, 255, 120);
  int gotas = int(map(precipProb, 0.35, 1.0, 25, 110));
  for (int i = 0; i < gotas; i++) {
    float x = random(width);
    float y = random(height * 0.68);
    line(x, y, x + 3, y + 10);
  }
}

void drawPanel(float day) {
  noStroke();
  fill(255, 250, 245, 20);
  rect(12, 12, width - 24, height - 24, 12);

  stroke(255, 255, 255, 135);
  noFill();
  rect(12, 12, width - 24, height - 24, 12);

  fill(42, 56, 82);
  textSize(20);
  text("Clima: " + conditionText, 24, 38);

  textSize(14);

  // texto ffff
  String tempStr = "Hacen maso " + nf(temp, 0, 1) + "°C.";
  text(tempStr, 24, 62);

  
  float tx = 24 + textWidth(tempStr) + 8;
  fill(42, 56, 82, 150);
  textSize(14);
  text("(" + ubicacionCorta + ")", tx, 62);

  //  
  fill(42, 56, 82);
  textSize(14);

  text("Prob. de lluvias cercanas: " + int(precipProb * 100) + "%", 24, 82);

  text(promptClima, 24, 112, width - 48, 60);

  textSize(20);
  String msg = convieneLavar ? "Sí, conviene lavar." : "No conviene lavar.";

  // el halo ese 
  fill(255, 40);
  text(msg, 25, 183);

  fill(55, 65, 80);
  text(msg, 24, 182);

  // mini barra que muestra cuanto de dia queda ahora mismo 
  noStroke();
  fill(236, 226, 235, 170);
  rect(width - 34, 20, 12, 60, 8);

  fill(120, 145, 200, 200);
  rect(width - 34, 20 + (1 - day) * 60, 12, day * 60, 8);
}

void fetchWeather() {
  lastFetchMs = millis();

  String url =
    "https://api.open-meteo.com/v1/forecast"
    + "?latitude=" + LAT
    + "&longitude=" + LON
    + "&current=temperature_2m,cloud_cover,wind_speed_10m,weather_code"
    + "&hourly=precipitation,precipitation_probability"
    + "&daily=precipitation_sum"
    + "&timezone=" + TZ;

  try {
    JSONObject json = loadJSONObject(url);
    JSONObject current = json.getJSONObject("current");
    JSONObject hourly = json.getJSONObject("hourly");
    JSONObject daily = json.getJSONObject("daily");

    temp = current.getFloat("temperature_2m");
    cloud = constrain(current.getFloat("cloud_cover") / 100.0, 0, 1);
    wind = current.getFloat("wind_speed_10m");
    conditionText = weatherCodeToText(current.getInt("weather_code"));

    JSONArray probs = hourly.getJSONArray("precipitation_probability");
    JSONArray mm = hourly.getJSONArray("precipitation");
    int horas = min(12, probs.size());

    precipProb = 0;
    convieneLavar = true;

    for (int i = 0; i < horas; i++) {
      float p = constrain(probs.getFloat(i) / 100.0, 0, 1);
      precipProb += p;

      // aca esta la regla 
      if (p >= 0.4 || mm.getFloat(i) > 0.1) convieneLavar = false;
    }

    if (horas > 0) precipProb /= horas;

    JSONArray rains = daily.getJSONArray("precipitation_sum");
    if (rains.size() > 0) rainMm = rains.getFloat(0);

    promptClima = buildPrompt();

  } catch (Exception e) {
    conditionText = "sin conexión";
    promptClima = "No pude actualizar el clima.";
  }
}

String buildPrompt() {
  if (rainMm >= 1.0)
    return "Garúa (aquella con su olvido hoy le ha abierto una gotera)";

  if (precipProb >= 0.55)
    return "Posibilidades reales de que caigan soretes de punta";

  if (cloud >= 0.7 && precipProb < 0.4)
    return "Grease (gris largo que promete lluvia pero no concreta)";

  if (cloud >= 0.4)
    return "Rozando lo nuboso";

  return "Bastante despejado.";
}

String weatherCodeToText(int code) {
  if (code == 0) return "despejado";
  if (code <= 3) return "rozando lo nuboso";
  if (code == 45 || code == 48) return "bruma húmeda";
  if (code >= 51 && code <= 67) return "lluvia";
  if (code >= 80 && code <= 99) return "chaparrón";
  return "variable";
}

float getLocalHour() {
  try {
    ZonedDateTime now = ZonedDateTime.now(ZoneId.of(TZ));
    return now.getHour() + now.getMinute() / 60.0;
  } catch (Exception e) {
    return hour() + minute() / 60.0;
  }
}

void tryFetchLocationByIP() {
  try {
    // ipwho.is suele ser fácil de parsear y no requiere API key
    JSONObject j = loadJSONObject("https://ipwho.is/");

    if (j == null) return;
    if (j.hasKey("success") && !j.getBoolean("success")) return;

    float lat = j.getFloat("latitude");
    float lon = j.getFloat("longitude");

    // validación mínima para no pisar con basura
    if (abs(lat) > 0.001 && abs(lon) > 0.001) {
      LAT = lat;
      LON = lon;
    }

    String city = j.isNull("city") ? "" : j.getString("city");
    String region = j.isNull("region") ? "" : j.getString("region");
    String country = j.isNull("country_code") ? "" : j.getString("country_code");

 
    if (city != null && city.length() > 0) ubicacionCorta = city;
    else if (region != null && region.length() > 0) ubicacionCorta = region;
    else if (country != null && country.length() > 0) ubicacionCorta = country;

     
    if (ubicacionCorta.length() > 12) ubicacionCorta = ubicacionCorta.substring(0, 12);

  } catch (Exception e) { 
    LAT = DEFAULT_LAT;
    LON = DEFAULT_LON;
    ubicacionCorta = "SF";
  }
}
