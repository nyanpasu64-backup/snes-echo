declare name     	"snes-echo";
declare version  	"0.";
declare author   	"nyanpasu64";
declare license  	"BSD";
declare copyright	"nyanpasu64";

// import("math.lib");
import("stdfaust.lib");
import("delays.lib");
SR = ma.SR;


// **** UTILITY FUNCTIONS ****

/// kilo
K = 1024;

// do not use pow2up/down, (passing in SR?) causes infinite runtime in FAUST compiler.

// Zero-indexing.
at(list, idx) = ba.subseq(list, idx, 1);

yes   	(bool) = bool;
not   	(bool) = 1-bool;
if(cond, yes, no) = select2(cond, no, yes);

signed	(bool) = if(bool, 1, -1);
nsign 	(bool) = if(bool, -1, 1);

clamp(x, low, high) = min(max(x, low), high);


// **** BEGIN PROGRAM

FIR_TAP_COUNT = 8;

enabled = checkbox("h:/v:[1]/[1]Echo Enabled");
normalized = checkbox("h:/v:[1]/[2]Normalize Volumes");
output_vol = 1;	// vslider("h:/v:[1]/[3]Output Volume", 2, 1, 2, 0.1);

// EDL register
MAXBLOCKS = 15;		// * 16ms/blk = 1024ms
nblocks = vslider("h:/v:[1]/[0]Echo blocks (16ms)", 5, 1, MAXBLOCKS, 1):rint;

mvolSign = checkbox("h:/v:[2]Master Volume/Negative"):nsign;
mvolR =  vslider("h:/v:[2]Master Volume/Master Volume", 63, 0, 127, 1) * mvolSign:rint;
mvolL = checkbox("h:/v:[2]Master Volume/Surround") : nsign(_)*mvolR;

evolSign = checkbox("h:/v:[3]Echo Volume/Negative"):nsign;
evolR =  vslider("h:/v:[3]Echo Volume/Echo Volume", 25, 0, 127, 1) * evolSign:rint;
evolL = checkbox("h:/v:[3]Echo Volume/Surround") : nsign(_)*evolR;

efbSign = checkbox("h:/v:[4]Echo Feedback/Negative"):nsign;
efbR =  vslider("h:/v:[4]Echo Feedback/Echo Feedback", 70, 0, 127, 1) * efbSign:rint;
efbL = checkbox("h:/v:[4]Echo Feedback/Surround (not on SNES)") : nsign(_)*efbR;


DEFAULT_FIR = 127,0,0,0,0,0,0,0;

firs = par(i, FIR_TAP_COUNT,
	vslider("h:/h:[5]FIR Filter/%i", at(DEFAULT_FIR, i), -128, 127, 1):rint
);


// **** CALCULATIONS

/// Convert [-128..127] volume to [-1, 1) float.
volf = _ / 128.0;

/// Convert SNES sample count to PC samples.
snes2sr = _ * SR / 32000.0;

// Samples per block?
// 16 ms/block * sec/1000ms * SR smp/sec * blocks
/// Echo duration in SNES samples.
echo_len_snes = 512*nblocks;

/// Echo duration in PC samples.
echo_len = snes2sr(echo_len_snes) : rint;


// # SNES echo buffer

// https://github.com/grame-cncm/faustlibraries/blob/master/delays.lib
// FDELAY = fdelay;
ORDER = 8;	// *2+1 breaks for unknown reasons
FIR_LOOKAHEAD = 32;
FDELAY(delay, signal) = fdelaylti(ORDER, FIR_LOOKAHEAD, delay, signal);	// NOTE: The requested delay should not be less than `(order-1)/2`.

/// Maximum volume level before sound is hard-clipped.
CLIP_LEVEL = 1;

/// This replicates the SNES echo buffer.
/// - Data gets fed into the echo buffer at full volume
/// - Echo buffer sent through the FIR filter, and {
/// 	- multiplied by feedback (and added to input) and
/// 	- multiplied by evol (and sent to output)
/// }
snes_feedback(x, feedback) = (
	// Add master and feedback.
	clamp(x + _, -CLIP_LEVEL, CLIP_LEVEL)

	// Store in echo buffer.
	// The maximum possible delay is capped at 128K samples,
	// which *may* be necessary for compilation.
	// Subtract 1 from the echo length, because the ~ operator has 1 sample of delay.
	// Subtract FIR_LOOKAHEAD from the echo buffer and add it to the per-tap delay,
	// because per-tap fractional delays (required to emulate 32000Hz integer delays
	// on PC sampling rates) are acausal.
	: delay(128*K, echo_len - 1 - FIR_LOOKAHEAD, _)

	// 8 FIR taps numbered i=0..7.
	<: volf(sum(i, FIR_TAP_COUNT,
		// coeff i is multiplied with delay 7-i.
		at(firs, i) * FDELAY(FIR_LOOKAHEAD + snes2sr(FIR_TAP_COUNT - 1 - i), _)
		// : attach(_, hbargraph("FIR delay %i", 0, FIR_TAP_COUNT)(i))
	))
) ~ (
	// Feed output into input, delayed by 1 sample.
	volf(feedback*_)
) : (
	// Output audio, delayed by 1 sample.
	_'
);


// **** AUDIO MIXER

snes_echo(signal, mvol, evol, feedback, max_vol) = (
	if(enabled,
		echo * if(normalized, 1/max_vol, output_vol),
		signal
	)
) with {
 	echo = volf(
 		mvol*signal + evol*snes_feedback(signal, feedback)
 	);
};


nbgraph = vbargraph("h:/[6]Echo blocks", 0, MAXBLOCKS);
srgraph = vbargraph("h:/[6]Sample Rate", 32000, 48000);
esnesgraph = vbargraph("h:/[7]SNES samples", 0, 32000);
elengraph = vbargraph("h:/[8]PC samples", 0, 32000);

process(l,r) =
	(snes_echo(l, mvolL, evolL, efbL, max_vol)),
	(snes_echo(r, mvolR, evolR, efbR, max_vol))
	// : attach(_, nbgraph(nblocks))
	// : attach(_, srgraph(SR))
	// : attach(_, esnesgraph(echo_len_snes))
	// : attach(_, elengraph(echo_len))
with {
	mabs(x, y) = max(abs(x), abs(y));
	max_mvol = mabs(mvolL, mvolR);
	max_evol = mabs(evolL, evolR);
	max_vol = max(max(max_mvol, max_evol), 1) : volf;
};
