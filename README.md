# metrix

[intellijel Metropolix](https://intellijel.com/shop/eurorack/metropolix/) for norns.

All functionality and terms are directly adopted from metropolix.
Have a look on yt or the Metropolix website for a general functional overview of the sequencer.
Please look at the manual for further explanations if something is unclear.

**TOC**
1. [Features](#features)
2. [Requirements](#requirements)
3. [Layout](#layout)
    - [Pages](#pages)
    - [Modifier Keys](#modifier-keys)

## Features
- Two independent tracks with 8 stages each
- Control many functions directly via grid (pulse count, gate type, ratchets, pitch, octave, accumulation, slide and accent)
- Set playback direction (forward, reverse, alternate, random) and clock division (1/1 - 1/32) per track
- Loop the whole sequence or choose parts of it
- Quantize to a scale and root note via global params
- Connect to Crow or via MIDI
- Save and load up to 64 presets
- Generate random sequences 

## Requirements
- norns (210114)
- grid
- optional: crow

## Layout
The Layout of **metrix** ist influenced strongly by [skylines](https://llllllll.co/t/skylines/38856) and Kria. <3

### Pages
In the bottom left corner, you can choose among the follwing pages:

1. pulses and gates
2. pitch
3. presets and track settings

### Track Selector / Loopy
On pages 1 & 2, use the first two rows to select one of two tracks and to set the loop start and end points:
- Tap on the currently unselected track to select it.
- Hold the start point and select the end point while holding down sets the looping stages.
- Tap on a stage on the currently selected track to select only a single stage.

### Modifier Keys
In the bottom right corner, the _[shift]_ and _[mod]_ keys are located.
Hold these keys for secondary functions and shortcuts.

#### _shift_
Hold the _[shift]_ key to switch to the secondary functions of a page. 
More on that on the corresponding sections.

#### _mod_
Hold the _[mod]_ key to access some shortcuts:

- `[mod] + [page 1] / [page 2]`
Randomize the values related to that page
- `[mod] + [value]`
Set all stages to the selected value. Use the shift key additionally to access the secondary functions.
