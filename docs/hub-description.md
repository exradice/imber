<!-- Text for the AWTRIX Hub listing. Short descriptions by allowed length:
~100 chars: Should I take rain gear today? Animated rain radar of your area and a chart for the rest of the day.
~150 chars: Should I take rain gear today? An animated rain radar of your area, when it starts at your place and a chart until evening. Only shows up when rain is coming.
~250 chars: Should I take rain gear today? Imber plays an animated rain radar of your area, shows when the rain starts at your place to the quarter hour, and a chart until the end of your day with thunderstorm warnings. It only joins the rotation when rain is coming.
-->

**Should I take rain gear today?** Imber (Latin for "downpour") answers this at a glance: where the rain is around you, when it starts at your place, and how the rest of your day looks. It is not a weather report but a decision aid for the commute and the day.

### How to read it

- **Left: the rain radar.** A round map of the area around you, 20 km in every direction by default. You are in the middle, between the four grey dots. It plays the forecast hour by hour, so you see the rain move across your area: black is dry, the brighter the blue, the more rain. A yellow dot marks thunderstorm potential, the brighter, the stronger.
- **Top right: the time window.** On the left the time the rain starts at your place (to the quarter hour; if it is already raining, now), on the right the time the chart ends.
- **Bottom right: the chart.** One pixel column per slice of time between these two times. The height is the rain at your place, a yellow column means thunderstorm potential nearby. A white line runs along with the radar and shows which moment it is at.

The app **only joins the rotation when rain is expected** before the end of your day (20:00 by default). On dry days you never see it.

### Setup

1. Install the script and open its settings.
2. Enter your **latitude and longitude** (decimal degrees, e.g. from a map app). The default is the centre of Germany.
3. Optional: adjust the map radius, the rain threshold, the end of your day and the animation length.

### Optional integrations

- **Show only when (MQTT topic):** the app only appears while this topic says `on`. Example: let Home Assistant publish `on` during your morning routine, so the forecast is on the clock when you get ready, and gone afterwards.
- **Indicator topic (MQTT):** lights one of the clock's indicators while rain is expected today, e.g. `awtrix/cmd/indicators/3` (use your own MQTT prefix).

### Good to know

- **Data:** [Open-Meteo](https://open-meteo.com) (CC BY 4.0), model ICON-D2 of the German Weather Service (DWD), about 2 km resolution, updated every hour. It covers **Germany and its neighbouring countries** only; elsewhere the app shows no data.
- **Two requests per update:** hourly values for the map (one request for all 37 points) and 15-minute values for your place. With the default interval of 15 minutes this is about 3,700 location calls a day, within Open-Meteo's free limit of 10,000 for non-commercial use. Shorter intervals can exceed it.
- **Thunderstorms** are shown by the lightning potential index (LPI) of the model. It tells how likely and how strong lightning is, but it is not a probability.
- The clock needs internet access (HTTPS to api.open-meteo.com).
- Made for the 52×16 display (Ulanzi TC002).
- Setup guide, settings and troubleshooting: **https://github.com/exradice/imber**
