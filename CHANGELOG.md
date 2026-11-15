# Changelog

## 4.2.0 - 2026-11-15

- **Heavy rain is dark purple.** On the radar and in the chart the blue turns towards purple
  from about a third of *Heavy rain at*, full purple at that rate. New setting *Heavy rain
  colour*.
- Demo pictures for the README and the Hub: `docs/imber.gif` (one run of the radar while a cold
  front passes) and `docs/imber-front.png` (the same run as five moments). They are made with
  `tools/render_demo.py` from example data.

## 4.1.0 - 2026-11-11

- The time on the top left now runs along with the radar (white, to the quarter hour). Each run
  still starts at the time the rain starts.
- *Animation length* defaults to 0 = automatic: one run of the radar per app time of the
  rotation (*App duration* in the clock's settings). Shown outside the rotation, e.g. with
  *Show*, a run takes 10 s. A value above 0 works as before.

## 4.0.0 - 2026-11-10

- **Animated rain radar.** The map no longer sums up the next hours; it plays the forecast hour
  by hour from the start time to the end of the chart, blending smoothly between the hours.
- A white line runs along the chart and shows which moment the radar is at.
- Imber stays on screen for one run of the radar plus a second, and starts from the beginning
  each time it comes up.
- New setting *Animation length* (default 6 s). *Map full colour at* is replaced by *Heavy rain
  at* (mm/h), shared by radar and chart; *Map hours* is gone. Radar and chart cover at least
  3 hours.

## 3.0.2 - 2026-11-10

First release on GitHub. The script was already published on the AWTRIX Hub.

- Round rain map of your area (37 points, radius 5-50 km) with the rain total over the map hours
  and thunderstorm potential (LPI) as yellow dots.
- Start of the rain at your place to the quarter hour, chart of the rain rate until the end of
  your day, map hours highlighted.
- Joins the rotation only when rain is expected before the end of your day.
- Optional MQTT gate topic (show only while it says `on`) and indicator topic.
- Data from Open-Meteo, model ICON-D2 of the DWD: one request for the map, one for the 15-minute
  values at your place.
