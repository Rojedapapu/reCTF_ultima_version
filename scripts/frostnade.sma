#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <cstrike>
#include <fun>

new g_frost

native ctf_item( const nombre[], precio, adm, descrip[], admt[] );
forward dar_item( id, item_id );





// AMXX 1.8.2 Compatibility

#if AMXX_VERSION_NUM < 183

    #include <chatcolor>
    #include <dhudmessage>
    
    #define print_team_default  GREY
    #define print_team_red      RED
    #define print_team_blue     BLUE
    #define print_team_grey     GREY
    
    #define Ham_CS_Player_ResetMaxSpeed Ham_Item_PreFrame
    
    #define client_disconnected(%0) client_disconnect(%0)
    
    #define MAX_PLAYERS 32

#endif

/* =================================================================================
*               [ Global ]
* ================================================================================= */

#define PLAYER_ARRAY            ( MAX_PLAYERS + 1 )

#define IsPlayer(%0)            ( 1 <= %0 <= MAX_PLAYERS )

#define GetPlayerBit(%0,%1)     ( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1)     ( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1)   ( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )
#define SwitchPlayerBit(%0,%1)  ( IsPlayer(%1) && ( %0 ^= ( 1 << ( %1 & 31 ) ) ) )

const FROSTNADE_ID = 8878;

const TASK_REMOVE_FREEZE = 100;

enum _:Cvars
{
    CVAR_SHOW_NOVA,
    
    CVAR_FREEZE_SELF,
    CVAR_FREEZE_TEAMMATES,
    CVAR_FREEZE_DURATION
}

new const g_szFreezeSound[ ]    = "frostnade/freeze.wav";
new const g_szUnfreezeSound[ ]  = "frostnade/unfreeze.wav";
new const g_szExplodeSound[ ]   = "frostnade/explode.wav";

new const g_szBeamSprite[ ]     = "sprites/laserbeam.spr";
new const g_szFlareSprite[ ]    = "sprites/flare1.spr";

new const g_szNovaModel[ ]      = "models/rectf_items/nova.mdl";
new const g_szFrostModel[ ]       = "models/rectf_items/v_frost.mdl";
new const g_szInfoTarget[ ]     = "info_target";
new const g_szNovaClassname[ ]  = "Nova";

new g_iIsConnected;
new g_iIsAlive;
new g_iIsFrozen;

new g_iBlueflare;
new g_iBeam;
new g_iScreenFade;
new g_iMaxPlayers;

new bool:g_bEnabled;

new g_pCvars[ Cvars ];

new Float:g_flPlayerVelocity[ PLAYER_ARRAY ][ 3 ];

/* =================================================================================
*               [ Plugin forwards ]
* ================================================================================= */

public plugin_precache( )
{
    precache_sound( g_szFreezeSound );
    precache_sound( g_szUnfreezeSound );
    precache_sound( g_szExplodeSound );
    
    precache_model( g_szNovaModel );
    precache_model(g_szFrostModel);

    g_iBeam         = precache_model( g_szBeamSprite );
    g_iBlueflare    = precache_model( g_szFlareSprite );
}

public plugin_init( )
{
    register_plugin( "FrostNade", "1.0", "Manu" );

    register_event("CurWeapon", "Event_CurWeapon", "be","1=1")

    register_forward( FM_SetModel, "OnSetModel_Pre", false );
    
    RegisterHam( Ham_Think, "grenade", "OnGrenadeThink_Pre", false );
    
    RegisterHam( Ham_Killed, "player", "OnPlayerKilled_Pre", false );
    RegisterHam( Ham_Spawn, "player", "OnPlayerSpawn_Post", true );
    
    register_logevent( "OnRoundStart", 2, "1=Round_Start" );
    register_logevent( "OnRoundEnd", 2, "1=Round_End" );
    
    register_logevent( "OnRoundEnd", 2, "0=World triggered", "1&Restart_Round_" );
    register_logevent( "OnRoundEnd", 2, "0=World triggered", "1=Game_Commencing" );
    
    g_pCvars[ CVAR_SHOW_NOVA ]          = register_cvar( "fn_show_nova", "1" );
    g_pCvars[ CVAR_FREEZE_SELF ]        = register_cvar( "fn_freeze_self", "1" );
    g_pCvars[ CVAR_FREEZE_TEAMMATES ]   = register_cvar( "fn_freeze_teammates", "0" );
    g_pCvars[ CVAR_FREEZE_DURATION ]    = register_cvar( "fn_freeze_duration", "4.0" );
    
    g_frost = ctf_item("FrostNade", 4000, ADMIN_ALL, "Congela al Enemigo", "");
    

    g_iMaxPlayers = get_maxplayers( );
    g_iScreenFade = get_user_msgid( "ScreenFade" );
}

/* =================================================================================
*               [ Events ]
* ================================================================================= */

public Event_CurWeapon(id)
{
    new weaponID = read_data(2)

    if(weaponID != CSW_SMOKEGRENADE)
        return PLUGIN_CONTINUE

    
    set_pev(id, pev_viewmodel2, g_szFrostModel)

    return PLUGIN_CONTINUE
    
}
public OnRoundStart( )
{
    g_bEnabled = true;
}

public OnRoundEnd( )
{
    g_bEnabled = false;
    
    for ( new iPlayer = 1 ; iPlayer <= g_iMaxPlayers ; iPlayer++ )
    {
        if ( !GetPlayerBit( g_iIsFrozen, iPlayer ) )
        {
            continue;
        }
        
        UnfreezePlayer( iPlayer );
    }
}

/* =================================================================================
*               [ Grenade section ]
* ================================================================================= */

public OnSetModel_Pre( const iEnt, const szModel[ ] )
{
    if ( !g_bEnabled )
    {
        return FMRES_IGNORED;
    }
    
    if ( ( strlen( szModel ) != 25 ) || ( ( szModel[ 7 ] != 'w' ) || ( szModel[ 8 ] != '_' ) || ( szModel[ 9 ] != 's' ) ) )
    {
        return FMRES_IGNORED;
    }
    
    if ( entity_get_float( iEnt, EV_FL_dmgtime ) == 0.0 )
    {
        return FMRES_IGNORED;
    }
    
    entity_set_int( iEnt, EV_INT_flTimeStepSound, FROSTNADE_ID );
    
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_BEAMFOLLOW );
    write_short( iEnt );
    write_short( g_iBeam );
    write_byte( 25 );
    write_byte( 3 );
    write_byte( 0 );
    write_byte( 50 );
    write_byte( 250 );
    write_byte( 200 );
    message_end( );
    
    set_rendering( iEnt, kRenderFxGlowShell, 0, 50, 250, kRenderNormal, 16 );
    
    return FMRES_IGNORED;
}

public OnGrenadeThink_Pre( const iEnt )
{
    if (!is_valid_ent(iEnt)) 
        return HAM_IGNORED;

    if ( !g_bEnabled )
        return HAM_IGNORED;
    
    
    if ( entity_get_int( iEnt, EV_INT_flTimeStepSound ) != FROSTNADE_ID )
    {
        return HAM_IGNORED;
    }
    
    if ( entity_get_float( iEnt, EV_FL_dmgtime ) > get_gametime( ) )
    {
        return HAM_IGNORED;
    }
    
    FrostExplode( iEnt );
    
    return HAM_SUPERCEDE;
}

/* =================================================================================
*               [ Player events ]
* ================================================================================= */

public OnPlayerSpawn_Post( const iId )
{
    if ( !is_user_alive( iId ) )
    {
        return HAM_IGNORED;
    }
    
    SetPlayerBit( g_iIsAlive, iId );
    
    return HAM_IGNORED;
}

public OnPlayerKilled_Pre( const iVictim, const iAttacker, const iShouldgib )
{
    ClearPlayerBit( g_iIsAlive, iVictim );
    
    if ( !GetPlayerBit( g_iIsFrozen, iVictim ) )
    {
        return HAM_IGNORED;
    }
    
    UnfreezePlayer( iVictim );
    
    if ( task_exists( iVictim + TASK_REMOVE_FREEZE ) )
    {
        remove_task( iVictim + TASK_REMOVE_FREEZE );
    }
    
    return HAM_IGNORED;
}

public OnTaskRemoveFreeze( const iTask )
{
    new iId = ( iTask - TASK_REMOVE_FREEZE );
    
    if ( !GetPlayerBit( g_iIsFrozen, iId ) )
    {
        return;
    }
    
    UnfreezePlayer( iId );
}

public dar_item(id, item_id)
{
    if( item_id != g_frost || !is_user_alive( id ))
        return;

    if ( user_has_weapon( id, CSW_SMOKEGRENADE ) )
    {
        cs_set_user_bpammo(id, CSW_SMOKEGRENADE, cs_get_user_bpammo(id, CSW_SMOKEGRENADE) + 1);
        return;
    }
    give_item(id, "weapon_smokegrenade");

}

/* =================================================================================
*               [ Client Connection ]
* ================================================================================= */

public client_putinserver( iId )
{
    SetPlayerBit( g_iIsConnected, iId );
}

public client_disconnected( iId )
{
    ClearPlayerBit( g_iIsConnected, iId );
    ClearPlayerBit( g_iIsAlive, iId );
    ClearPlayerBit( g_iIsFrozen, iId );
    
    RemoveEntityByOwner( iId, g_szNovaClassname );
    
    if ( task_exists( iId + TASK_REMOVE_FREEZE ) )
    {
        remove_task( iId + TASK_REMOVE_FREEZE );
    }
}

/* =================================================================================
*               [ Freeze Modules ]
* ================================================================================= */

FreezePlayer( const iId )
{
    SetPlayerBit( g_iIsFrozen, iId );
    
    entity_get_vector( iId, EV_VEC_velocity, g_flPlayerVelocity[ iId ] );
    
    entity_set_vector( iId, EV_VEC_velocity, Float:{ 0.0, 0.0, 0.0 } );
    entity_set_int( iId, EV_INT_flags, entity_get_int( iId, EV_INT_flags ) | FL_FROZEN );
    
    emit_sound( iId, CHAN_BODY, g_szFreezeSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
    
    set_rendering( iId, kRenderFxGlowShell, 0, 60, 240, kRenderNormal, 80 );
    
    SendScreenFade( iId, { 0, 60, 240 }, 4, 0, 0x0000, 40 );
}

UnfreezePlayer( const iId )
{
    ClearPlayerBit( g_iIsFrozen, iId );
    
    entity_set_int( iId, EV_INT_flags, entity_get_int( iId, EV_INT_flags ) & ~FL_FROZEN );
    entity_set_vector( iId, EV_VEC_velocity, g_flPlayerVelocity[ iId ] );
    
    emit_sound( iId, CHAN_BODY, g_szUnfreezeSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
    
    set_rendering( iId );
    
    RemoveEntityByOwner( iId, g_szNovaClassname );
}

/* =================================================================================
*               [ Explosion Modules ]
* ================================================================================= */

FrostExplode( const iEnt )
{
    new iOwner = entity_get_edict( iEnt, EV_ENT_owner );

    if ( !GetPlayerBit( g_iIsConnected, iOwner ) )
    {
        return;
    }
    
    new Float:flOrigin[ 3 ];
    
    entity_get_vector( iEnt, EV_VEC_origin, flOrigin );

    CreateFrostEffect( flOrigin );

    emit_sound( iEnt, CHAN_BODY, g_szExplodeSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
    
    new iTeam = get_pdata_int( iOwner, 114 );
    
    new bool:bShowNova = ( get_pcvar_num( g_pCvars[ CVAR_SHOW_NOVA ] ) > 0 );
    new bool:bFreezeSelf = ( get_pcvar_num( g_pCvars[ CVAR_FREEZE_SELF ] ) > 0 );
    new bool:bFreezeTeammates = ( get_pcvar_num( g_pCvars[ CVAR_FREEZE_TEAMMATES ] ) > 0 );
    
    new Float:flDuration = floatmax( 0.25, get_pcvar_float( g_pCvars[ CVAR_FREEZE_DURATION ] ) );
    
    new iVictim;
    
    while ( ( iVictim = find_ent_in_sphere( iVictim, flOrigin, 250.0 ) ) > 0 )
    {
        if ( !GetPlayerBit( g_iIsAlive, iVictim ) || GetPlayerBit( g_iIsFrozen, iVictim ) )
        {
            continue;
        }
        
        if ( iVictim != iOwner )
        {
            if ( !bFreezeTeammates && ( iTeam == get_pdata_int( iVictim, 114 ) ) )
            {
                continue;
            }
        }
        else if ( !bFreezeSelf )
        {
            continue;
        }
        
        FreezePlayer( iVictim );
        
        if ( bShowNova )
        {
            CreateNova( iVictim );
        }
        
        set_task( flDuration, "OnTaskRemoveFreeze", ( iVictim + TASK_REMOVE_FREEZE ) );
    }
    
    remove_entity( iEnt );
}

CreateFrostEffect( const Float:flOrigin[ 3 ] )
{
    new iOrigin[ 3 ];
    
    FVecIVec( flOrigin, iOrigin );
    
    for ( new i = 1 ; i < 4 ; i++ )
    {
        message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
        write_byte( TE_BEAMCYLINDER );
        write_coord( iOrigin[ 0 ] );
        write_coord( iOrigin[ 1 ] );
        write_coord( iOrigin[ 2 ] );
        write_coord( iOrigin[ 0 ] );
        write_coord( iOrigin[ 1 ] );
        write_coord( iOrigin[ 2 ] + ( i * 111 ) );
        write_short( g_iBeam );
        write_byte( 1 );
        write_byte( 1 );
        write_byte( 5 );
        write_byte( 100 );
        write_byte( 0 );
        write_byte( 0 );
        write_byte( 50 );
        write_byte( 250 );
        write_byte( 200 );
        write_byte( 0 );
        message_end( );
    }
    
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_SPRITETRAIL );
    write_coord( iOrigin[ 0 ] );
    write_coord( iOrigin[ 1 ] );
    write_coord( iOrigin[ 2 ] );
    write_coord( iOrigin[ 0 ] );
    write_coord( iOrigin[ 1 ] );
    write_coord( iOrigin[ 2 ] );
    write_short( g_iBlueflare );
    write_byte( 100 );
    write_byte( 1 );
    write_byte( 2 );
    write_byte( 50 );
    write_byte( 50 );
    message_end( );
    
    message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
    write_byte( TE_DLIGHT );
    write_coord( iOrigin[ 0 ] );
    write_coord( iOrigin[ 1 ] );
    write_coord( iOrigin[ 2 ] );
    write_byte( 48 );
    write_byte( 0 );
    write_byte( 50 );
    write_byte( 255 );
    write_byte( 10 );
    write_byte( 50 );
    message_end( );
}

/* =================================================================================
*               [ Nova Creation ]
* ================================================================================= */

CreateNova( const iId )
{
    new iEnt = create_entity( g_szInfoTarget ); 

    if ( !is_valid_ent( iEnt ) )
    {
        return -1;
    }
    
    new Float:flOrigin[ 3 ];

    entity_get_vector( iId, EV_VEC_origin, flOrigin );
    
    ( entity_get_int( iId, EV_INT_flags ) & FL_DUCKING ) ?
        ( flOrigin[ 2 ] -= 18.0 ) : ( flOrigin[ 2 ] -= 36.0 ); 

    entity_set_string( iEnt, EV_SZ_classname, g_szNovaClassname );

    entity_set_size( iEnt, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 } );
    entity_set_model( iEnt, g_szNovaModel );
    
    entity_set_vector( iEnt, EV_VEC_origin, flOrigin );

    entity_set_int( iEnt, EV_INT_solid, SOLID_NOT );
    entity_set_int( iEnt, EV_INT_movetype, MOVETYPE_FLY );

    entity_set_edict( iEnt, EV_ENT_owner, iId );

    return iEnt;
}

/* =================================================================================
*               [ Remove Entities ]
* ================================================================================= */

RemoveEntityByOwner( const iOwner, const szClassname[ ] )
{
    new iEnt = -1;
    
    while ( ( iEnt = find_ent_by_owner( iEnt, szClassname, iOwner ) ) > 0 )
    {
        remove_entity( iEnt );
    }
}

/* =================================================================================
*               [ Screenfade ]
* ================================================================================= */

SendScreenFade( const iPlayer, const iRGB[ 3 ], const iDuration, const iHoldTime, const iFlag, const iAlpha )
{
    message_begin( MSG_ONE_UNRELIABLE, g_iScreenFade, .player = iPlayer );
    write_short( ( 1<<12 ) * iDuration );
    write_short( ( 1<<12 ) * iHoldTime );
    write_short( iFlag );
    write_byte( iRGB[ 0 ] );
    write_byte( iRGB[ 1 ] );
    write_byte( iRGB[ 2 ] );
    write_byte( iAlpha );
    message_end( );
} 