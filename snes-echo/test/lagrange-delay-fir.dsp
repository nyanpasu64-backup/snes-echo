declare name     	"lagrange delay";
declare version  	"0.";
declare author   	"nyanpasu64";
declare license  	"bsd";
declare copyright	"nyanpasu64";

import("math.lib");
import("stdfaust.lib");
import("delays.lib");

snes2sr = _ * SR / 32000.0;

DELAY = 32;
ORDER = DELAY;


FIR_NDELAY = 1;

delayt = vslider("Delay samples", 0.5, 0, 1, 0.01) + DELAY;

fir_delay(i, signal) = fdelaylti(ORDER, 2*DELAY, DELAY + snes2sr(i), signal);

process(l, r) = (
	fdelaylti(ORDER, 2*DELAY, delayt, l)
	,
	/*fdelay(2*DELAY, delayt, r)*/

	// 8 FIR taps, with delays from 0..7.
	// coeff x is multiplied with delay 7-x.
	sum(
		i, FIR_NDELAY,
		1/8 * fir_delay(FIR_NDELAY-1 - i, r)
	)
);
