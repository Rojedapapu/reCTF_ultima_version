#include <amxmodx>
#include <hamsandwich>
#include <engine>

/* =================================================================================
 *              [ Global Stuff ]
 * ================================================================================== */

#define PLAYER_ARRAY                33

#define IsPlayer(%0)                ( 1 <= %0 <= g_iMaxPlayers )

#define GetPlayerBit(%0,%1)         ( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1)         ( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1)       ( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )

new const g_szParachuteClass[ ] = "Parachute";
new const g_szParachuteModel[ ] = "models/lwf_parachute.mdl";

new g_pCvarFallSpeed;
new g_pCvarFlags;

new g_iIsAlive;
new g_iIsParachuteInUse;
new g_iIsParachuteAllowed;

new g_iMaxPlayers;
new g_iRequiredFlags;
new Float:g_flFallSpeed;

new g_iPlayerParachute[ 33 ];

/* =================================================================================
 *              [ Plugin events ]
 * ================================================================================== */

public plugin_precache( )
	precache_model( g_szParachuteModel );


public plugin_init( )
{
	register_plugin( "Parachute", "1.0", "Manu" );
	
	RegisterHam( Ham_Spawn, "player", "OnPlayerSpawn_Post", true );
	RegisterHam( Ham_Killed, "player", "OnPlayerKilled_Post", true );
	RegisterHam( Ham_Player_PreThink, "player", "OnPlayerPreThink_Post", true );
	
	g_iMaxPlayers       = get_maxplayers( );
	
	g_pCvarFallSpeed 	= register_cvar( "parachute_speed", "50.0" );
	g_pCvarFlags 		= register_cvar( "parachute_flags", "b" );
}

public plugin_cfg( )
{
	DoCacheCvars( );
}

/* =================================================================================
 *              [ Forwards ]
 * ================================================================================== */

public OnPlayerSpawn_Post( iId )
{
	if ( !is_user_alive( iId ) )
		return HAM_IGNORED;
	
	SetPlayerBit( g_iIsAlive, iId );
	
	if ( GetPlayerBit( g_iIsParachuteInUse, iId ) )
	{
		StopUsingParachute( iId );
	}
	
	UpdateParachute( iId );
	
	return HAM_IGNORED;
}

public OnPlayerKilled_Post( iId )
{
	ClearPlayerBit( g_iIsAlive, iId );
	
	if ( GetPlayerBit( g_iIsParachuteInUse, iId ) )
	{
		StopUsingParachute( iId );
	}
}

public OnPlayerPreThink_Post( iId )
{
	if ( !GetPlayerBit( g_iIsAlive, iId ) || !GetPlayerBit( g_iIsParachuteAllowed, iId ) )
		return HAM_IGNORED;
	
	static iFlags; iFlags = entity_get_int( iId, EV_INT_flags );
	static iButton; iButton = entity_get_int( iId, EV_INT_button );
	
	if ( iFlags & FL_ONGROUND )
	{
		if ( GetPlayerBit( g_iIsParachuteInUse, iId ) )
		{
			StopUsingParachute( iId );
		}
		
		return HAM_IGNORED;
	}
	
	if ( ~iButton & IN_USE )
	{
		if ( GetPlayerBit( g_iIsParachuteInUse, iId ) )
		{
			StopUsingParachute( iId );
		}
		
		return HAM_IGNORED;
	}
	
	static Float:flVelocity[ 3 ];
	
	entity_get_vector( iId, EV_VEC_velocity, flVelocity );
	
	if ( flVelocity[ 2 ] >= 0.0 )
	{
		if ( GetPlayerBit( g_iIsParachuteInUse, iId ) )
		{
			StopUsingParachute( iId );
		}
		
		return HAM_IGNORED;
	}
	
	flVelocity[ 2 ] = floatmin( ( flVelocity[ 2 ] + 40.0 ), g_flFallSpeed ); 
	
	entity_set_vector( iId, EV_VEC_velocity, flVelocity );
	
	entity_set_float( iId, EV_FL_gravity, 0.1 );
	
	entity_set_int( iId, EV_INT_sequence, 3 );
	entity_set_int( iId, EV_INT_gaitsequence, 1 );
	
	entity_set_float( iId, EV_FL_frame, 1.0 );
	entity_set_float( iId, EV_FL_framerate, 1.0 );
	
	if ( !GetPlayerBit( g_iIsParachuteInUse, iId ) )
	{
		entity_set_int( g_iPlayerParachute[ iId ], EV_INT_effects, ( entity_get_int( g_iPlayerParachute[ iId ], EV_INT_effects ) & ~EF_NODRAW ) );
		
		SetPlayerBit( g_iIsParachuteInUse, iId );
	}
	
	return HAM_IGNORED;
}

/* =================================================================================
 *              [ Client Connection ]
 * ================================================================================== */

public client_disconnected( iId )
{
	ClearPlayerBit( g_iIsAlive, iId );
	ClearPlayerBit( g_iIsParachuteInUse, iId );
	ClearPlayerBit( g_iIsParachuteAllowed, iId );
	
	if ( is_valid_ent( g_iPlayerParachute[ iId ] ) )
	{
		remove_entity( g_iPlayerParachute[ iId ] );
	}
	
	g_iPlayerParachute[ iId ] = 0;
}

/* =================================================================================
 *              [ Modules ]
 * ================================================================================== */

CreateParachute( const iId )
{
	new iEnt = create_entity( "info_target" );
	
	if ( !is_valid_ent( iEnt ) )
	{
		return -1;
	}
	
	entity_set_string( iEnt, EV_SZ_classname, g_szParachuteClass );
	entity_set_model( iEnt, g_szParachuteModel );
	
	entity_set_edict( iEnt, EV_ENT_aiment, iId );
	entity_set_edict( iEnt, EV_ENT_owner, iId );
	
	entity_set_int( iEnt, EV_INT_movetype, MOVETYPE_FOLLOW );
	
	entity_set_int( iEnt, EV_INT_sequence, 0 );
	entity_set_int( iEnt, EV_INT_gaitsequence, 1 );
	
	entity_set_float( iEnt, EV_FL_frame, 0.0 );
	entity_set_float( iEnt, EV_FL_fuser1, 0.0 );
	entity_set_int( iEnt, EV_INT_effects, ( entity_get_int( iEnt, EV_INT_effects ) | EF_NODRAW ) );
	
	return iEnt;
}

StopUsingParachute( const iId )
{
	ClearPlayerBit( g_iIsParachuteInUse, iId );
	
	entity_set_float( iId, EV_FL_gravity, 1.0 );
	entity_set_int( g_iPlayerParachute[ iId ], EV_INT_effects, ( entity_get_int( g_iPlayerParachute[ iId ], EV_INT_effects ) | EF_NODRAW ) );
}

UpdateParachute( const iId )
{
	new iFlags = get_user_flags( iId );

	SetPlayerBit( g_iIsParachuteAllowed, iId );
		
	if ( !is_valid_ent( g_iPlayerParachute[ iId ] ) )
	{
		g_iPlayerParachute[ iId ] = CreateParachute( iId );
	}
	
	/*if ( iFlags & g_iRequiredFlags )
	{
		SetPlayerBit( g_iIsParachuteAllowed, iId );
		
		if ( !is_valid_ent( g_iPlayerParachute[ iId ] ) )
		{
			g_iPlayerParachute[ iId ] = CreateParachute( iId );
		}
	}
	else
	{
		ClearPlayerBit( g_iIsParachuteAllowed, iId );
		
		if ( is_valid_ent( g_iPlayerParachute[ iId ] ) )
		{
			remove_entity( g_iPlayerParachute[ iId ] );
		}
		
		g_iPlayerParachute[ iId ] = 0;
	}*/
}

DoCacheCvars( )
{
	new szFlags[ 16 ];
	
	get_pcvar_string( g_pCvarFlags, szFlags, charsmax( szFlags ) );
	
	g_iRequiredFlags = read_flags( szFlags );
	g_flFallSpeed = ( get_pcvar_float( g_pCvarFallSpeed ) * -1.0 );
}