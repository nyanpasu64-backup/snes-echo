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

// do not use pow2up/down, (passing in SR?) causes infinite runtime in FAUST compiler.

// Zero-indexing.
at(list, idx) = ba.subseq(list, idx, 1);

yes   	(bool) = bool;
not   	(bool) = 1-bool;
if(cond, then, else) = cond*then + (1-cond)*else;

signed	(bool) = 2*bool - 1;
nsign 	(bool) = 1 - 2*bool;

clamp(x, low, high) = min(max(x, low), high);


// **** BEGIN PROGRAM

FIR_NDELAY = 8;

DELAY = 32;
SR_MAX_DELAY = 2 * DELAY;

ORDER = 8;	// *2+1 breaks for unknown reasons


enabled = checkbox("h:/v:[1]/[1]Echo Enabled");
normalized = checkbox("h:/v:[1]/[2]Normalize Volumes");
output_vol = 1;	// vslider("h:/v:[1]/[3]Output Volume", 2, 1, 2, 0.1);

// EDL register
MAXBLOCKS = 15;		// * 16ms/blk = 1024ms
nblocks = vslider("h:/v:[1]/[0]Echo blocks (16ms)", 5, 1, MAXBLOCKS, 1):rint;

mvolSign = checkbox("h:/v:[2]Master Volume/Negative"):nsign;
mvol2 =  vslider("h:/v:[2]Master Volume/Master Volume", 63, 0, 127, 1) * mvolSign:rint;
mvol1 = checkbox("h:/v:[2]Master Volume/Surround") : nsign(_)*mvol2;

evolSign = checkbox("h:/v:[3]Echo Volume/Negative"):nsign;
evol2 =  vslider("h:/v:[3]Echo Volume/Echo Volume", 25, 0, 127, 1) * evolSign:rint;
evol1 = checkbox("h:/v:[3]Echo Volume/Surround") : nsign(_)*evol2;

efbSign = checkbox("h:/v:[4]Echo Feedback/Negative"):nsign;
efb2 =  vslider("h:/v:[4]Echo Feedback/Echo Feedback", 70, 0, 127, 1) * efbSign:rint;
efb1 = checkbox("h:/v:[4]Echo Feedback/Surround (not on SNES)") : nsign(_)*efb2;



default_fir = 127,0,0,0,0,0,0,0;

firs = par(i, FIR_NDELAY,
	vslider("h:/h:[5]FIR Filter/%i", at(default_fir, i), -128, 127, 1):rint
);



// **** CALCULATIONS

// Volume function
volf = _ / 128.0;	// 0x80;
snes2sr = _ * SR / 32000.0;


// Samples per block?
// 16 ms/block * sec/1000ms * SR smp/sec * blocks

// Fake FIR filter...
echo_len_snes = 512*nblocks;
echo_len = snes2sr(echo_len_snes) : rint;


/* SNES ECHO BUFFER
This replicates the SNES echo buffer.
- Data gets fed into the echo buffer at full volume
- Echo buffer sent through the FIR filter, and {
	- multiplied by feedback (and added to input) and
	- multiplied by evol (and sent to output)
}
*/


// https://github.com/grame-cncm/faustlibraries/blob/master/delays.lib

// FDELAY = fdelay;
FDELAY(maxdelay, delay, signal) = fdelaylti(ORDER, maxdelay, delay, signal);	// NOTE: The requested delay should not be less than `(order-1)/2`.

fir_delay(i, signal) = FDELAY(SR_MAX_DELAY, DELAY + snes2sr(i), signal);

CLAMP = 1;
snes_feedback(x, feedback) = (
	// Add master and echo.
	clamp(_ + x, -CLAMP, CLAMP)

	// Store in echo buffer.
	: delay(131072, echo_len - 1 - DELAY, _)	// TODO: probably can't remove magic #

	// 8 FIR taps, with delays from 0..7.
	// coeff x is multiplied with delay 7-x.
	<: volf(sum(i, FIR_NDELAY,
		at(firs, i) * fir_delay(FIR_NDELAY-1 - i, _)
			// : attach(_, hbargraph("FIR delay %i", 0, FIR_NDELAY)(i))
	))

// * FEEDBACK
) ~ (
	// Volume
	volf(feedback*_)

// * OUTPUT
) : (
	// Match 1-sample delay
	_@1
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
	(snes_echo(l, mvol1, evol1, efb1, max_vol)),
	(snes_echo(r, mvol2, evol2, efb2, max_vol))
	// : attach(_, nbgraph(nblocks))
	// : attach(_, srgraph(SR))
	// : attach(_, esnesgraph(echo_len_snes))
	// : attach(_, elengraph(echo_len))
with {
	mabs(x, y) = max(abs(x), abs(y));
	max_mvol = mabs(mvol1, mvol2);
	max_evol = mabs(evol1, evol2);
	max_vol = max(max(max_mvol, max_evol), 1) : volf;
};
