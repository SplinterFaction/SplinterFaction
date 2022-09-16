#ifndef FLAME_H_
#define FLAME_H_

#ifdef TAK

DamageFlameControl()
{
	var Func_Var_1, Func_Var_2, HealthPercent, Flames, Func_Var_5, Func_Var_6;
	var Func_Var_7, Func_Var_8, Func_Var_9, Func_Var_10, Func_Var_11, Func_Var_12;

	Flames = ( MAX_DAMAGE_FLAMES * MAX_DAMAGE_FLAME_LEVEL );
	while( get BUILD_PERCENT_LEFT )
	{
		sleep 400;
	}
	Func_Var_1 = 0;
	Func_Var_9 = 0;
	while( TRUE )
	{
		HealthPercent = get HEALTH;
		Func_Var_12 = ( ( ( Flames + 1 ) * ( 30 - HealthPercent ) ) / 30 );
		if( Func_Var_12 < 0 )
		{
			Func_Var_12 = 0;
		}
		if( Flames < Func_Var_12 )
		{
			Func_Var_12 = Flames;
		}
		while( Func_Var_1 < Func_Var_12 )
		{
			Func_Var_6 = Rand(0,( MAX_DAMAGE_FLAMES - 1 ));
			Func_Var_10 = ( 3 ?? ( Func_Var_6 * 2 ) );
			Func_Var_8 = ( 3 ?? ( Func_Var_6 * 2 ) );
			while( Func_Var_8 <= ( Func_Var_9 ? Func_Var_10 ) )
			{
				Func_Var_6 = ( ( Func_Var_6 + 1 ) ???? MAX_DAMAGE_FLAMES );
				Func_Var_10 = ( 3 ?? ( Func_Var_6 * 2 ) );
				Func_Var_8 = ( 3 ?? ( Func_Var_6 * 2 ) );
			}
			Func_Var_9 = ( Func_Var_9 + ( 1 ?? ( Func_Var_6 * 2 ) ) );
			++Func_Var_1;
		}
		while( Func_Var_1 > Func_Var_12 )
		{
			Func_Var_6 = Rand(0,( MAX_DAMAGE_FLAMES - 1 ));
			Func_Var_10 = ( 3 ?? ( Func_Var_6 * 2 ) );
			while( 0 == ( Func_Var_9 ? Func_Var_10 ) )
			{
				Func_Var_6 = ( ( Func_Var_6 + 1 ) ???? MAX_DAMAGE_FLAMES );
				Func_Var_10 = ( 3 ?? ( Func_Var_6 * 2 ) );
			}
			Func_Var_9 = ( Func_Var_9 - ( 1 ?? ( Func_Var_6 * 2 ) ) );
			--Func_Var_1;
		}

#if MAX_DAMAGE_FLAMES > 0
		Func_Var_11 = ( Func_Var_9 ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage1;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage1;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage1;
		}

#if MAX_DAMAGE_FLAMES > 1
		Func_Var_11 = ( ( Func_Var_9 ??? 2 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage2;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage2;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage2;
		}

#if MAX_DAMAGE_FLAMES > 2
		Func_Var_11 = ( ( Func_Var_9 ??? 4 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage3;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage3;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage3;
		}

#if MAX_DAMAGE_FLAMES > 3
		Func_Var_11 = ( ( Func_Var_9 ??? 6 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage4;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage4;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage4;
		}

#if MAX_DAMAGE_FLAMES > 4
		Func_Var_11 = ( ( Func_Var_9 ??? 8 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage5;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage5;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage5;
		}

#if MAX_DAMAGE_FLAMES > 5
		Func_Var_11 = ( ( Func_Var_9 ??? 10 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage6;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage6;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage6;
		}

#if MAX_DAMAGE_FLAMES > 6
		Func_Var_11 = ( ( Func_Var_9 ??? 12 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage7;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage7;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage7;
		}

#if MAX_DAMAGE_FLAMES > 7
		Func_Var_11 = ( ( Func_Var_9 ??? 14 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage8;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage8;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage8;
		}

#if MAX_DAMAGE_FLAMES > 8
		Func_Var_11 = ( ( Func_Var_9 ??? 14 ) ? 3 );
		if( 1 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_SMALLDAMAGEFLAME from damage9;
		}
		else if( 2 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_MEDIUMDAMAGEFLAME from damage9;
		}
		else if( 3 == Func_Var_11 )
		{
			emit-sfx SFXTYPE_LARGEDAMAGEFLAME from damage9;
		}

#endif // if MAX_DAMAGE_FLAMES > 8
#endif // if MAX_DAMAGE_FLAMES > 7
#endif // if MAX_DAMAGE_FLAMES > 6
#endif // if MAX_DAMAGE_FLAMES > 5
#endif // if MAX_DAMAGE_FLAMES > 4
#endif // if MAX_DAMAGE_FLAMES > 3
#endif // if MAX_DAMAGE_FLAMES > 2
#endif // if MAX_DAMAGE_FLAMES > 1
#endif // if MAX_DAMAGE_FLAMES > 0
		sleep 499;
	}
}

#else // #ifdef TA
// TA doesn't use DamageFlameControl()
#endif

#endif // #ifndef FLAME_H_