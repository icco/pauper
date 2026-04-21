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

-- Note history for display: most recent first, up to NOTE_HISTORY_MAX entries.
local NOTE_HISTORY_MAX = 6
local note_history = {}

local redraw_clock -- clock coroutine id

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Stable hash for a grid position; used as a table key for state.held.
local function grid_key(x, y)
  return x * GRID_HEIGHT + y
end

-- Returns a display string like "C4" or "G#3" for a MIDI note number.
local function note_display_name(note)
  return musicutil.NOTE_NAMES[(note % 12) + 1] .. tostring(math.floor(note / 12) - 1)
end

-- Prepend a note name to the history list, trimming to NOTE_HISTORY_MAX.
local function push_note_history(note)
  table.insert(note_history, 1, note_display_name(note))
  if #note_history > NOTE_HISTORY_MAX then
    table.remove(note_history)
  end
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
    push_note_history(event.note)
    redraw()
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
    push_note_history(note)
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

  -- Title
  screen.level(15)
  screen.move(2, 10)
  screen.text("pauper")

  -- Status indicator, right-aligned on same line as title
  screen.level(15)
  screen.move(126, 10)
  if state.recording then
    screen.text_right("[ REC ]")
  elseif state.playing then
    screen.text_right("[ PLAY ]")
  else
    screen.text_right("[ --- ]")
  end

  -- Scale and octave info
  screen.level(10)
  screen.move(2, 22)
  screen.text(musicutil.NOTE_NAMES[params:get("root")] .. " " .. SCALE_DISPLAY[params:get("scale")])
  screen.move(2, 32)
  screen.text("oct " .. params:get("base_oct"))

  -- Note history: most recent at top, fading toward the bottom
  local levels = { 15, 11, 7, 4, 2, 1 }
  for i = 1, math.min(#note_history, #levels) do
    screen.level(levels[i])
    screen.move(2, 32 + i * 9 + 4)
    screen.text(note_history[i])
  end

  -- Event count, subtle at bottom right
  screen.level(3)
  screen.move(126, 62)
  screen.text_right(pt.count .. " ev")

  screen.update()
end

function init()
  params:add_separator("pauper_sep", "PAUPER")
  params:add_option("root", "Root", musicutil.NOTE_NAMES, 1)
  params:add_option("scale", "Scale", SCALE_DISPLAY, 1)

  params:add_number("base_oct", "Base Octave", 1, 6, 2)
  params:add_control("level", "Level", controlspec.new(0, 1, "lin", 0.01, 0.15, ""))
  params:add_control("attack", "Attack", controlspec.new(0.01, 10, "lin", 0.01, 0.05, "s"))
  params:add_control("release", "Release", controlspec.new(0.01, 10, "lin", 0.01, 1.0, "s"))
  params:add_control("cutoff", "Cutoff", controlspec.new(0, 32, "lin", 0.1, 8, ""))

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
