import java.time.*;
import processing.awt.PSurfaceAWT;
import java.awt.Frame;
import java.awt.geom.RoundRectangle2D;

float humedad = 0;   // 0..1
float closeR = 10;

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
  size(400, 200);
   // ventana real 
  PSurfaceAWT.SmoothCanvas canvas = 
     (PSurfaceAWT.SmoothCanvas) surface.getNative();

  Frame frame = canvas.getFrame();
  frame.dispose();
  frame.setUndecorated(true);
  frame.setVisible(true);
  
  // bordes redondeados 
  frame.setShape(new RoundRectangle2D.Double(
    0, 0, width, height, 30, 30
  ));
 
    
  int margenDerecho = 20;
  int margenInferior = 70;
  
  int x = displayWidth - 400 - margenDerecho;
  int y = displayHeight - 200 - margenInferior;
 
  surface.setLocation(x, y);
  surface.setTitle(""); 
  surface.setAlwaysOnTop(true);

// ver como mover de lugar arrastrando el mouse mejorar
  smooth(4);
 
  textFont(createFont("Consolas Bold", 16, true));
 
  tryFetchLocationByIP();

  fetchWeather();
}

 
void draw() {
  if (millis() - lastFetchMs > fetchEveryMs) fetchWeather();

  float hourNow = getLocalHour();
  float day = getDayFactor(hourNow); // 0 noche, 1 dia

  drawCozySky(day, hourNow);
  drawSeaWithWaves(day);
  drawRainIfNeeded();
  drawPanel(day);
  
  drawCloseButton();
}

float getDayFactor(float hourNow) {
  if (hourNow >= 7 && hourNow <= 19) return 1;
  if (hourNow > 6 && hourNow < 7) return map(hourNow, 6, 7, 0, 1);
  if (hourNow > 19 && hourNow < 20) return map(hourNow, 19, 20, 1, 0);
  return 0;
}

void drawCozySky(float day, float hourNow) {
  // gradiente día/noche con cambios segun la nubosidaad
  //  el cielo cambia peeero sin usar imagenes  
  
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
  // da sensación de tiempo sin cálculos   
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

  // estrellas pero rarisimo mejorar
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
 
  if (precipProb < 0.40) return;

  float intensidad = map(constrain(precipProb, 0.50, 1.0), 0.50, 1.0, 0, 1);

  // nueva cosita: 
  intensidad *= map(constrain(cloud, 0.4, 1.0), 0.4, 1.0, 0.35, 1.0);

  int gotas = int(map(intensidad, 0, 1, 12, 95));

  stroke(220, 230, 255, 110 + 70 * intensidad);
  strokeWeight(1.2);

  for (int i = 0; i < gotas; i++) {
    float x = random(width);
    float y = random(height * 0.68);
    float largo = 7 + 8 * intensidad;
    float deriva = 2 + wind * 0.08;

    line(x, y, x + deriva, y + largo);
  }

  strokeWeight(1);
}

void drawPanel(float day) {
  //noStroke();
  //fill(255, 250, 245, 20);
  //rect(12, 12, width - 24, height - 24, 12);

  //stroke(255, 255, 255, 135);
  //noFill();
  //rect(12, 12, width - 24, height - 24, 12);


  
  
  fill(100, 118, 156); // azul lavardito
  textSize(18);
  text(conditionText + " en " + ubicacionCorta, 24, 38);

 

  // texto ffff
  //String tempStr = "Hacen maso " + nf(temp, 0, 1) + "°C.";
  //text(tempStr, 24, 62);

  
  //float tx = 24 + textWidth(tempStr) + 8;
  //fill(42, 56, 82, 150);
  //textSize(14);
  //text("(" + ubicacionCorta + ")", tx, 62);

  //  
  //fill(42, 56, 82);
  //textSize(14);

  //text("Prob. de lluvias cercanas: " + int(precipProb * 100) + "%", 24, 82);

//  text(promptClima, 24, 112, width - 48, 60);
  textSize(14);
  text(promptClima, 24, 62, width - 48, 60);

  textSize(14);
  String msg = convieneLavar ? "Sí, conviene lavar." : "No, no te conviene lavar.";

 
  fill(70, 86, 118);  // azul grisáceo claro (misma idea que el original pero más suave)
 // text(msg, 25, 183);
  text(msg, 25, 120);


  // mini barra que muestra cuanto de día queda ahora mismo
  noStroke();
  fill(236, 226, 235, 170);
  rect(width - 34, 34, 12, 60, 8);
  
  fill(120, 145, 200, 200);
  rect(width - 34, 34 + (1 - day) * 60, 12, day * 60, 8);
}



void fetchWeather() {
  lastFetchMs = millis();

  String url =
    "https://api.open-meteo.com/v1/forecast"
    + "?latitude=" + LAT
    + "&longitude=" + LON
    + "&current=temperature_2m,relative_humidity_2m,cloud_cover,wind_speed_10m,weather_code"
    + "&hourly=precipitation,precipitation_probability"
    + "&daily=precipitation_sum"
    + "&timezone=" + TZ;

  try {
    JSONObject json = loadJSONObject(url);

    JSONObject climaActual = json.getJSONObject("current");
    JSONObject climaPorHora = json.getJSONObject("hourly");
    JSONObject climaDiario = json.getJSONObject("daily");

    temp = climaActual.getFloat("temperature_2m");
    humedad = constrain(climaActual.getFloat("relative_humidity_2m") / 100.0, 0, 1);
    cloud = constrain(climaActual.getFloat("cloud_cover") / 100.0, 0, 1);
    wind = climaActual.getFloat("wind_speed_10m");

    int codigoClima = climaActual.getInt("weather_code");
    conditionText = weatherCodeToText(codigoClima);

    JSONArray probLluviaPorHora = climaPorHora.getJSONArray("precipitation_probability");
    JSONArray lluviaPorHoraMm = climaPorHora.getJSONArray("precipitation");

    int horasARevisar = min(12, min(probLluviaPorHora.size(), lluviaPorHoraMm.size()));

    float probMaxima12h = 0;
    float lluviaAcumulada12h = 0;
    float sumaProbabilidades = 0;
    boolean llueveDentroDe12h = false;

    for (int i = 0; i < horasARevisar; i++) {
      float probHora = constrain(probLluviaPorHora.getFloat(i) / 100.0, 0, 1);
      float mmHora = max(0, lluviaPorHoraMm.getFloat(i));

      sumaProbabilidades += probHora;
      lluviaAcumulada12h += mmHora;
      probMaxima12h = max(probMaxima12h, probHora);

      // si al menos una hora ya es fea alcanza
      if (probHora >= 0.45 || mmHora > 0.2) {
        llueveDentroDe12h = true;
      }
    }

    precipProb = (horasARevisar > 0) ? (sumaProbabilidades / horasARevisar) : 0;

    JSONArray lluviaDiaria = climaDiario.getJSONArray("precipitation_sum");
    rainMm = (lluviaDiaria.size() > 0) ? max(0, lluviaDiaria.getFloat(0)) : 0;

    convieneLavar = evaluarSiConvieneLavar(
      temp,
      humedad,
      cloud,
      wind,
      codigoClima,
      probMaxima12h,
      lluviaAcumulada12h,
      llueveDentroDe12h
    );

    promptClima = buildPrompt();

  } catch (Exception e) {
    conditionText = "sin conexión";
    promptClima = "No pude actualizar el clima.";
  }
}

//aca va la logica dura, con variables mas claras
boolean evaluarSiConvieneLavar(
  float temperaturaActual,
  float humedadActual,
  float nubosidadActual,
  float vientoActual,
  int codigoClimaActual,
  float probMaximaLluvia12h,
  float lluviaAcumulada12h,
  boolean llueveDentroDe12h
) {
  boolean climaInestableAhora = (codigoClimaActual >= 80 && codigoClimaActual <= 99);

  // si parece que va a llover, no lavar
  if (llueveDentroDe12h) return false;
  if (probMaximaLluvia12h >= 0.60) return false;
  if (lluviaAcumulada12h >= 1.5) return false;
  if (climaInestableAhora && humedadActual >= 0.80) return false;

  // puntaje de secado:  (si re pesada ya se)
  // arranca 0 y va sumando o restando según si el ambiente ayuda o arruina.
  float puntajeSecado = 0;

  // considera la humedad 
  if (humedadActual >= 0.90) {
    puntajeSecado -= 4.5;
  } else if (humedadActual >= 0.85) {
    puntajeSecado -= 3.5;
  } else if (humedadActual >= 0.78) {
    puntajeSecado -= 2.5;
  } else if (humedadActual >= 0.70) {
    puntajeSecado -= 1.2;
  } else {
    puntajeSecado += 0.8;
  }

  // temp poque seca re lento
  if (temperaturaActual < 18) {
    puntajeSecado -= 2.0;
  } else if (temperaturaActual < 22) {
    puntajeSecado -= 1.0;
  } else if (temperaturaActual <= 30) {
    puntajeSecado += 1.2;
  } else {
    puntajeSecado += 0.6;
  }

  //  nada de viento en ambiente húmedo hmm
  if (vientoActual < 5) {
    puntajeSecado -= 2.0;
  } else if (vientoActual < 9) {
    puntajeSecado -= 0.8;
  } else if (vientoActual <= 18) {
    puntajeSecado += 1.3;
  } else {
    puntajeSecado += 0.8;
  }

  // nubes
  if (nubosidadActual >= 0.90) {
    puntajeSecado -= 1.5;
  } else if (nubosidadActual >= 0.75) {
    puntajeSecado -= 0.8;
  } else if (nubosidadActual <= 0.35) {
    puntajeSecado += 0.5;
  }

  // penalizaciones combinadas
  
  if (humedadActual >= 0.85 && vientoActual < 8) {
    puntajeSecado -= 2.2;
  }

  if (humedadActual >= 0.78 && temperaturaActual < 22) {
    puntajeSecado -= 1.5;
  }

  if (nubosidadActual >= 0.80 && humedadActual >= 0.78 && vientoActual < 8) {
    puntajeSecado -= 1.5;
  }

  // riesgo de lluvia futura también afecta
  if (probMaximaLluvia12h >= 0.35) {
    puntajeSecado -= 1.0;
  }

  if (lluviaAcumulada12h >= 0.7) {
    puntajeSecado -= 1.0;
  }

  // Umbral: arriba de 0.5 da una ventana de OK para mi mejorar
  return puntajeSecado > 0.5;
}

String weatherCodeToText(int code) {
  if (code == 0) return "despejado";

  if (code == 1) return "mayormente despejado";
  if (code == 2) return "rozando lo nuboso";
  if (code == 3) return "drama nuboso";

  if (code == 45 || code == 48) return "bruma húmeda";
  
  if (code >= 51 && code <= 57) return "llovizna";
  if (code >= 61 && code <= 67) return "lluvia";

  if (code >= 71 && code <= 77) return "precipitación confusa";

  if (code >= 80 && code <= 82) return "energías inestables";
  if (code >= 85 && code <= 86) return "posible agua fría cayendo";

  if (code >= 95 && code <= 100) return "está pesado";

  return "variable como mi voluntad";
}

String buildPrompt() { // GRACIAS PATO POR ARMAR ESTO
  if (rainMm >= 1.0)
    return "proximo a garuar (aquella que con su olvido hoy le ha abierto una gotera)";

  if (precipProb >= 0.55)
    return "grease (sería ese gris largo que promete lluvia pero no concreta)";

  if (cloud >= 0.7 && precipProb < 0.4)
    return "posibilidades reales de que caigan soretes de punta";

  if (cloud >= 0.4)
    return "mucha nube, pero no tanta. en realidad muy pocas nubes.";

  return "soleadou y despejadou";
}


String weatherCodeToTextold(int code) {
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

void drawCloseButton() {

  float x = width - 16;
  float y = 14;

  noStroke();
  fill(dist(mouseX, mouseY, x, y) < closeR ? color(210,95,95) : color(180,90,90));
  circle(x, y, closeR * 2);

  stroke(255, 220);
  strokeWeight(1.5);
  line(x-3, y-3, x+3, y+3);
  line(x+3, y-3, x-3, y+3);
}

void mousePressed() {

  float x = width - 16;
  float y = 14;

  if (dist(mouseX, mouseY, x, y) < closeR) {
    exit();
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
