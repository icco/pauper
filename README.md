# pauper

A bad piano and recorder inspired by [earthsea](https://github.com/tehn/ash/blob/main/earthsea.lua) that runs in Norns.

pauper turns a 16×8 [monome grid](https://monome.org/grid/) into an isomorphic keyboard with a free-time pattern recorder. the same chord shape works anywhere on the grid — slide it to transpose, or stack fingers for chords.

## requirements

- norns
- grid (16×8)

## install

from [maiden](https://monome.org/docs/norns/maiden/):

```
;install https://github.com/icco/pauper
```

## controls

| input | action |
|-------|--------|
| grid | play notes (polyphonic) |
| key2 | toggle record |
| key3 | toggle playback (loops) |
| enc1 | root note |
| enc2 | scale |
| enc3 | base octave |

key2 starts a new recording and clears any previous pattern. key3 won't fire until at least one note has been recorded. you can play the grid while the pattern loops.

## grid layout

every row is a **perfect 4th** (5 semitones) above the row below it. every step right is +1 semitone. led brightness shows scale membership:

- **15** — key held
- **10** — root note of current scale
- **5** — in-scale note
- **0** — out of scale

## params

| param | range | default |
|-------|-------|---------|
| Root | C–B | C |
| Scale | 9 modes | Major |
| Base Octave | 1–6 | 2 |
| Level | 0–1 | 0.15 |
| Attack | 0.01–10s | 0.05s |
| Release | 0.01–10s | 1s |
| Cutoff | 0–32 | 8 |

scales: Major, Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian, Pentatonic Major, Pentatonic Minor.

## references

- [norns scripting](https://monome.org/docs/norns/scripting/) — norns Lua API
- [norns studies](https://monome.org/docs/norns/studies/) — grid, clock, engine, params tutorials
- [musicutil](https://monome.org/docs/norns/reference/lib/musicutil) — scale generation and note conversion (`musicutil.NOTE_NAMES`, `musicutil.generate_scale`)
- [pattern_time](https://monome.org/docs/norns/reference/lib/pattern_time) — free-time event recorder used for pattern capture and looping
- [PolySub engine](https://monome.org/docs/norns/reference/engine) — built-in polyphonic subtractive synth with ADSR sustain
- [norns tutorial thread](https://llllllll.co/t/norns-tutorial/23241) — community scripting guide

## license

MIT © Nat Welch
