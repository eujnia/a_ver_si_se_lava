import java.time.*;
import java.time.format.*;

// UI / Paleta


// Color del panel tipo vidrio (RGBA: alpha 185 lo hace semitransparente)
color UI_PANEL      = color(245, 248, 255, 185);

// Borde suave del panel (más transparente todavía)
color UI_PANEL_EDGE = color(255, 255, 255, 120);

// Color principal de texto (azul grisáceo)
color UI_TEXT       = color(35, 45, 70);

// Color secundario de texto (más apagado)
color UI_MUTED      = color(90, 105, 135);

// Acento positivo (cuando conviene lavar)
color UI_ACCENT_OK  = color(90, 155, 125);

// Acento negativo (cuando no conviene lavar)
color UI_ACCENT_BAD = color(175, 110, 120);

// Fuentes para UI (normal y bold)
PFont fontUI;
PFont fontUIBold;

// Padding base para márgenes internos en paneles
int PAD = 12;

// Resultado final de la lógica de decisión
boolean convieneLavar = true;

// Texto corto tipo prompt para el panel de nota
String promptClima = "";


// Config clima


// Coordenadas para la consulta a Open-Meteo
float LAT = -31.6333;
float LON = -60.7000;

// Zona horaria para que Open-Meteo devuelva series alineadas a tu hora local
String TZ = "America/Argentina/Cordoba";


// -----------------------------------------------------------------------------
// Geo por IP (sin permisos del navegador, funciona en PC normal)
// Usa ip-api.com (simple) y cae a tu LAT/LON fija si falla.
// -----------------------------------------------------------------------------
boolean usarGeoIp = true;

void actualizarUbicacionDesdeIP() {
  if (!usarGeoIp) return;

  try {
    // Devuelve JSON con lat/lon y timezone por IP
    // Ejemplo: { "lat":..., "lon":..., "timezone":"America/Argentina/Cordoba", ...}
    JSONObject geo = loadJSONObject("http://ip-api.com/json/?fields=status,message,lat,lon,timezone,city,country");

    String status = geo.getString("status");
    if (!status.equals("success")) {
      // Si falla, no tocamos nada
      println("GeoIP fallo: " + geo.getString("message"));
      return;
    }

    // Setea coordenadas y timezone globales
    LAT = geo.getFloat("lat");
    LON = geo.getFloat("lon");

    // Timezone en formato IANA (justo lo que vos necesitás)
    TZ = geo.getString("timezone");

    println("GeoIP ok -> " + geo.getString("city") + ", " + geo.getString("country") +
            " | LAT=" + LAT + " LON=" + LON + " TZ=" + TZ);

  } catch (Exception e) {
    // Si no hay internet o el endpoint no responde, seguimos con valores default
    println("GeoIP exception: " + e);
  }
}
// Estado del clima (se actualiza cada tanto)


// Nubosidad como factor 0..1
float cloud = 0.5;

// Probabilidad de precipitación promedio 0..1 en próximas 12 horas
float precipProb = 0.0;

// Viento en km/h (Open-Meteo suele devolver km/h para wind_speed_10m)
float wind = 3.0;

// Temperatura actual en °C
float temp = 20.0;

// Mínima y máxima del día (°C)
float tMin = 0, tMax = 0;

// Precipitación diaria acumulada del día (mm)
float rainMm = 0;

// Código de clima Open-Meteo/WMO para mapear a texto humano
int weatherCode = -1;

// Texto humano mostrado en el HUD
String conditionText = "cargando...";

// Control de cuándo fue la última consulta y cada cuánto consultar
int lastFetchMs = -999999;
int fetchEveryMs = 60 * 1000; // 1 minuto


// Lluvia


// Array de partículas de lluvia
RainDrop[] drops;

// Máximo de gotas instanciadas (tope)
int maxDrops = 700;

// Contador de horas con lluvia (ojo: se incrementa, pero no se resetea en cada fetch)
int horasConLluvia = 0;


// Optimización cielo (niebla cacheada)


// Capa offscreen para dibujar la niebla una vez y reusarla
PGraphics fogLayer;

// Valores cacheados para decidir si hay que reconstruir la niebla
float fogCloudCached = -999;
float fogDayCached   = -999;

// Cantidad máxima de puntos de niebla cuando está muy nublado
int fogMax = 1200;

// Altura relativa donde se dibuja la niebla (0.85 = 85% superior)
float fogHeightFactor = 0.85;


// Control de dibujo


// Dibuja viento cada N frames para ahorrar CPU
int windStride = 2;


// setup: corre una vez al iniciar
void setup() {
  size(440, 220, P2D);
  pixelDensity(1);
  smooth(4);

  fontUI = createFont("Monospaced", 24, true);
  fontUIBold = createFont("Monospaced", 24, true);
  if (fontUIBold == null) fontUIBold = fontUI;

  textFont(fontUI);
  textLeading(18);

  drops = new RainDrop[maxDrops];
  for (int i = 0; i < drops.length; i++) drops[i] = new RainDrop();

  fogLayer = createGraphics(width, height, P2D);

  // NUEVO: primero ubicacion por IP
  actualizarUbicacionDesdeIP();

  // Luego clima ya con LAT/LON/TZ correctos
  fetchWeather();
  promptClima = construirPromptClima();
}

// draw: corre cada frame

void draw() {
  // Si pasó el intervalo, vuelve a pedir clima
  if (millis() - lastFetchMs > fetchEveryMs) fetchWeather();

  // Calcular hora local como float (ej 13.5 = 13:30)
  float hourNow = localHourFloat();

  // Factor día/noche 0..1 (1 = día, 0 = noche)
  float dayNow  = daylightFactor(hourNow);

  // Dibuja cielo según hora, día/noche y nubosidad
  drawSky(hourNow, dayNow, cloud);

  // Dibuja suelo/agua según día/noche (y usa cloud dentro)
  drawGround(dayNow);

  // Dibuja viento cada windStride frames (ahorra trabajo)
  if (frameCount % windStride == 0) {
    drawWind(wind, cloud, dayNow);
  }

  // Determina cuántas gotas activar según probabilidad de lluvia
  int activeDrops = int(map(constrain(precipProb, 0, 1), 0, 1, 0, maxDrops));

  // Ajuste adaptativo: si baja el framerate, reduce gotas activas
  if (frameRate < 45) activeDrops = int(activeDrops * 0.6);
  if (frameRate < 30) activeDrops = int(activeDrops * 0.4);

  // Actualiza y dibuja solo las gotas activas
  for (int i = 0; i < activeDrops; i++) {
    drops[i].update(wind);
    drops[i].display();
  }

  // Dibuja HUD superior con datos de clima
  drawHud(hourNow);

  // Dibuja panel inferior con prompt y recomendación de lavar
  drawNotePanel();
}


// Viento: líneas diagonales que simulan ráfagas

void drawWind(float windMag, float cloud, float day) {
  // Cantidad de líneas de viento según magnitud del viento (0..40 km/h)
  int n = int(map(constrain(windMag, 0, 40), 0, 40, 20, 120));

  // Ángulo de las líneas de viento (negativo = inclinación hacia arriba a la derecha)
  float angle = radians(-25);

  // Vector unitario en la dirección del viento
  float dx = cos(angle);
  float dy = sin(angle);

  // Color del viento de día y de noche
  color windDay = color(240, 248, 255);
  color windNight = color(190, 215, 255);

  // Mezcla entre noche y día según factor day
  color wcol = lerpColor(windNight, windDay, day);

  // Alpha base del viento: se ve más con nubes y durante el día
  float aBase = lerp(4, 14, cloud) * lerp(0.7, 1.0, day);

  // Configura stroke con alpha calculado
  stroke(red(wcol), green(wcol), blue(wcol), aBase);

  // Dibuja n líneas en posiciones aleatorias del cielo (hasta el horizonte 0.72)
  for (int i = 0; i < n; i++) {
    float x = random(width);
    float y = random(height * 0.72);

    // Longitud variable, y además aumenta con el viento
    float len = random(10, 50) * map(constrain(windMag, 0, 40), 0, 40, 0.6, 1.4);

    // Línea orientada según dx/dy
    line(x, y, x + dx * len, y + dy * len);
  }
}


// Clima (Open-Meteo): construye URL, parsea JSON y actualiza estado

void fetchWeather() {
  // Marca cuándo se hizo el fetch (para el intervalo)
  lastFetchMs = millis();

  // Arma la URL con:
  // - current: variables actuales
  // - hourly: precipitación y probabilidad por hora
  // - daily: min, max y suma de lluvia del día
  // - timezone: para que los timestamps coincidan con tu hora local
  String url =
    "https://api.open-meteo.com/v1/forecast"
    + "?latitude=" + LAT
    + "&longitude=" + LON
    + "&current=temperature_2m,cloud_cover,wind_speed_10m,weather_code"
    + "&hourly=precipitation,precipitation_probability"
    + "&daily=temperature_2m_min,temperature_2m_max,precipitation_sum"
    + "&timezone=" + TZ;

  try {
    // Descarga y parsea JSON automáticamente
    JSONObject json = loadJSONObject(url);

    // ---------------- CURRENT ----------------
    JSONObject current = json.getJSONObject("current");

    // Temperatura actual
    temp = current.getFloat("temperature_2m");

    // Nubosidad viene 0..100, se normaliza a 0..1
    float cloudPct = current.getFloat("cloud_cover");
    cloud = constrain(cloudPct / 100.0, 0, 1);

    // Viento actual
    wind = current.getFloat("wind_speed_10m");

    // Código de clima
    weatherCode = current.getInt("weather_code");

    // ---------------- DAILY (hoy) ----------------
    JSONObject daily = json.getJSONObject("daily");

    // Arrays diarios: el índice 0 es hoy
    JSONArray mins = daily.getJSONArray("temperature_2m_min");
    JSONArray maxs = daily.getJSONArray("temperature_2m_max");
    JSONArray rains = daily.getJSONArray("precipitation_sum");

    // Lee solo si existe índice 0
    if (mins.size() > 0) tMin = mins.getFloat(0);
    if (maxs.size() > 0) tMax = maxs.getFloat(0);
    if (rains.size() > 0) rainMm = rains.getFloat(0);

    // ---------------- HOURLY (alineado a ahora) ----------------
    JSONObject hourly = json.getJSONObject("hourly");

    // Tiempos horarios (strings ISO) y sus series paralelas de lluvia y probabilidad
    JSONArray times = hourly.getJSONArray("time");
    JSONArray prProbArr = hourly.getJSONArray("precipitation_probability");
    JSONArray prMmArr   = hourly.getJSONArray("precipitation");

    // Hora actual según API, para ubicar el índice correcto dentro del hourly
    String currentTimeStr = current.getString("time"); // ej 2026-03-05T11:00

    // Busca índice exacto de esa hora en el array hourly.time
    int idxNow = findHourlyIndex(times, currentTimeStr);

    // Si no está exacto, busca el primer índice posterior o igual
    if (idxNow < 0) idxNow = findNextHourlyIndex(times, currentTimeStr);

    // Ventana de análisis: próximas 12 horas
    int horasARevisar = 12;

    // Acumuladores para promedio de probabilidad
    float sumProb = 0;
    int count = 0;

    // Supone que sí conviene lavar hasta que se demuestre lo contrario
    convieneLavar = true;

    // Promedio real de probabilidad en próximas 12 horas
    for (int i = 0; i < horasARevisar; i++) {
      int idx = idxNow + i;
      if (idx < 0 || idx >= times.size()) break;

      // Probabilidad viene 0..100, se normaliza a 0..1
      float p = prProbArr.getFloat(idx) / 100.0;
      p = constrain(p, 0, 1);

      // Suma para promedio
      sumProb += p;
      count++;

      // Lluvia en mm/h (fallback para la decisión)
      float mm = prMmArr.getFloat(idx);

      // Regla simple:
      // - si llueve más de 0.1 mm/h o
      // - si la probabilidad es >= 0.4
      // entonces no conviene lavar
      if (mm > 0.1 || p >= 0.4) {
        horasConLluvia++;
        convieneLavar = false;
      }
    }

    // Probabilidad promedio final (0 si no hubo datos)
    precipProb = (count > 0) ? (sumProb / count) : 0;

    // Traduce weatherCode a texto para UI
    conditionText = weatherCodeToText(weatherCode);

    // Actualiza el prompt textual
    promptClima = construirPromptClima();

  } catch (Exception e) {
    // Si falla la request o el parse, muestra estado degradado
    conditionText = "sin conexión";
  }
}


// Utilidad: buscar índice exacto en hourly.time

int findHourlyIndex(JSONArray times, String target) {
  for (int i = 0; i < times.size(); i++) {
    if (times.getString(i).equals(target)) return i;
  }
  return -1;
}


// Utilidad: buscar el primer índice cuyo time sea >= target

int findNextHourlyIndex(JSONArray times, String target) {
  // Como es ISO YYYY-MM-DDTHH:MM, comparar strings sirve (orden lexicográfico)
  for (int i = 0; i < times.size(); i++) {
    String t = times.getString(i);
    if (t.compareTo(target) >= 0) return i;
  }
  // Si todo falló, vuelve al inicio
  return 0;
}


// Hora local: devuelve hora como float, intentando usar TZ real

float localHourFloat() {
  try {
    // Hora real según zona horaria, para alinear cielo con TZ
    ZonedDateTime now = ZonedDateTime.now(ZoneId.of(TZ));
    return now.getHour() + now.getMinute() / 60.0;
  } catch (Exception e) {
    // Fallback: hour() y minute() de Processing (depende del sistema)
    return (hour() + minute() / 60.0);
  }
}


// Cielo: gradiente, golden hour, glow solar/lunar, niebla cacheada y bruma

void drawSky(float hour, float day, float cloud) {

  // ---------------- 1) Amanecer y atardecer ----------------
  // Horas aproximadas, usadas para factor de luz y color cálido
  float sunrise = 6.5;
  float sunset  = 19.5;

  // dawn: cerca de sunrise, dusk: cerca de sunset, 0 en resto
  float dawn = 1.0 - constrain(abs(hour - sunrise) / 1.2, 0, 1);
  float dusk = 1.0 - constrain(abs(hour - sunset)  / 1.2, 0, 1);

  // golden toma el pico de cualquiera de los dos
  float golden = max(dawn, dusk);

  // Elevar al cuadrado suaviza la transición (menos lineal, más orgánica)
  golden = golden * golden;

  // ---------------- 2) Colores base día/noche ----------------
  color dayTop    = color(210, 235, 255);
  color dayBottom = color(170, 215, 255);

  color nightTop    = color(25, 32, 55);
  color nightBottom = color(50, 65, 105);

  // Mezcla según factor day
  color topBase = lerpColor(nightTop, dayTop, day);
  color botBase = lerpColor(nightBottom, dayBottom, day);

  // Colores cuando está muy nublado
  color overcastTop    = color(185, 190, 215);
  color overcastBottom = color(170, 180, 210);

  // Mezcla base con overcast según cloud
  color topFinal = lerpColor(topBase, overcastTop, cloud);
  color botFinal = lerpColor(botBase, overcastBottom, cloud);

  // ---------------- 3) Golden hour: tinte cálido ----------------
  // warmAmt crece con golden, baja con cloud, y se escala para no exagerar
  float warmAmt = golden * (1.0 - cloud) * 0.75;

  // Colores cálidos (durazno)
  color warmTop = color(255, 210, 185);
  color warmBot = color(255, 195, 165);

  // Aplica tinte cálido al gradiente
  topFinal = lerpColor(topFinal, warmTop, warmAmt);
  botFinal = lerpColor(botFinal, warmBot, warmAmt);

  // ---------------- 4) Gradiente vertical ----------------
  noFill();
  for (int y = 0; y < height; y++) {
    float t = y / float(height);

    // Smoothstep: t*t*(3-2t) suaviza la transición del gradiente
    float tt = t * t * (3 - 2 * t);

    // Color interpolado en esa altura
    color c = lerpColor(topFinal, botFinal, tt);

    stroke(c);
    line(0, y, width, y);
  }

  // ---------------- 5) Glow solar/lunar según hora ----------------
  // Determina si es día real según sunrise/sunset
  boolean isDay = (hour >= sunrise && hour <= sunset);

  // tArc es 0..1 para recorrer el arco en el cielo
  float tArc;
  if (isDay) {
    // Día: sol recorre de sunrise a sunset
    tArc = map(hour, sunrise, sunset, 0, 1);
  } else {
    // Noche: re-mapea la hora para que 0..6 se convierta en 24..30
    float h = hour;
    if (h < sunrise) h += 24;
    tArc = map(h, sunset, sunrise + 24, 0, 1);
  }
  tArc = constrain(tArc, 0, 1);

  // Posición del glow:
  // x: de izquierda a derecha
  // y: parábola que sube al medio y baja
  float xGlow = lerp(width * 0.12, width * 0.88, tArc);
  float yGlow = lerp(height * 0.70, height * 0.18, 4 * tArc * (1 - tArc));
  yGlow = constrain(yGlow, 0, height * 0.72);

  // Intensidad: más fuerte de día, cae con nubes
  float baseGlow = isDay ? 1.0 : 0.55;
  float glowAmt = baseGlow * (1.0 - cloud);

  // Ajuste extra para que en golden hour el glow no domine
  glowAmt *= lerp(0.35, 1.0, 1.0 - golden * 0.6);

  // Si hay algo de glow, dibuja tres halos
  if (glowAmt > 0.02) {
    noStroke();

    // Color cálido para sol, frío para luna
    color glowCol = isDay ? color(255, 245, 220) : color(210, 225, 255);

    // Halo grande
    fill(red(glowCol), green(glowCol), blue(glowCol), 28 * glowAmt);
    ellipse(xGlow, yGlow, 180, 180);

    // Halo medio
    fill(red(glowCol), green(glowCol), blue(glowCol), 42 * glowAmt);
    ellipse(xGlow, yGlow, 110, 110);

    // Núcleo
    fill(red(glowCol), green(glowCol), blue(glowCol), 60 * glowAmt);
    ellipse(xGlow, yGlow, 55, 55);
  }

  // ---------------- 6) Niebla cacheada ----------------
  // Solo recalcula la capa si cambió bastante cloud o day
  if (abs(cloud - fogCloudCached) > 0.06 || abs(day - fogDayCached) > 0.12) {
    rebuildFogLayer(cloud, day);
    fogCloudCached = cloud;
    fogDayCached = day;
  }

  // Pega la capa de niebla arriba del cielo
  image(fogLayer, 0, 0);

  // ---------------- 7) Bruma del horizonte ----------------
  // Líneas horizontales semitransparentes para dar profundidad atmosférica
  int hazeLines = 18;
  for (int i = 0; i < hazeLines; i++) {
    float yy = lerp(height * 0.50, height * 0.78, i / float(hazeLines - 1));
    float a = lerp(0, 22, i / float(hazeLines - 1)) * lerp(0.8, 1.0, day);
    stroke(235, 240, 255, a);
    line(0, yy, width, yy);
  }
}


// Rebuild niebla: (re)genera puntos aleatorios en fogLayer

void rebuildFogLayer(float cloud, float day) {
  fogLayer.beginDraw();

  // Limpia el buffer con transparencia total
  fogLayer.clear();

  // Cantidad de puntos de niebla proporcional a cloud
  int fog = int(lerp(0, fogMax, cloud));

  // Alpha de cada punto: más alto con nubes, más visible de día
  float fogAlpha = lerp(6, 14, cloud) * lerp(0.7, 1.0, day);

  // Color de puntos (lavanda claro), alpha calculado
  fogLayer.stroke(235, 230, 245, fogAlpha);

  // Puntos aleatorios en casi todo el alto del canvas
  for (int i = 0; i < fog; i++) {
    fogLayer.point(random(width), random(height * fogHeightFactor));
  }

  fogLayer.endDraw();
}


// Prompt texto clima: genera un texto corto para el panel

String construirPromptClima() {
  // Lógica:
  // - si la precipitación diaria acumulada ya es >= 1mm, da por hecho que llueve hoy
  // - si la prob promedio 12h es alta, advierte inestabilidad
  // - si está muy nublado, comenta que está pesado
  // - si no, asume despejado
  if (rainMm >= 1.0) return "Hoy llueve en algún momento";
  if (precipProb >= 0.45) return "Inestable, princesita. Hay muchas chances de que llueva";
  if (cloud >= 0.7) return "Está pesadoooo";
  return "Soleadou y despejadou";
}


// Mapeo de weather_code a texto humano

String weatherCodeToText(int code) {
  // Mapeo resumido de códigos WMO usados por Open-Meteo
  if (code == 0) return "re lindo";
  if (code == 1 || code == 2) return "algo nuboso";
  if (code == 3) return "rozando lo nuboso";
  if (code == 45 || code == 48) return "nuebla?";
  if (code >= 51 && code <= 57) return "llovizna";
  if (code >= 61 && code <= 67) return "llueve";
  if (code >= 71 && code <= 77) return "llueve bastante";
  if (code >= 80 && code <= 82) return "chaparron";
  if (code >= 95) return "tormenta";
  return "clima";
}


// Día/noche: factor 0..1 según hora

float daylightFactor(float hour) {
  float sunrise = 6.5;
  float sunset  = 19.5;

  // Noche cerrada fuera de una ventana alrededor del día
  if (hour < sunrise - 1 || hour > sunset + 1) return 0;

  // Día pleno entre sunrise y sunset
  if (hour >= sunrise && hour <= sunset) return 1;

  // Transición suave: 1 hora antes y 1 hora después
  if (hour < sunrise) return map(hour, sunrise - 1, sunrise, 0, 1);
  return map(hour, sunset, sunset + 1, 1, 0);
}



void drawGround(float day) {
  // ----------------------------------------------------------------------------
  // Agua más oscura + movimiento tipo olas, pero barato:
  // - 2 o 3 "capas" de olas grandes (seno) con pocos pasos en X
  // - el detalle fino se sugiere con pocas líneas horizontales (barato)
  // - nada de per-pixel ni miles de líneas
  // ----------------------------------------------------------------------------

  // Base día/noche (profundo)
  color waterDay   = color(55, 110, 165);
  color waterNight = color(10, 25, 55);

  // Tinte nublado
  color overcast = color(45, 70, 95);

  // Mezcla por día/noche y nubosidad
  color base = lerpColor(waterNight, waterDay, day);
  base = lerpColor(base, overcast, cloud * 0.55);

  // Bloque de agua
  noStroke();
  fill(base);
  rect(0, height * 0.72, width, height * 0.28);

  int y0 = int(height * 0.72);
  int y1 = height;

  // --------------------------------------------------------------------------
  // Olas grandes: 2 capas de curvas (line strip) con pocos puntos
  // --------------------------------------------------------------------------
  // Paso en X: mientras más grande, más barato (y más "low poly")
  int stepX = 10;

  // Tiempo (usar frameCount es barato)
  float t = frameCount * 0.03;

  // Capa 1: ola principal (más visible)
  noFill();
  stroke(140, 175, 205, 60 * lerp(0.45, 1.0, day) * lerp(1.0, 0.75, cloud));
  strokeWeight(2);

  beginShape();
  for (int x = 0; x <= width; x += stepX) {
    // y base dentro del agua, tirando un poco hacia arriba
    float yBase = lerp(y0 + 10, y1 - 18, 0.35);

    // Ola: combinación de 2 senos (casi gratis) para que no parezca repetitiva
    float w =
      sin(x * 0.035 + t * 1.1) * 4.0 +
      sin(x * 0.012 - t * 0.8) * 2.5;

    vertex(x, yBase + w);
  }
  endShape();

  // Capa 2: ola secundaria (más abajo, más suave)
  stroke(120, 160, 195, 40 * lerp(0.40, 0.95, day) * lerp(1.0, 0.78, cloud));
  strokeWeight(1);

  beginShape();
  for (int x = 0; x <= width; x += stepX) {
    float yBase = lerp(y0 + 18, y1 - 10, 0.70);

    float w =
      sin(x * 0.028 + t * 0.9 + 1.7) * 3.0 +
      sin(x * 0.010 - t * 0.6) * 2.0;

    vertex(x, yBase + w);
  }
  endShape();

  // --------------------------------------------------------------------------
  // Textura barata: pocas líneas horizontales con offset ondulado
  // --------------------------------------------------------------------------
  int lines = 14; // muy pocas, costo bajo
  strokeWeight(1);

  for (int i = 0; i < lines; i++) {
    float yy = lerp(y0 + 6, y1 - 2, i / float(lines - 1));
    float depth = map(yy, y0, y1, 0, 1);

    // Offset horizontal suave para que "respire"
    float dx =
      sin(yy * 0.05 + t * 0.7) * lerp(3, 10, depth) +
      sin(yy * 0.09 - t * 0.4) * 2;

    float alpha = lerp(10, 35, depth) * lerp(0.45, 0.95, day) * lerp(1.0, 0.75, cloud);

    // Reflejo apagado (no blanco)
    stroke(165, 195, 215, alpha);
    line(dx, yy, width + dx, yy);
  }

  // --------------------------------------------------------------------------
  // Oscurecimiento suave al fondo (profundidad)
  // --------------------------------------------------------------------------
  for (int i = 0; i < 14; i++) {
    float yy = lerp(y0, y1, i / 13.0);
    float a  = lerp(0, 45, i / 13.0) * lerp(0.50, 1.00, 1.0 - day);
    stroke(0, 0, 0, a);
    line(0, yy, width, yy);
  }
}


// HUD superior: panel con clima ahora y barra vertical día/noche

void drawHud(float hour) {
  // Posición y tamaño del panel HUD
  int hudX = PAD;
  int hudY = PAD;
  int hudW = width - PAD*2 - 18 - 8; // deja espacio para la barra vertical
  int hudH = 84;

  // Fondo del panel
  noStroke();
  fill(UI_PANEL);
  rect(hudX, hudY, hudW, hudH, 12);

  // Borde del panel
  stroke(UI_PANEL_EDGE);
  noFill();
  rect(hudX, hudY, hudW, hudH, 12);

  // Título principal
  noStroke();
  fill(UI_TEXT);
  textFont(fontUIBold);
  textSize(18);
  text("Clima ahora: " + conditionText, hudX + 12, hudY + 22);

  // Texto secundario
  textFont(fontUI);
  textSize(16);
  fill(UI_TEXT);

  // Línea 1: temp + nubosidad
  String s1 = "Temp: " + nf(temp, 0, 1) + "°C   Nub: " + int(cloud * 100) + "%";

  // Línea 2: prob lluvia 12h + viento
  String s2 = "Prob. lluvia (12h): " + int(precipProb * 100) + "%   Viento: " + nf(wind, 0, 1);

  text(s1, hudX + 12, hudY + 44);
  fill(UI_MUTED);
  text(s2, hudX + 12, hudY + 62);

  // Barra vertical: indica día/noche con factor d
  float d = daylightFactor(hour);

  int barX = width - PAD - 18;
  int barY = PAD;
  int barW = 18;
  int barH = hudH;

  // Fondo de la barra
  noStroke();
  fill(245, 248, 255, 150);
  rect(barX, barY, barW, barH, 12);

  // Relleno: cuanto más día, más se llena hacia arriba
  fill(120, 150, 210, 170);
  rect(barX, barY + (1 - d) * barH, barW, d * barH, 12);
}


// Panel Nota: prompt arriba y recomendación abajo

void drawNotePanel() {
  int panelX = PAD;
  int panelY = 100;
  int panelW = width - PAD*2;
  int panelH = height - panelY - PAD;

  // Fondo del panel con alpha reducido para ser más liviano visualmente
  noStroke();
  fill(red(UI_PANEL), green(UI_PANEL), blue(UI_PANEL), 110);
  rect(panelX, panelY, panelW, panelH, 12);

  // Borde aún más sutil
  stroke(red(UI_PANEL_EDGE), green(UI_PANEL_EDGE), blue(UI_PANEL_EDGE), 70);
  noFill();
  rect(panelX, panelY, panelW, panelH, 12);

  // Texto del prompt, envuelto
  noStroke();
  fill(UI_TEXT);
  textFont(fontUI);
  textSize(16);

  String linea = promptClima;
  drawWrappedText(linea, panelX + 12, panelY + 22, panelW - 24, 16);

  // Mensaje final grande
  textFont(fontUIBold);
  textSize(22);

  // Color del mensaje final según convieneLavar
  if (convieneLavar) fill(UI_ACCENT_OK);
  else fill(UI_ACCENT_BAD);

  // Mensaje final según convieneLavar
  String msg = convieneLavar
    ? "Buen momento para lavar ropa."
    : "No, no conviene que laves.";

  // Lo dibuja pegado abajo del panel
  text(msg, panelX + 12, panelY + panelH - 12);
}


// Utilidad: texto envuelto dentro de un ancho w

void drawWrappedText(String s, float x, float y, float w, float lineH) {
  // Separa por espacios
  String[] words = splitTokens(s, " ");

  // Acumula palabras en una línea hasta que textWidth supere el ancho
  String line = "";
  float yy = y;

  for (int i = 0; i < words.length; i++) {
    String test = line.isEmpty() ? words[i] : (line + " " + words[i]);

    // Si el texto excede el ancho, imprime la línea y empieza otra
    if (textWidth(test) > w) {
      text(line, x, yy);
      line = words[i];
      yy += lineH;

      // Corte por seguridad para no escribir fuera de la pantalla
      if (yy > height - PAD - 30) break;
    } else {
      // Si entra, sigue acumulando
      line = test;
    }
  }

  // Imprime la última línea si quedó algo
  if (!line.isEmpty() && yy <= height - PAD - 30) {
    text(line, x, yy);
  }
}


// Clase RainDrop: partícula simple de lluvia

class RainDrop {
  float x, y, vy;

  // Constructor: crea gota y la distribuye en altura aleatoria inicial
  RainDrop() {
    reset();
    y = random(height);
  }

  // Reset: ubica la gota arriba del cielo y le da velocidad vertical aleatoria
  void reset() {
    x = random(width);
    y = random(-height * 0.5, 0);
    vy = random(6, 16);
  }

  // update: avanza y, desplaza x según viento, y recicla si toca el suelo/agua
  void update(float windMag) {
    // Caída vertical
    y += vy;

    // Deriva horizontal según viento
    x += map(constrain(windMag, 0, 40), 0, 40, 0.2, 3.0);

    // Si baja del horizonte (0.72), la recicla arriba
    if (y > height * 0.72) {
      y = random(-100, 0);
      x = random(width);
    }

    // Wrap horizontal simple
    if (x > width) x = 0;
  }

  // display: dibuja una línea vertical corta como gota
  void display() {
    stroke(220, 90);
    line(x, y, x, y + 8);
  }
}
