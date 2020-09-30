declare name     	"lagrange delay";
declare version  	"0.";
declare author   	"nyanpasu64";
declare license  	"bsd";
declare copyright	"nyanpasu64";

import("delays.lib");

snes2sr = _ * SR / 32000.0;

PRERINGING = 32;	// corrupted output at 256
delayt = vslider("Delay samples", 0.5, 0, 1, 0.01) + PRERINGING;

process(l, r) =
	fdelaylti(PRERINGING, 2*PRERINGING, delayt, l),
	fdelay(2*PRERINGING, delayt, r);
