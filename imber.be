# @name    Imber
# @desc    Should I take rain gear today? LEFT: an animated rain radar of the area around you (you are the centre between the four grey dots). It plays the forecast hour by hour from the start time to the end of the chart: black = dry, brighter blue = more rain, dark purple = heavy rain, a yellow dot = thunderstorm potential. TOP RIGHT: the time the radar shows, running along with it (each run starts at the time the rain starts; if it is already raining, now), and the time the chart ends, to the quarter hour. BELOW: a bar chart between these two times, one pixel column per slice of time, height = rain at your location, yellow = thunderstorm potential. A white line runs along the chart and shows which moment the radar is at. The app only joins the rotation when rain is expected before the end of your day. Data: Open-Meteo (CC BY 4.0), DWD ICON-D2 model, so it works for Germany and its neighbours.
# @author  exradice
# @version 4.2.0
# @display 52x16
# @config lat             text   "Latitude"                 default="51.1634" group="Location" help="Your location in decimal degrees, e.g. 51.1634. The centre of the map."
# @config lon             text   "Longitude"                default="10.4477"  group="Location" help="Your location in decimal degrees, e.g. 10.4477."
# @config radius          number "Map radius"               default=20 min=5 max=50 unit=km group="Location" help="How far the round map reaches from the centre. One cell is a third of this."
# @config threshold       number "Rain from"                default=0.2 min=0.1 max=2 step=0.1 unit=mm/h group="Forecast" help="Less rain counts as dry. Raise it if light drizzle should not count."
# @config day_end         number "End of day"               default=20 min=12 max=24 unit=h group="Forecast" help="The radar and the chart end at this hour, but always cover at least 3 hours. Rain that starts later does not bring the app into the rotation."
# @config interval        number "Update every"             default=15 min=5 max=60 unit=min group="Forecast" help="How often the forecast is fetched. ICON-D2 is updated every hour."
# @config anim_seconds    number "Animation length"         default=0 min=0 max=60 unit=s group="Display" help="How long one run of the radar takes, from the start time to the end of the chart. 0 = automatic: one run per app time of the rotation (Settings, App duration). Shown outside the rotation, e.g. with Show, a run takes 10 s. Any other value: one run takes that long and the app stays on screen for one run."
# @config bar_full        number "Heavy rain at"            default=4 min=1 max=20 unit=mm/h group="Display" help="Rain rate that gets the full heavy rain colour (dark purple) on the radar and fills a bar to the top. From about a third of it the blue turns towards purple."
# @config storm_full      number "Storm full colour at"     default=10 min=1 max=50 unit=J/kg group="Display" help="Lightning potential index (LPI) that gets the brightest yellow. It shows how likely and strong lightning is, it is not a probability."
# @config color_rain      color  "Rain colour"              default=#60C8FF group="Display"
# @config color_heavy     color  "Heavy rain colour"        default=#7A28E0 group="Display" help="Heavy rain turns from the rain colour into this colour, on the radar and in the chart."
# @config color_text      color  "Text colour"              default=#4FA8FF group="Display"
# @config gate_topic      text   "Show only when (MQTT topic)" default="" group="Integration" help="Optional. The app only joins the rotation while this topic says on (also true or 1). Leave empty to show it whenever rain is expected."
# @config indicator_topic text   "Indicator topic (MQTT)"   default="" group="Integration" help="Optional, e.g. awtrix/cmd/indicators/3. Lights an indicator while rain is expected today. Leave empty for none."
# @config color_indicator color  "Indicator colour"         default=#0050FF group="Integration"

# Imber - https://github.com/exradice/imber
# Copyright (c) 2026 exradice. MIT License.
# Weather data: Open-Meteo (https://open-meteo.com), CC BY 4.0, model ICON-D2 of DWD.
#
# Two requests to Open-Meteo: hourly values for all map points, and 15-minute values
# for the centre only (chart and start time). A value covers the period BEFORE its
# timestamp: one hour for hourly values, a quarter hour for 15-minute values.
# Without 15-minute values the chart falls back to the hourly values of the centre.

import json
import math

class Imber
  var cells       # [gx, gy] per map point, -3..3, corners left out
  var centre      # index of the centre cell
  var url_map
  var url_fine
  var data        # hourly answer, one map per point
  var fetched     # time of the last good hourly answer, seconds UTC
  var fine        # 15-minute answer for the centre ('minutely_15')
  var fine_at     # time of the last good 15-minute answer
  var countdown   # seconds until the next fetch
  var busy        # requests still on their way
  var gate        # value of the gate topic: nil = unknown
  var active      # rain expected and the app may join the rotation
  var indicator   # last indicator state sent
  var stamp       # minute of the last evaluation, -1 = new data
  var frames      # radar: [middle of the hour, colours, storm colours] per hour, seconds UTC
  var anim_a      # radar and chart run from anim_a to anim_b, seconds UTC
  var anim_b
  var anim_ms     # length of one radar run
  var anim_t0     # now_ms() when the app came on screen
  var turn_ms     # now_ms() when the rotation last gave the app a turn
  var bars        # [height, colour] per pixel column of the chart
  var label_end
  var offset      # local time minus UTC, seconds
  var now_label   # label of the time the radar shows, and its quarter hour
  var now_q
  var color_text

  def init()
    self.cells = []
    self.centre = 0
    for gy: -3 .. 3
      for gx: -3 .. 3
        if gx * gx + gy * gy <= 12
          if gx == 0 && gy == 0 self.centre = size(self.cells) end
          self.cells.push([gx, gy])
        end
      end
    end
    self.url_map = ""
    self.url_fine = ""
    self.data = nil
    self.fetched = 0
    self.fine = nil
    self.fine_at = 0
    self.countdown = 0
    self.busy = 0
    self.gate = nil
    self.active = false
    self.indicator = nil
    self.stamp = -1
    self.frames = []
    self.anim_a = 0
    self.anim_b = 0
    self.anim_ms = 10000
    self.anim_t0 = 0
    self.turn_ms = -100000
    self.bars = []
    self.label_end = ""
    self.offset = 0
    self.now_label = ""
    self.now_q = -1
    self.color_text = 0x4FA8FF
  end

  def cfg(key, default)
    var v = nil
    try v = store.get(key) except .. end
    return v != nil ? v : default
  end

  def number(key, default)
    var v = real(default)
    try v = real(self.cfg(key, default)) except .. end
    return v
  end

  def setup()
    self.color_text = self.cfg("color_text", 0x4FA8FF)

    # 7 x 7 points across the diameter, spacing = 2 * radius / 6
    var lat0 = self.number("lat", 51.1634)
    var lon0 = self.number("lon", 10.4477)
    var step = self.number("radius", 20) * 2 / 6
    var km_lon = 111.32 * math.cos(lat0 * math.pi / 180)
    var lats = []
    var lons = []
    for c: self.cells
      lats.push(format("%.4f", lat0 - c[1] * step / 111.32))
      lons.push(format("%.4f", lon0 + c[0] * step / km_lon))
    end
    var base = "https://api.open-meteo.com/v1/forecast?models=icon_d2&timeformat=unixtime"
    self.url_map = base + "&latitude=" + lats.concat(",") + "&longitude=" + lons.concat(",") +
                   "&hourly=precipitation,lightning_potential,weather_code&forecast_hours=24"
    self.url_fine = base + format("&latitude=%.4f&longitude=%.4f", lat0, lon0) +
                    "&minutely_15=precipitation,lightning_potential&forecast_minutely_15=96"

    var gt = str(self.cfg("gate_topic", ""))
    if size(gt) > 0
      mqtt.subscribe(gt, / t, p -> self.on_gate(p))
    end
  end

  def on_gate(p)
    var s = str(p)
    self.gate = s == "on" || s == "true" || s == "1"
    self.stamp = -1
    self.evaluate()
  end

  def fetch()
    if self.busy > 0 || size(self.url_map) == 0 return end
    self.busy = 2
    http.get(self.url_map, / body, status -> self.on_map(body, status), {"cap": 81920})
    http.get(self.url_fine, / body, status -> self.on_fine(body, status), {"cap": 16384})
  end

  def parse(body, status)
    if body == nil || status != 200 return nil end
    var d = nil
    try d = json.load(body) except .. end
    return d
  end

  def on_map(body, status)
    var d = self.parse(body, status)
    if isinstance(d, list) && size(d) == size(self.cells)
      self.data = d
      self.fetched = int(epoch_ms() / 1000)
    else
      log("Imber: map fetch failed, status " + str(status))
    end
    self.done()
  end

  def on_fine(body, status)
    var d = self.parse(body, status)
    if isinstance(d, map) && d.find('minutely_15') != nil
      self.fine = d['minutely_15']
      self.fine_at = int(epoch_ms() / 1000)
    else
      log("Imber: 15-minute fetch failed, status " + str(status))
    end
    self.done()
  end

  def done()
    self.busy -= 1
    if self.busy > 0 return end
    # after an error try again in 2 minutes
    var ok = int(epoch_ms() / 1000) - self.fetched < 120
    self.countdown = ok ? int(self.number("interval", 15) * 60) : 120
    self.stamp = -1
    self.evaluate()
  end

  def val(v)
    return v == nil ? 0.0 : real(v)
  end

  # colour at percent % brightness
  def dim(color, percent)
    var r = ((color >> 16) & 0xFF) * percent / 100
    var g = ((color >> 8) & 0xFF) * percent / 100
    var b = (color & 0xFF) * percent / 100
    return (r << 16) | (g << 8) | b
  end

  def mix(c1, c2, t)
    var r = int(((c1 >> 16) & 0xFF) + (((c2 >> 16) & 0xFF) - ((c1 >> 16) & 0xFF)) * t)
    var g = int(((c1 >> 8) & 0xFF) + (((c2 >> 8) & 0xFF) - ((c1 >> 8) & 0xFF)) * t)
    var b = int((c1 & 0xFF) + ((c2 & 0xFF) - (c1 & 0xFF)) * t)
    return (r << 16) | (g << 8) | b
  end

  # colour of a rain rate: dark to bright rain colour, then towards the heavy rain colour;
  # square root, so that little rain is still visible
  def rain_shade(rate, min_percent)
    var f = math.sqrt(rate / self.number("bar_full", 4))
    if f > 1.0 f = 1.0 end
    if f >= 0.6
      return self.mix(self.cfg("color_rain", 0x60C8FF), self.cfg("color_heavy", 0x7A28E0), (f - 0.6) / 0.4)
    end
    var pc = int(f / 0.6 * 100)
    return self.dim(self.cfg("color_rain", 0x60C8FF), pc < min_percent ? min_percent : pc)
  end

  # dark to bright yellow by lightning potential, 0 = none
  def storm_color(lpi, coded)
    var g = lpi / self.number("storm_full", 10)
    if coded && g < 0.8 g = 0.8 end
    if g <= 0.0 return 0 end
    if g < 0.25 g = 0.25 end
    if g > 1.0 g = 1.0 end
    return self.mix(0x302000, 0xFFE000, g)
  end

  def clock(ts, offset)
    var s = (ts + offset) % 86400
    if s < 0 s += 86400 end
    return format("%d:%02d", s / 3600, (s % 3600) / 60)
  end

  # time series for the chart: [end times, rain per step, lightning, step seconds]
  def series()
    if self.fine != nil && int(epoch_ms() / 1000) - self.fine_at <= 3 * 3600
      return [self.fine['time'], self.fine['precipitation'], self.fine['lightning_potential'], 900]
    end
    var h = self.data[self.centre].find('hourly')
    return [h['time'], h['precipitation'], h['lightning_potential'], 3600]
  end

  # radar: one picture per hour that touches a..b, rain rate and storm per cell
  def build_frames(a, b)
    var hours = self.data[self.centre].find('hourly')['time']
    var frames = []
    for k: 0 .. size(hours) - 1
      var t = int(hours[k])
      if t - 3600 < b && t > a
        var colors = []
        var storm = []
        for p: self.data
          var h = p.find('hourly')
          # an hourly value is the rain of the hour before its timestamp, so mm = mm/h
          var rate = self.val(h['precipitation'][k])
          var code = h['weather_code'][k]
          colors.push(rate < 0.05 ? 0 : self.rain_shade(rate, 8))
          storm.push(self.storm_color(self.val(h['lightning_potential'][k]), code != nil && int(code) >= 95))
        end
        frames.push([t - 1800, colors, storm])
      end
    end
    self.frames = frames
  end

  # chart: 36 pixel columns from a to b (seconds UTC)
  def build_bars(a, b)
    var rain_color = self.cfg("color_rain", 0x60C8FF)
    var full = self.number("bar_full", 4)
    var threshold = self.number("threshold", 0.2)
    var s = self.series()
    var times = s[0]
    var rain = s[1]
    var lpis = s[2]
    var step = s[3]
    var per_hour = 3600 / step

    # storm anywhere on the map, per hour
    var hours = self.data[self.centre].find('hourly')['time']
    var area = []
    for i: 0 .. size(hours) - 1
      var lpi = 0.0
      var coded = false
      for p: self.data
        var h = p.find('hourly')
        if self.val(h['lightning_potential'][i]) > lpi lpi = self.val(h['lightning_potential'][i]) end
        var c = h['weather_code'][i]
        if c != nil && int(c) >= 95 coded = true end
      end
      area.push([lpi, coded])
    end

    var cols = 36
    var dur = (b - a) / cols
    var bars = []
    for col: 0 .. cols - 1
      var ca = a + col * dur
      var cb = ca + dur
      # strongest rain rate and lightning of the steps this column touches
      var rate = 0.0
      var lpi = 0.0
      for i: 0 .. size(times) - 1
        var t = int(times[i])
        if t - step < cb && t > ca
          var r = self.val(rain[i]) * per_hour
          if r > rate rate = r end
          if self.val(lpis[i]) > lpi lpi = self.val(lpis[i]) end
        end
      end
      var coded = false
      var mid = ca + dur / 2
      for i: 0 .. size(hours) - 1
        var t = int(hours[i])
        if t - 3600 <= mid && mid < t
          if area[i][0] > lpi lpi = area[i][0] end
          if area[i][1] coded = true end
        end
      end
      var bh = int(math.sqrt(rate / full) * 8 + 0.5)
      if bh > 8 bh = 8 end
      if rate >= 0.05 && bh < 1 bh = 1 end
      var storm = self.storm_color(lpi, coded)
      var color = storm != 0 ? storm : (rate >= threshold ? self.rain_shade(rate, 100) : self.dim(rain_color, 40))
      bars.push([bh, color])
    end
    self.bars = bars
  end

  def set_indicator(on)
    if on == self.indicator return end
    var topic = str(self.cfg("indicator_topic", ""))
    if size(topic) > 0
      var c = self.cfg("color_indicator", 0x0050FF)
      mqtt.publish(topic, on ? format("{\"color\": \"#%06X\"}", c) : "")
    end
    self.indicator = on
  end

  def evaluate()
    var now = epoch_ms()
    if now < 0 || hour() < 0 || self.data == nil
      self.active = false
      return
    end
    var now_s = int(now / 1000)
    # the chart moves by the minute, so a full evaluation once a minute is enough
    if self.stamp == now_s / 60 return end
    self.stamp = now_s / 60

    var new_active = false
    var rain_today = false
    if now_s - self.fetched <= 3 * 3600
      try
        var threshold = self.number("threshold", 0.2)
        var since_midnight = hour() * 3600 + minute() * 60 + second()
        var day_end = now_s - since_midnight + int(self.number("day_end", 20)) * 3600
        # offset of local time to UTC, for the labels
        var offset = since_midnight - now_s % 86400
        if offset < -43200 offset += 86400 end
        if offset > 50400 offset -= 86400 end

        # start of rain: first step that ends in the future and is wet enough
        var s = self.series()
        var times = s[0]
        var rain = s[1]
        var step = s[3]
        var per_hour = 3600 / step
        var start = -1
        for i: 0 .. size(times) - 1
          var t = int(times[i])
          if start < 0 && t > now_s && t - step < day_end && self.val(rain[i]) * per_hour >= threshold
            start = t - step
          end
        end
        rain_today = start >= 0
        # already raining: start now; no rain: start now as well, for a look with "Show"
        var a = rain_today && start > now_s ? start : now_s - now_s % 900
        var b = day_end
        if b < a + 3 * 3600 b = a + 3 * 3600 end

        self.build_frames(a, b)
        if size(self.frames) > 0
          self.build_bars(a, b)
          self.anim_a = a
          self.anim_b = b
          self.label_end = self.clock(b, offset)
          self.offset = offset
          self.now_q = -1
          if rain_today
            new_active = size(str(self.cfg("gate_topic", ""))) == 0 || self.gate != false
          end
        end
      except .. as e, msg
        log("Imber: " + str(msg))
      end
    end
    self.active = new_active
    self.set_indicator(rain_today && hour() >= 5 && hour() < int(self.number("day_end", 20)))
  end

  def loop()
    if epoch_ms() < 0 return end
    self.countdown -= 1
    if self.countdown <= 0
      self.countdown = 60   # until the answers arrive
      self.fetch()
    end
    self.evaluate()
  end

  def should_show()
    self.evaluate()
    return self.active
  end

  # length of one run: the setting, or automatic (0): the app time of the rotation minus
  # the pause at the end; outside a rotation turn (Show) or without that setting 10 s
  def anim_length(in_turn)
    var s = self.number("anim_seconds", 0)
    if s > 0 return int(s * 1000) end
    if in_turn
      var d = nil
      try d = settings.get("appDurationMs") except .. end
      if d != nil && real(d) >= 3000 return int(real(d)) - 1000 end
    end
    return 10000
  end

  # called when the rotation reaches the app: with a set length stay on screen for one run
  # plus the pause at its end, automatic keeps the app time of the rotation (0)
  def duration()
    self.turn_ms = now_ms()
    self.anim_ms = self.anim_length(true)
    return self.number("anim_seconds", 0) > 0 ? self.anim_ms + 1000 : 0
  end

  # every appearance starts the radar from the beginning; without a rotation turn just
  # before (Show), automatic falls back to the default length
  def on_show()
    self.anim_t0 = now_ms()
    if self.anim_t0 - self.turn_ms > 3000
      self.anim_ms = self.anim_length(false)
    end
  end

  def draw()
    clear()
    if size(self.frames) == 0
      text((width() - text_ink_width("no data")) / 2, 10, "no data", 0x808080)
      return
    end

    # where the radar is: one run, then a second standing still at the end
    var e = (now_ms() - self.anim_t0) % (self.anim_ms + 1000)
    var p = e >= self.anim_ms ? 1.0 : real(e) / self.anim_ms
    var t = self.anim_a + (self.anim_b - self.anim_a) * p

    # the two hourly pictures around t, blended for a smooth motion
    var n = size(self.frames)
    var j = 0
    while j + 1 < n && self.frames[j + 1][0] <= t j += 1 end
    var k = j + 1 < n ? j + 1 : j
    var f = 0.0
    if k != j && t > self.frames[j][0]
      f = (t - self.frames[j][0]) / (self.frames[k][0] - self.frames[j][0])
      if f > 1.0 f = 1.0 end
    end
    var c1 = self.frames[j][1]
    var c2 = self.frames[k][1]
    var storm = self.frames[f < 0.5 ? j : k][2]

    # map 14 x 14 pixels, cells 2 x 2, one row from the top
    var dry = 0x0C0C14
    for i: 0 .. size(self.cells) - 1
      var c = self.cells[i]
      var x = (c[0] + 3) * 2
      var y = 1 + (c[1] + 3) * 2
      var a = c1[i] != 0 ? c1[i] : dry
      var b = c2[i] != 0 ? c2[i] : dry
      rect_fill(x, y, 2, 2, a == b ? a : self.mix(a, b, f))
      if storm[i] != 0 pixel(x + 1, y, storm[i]) end
    end
    # your location: four grey dots at the corners of the centre cell
    pixel(5, 6, 0x707070)
    pixel(8, 6, 0x707070)
    pixel(5, 9, 0x707070)
    pixel(8, 9, 0x707070)

    # the time the radar shows on the left (to the quarter hour, it starts at the start
    # time), end of the chart on the right, a dash between if it fits
    var q = int(t) / 900
    if q != self.now_q
      self.now_q = q
      self.now_label = self.clock(q * 900, self.offset)
    end
    var x0 = 16
    var w_start = text_ink_width(self.now_label)
    var w_end = text_ink_width(self.label_end)
    text(x0, 6, self.now_label, 0xFFFFFF)
    text(width() - w_end, 6, self.label_end, self.color_text)
    var space = width() - w_end - (x0 + w_start)
    if space >= 5
      rect_fill(x0 + w_start + (space - 3) / 2, 3, 3, 1, self.dim(self.color_text, 60))
    end

    # one bar per pixel column, rows 8 to 15
    for i: 0 .. size(self.bars) - 1
      var bar = self.bars[i]
      if bar[0] > 0
        rect_fill(x0 + i, 16 - bar[0], 1, bar[0], bar[1])
      else
        pixel(x0 + i, 15, 0x101018)
      end
    end
    # the white line: the moment the radar shows
    var cols = size(self.bars)
    if cols > 0
      rect_fill(x0 + int(p * (cols - 1) + 0.5), 8, 1, 8, 0xFFFFFF)
    end
  end
end

return Imber()
