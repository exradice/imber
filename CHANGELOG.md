# Changelog

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
