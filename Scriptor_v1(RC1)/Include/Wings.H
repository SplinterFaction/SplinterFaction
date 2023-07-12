/* Hitweap.h -- Rock the unit when it takes a hit */

#ifndef __HITWEAP_H_
#define __HITWEAP_H_

/*
** HitByWeapon() -- Called when the unit is hit.  Makes it rock a bit
**							to look like it is shaking from the impact.
*/

HitByWeapon(anglex,anglez)
	{
	show Lwing1-2;
	show Lwing2-2;
	show Lwing3-2;
	show Lwing4-2;
	show Rwing1-2;
	show Rwing2-2;
	show Rwing3-2;
	show Rwing4-2;
	turn Lwing1-1 to z-axis <0> speed <82.500000>;
	turn Lwing1-2 to z-axis <0> speed <100.000000>;
	turn Lwing2-1 to z-axis <0> speed <72.500000>;
	turn Lwing2-2 to z-axis <0> speed <100.000000>;
	turn Lwing3-1 to z-axis <0> speed <60.000000>;
	turn Lwing3-2 to z-axis <0> speed <100.000000>;
	turn Lwing4-1 to z-axis <0> speed <37.500000>;
	turn Lwing4-2 to z-axis <0> speed <100.000000>;
	turn Rwing1-1 to z-axis <0> speed <82.500000>;
	turn Rwing1-2 to z-axis <0> speed <100.000000>;
	turn Rwing2-1 to z-axis <0> speed <72.500000>;
	turn Rwing2-2 to z-axis <0> speed <100.000000>;
	turn Rwing3-1 to z-axis <0> speed <60.000000>;
	turn Rwing3-2 to z-axis <0> speed <100.000000>;
	turn Rwing4-1 to z-axis <0> speed <37.500000>;
	turn Rwing4-2 to z-axis <0> speed <100.000000>;
	return (0);
	}
#endif
