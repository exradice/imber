# Imber

**Should I take rain gear today?** Imber answers this at a glance on your AWTRIX clock: where the
rain is around you, when it starts at your place, and how the rest of your day looks. It is not a
weather report but a decision aid for the commute and the day.

*Imber* is Latin for "downpour".

<!-- Demo: docs/imber.gif -->

[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/exradice)

## How to read it

```
┌──────────────┬─────────────────────────────────────┐
│   rain map   │  7:15 ───────────────────── 20:00   │  start of the rain, end of the chart
│  (round, 14  │                                     │
│   × 14 px)   │  ▂▃▅▇▆▄▃▂▁   ▁▂▂▁                   │  rain at your place over time
└──────────────┴─────────────────────────────────────┘
```

- **Left: the rain map.** A round map of the area around you, 20 km in every direction by
  default. You are in the middle, between the four grey dots. Each cell shows the rain total of
  the next 3 hours from the start time: black is dry, the brighter the blue, the more rain. A
  yellow dot marks thunderstorm potential; the brighter, the stronger.
- **Top right: the time window.** On the left the time the rain starts at your place (to the
  quarter hour; if it is already raining, now), on the right the time the chart ends.
- **Bottom right: the chart.** One pixel column per slice of time between these two times. The
  height is the rain at your place; a yellow column means thunderstorm potential nearby. The
  bright part at the start covers the same hours as the map, the rest of the day is dimmed.

Imber **only joins the rotation when rain is expected** before the end of your day (20:00 by
default). On dry days you never see it.

## Requirements

- **An AWTRIX NG clock with a 52×16 display** (Ulanzi TC002).
- **Internet access** for the clock, to reach `api.open-meteo.com` over HTTPS.
- **A location in Germany or a neighbouring country.** Imber uses the ICON-D2 model of the German
  Weather Service, which covers Germany and the regions around it. Elsewhere the app shows no
  data.

No Home Assistant, no account and no API key needed.

## Setup

1. **Install the script.** Get *Imber* from the AWTRIX Hub, or create a script named `Imber` in
   the clock's web interface (*Scripts* tab) and paste [`imber.be`](imber.be).
2. **Enter your location.** *Apps* tab → gear icon of Imber → **Latitude** and **Longitude** in
   decimal degrees, for example `52.5200` and `13.4050`. A map app shows them when you tap and
   hold a place. The default is the centre of Germany.
3. **Optional:** adjust the map radius, the map hours, the rain threshold and the end of your day.

The first forecast arrives within a minute. If rain is coming today, Imber joins the rotation.

## Settings

In the clock's web interface, *Apps* tab, gear icon of Imber:

| Group | Setting | Default | What it does |
|---|---|---|---|
| Location | Latitude, Longitude | centre of Germany | Your place, the centre of the map |
| Location | Map radius | 20 km | How far the round map reaches; one cell is a third of it |
| Forecast | Map hours | 3 h | The map sums up the rain over this many hours from the start time |
| Forecast | Rain from | 0.2 mm/h | Less counts as dry; raise it if light drizzle should not count |
| Forecast | End of day | 20 h | The chart ends here (or later, if the map hours reach further). Rain after this time does not bring Imber into the rotation |
| Forecast | Update every | 15 min | How often the forecast is fetched; ICON-D2 is updated every hour |
| Display | Map full colour at | 5 mm | Rain total of a map cell that gets the brightest blue |
| Display | Bar full height at | 4 mm/h | Rain rate that fills a bar to the top |
| Display | Storm full colour at | 10 J/kg | Lightning potential (LPI) that gets the brightest yellow |
| Display | Rain colour, Text colour | blue | Colours of the map, chart and times |
| Integration | Show only when (MQTT topic) | *(empty)* | See below |
| Integration | Indicator topic (MQTT) | *(empty)* | See below |
| Integration | Indicator colour | blue | Colour of that indicator |

## Optional: MQTT integration

Both settings are optional; leave them empty and Imber works on its own.

- **Show only when (MQTT topic):** Imber only joins the rotation while this topic says `on`
  (also `true` or `1`). Example: let Home Assistant publish `on` during your morning routine, so
  the forecast is on the clock while you get ready, and gone afterwards.
- **Indicator topic (MQTT):** lights one of the clock's indicators while rain is expected today,
  for example `<prefix>/cmd/indicators/3`.

**Use topics under your clock's prefix**, for example `kitchen/data/morning` and
`kitchen/cmd/indicators/3` for a clock with the prefix `kitchen` (field *Topic prefix* in the
clock's MQTT settings). If your broker only lets the clock read and write its own topics, other
topics silently do nothing.

## Good to know

- **Data:** [Open-Meteo](https://open-meteo.com), model ICON-D2 of the German Weather Service
  (DWD), about 2 km resolution, updated every hour.
- **Two requests per update:** hourly values for the map (one request for all 37 points) and
  15-minute values for your place. With the default interval of 15 minutes this is about 3,700
  location calls a day, within Open-Meteo's free limit of 10,000 for non-commercial use. Shorter
  intervals can exceed it.
- **Thunderstorms** are shown by the lightning potential index (LPI) of the model. It tells how
  likely and how strong lightning is, but it is not a probability.
- **On the days the clocks change** the end of the day can be one hour off.

## Troubleshooting

- **Imber never shows up:** that is normal on dry days. To see it anyway, start it from the web
  interface (*Apps* tab). `no data` means no forecast has arrived yet.
- **`no data` stays:** look at the clock's log. `Imber: map fetch failed, status …` or
  `15-minute fetch failed` point to a network problem or a location outside the ICON-D2 area.
- **It shows up although you set a gate topic:** check that the topic really says `off` (or
  anything other than `on`, `true`, `1`) and that the clock may read it.

## Privacy

The script sends your **latitude and longitude** (and the 37 map points around it) to
api.open-meteo.com with every update. Nothing else leaves your network.

## Credits

- Weather data by [Open-Meteo.com](https://open-meteo.com), licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), based on the ICON-D2 model of the
  [Deutscher Wetterdienst](https://www.dwd.de).
- Open-Meteo is free for non-commercial use. If you use it a lot or commercially, consider their
  [API plans](https://open-meteo.com/en/pricing), which keep the service running.
- AWTRIX is a name of its owner. Imber is an independent project and not affiliated with AWTRIX,
  Open-Meteo or the DWD.

## Support

Imber is free and stays free. If it saved you from getting wet and you want to say thanks, you
can [buy me a coffee on Ko-fi](https://ko-fi.com/exradice). Bug reports and ideas are welcome as
GitHub issues.

## License

[MIT](LICENSE) © 2026 exradice

---

<p align="center">Made with ❤️ in the EU 🇪🇺</p>
