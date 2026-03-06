## a ver si se lava


A tiny cozy Processing sketch that checks the weather and answers if you should do laundry today. 

It pulls live data from Open-Meteo and turns it into a small animated weather scene that changes with the real conditions outside. 
Based on the current conditions, it gives a tiny yes-or-no answer on whether today feels like a good laundry day.

The laundry verdict comes from a simple score: It first rules out the cases like near-future rain or unstable wet weather, and then builds a drying score based on humidity, temperature, wind and cloud cover. Some combinations are penalized extra, especially when the air is humid and heavy. 

<p align="center">
$\text{drying score} = \text{humidity score} + \text{temperature score} + \text{wind score} + \text{cloudiness score} + \text{combined penalties} + \text{low rain penalties}$
</p>

If the final score clears a small threshold, the day is marked as laundry-friendly.


<img width="859" height="678" alt="imagen" src="https://github.com/user-attachments/assets/300e9c73-1c8e-4c11-b999-092c6498be07" />

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
