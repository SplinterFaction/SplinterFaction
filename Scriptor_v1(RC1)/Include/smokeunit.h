/* SmokeUnit.h -- Process unit smoke when damaged */
/* Modified by KhlavKalash */

#ifndef SMOKE_H_
#define SMOKE_H_

#include "SFXtype.h"
#include "EXPtype.h"


#ifdef TAK

SmokeControl()
{

	var healthpercent, smoketype, sleeptime;

#if MAX_DAMAGE_FLAMES > 1
	var x;
#endif

	while( get BUILD_PERCENT_LEFT )
	{
		sleep 400;
	}

	while( TRUE )
	{
		healthpercent = get HEALTH;
#if MAX_DAMAGE_FLAMES > 0
		if( healthpercent < 66 )
		{
			smoketype = ( 256 | 1 );
			if( healthpercent < Rand(1,66) )
			{
				smoketype = ( 256 | 2 );
			}
#if MAX_DAMAGE_FLAMES == 1
			emit-sfx smoketype from damage1;
#else
			x = Rand(0,MAX_DAMAGE_FLAMES);
			if( x == 0 )
			{
				emit-sfx smoketype from damage1;
			}
			else if( x == 1 )
			{
				emit-sfx smoketype from damage2;
			}
#if MAX_DAMAGE_FLAMES > 2
			else if( x == 2 )
			{
				emit-sfx smoketype from damage3;
			}
#if MAX_DAMAGE_FLAMES > 3
			else if( x == 3 )
			{
				emit-sfx smoketype from damage4;
			}
#if MAX_DAMAGE_FLAMES > 4
			else if( x == 4 )
			{
				emit-sfx smoketype from damage5;
			}
#if MAX_DAMAGE_FLAMES > 5
			else if( x == 5 )
			{
				emit-sfx smoketype from damage6;
			}
#if MAX_DAMAGE_FLAMES > 6
			else if( x == 6 )
			{
				emit-sfx smoketype from damage7;
			}
#if MAX_DAMAGE_FLAMES > 7
			else if( x == 7 )
			{
				emit-sfx smoketype from damage8;
			}
#if MAX_DAMAGE_FLAMES > 8
			else if( x == 8 )
			{
				emit-sfx smoketype from damage9;
			}
#endif // end if MAX_DAMAGE_FLAMES > 8
#endif // end if MAX_DAMAGE_FLAMES > 7
#endif // end if MAX_DAMAGE_FLAMES > 6
#endif // end if MAX_DAMAGE_FLAMES > 5
#endif // end if MAX_DAMAGE_FLAMES > 4
#endif // end if MAX_DAMAGE_FLAMES > 3
#endif // end if MAX_DAMAGE_FLAMES > 2
#endif // end if MAX_DAMAGE_FLAMES == 1
		}
#endif // end if MAX_DAMAGE_FLAMES > 0
		sleeptime = ( ( healthpercent * 50 ) + Rand(0,( 1000 / MAX_SMOKE_PUFFS_PER_SECOND )) );
		if( sleeptime < ( 1000 / MAX_SMOKE_PUFFS_PER_SECOND ) )
		{
			sleeptime = ( 1000 / MAX_SMOKE_PUFFS_PER_SECOND );
		}
		sleep sleeptime;
	}
}


#else // #ifdef TA

// Figure out how many smoking pieces are defined

#ifdef SMOKEPIECE4
	#define NUM_SMOKE_PIECES 4
#else
	#ifdef SMOKEPIECE3
		#define NUM_SMOKE_PIECES 3
	#else
		#ifdef SMOKEPIECE2
			#define NUM_SMOKE_PIECES 2
		#else
			#define NUM_SMOKE_PIECES 1
			#ifndef SMOKEPIECE1
				#define SMOKEPIECE1 SMOKEPIECE
			#endif
		#endif
	#endif
#endif


SmokeUnit()
{
	var healthpercent, sleeptime, smoketype;

#if NUM_SMOKE_PIECES > 1
	var choice;
#endif

	// Wait until the unit is actually built
	while (get BUILD_PERCENT_LEFT)
	{
		sleep 400;
	}

	// Smoke loop
	while (TRUE)
	{
		// How is the unit doing?
		healthpercent = get HEALTH;

		if (healthpercent < 66)
		{
			// Emit a puff of smoke

			smoketype = SFXTYPE_BLACKSMOKE;

			if (rand( 1, 66 ) < healthpercent)
			{
				smoketype = SFXTYPE_WHITESMOKE;
			}

		 	// Figure out which piece the smoke will emit from, and spit it out

#if NUM_SMOKE_PIECES == 1
			emit-sfx smoketype from SMOKEPIECE1;
#else
			choice = rand( 1, NUM_SMOKE_PIECES );

			if (choice == 1)
			{	emit-sfx smoketype from SMOKEPIECE1; }
			if (choice == 2)
			{	emit-sfx smoketype from SMOKEPIECE2; }
 #if NUM_SMOKE_PIECES >= 3
			if (choice == 3)
			{	emit-sfx smoketype from SMOKEPIECE3; }
  #if NUM_SMOKE_PIECES >= 4
			if (choice == 4)
			{	emit-sfx smoketype from SMOKEPIECE4; }
  #endif
 #endif
#endif
		}

		// Delay between puffs

		sleeptime = healthpercent * 50;
		if (sleeptime < 200)
		{
			sleeptime = 200;	// Fastest rate is five times per second
		}

		sleep sleeptime;
	}
}

// Clean up pre-processor
#undef NUM_SMOKE_PIECES


#endif // #ifdef TA

#endif // if SMOKE_H_