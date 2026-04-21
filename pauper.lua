-- pauper
-- v1.0.0 @icco
-- llllllll.co/t/pauper
--
-- isomorphic grid piano
-- with single-pattern recorder
--
-- grid: play notes
-- key2: toggle record
-- key3: toggle playback
-- enc1: root note
-- enc2: scale
-- enc3: base octave

engine.name = "PolySub"

local musicutil = require("musicutil")
local pattern_time = require("lib/pattern_time")

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local ROW_INTERVAL = 5 -- semitones between rows (perfect 4th)
local GRID_WIDTH = 16
local GRID_HEIGHT = 8
local C1_MIDI = 24 -- MIDI note number for C1; base of the lowest octave row

-- musicutil scale identifiers and short display names matched by index.
-- Names must match musicutil.generate_scale expectations (lowercase).
local SCALE_IDS = {
  "major",
  "natural minor",
  "dorian",
  "phrygian",
  "lydian",
  "mixolydian",
  "locrian",
  "major pentatonic",
  "minor pentatonic",
}

local SCALE_DISPLAY = {
  "Major",
  "Minor",
  "Dorian",
  "Phrygian",
  "Lydian",
  "Mixolydian",
  "Locrian",
  "Pent. Maj",
  "Pent. Min",
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

-- [note_class 0..11] = true when in the current scale
local scale_classes = {}

local state = {
  recording = false,
  playing = false,
  held = {}, -- [grid_key(x,y)] = true when that key is held
}

local redraw_clock -- clock coroutine id

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Stable hash for a grid position; used as a table key for state.held.
local function grid_key(x, y)
  return x * GRID_HEIGHT + y
end

local function rebuild_scale()
  scale_classes = {}
  -- params:get("root") returns a 1-based index; convert to 0-based MIDI class
  local root = params:get("root") - 1
  local name = SCALE_IDS[params:get("scale")]
  for _, n in ipairs(musicutil.generate_scale(root, name, 1)) do
    scale_classes[n % 12] = true
  end
end

-- Returns the MIDI note number for grid position (x, y).
-- y=1 is the top row (highest pitch); y=GRID_HEIGHT is the bottom (lowest).
local function grid_to_note(x, y)
  local base = C1_MIDI + (params:get("base_oct") - 1) * 12 + (params:get("root") - 1)
  return base + (GRID_HEIGHT - y) * ROW_INTERVAL + (x - 1)
end

-- ---------------------------------------------------------------------------
-- Grid device
-- ---------------------------------------------------------------------------

local g = grid.connect()

local function grid_redraw()
  if g.device == nil then
    return
  end
  -- Hoist params out of the 128-cell loop
  local root_class = params:get("root") - 1
  local base = C1_MIDI + (params:get("base_oct") - 1) * 12 + root_class
  g:all(0)
  for y = 1, GRID_HEIGHT do
    for x = 1, GRID_WIDTH do
      local nc = (base + (GRID_HEIGHT - y) * ROW_INTERVAL + (x - 1)) % 12
      local level
      if state.held[grid_key(x, y)] then
        level = 15
      elseif nc == root_class then
        level = 10
      elseif scale_classes[nc] then
        level = 5
      else
        level = 0
      end
      g:led(x, y, level)
    end
  end
  g:refresh()
end

-- ---------------------------------------------------------------------------
-- Pattern recorder
-- ---------------------------------------------------------------------------

local function on_playback_event(event)
  local freq = musicutil.note_num_to_freq(event.note)
  if event.type == "on" then
    engine.start(event.note, freq)
  elseif event.type == "off" then
    engine.stop(event.note)
  end
end

local pt = pattern_time.new()
pt.process = on_playback_event

-- ---------------------------------------------------------------------------
-- Grid input
-- ---------------------------------------------------------------------------

g.key = function(x, y, z)
  local note = grid_to_note(x, y)
  local freq = musicutil.note_num_to_freq(note)
  if z == 1 then
    engine.start(note, freq)
    state.held[grid_key(x, y)] = note
    if state.recording then
      pt:watch({ type = "on", note = note })
    end
  else
    engine.stop(note)
    state.held[grid_key(x, y)] = nil
    if state.recording then
      pt:watch({ type = "off", note = note })
    end
  end
  grid_redraw()
end

-- ---------------------------------------------------------------------------
-- Norns hardware callbacks
-- ---------------------------------------------------------------------------

function key(n, z)
  if z ~= 1 then
    return
  end
  if n == 2 then
    if state.recording then
      state.recording = false
      for _, held_note in pairs(state.held) do
        pt:watch({ type = "off", note = held_note })
      end
      pt:rec_stop()
    else
      pt:stop()
      state.playing = false
      pt:rec_start()
      state.recording = true
    end
  elseif n == 3 then
    if state.playing then
      pt:stop()
      state.playing = false
    elseif pt.count > 0 then
      state.recording = false
      pt:rec_stop()
      pt.loop = 1
      pt:start()
      state.playing = true
    end
  end
  redraw()
end

function enc(n, d)
  if n == 1 then
    params:delta("root", d)
    rebuild_scale()
  elseif n == 2 then
    params:delta("scale", d)
    rebuild_scale()
  elseif n == 3 then
    params:delta("base_oct", d)
  end
  grid_redraw()
  redraw()
end

function redraw()
  screen.clear()
  screen.font_face(1)
  screen.font_size(8)

  screen.level(15)
  screen.move(2, 10)
  screen.text("pauper")

  screen.level(10)
  screen.move(2, 22)
  screen.text(musicutil.NOTE_NAMES[params:get("root")] .. " " .. SCALE_DISPLAY[params:get("scale")])
  screen.move(2, 32)
  screen.text("oct " .. params:get("base_oct"))

  screen.level(15)
  screen.move(2, 50)
  if state.recording then
    screen.text("[ REC ]")
  elseif state.playing then
    screen.text("[PLAY ]")
  else
    screen.text("[ --- ]")
  end

  screen.level(5)
  screen.move(2, 60)
  screen.text(pt.count .. " events")

  screen.update()
end

function init()
  params:add_separator("pauper_sep", "PAUPER")
  params:add_option("root", "Root", musicutil.NOTE_NAMES, 1)
  params:add_option("scale", "Scale", SCALE_DISPLAY, 1)

  params:add_number("base_oct", "Base Octave", 1, 6, 2)
  params:add_control("level", "Level", controlspec.new(0, 1, "lin", 0.01, 0.8, ""))
  params:add_control("attack", "Attack", controlspec.new(0.001, 1, "exp", 0.001, 0.005, "s"))
  params:add_control("release", "Release", controlspec.new(0.01, 4, "exp", 0.01, 0.5, "s"))
  params:add_control("cutoff", "Cutoff", controlspec.new(200, 8000, "exp", 1, 2000, "hz"))

  params:set_action("level", function(v)
    engine.level(v)
  end)
  params:set_action("attack", function(v)
    engine.ampAtk(v)
  end)
  params:set_action("release", function(v)
    engine.ampRel(v)
  end)
  params:set_action("cutoff", function(v)
    engine.cut(v)
  end)

  params:bang()

  rebuild_scale()

  -- Drive grid LED updates at ~30 fps independently of input events
  redraw_clock = clock.run(function()
    while true do
      clock.sleep(1 / 30)
      grid_redraw()
    end
  end)

  redraw()
end

function cleanup()
  pt:stop()
  clock.cancel(redraw_clock)
end
