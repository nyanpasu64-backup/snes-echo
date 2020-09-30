# SNES Echo Simulator - Faust program/VST

snes-echo is an cross-platform audio processing plugin, written in Faust. It simulates the SNES SPC700 DSP reverb/echo effect.

This program is located in `snes-echo/snes-echo.dsp`.

This plugin does not strive for bit-accuracy and overflow handling, but instead being audibly indistinguishable for "normal" SPCs.

## Installation

To compile, install [Faust (faust.grame.fr)](https://faust.grame.fr/downloads/index.html). The page also offers FaustLive, a GUI for hosting the engine code created by Faust's compiler.

Faust also has a [web-based editor](https://fausteditor.grame.fr/) which tends to stutter, but is sufficient for testing and allows you to export VSTs and other plugins without setting up compilers yourself.

I tried exporting a Win64 VST from the web editor, but I was unable to load the resulting `untitled.dll` in most programs I tried. I suspect this repo cannot be used as a VST in its current form. If anyone can fix this, I'm accepting contributions (pull requests).

## Usage

- Enable the "Normalize Volumes" checkbox/slider to scale max(dry volume, wet volume) to unity gain.
- Feedback *input* (not output) is clamped to ±full-scale.
- FIR filter taps are implemented using Lagrange fractional delay lines. They preserve high frequencies better than linear interpolation, and are sample-rate independent (unlike 1-sample delays).
- Setting the echo buffer length to 0 (producing an 8-tap FIR filter, or IIR if feedback enabled) is supported, but only sampling rate 32000 produces the same filter effects as SNES hardware. Integer multiples of 32000 (like 96000) should also work, but I was unable to test.

## TODO

- Write GUI wrapper around Faust-to-C++ compiled classes.
    - Easier than writing a high-quality Lagrange fractional-delay in C++.
- Check if high-order Lagrange fractional-delays still causes VST crashes. Test with asan/ubsan to check for out-of-bounds access.
