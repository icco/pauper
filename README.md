# pauper

> bad piano. good patterns.

pauper is a [norns](https://monome.org/docs/norns/) script for the 16×8 [monome grid](https://monome.org/grid/). it turns the grid into an isomorphic keyboard — where the same chord shape works at any position — and captures a single free-time looping pattern.

## requirements

- norns (update 240424 or later)
- [grid](https://monome.org/grid/) 128 (16×8)

## install

from [maiden](https://monome.org/docs/norns/maiden/):

```
;install https://github.com/icco/pauper
```

## the grid

the keyboard is **isomorphic**: every row is a **perfect 4th** (5 semitones) higher than the row below it. the same chord shape therefore works anywhere on the grid — slide it left/right to transpose, up/down to change voicing.

```
row 1 (top)   ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·   highest
row 2         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 3         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 4         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 5         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 6         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 7         ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·
row 8 (bottom)·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·   lowest
              └─ each step right = +1 semitone ──────────────┘
```

**led brightness:**

| brightness | meaning |
|------------|---------|
| bright (15) | key currently held |
| dim (4) | root note of current scale |
| faint (2) | in-scale note |
| off (0) | out of scale |

all keys are playable regardless of scale — the led dimness just helps you navigate.

## norns keys

| key | action |
|-----|--------|
| key2 | **record** — press to start recording, press again to stop |
| key3 | **play** — press to loop the recorded pattern, press again to stop |

recording a new pattern automatically stops any current playback. starting playback automatically stops recording.

## norns encoders

| encoder | action |
|---------|--------|
| enc1 | root note (C → C# → D … → B) |
| enc2 | scale |
| enc3 | base octave (1–6) |

changing the root or scale updates the led display immediately. it does **not** retune an in-progress recording — the recorded notes keep their original pitches.

## params

open the norns params menu to find the **PAUPER** section:

| param | range | description |
|-------|-------|-------------|
| Root | C–B | root note for scale and led display |
| Scale | 9 choices | scale used for led highlighting |
| Base Octave | 1–6 | starting octave for the bottom row |
| Amp | 0.0–1.0 | output amplitude |
| Release | 0.1–4s | note decay time |
| Cutoff | 200–8000 hz | moog filter cutoff frequency |
| Gain | 1.0–4.0 | filter resonance |

## available scales

- Major, Minor
- Dorian, Phrygian, Lydian, Mixolydian, Locrian
- Pentatonic Major, Pentatonic Minor

## recording a pattern

1. press **key2** — screen shows `[ REC ]`
2. play notes freely on the grid
3. press **key2** — recording stops
4. press **key3** — screen shows `[PLAY ]` — your pattern loops
5. press **key3** again to stop

only one pattern can be recorded. starting a new recording with **key2** clears the previous one.

you can play notes on the grid while the pattern is looping — your live notes sound alongside the recorded ones.

## norns screen

```
pauper
C Major
oct 2

[ REC ]      ← current state: REC / PLAY / ---
23 events    ← count of recorded note-on events
```

## default pitch range

with Base Octave = 2 and Root = C, the grid spans:

- bottom-left (1, 8): C2  (midi 24)
- top-right (16, 1): D#6 (midi 87)

roughly 5.3 octaves of chromatic range.

## engine

pauper uses norns' built-in **PolyPerc** engine: a pulse-wave oscillator through a Moog filter with a percussive envelope. voices are polyphonic and decay naturally — no explicit note-off is needed.

## license

MIT © Nat Welch
