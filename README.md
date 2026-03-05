## A ver si se lava

Just a tiny processing sketch that checks the weather and answers if you should do laundry today. It pulls live data from Open-Meteo and turns it into a very small animated landscape (sky, clouds, rain, wind and water movement change according to current conditions).
If rain is likely in the next few hours, it suggests not washing clothes.

<img width="744" height="490" alt="imagen" src="https://github.com/user-attachments/assets/bf3968c7-645f-4008-8a6c-af93e1053814" />


#### How to run:

For a quick try (Windows):

1. Download the executable from the **Releases** section.

2. Unzip the file and run: a_ver_si_se_lava.exe

The download is relatively LARGE because it includes a bundled Java so it can run on any win, so you don't need to install anything.

---

Run the code (lightweight, and you can experiment):

1. Install Processing: https://processing.org/download

2. Download or clone this repository  
(you only need the `.pde` file)

3. Open the `.pde` file in Processing

4. Press **Run**

The sketch will fetch weather data from the Open-Meteo API and generate the landscape automatically.



## Built with

Processing (Java mode)

Weather data from https://open-meteo.com/
