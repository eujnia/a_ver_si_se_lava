# a ver si se lava


A tiny cozy app that checks the weather and answers if you should do laundry today. 

It pulls live data from Open-Meteo and turns it into a small animated weather scene that changes with the real conditions outside. 
Based on the current conditions, it gives a tiny yes-or-no answer on whether today feels like a good laundry day.

The laundry verdict comes from a simple score: It first rules out the cases like near-future rain or unstable wet weather, and then builds a drying score based on humidity, temperature, wind and cloud cover. Some combinations are penalized extra, especially when the air is humid and heavy. 


```math
\text{drying score} = \text{humidity score} + \text{temperature score} + \text{wind score} + \text{cloudiness score} + \text{combined penalties} + \text{low rain penalties}
```

If the final score clears a small threshold, the day is marked as laundry-friendly.


<img width="859" height="678" alt="imagen" src="https://github.com/user-attachments/assets/300e9c73-1c8e-4c11-b999-092c6498be07" />

### How to try it:

1. Download the executable from the **Releases** section.

2. Unzip the file and run: a_ver_si_se_lava.exe
   
Note: The download includes a minimized Java runtime so it can run on any Windows machine without requiring a separate installation :)

---

### Built with

Processing (Java mode)

Weather data from https://open-meteo.com/
