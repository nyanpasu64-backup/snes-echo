# SNES Echo Simulator - Faust VST

snes-echo is an cross-platform audio processing plugin, written in Faust. It simulates the SNES SPC700 DSP reverb/echo effect.

This program is located in `snes-echo/snes-echo.dsp`.

This plugin does not strive for bit-accuracy and overflow handling, but instead being audibly indistinguishable for "normal" SPCs.

To compile, install [FaustLive or Faust (faust.grame.fr)](faust.grame.fr).

## Usage

- You must toggle the "Echo Enabled" checkbox/slider to enable the effect.
- Enable the "Normalize Volumes" checkbox/slider to scale max(master volume, echo volume) to unity gain.

## Design

- Feedback *input* (not output) is clamped to ±full-scale.
- FIR filter taps are implemented using Lagrange fractional delay lines. They preserve high frequencies better than linear interpolation, and are sample-rate independent (unlike 1-sample delays).
- Delay of 0 (8-tap FIR filter, or IIR if feedback enabled) is not supported.


## TODO

* Write GUI wrapper around Faust-to-C++ compiled classes.
    * Easier than writing a high-quality Lagrange fractional-delay in C++.
* Find why high-order Lagrange fractional-delays cause VST crashes.
