# A Ver Si Se Lava

Just a tiny processing sketch that checks the weather and answers if you should you do laundry today. 

It pulls live data from Open-Meteo and turns it into a very small animated landscape (sky, clouds, rain, wind and water movement change according to current conditions)

If rain is likely in the next hours, it suggests not washing clothes.

<img width="737" height="459" alt="imagen" src="https://github.com/user-attachments/assets/2e942d9a-f0ce-40be-b71c-2af3a65ca2c3" />

## How to run

### Quick try (Windows)

Download the executable from the **Releases** section.

Unzip the file and run:

a_ver_si_se_lava.exe

The download is relatively LARGE because it includes a bundled Java runtime so it can run on any Windows machine without installing anything :) 

---

### Run the code (lightweight, and you can experiment)

1. Install Processing  
https://processing.org/download

2. Download or clone this repository  
(you only need the `.pde` file)

3. Open the `.pde` file in Processing

4. Press **Run**

The sketch will fetch weather data from the Open-Meteo API and generate the landscape automatically.
## Built with

Processing (Java mode)

Weather data from  
https://open-meteo.com/
