/*
	Just Capture the Flag - Versión reAPI ( reCTF )

	Ultimos cambios

	- orpheu removido
	- se re armo el código con reAPI
	- se removio código innecesario


	Ultimos cambios 15/09/2020
	Cambios Hechos por Hypnotize ( https://amxmodx-es.com/Hypnotize )
*/

new const MOD_TITLE[] =			"re Just Capture the Flag"	/* Please don't modify. */
new const MOD_AUTHOR[] =		"Digi"			/* If you make major changes, add " & YourName" at the end */
new const MOD_VERSION[] =		"1.0b"			/* If you make major changes, add "custom" at the end but do not modify the actual version number! */

#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <print_center_fx>

native set_user_coins(id, cant);
native get_user_coins(id);

#define REWARD_RETURN				10,		0,		10
#define REWARD_RETURN_ASSIST			10,		0,		10

#define REWARD_CAPTURE				10,		3,		10
#define REWARD_CAPTURE_ASSIST			10,		3,		10
#define REWARD_CAPTURE_TEAM			10,		0,		10

#define REWARD_STEAL				10,		1,		10
#define REWARD_PICKUP				10,		1,		10
#define PENALTY_DROP				-10,	-1,		-10

#define REWARD_KILL				0,		0,		10
#define REWARD_KILLCARRIER			10,		1,		10

#define PENALTY_SUICIDE				0,		0,		-10
#define PENALTY_TEAMKILL			0,		0,		-10

const ADMIN_RETURN =				ADMIN_RCON	// access required for admins to return flags (full list in includes/amxconst.inc)
const ADMIN_RETURNWAIT =			15		// time the flag needs to stay dropped before it can be returned by command

const Float:SPEED_FLAG =			0.9		// speed while carying the enemy flag

new const Float:BASE_HEAL_DISTANCE =	96.0		// healing distance for flag

new const FLAG_SAVELOCATION[] =		"maps/%s.ctf" // you can change where .ctf files are saved/loaded from

new const INFO_TARGET[] =			"info_target"
new const WEAPONBOX[] =				"weaponbox"

new const BASE_CLASSNAME[] =			"ctf_flagbase"
new const Float:BASE_THINK =			0.25

new const FLAG_CLASSNAME[] =			"ctf_flag"
new const FLAG_MODEL[] =			"models/lwf_bandera.mdl"
new modelIndex_flag;

new const Float:FLAG_THINK =			0.1
const FLAG_SKIPTHINK =				20 /* FLAG_THINK * FLAG_SKIPTHINK = 2.0 seconds ! */

new const Float:FLAG_HULL_MIN[3] =		{-2.0, -2.0, 0.0}
new const Float:FLAG_HULL_MAX[3] =		{2.0, 2.0, 16.0}

new const Float:FLAG_SPAWN_VELOCITY[3] =	{0.0, 0.0, -500.0}
new const Float:FLAG_SPAWN_ANGLES[3] =	{0.0, 0.0, 0.0}

new const Float:FLAG_DROP_VELOCITY[3] =	{0.0, 0.0, 50.0}

new const Float:FLAG_PICKUPDISTANCE =	80.0

const FLAG_LIGHT_RANGE =			12
const FLAG_LIGHT_LIFE =				5
const FLAG_LIGHT_DECAY =			1

const FLAG_ANI_DROPPED =			0
const FLAG_ANI_STAND =				1
const FLAG_ANI_BASE =				2

const FLAG_HOLD_BASE =				33
const FLAG_HOLD_DROPPED =			34

new const SND_GETMEDKIT[] =			"items/smallmedkit1.wav"

new const CHAT_PREFIX[] =			"^x03[^x04 reCTF^x03 ]^x01 "
new const CONSOLE_PREFIX[] =			"[ reCTF ] "

const FADE_OUT =					0x0000
const FADE_IN =					0x0001

new const PLAYER[] =				"player"

#define NULL					""

#define HUD_HINT					255, 255, 255, 0.15, -0.3, 0, 0.0, 10.0, 2.0, 10.0, 4
#define HUD_HELP					255, 255, 0, -1.0, 0.2, 2, 0.1, 2.0, 0.01, 2.0, 2
#define HUD_HELP2					255, 255, 0, -1.0, 0.25, 2, 0.1, 2.0, 0.01, 2.0, 3
#define HUD_ANNOUNCE				-1.0, 0.3, 0, 0.0, 3.0, 0.1, 1.0, 4
#define HUD_RESPAWN				0, 255, 0, -1.0, 0.6, 2, 0.5, 0.1, 0.0, 1.0, 1
#define HUD_PROTECTION				255, 255, 0, -1.0, 0.6, 2, 0.5, 0.1, 0.0, 1.0, 1
#define HUD_ADRENALINE				255, 255, 255, -1.0, -0.1, 0, 0.0, 600.0, 0.0, 0.0, 1

#define entity_spawn(%1)			DispatchSpawn(%1)
#define weapon_remove(%1)			call_think(%1)

#define task_set(%1)				set_task(%1)
#define task_remove(%1)				remove_task(%1)

#define player_hasFlag(%1)			(g_iFlagHolder[TEAM_RED] == %1 || g_iFlagHolder[TEAM_BLUE] == %1)

#define player_allowChangeTeam(%1)		set_pdata_int(%1, 125, get_pdata_int(%1, 125) & ~(1<<8))

#define gen_color(%1,%2)			%1 == TEAM_RED ? %2 : 0, 0, %1 == TEAM_RED ? 0 : %2

#define get_opTeam(%1)				(%1 == TEAM_BLUE ? TEAM_RED : (%1 == TEAM_RED ? TEAM_BLUE : 0))

enum
{
	x,
	y,
	z
}

enum
{
	pitch,
	yaw,
	roll
}

enum (+= 64)
{
	TASK_RESPAWN = 64,
	TASK_PROTECTION,
	TASK_DAMAGEPROTECTION,
	TASK_EQUIPAMENT,
	TASK_PUTINSERVER,
	TASK_TEAMBALANCE,
	TASK_ADRENALINE,
	TASK_DEFUSE,
	TASK_CHECKHP
}

enum
{
	TEAM_NONE = 0,
	TEAM_RED,
	TEAM_BLUE,
	TEAM_SPEC
}

new const g_szCSTeams[][] =
{
	NULL,
	"TERRORIST",
	"CT",
	"SPECTATOR"
}

new const g_szTeamName[][] =
{
	NULL,
	"Red",
	"Blue",
	"Spectator"
}

new const g_szMLTeamName[][] =
{
	NULL,
	"TEAM_RED",
	"TEAM_BLUE",
	"TEAM_SPEC"
}

new const g_szMLFlagTeam[][] =
{
	NULL,
	"FLAG_RED",
	"FLAG_BLUE",
	NULL
}

enum
{
	FLAG_STOLEN = 0,
	FLAG_PICKED,
	FLAG_DROPPED,
	FLAG_MANUALDROP,
	FLAG_RETURNED,
	FLAG_CAPTURED,
	FLAG_AUTORETURN,
	FLAG_ADMINRETURN
}

enum
{
	EVENT_TAKEN = 0,
	EVENT_DROPPED,
	EVENT_RETURNED,
	EVENT_SCORE,
}

new const g_szSounds[][][] =
{
	{NULL, "red_flag_taken", "blue_flag_taken"},
	{NULL, "red_flag_dropped", "blue_flag_dropped"},
	{NULL, "red_flag_returned", "blue_flag_returned"},
	{NULL, "red_team_scores", "blue_team_scores"}
}

new const g_szRemoveEntities[][] =
{
	"func_buyzone",
	"armoury_entity",
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"info_map_parameters",
	"player_weaponstrip",
	"game_player_equip"
}

new g_szMap[32],
	g_szGame[16],
	g_iTeam[33],
	g_iScore[3],
	g_iFlagHolder[3],
	g_iFlagEntity[3],
	g_iBaseEntity[3];

new bool:g_bRestarting,
	bool:g_bAlive[33],
	bool:g_bDefuse[33],
	bool:g_bBuyZone[33],
	bool:g_bSuicide[33],
	bool:g_bFreeLook[33],
	bool:g_bAssisted[33][3],
	bool:g_bProtected[33],
	bool:g_bRestarted[33],
	bool:g_bFirstSpawn[33],
	bool:dojump[33][2];

new jumpnum[33],
	g_adrenaline[33];

new Float:g_fFlagBase[3][3],
	Float:g_fFlagLocation[3][3],
	Float:g_fLastDrop[33],
	Float:g_fLastBuy[33][4],
	Float:g_fFlagDropped[3];

new pCvar_ctf_flagcaptureslay,
	pCvar_ctf_flagheal,
	pCvar_ctf_flagreturn,
	pCvar_ctf_respawntime,
	pCvar_ctf_protection,
	pCvar_ctf_glows,
	pCvar_ctf_weaponstay,
	cvar_autoregenerate, 
	cvar_healh_regenerate,
	cvar_regenerate_time,
	cvar_speed,
	cvar_weapons;

new pCvar_ctf_sound[4],
	pCvar_mp_winlimit,
	pCvar_mp_startmoney,
	pCvar_mp_fadetoblack,
	pCvar_mp_forcecamera,
	pCvar_mp_forcechasecam,
	pCvar_mp_autoteambalance

new gMsg_SayText,
	gMsg_RoundTime,
	gMsg_ScreenFade,
	gMsg_HostageK,
	gMsg_HostagePos,
	gMsg_ScoreInfo,
	gMsg_ScoreAttrib,
	gMsg_TextMsg,
	gMsg_TeamScore;

new g_iMaxPlayers,
	gHook_EntSpawn,
	gSpr_regeneration,
	g_iForwardReturn,
	g_iFW_flag,
	gHealingBeam;

public plugin_precache()
{
	static szSound[64], i;

	gHealingBeam = precache_model("sprites/arrow.spr");

	modelIndex_flag = precache_model(FLAG_MODEL)

	precache_sound(SND_GETMEDKIT)

	gSpr_regeneration = precache_model("sprites/th_jctf_heal.spr")

	for( i = 0; i < sizeof g_szSounds; i++ )
	{
		for(new t = 1; t <= 2; t++)
		{
			formatex(szSound, charsmax(szSound), "sound/lwf/%s.mp3", g_szSounds[i][t]);
			precache_generic(szSound);
		}
	}

	gHook_EntSpawn = register_forward(FM_Spawn, "ent_spawn");
}

public ent_spawn(ent)
{
	if( !is_entity( ent ) )
		return FMRES_IGNORED

	static szClass[32]

	get_entvar(ent, var_classname, szClass, charsmax(szClass))

	for(new i = 0; i < sizeof g_szRemoveEntities; i++)
	{
		if(equal(szClass, g_szRemoveEntities[i]))
		{
			remove_entity(ent)
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public plugin_init()
{
	register_plugin(MOD_TITLE, MOD_VERSION, MOD_AUTHOR);

	set_lights("j");

	set_member_game(m_GameDesc, MOD_TITLE);
	
	register_dictionary("jctf.txt");
	register_dictionary("common.txt");

	set_cvar_num("sv_airaccelerate", 9999);

	// Forwards, hooks, events, etc
	unregister_forward(FM_Spawn, gHook_EntSpawn);

	register_touch(FLAG_CLASSNAME, PLAYER, "flag_touch");

	register_think(FLAG_CLASSNAME, "flag_think");
	register_think(BASE_CLASSNAME, "base_think");

	register_logevent("event_restartGame", 2, "1&Restart_Round", "1&Game_Commencing");
	register_event("HLTV", "event_roundStart", "a", "1=0", "2=0");

	register_clcmd("fullupdate", "msg_block");
	register_clcmd("buy", "msg_block");
	register_clcmd("buyammo1", "msg_block");
	register_clcmd("buyammo2", "msg_block");
	register_clcmd("primammo", "msg_block");
	register_clcmd("secammo", "msg_block");
	register_clcmd("client_buy_open", "msg_block");
	register_clcmd("say /rs", "reset_score");
	register_clcmd("say rs", "reset_score");
	register_clcmd("say /spect", "go_spect");

	register_clcmd("autobuy", "msg_block");
	register_clcmd("cl_autobuy", "msg_block");
	register_clcmd("cl_setautobuy", "msg_block");

	register_clcmd("rebuy", "msg_block");
	register_clcmd("cl_rebuy", "msg_block");
	register_clcmd("cl_setrebuy", "msg_block");

	register_event("TeamInfo", "player_joinTeam", "a");

	RegisterHookChain( RG_CBasePlayer_Spawn, "@player_spawn", .post = true );
	RegisterHookChain( RG_CBasePlayer_Killed, "@player_killed", .post = true );
	RegisterHookChain( RG_CBasePlayer_TakeDamage, "@player_damage", .post = false );
	RegisterHookChain( RG_CBasePlayer_ResetMaxSpeed, "@fw_ResetMaxSpeed_Post", .post = true );
	RegisterHookChain( RG_CBasePlayer_Jump, "@fw_PlayerJump_Pre", .post = false );
	
	register_clcmd("ctf_moveflag", "admin_cmd_moveFlag", ADMIN_RCON, "<red/blue> - Moves team's flag base to your origin (for map management)");
	register_clcmd("ctf_save", "admin_cmd_saveFlags", ADMIN_RCON);
	register_clcmd("ctf_return", "admin_cmd_returnFlag", ADMIN_RETURN);

	register_clcmd("dropflag", "player_cmd_dropFlag");
	register_clcmd("say /dropflag", "player_cmd_dropFlag");

	RegisterHam(Ham_Spawn, WEAPONBOX, "weapon_spawn", 1);

	gMsg_HostagePos = get_user_msgid("HostagePos");
	gMsg_HostageK = get_user_msgid("HostageK");
	gMsg_RoundTime = get_user_msgid("RoundTime");
	gMsg_SayText = get_user_msgid("SayText");
	gMsg_ScoreInfo = get_user_msgid("ScoreInfo");
	gMsg_ScoreAttrib = get_user_msgid("ScoreAttrib");
	gMsg_ScreenFade = get_user_msgid("ScreenFade");
	gMsg_TextMsg = get_user_msgid("TextMsg");
	gMsg_TeamScore = get_user_msgid("TeamScore");

	register_message(gMsg_TextMsg, "msg_textMsg");
	register_message(get_user_msgid("BombDrop"), "msg_block");
	register_message(gMsg_HostageK, "msg_block");
	register_message(gMsg_HostagePos, "msg_block");
	register_message(gMsg_RoundTime, "msg_roundTime");
	register_message(gMsg_ScreenFade, "msg_screenFade");
	register_message(gMsg_ScoreAttrib, "msg_scoreAttrib");
	register_message(gMsg_TeamScore, "msg_teamScore");
	register_message(gMsg_SayText, "msg_sayText");

	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

	// CVARs
	cvar_speed = register_cvar("ctf_speed", "0");
	cvar_weapons = register_cvar("ctf_weapons", "1");
	pCvar_ctf_flagcaptureslay = register_cvar("ctf_flagcaptureslay", "0");
	pCvar_ctf_flagheal = register_cvar("ctf_flagheal", "1");
	pCvar_ctf_flagreturn = register_cvar("ctf_flagreturn", "120");
	pCvar_ctf_respawntime = register_cvar("ctf_respawntime", "3");
	pCvar_ctf_protection = register_cvar("ctf_protection", "2");
	pCvar_ctf_glows = register_cvar("ctf_glows", "1");
	pCvar_ctf_weaponstay = register_cvar("ctf_weaponstay", "6");

	cvar_autoregenerate = register_cvar("ctf_autoregeneratet", "1");
	cvar_healh_regenerate = register_cvar("ctf_healh_regenerate", "2.0");
	cvar_regenerate_time = register_cvar("ctf_regenerate_time", "4.0");

	pCvar_ctf_sound[EVENT_TAKEN] = register_cvar("ctf_sound_taken", "1");
	pCvar_ctf_sound[EVENT_DROPPED] = register_cvar("ctf_sound_dropped", "1");
	pCvar_ctf_sound[EVENT_RETURNED] = register_cvar("ctf_sound_returned", "1");
	pCvar_ctf_sound[EVENT_SCORE] = register_cvar("ctf_sound_score", "1");
	

	pCvar_mp_winlimit = get_cvar_pointer("mp_winlimit");
	pCvar_mp_startmoney = get_cvar_pointer("mp_startmoney");
	pCvar_mp_fadetoblack = get_cvar_pointer("mp_fadetoblack");
	pCvar_mp_forcecamera = get_cvar_pointer("mp_forcecamera");
	pCvar_mp_forcechasecam = get_cvar_pointer("mp_forcechasecam");
	pCvar_mp_autoteambalance = get_cvar_pointer("mp_autoteambalance");

	// Plugin's forwards

	g_iFW_flag = CreateMultiForward("jctf_flag", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);


	// Variables

	new szGame[3];

	get_modname(szGame, charsmax(szGame));

	if(szGame[0] == 'c')
	{
		switch(szGame[1])
		{
			case 's': copy(g_szGame, charsmax(g_szGame), "CS 1.6 "); // leave the space at the end
			case 'z': copy(g_szGame, charsmax(g_szGame), "CS:CZ ");
		}
	}

	get_mapname(g_szMap, charsmax(g_szMap));

	g_iMaxPlayers = get_maxplayers( );

}

public plugin_cfg()
{
	new szFile[64]

	formatex(szFile, charsmax(szFile), FLAG_SAVELOCATION, g_szMap)

	new hFile = fopen(szFile, "rt")

	if(hFile)
	{
		new iFlagTeam = TEAM_RED
		new szData[24]
		new szOrigin[3][6]

		while(fgets(hFile, szData, charsmax(szData)))
		{
			if(iFlagTeam > TEAM_BLUE)
				break

			trim(szData)
			parse(szData, szOrigin[x], charsmax(szOrigin[]), szOrigin[y], charsmax(szOrigin[]), szOrigin[z], charsmax(szOrigin[]))

			g_fFlagBase[iFlagTeam][x] = str_to_float(szOrigin[x])
			g_fFlagBase[iFlagTeam][y] = str_to_float(szOrigin[y])
			g_fFlagBase[iFlagTeam][z] = str_to_float(szOrigin[z])

			iFlagTeam++
		}

		fclose(hFile)
	}
	else 
	{
		new iPosFlag, any:iTeam = TEAM_TERRORIST;

		while(iTeam <= TEAM_CT)
		{
			iPosFlag = find_ent_by_tname(-1, (iTeam == TEAM_TERRORIST) ? "redflag" : "blueflag");

			if(iPosFlag == -1)
				iPosFlag = rg_find_ent_by_class(-1, (iTeam == TEAM_TERRORIST) ? "info_player_start" : "info_player_deathmatch");

			if(iPosFlag == -1)
			{
				set_fail_state("[reCTF] El mapa no cuenta con un SPAWN de %s!", iTeam == TEAM_TERRORIST ? "TERRORISTA":"POLICIA");
				break;
			}

			get_entvar(iPosFlag, var_origin, g_fFlagBase[iTeam++]);
		}
		//saveFlagsOrigin();
	}

	flag_spawn(TEAM_RED)
	flag_spawn(TEAM_BLUE)

	task_set(6.5, "plugin_postCfg")
}

public plugin_postCfg()
{
	set_cvar_num("mp_freezetime", 0)
	set_cvar_num("mp_limitteams", 0)
	set_cvar_num("mp_buytime", 99999999)
	set_cvar_num("sv_airaccelerate", 9999);
	set_cvar_num("sv_maxspeed", 420);
	set_cvar_num("sv_alltalk", 1);
	set_cvar_num("mp_refill_bpammo_weapons", 3);
	set_cvar_num("mp_infinite_ammo", 2);
	set_cvar_num("mp_round_infinite", 1);
}

public plugin_natives()
{
	register_library("jctf")

	register_native("jctf_get_team", "native_get_team")
	register_native("jctf_get_flagcarrier", "native_get_flagcarrier")

	register_native("set_user_adrenaline", "native_set_adrenaline", 1);
	register_native("get_user_adrenaline", "native_get_adrenaline", 1);
}

public native_set_adrenaline(id, cant) {
	g_adrenaline[id] = clamp(cant, 0, 100);
}

public native_get_adrenaline(id) {
	return g_adrenaline[id];
}

public plugin_end()
{
	DestroyForward(g_iFW_flag)
}

public native_get_team(iPlugin, iParams)
{
	/* jctf_get_team(id) */

	return g_iTeam[get_param(1)]
}

public native_get_flagcarrier(iPlugin, iParams)
{
	/* jctf_get_flagcarrier(id) */

	new id = get_param(1)

	return g_iFlagHolder[get_opTeam(g_iTeam[id])] == id
}

public flag_spawn(iFlagTeam)
{
	if(g_fFlagBase[iFlagTeam][x] == 0.0 && g_fFlagBase[iFlagTeam][y] == 0.0 && g_fFlagBase[iFlagTeam][z] == 0.0)
	{
		new iFindSpawn = rg_find_ent_by_class(g_iMaxPlayers, iFlagTeam == TEAM_BLUE ? "info_player_start" : "info_player_deathmatch")

		if(iFindSpawn)
		{
			get_entvar( iFindSpawn, var_origin, g_fFlagBase[iFlagTeam] );

			server_print("[CTF] %s flag origin not defined, set on player spawn.", g_szTeamName[iFlagTeam])
			log_error(AMX_ERR_NOTFOUND, "[CTF] %s flag origin not defined, set on player spawn.", g_szTeamName[iFlagTeam])
		}
		else
		{
			server_print("[CTF] WARNING: player spawn for ^"%s^" team does not exist !", g_szTeamName[iFlagTeam])
			log_error(AMX_ERR_NOTFOUND, "[CTF] WARNING: player spawn for ^"%s^" team does not exist !", g_szTeamName[iFlagTeam])
			set_fail_state("Player spawn unexistent!")

			return PLUGIN_CONTINUE
		}
	}
	else
		server_print("[CTF] %s flag and base spawned at: %.1f %.1f %.1f", g_szTeamName[iFlagTeam], g_fFlagBase[iFlagTeam][x], g_fFlagBase[iFlagTeam][y], g_fFlagBase[iFlagTeam][z])

	new ent
	new Float:fGameTime = get_gametime()

	// the FLAG

	ent = rg_create_entity(INFO_TARGET);

	if(!ent)
		return flag_spawn(iFlagTeam)

	set_entvar( ent, var_model, FLAG_MODEL );
	set_entvar( ent, var_modelindex, modelIndex_flag );
	set_entvar( ent, var_classname, FLAG_CLASSNAME );
	set_entvar( ent, var_body, 1 );
	set_entvar( ent, var_sequence, 0 );
	set_entvar( ent, var_skin, iFlagTeam == TEAM_CT ? 0 : 1 );
	entity_spawn(ent)
	
	set_entvar( ent, var_origin, g_fFlagBase[iFlagTeam] );
	set_entvar( ent, var_mins, FLAG_HULL_MIN );
	set_entvar( ent, var_maxs, FLAG_HULL_MAX );
	new Float:size[3]
	math_mins_maxs(FLAG_HULL_MIN, FLAG_HULL_MAX, size);
	set_entvar( ent, var_size, size );
	set_entvar( ent, var_velocity, FLAG_SPAWN_VELOCITY );
	set_entvar( ent, var_angles, FLAG_SPAWN_ANGLES );
	set_entvar( ent, var_aiment, 0 );
	set_entvar( ent, var_movetype, MOVETYPE_TOSS );
	set_entvar( ent, var_solid, SOLID_TRIGGER );
	set_entvar( ent, var_gravity, 2.0 );
	set_entvar( ent, var_nextthink, fGameTime + FLAG_THINK );

	g_iFlagEntity[iFlagTeam] = ent
	g_iFlagHolder[iFlagTeam] = FLAG_HOLD_BASE

	//SetTouch(ent, "flag_think");
	//SetTouch( ent, "flag_touch" );

	// flag BASE

	ent = rg_create_entity(INFO_TARGET)

	if(!ent)
		return flag_spawn(iFlagTeam)

	set_entvar( ent, var_model, FLAG_MODEL );
	set_entvar( ent, var_modelindex, modelIndex_flag );
	set_entvar( ent, var_classname, BASE_CLASSNAME );
	set_entvar( ent, var_body, 0 );
	set_entvar( ent, var_sequence, FLAG_ANI_BASE );
	entity_spawn(ent)
	
	set_entvar( ent, var_origin, g_fFlagBase[iFlagTeam] );
	set_entvar( ent, var_velocity, FLAG_SPAWN_VELOCITY );
	set_entvar( ent, var_movetype, MOVETYPE_TOSS );
	set_entvar( ent, var_nextthink, fGameTime + BASE_THINK );

	//SetThink( ent, "base_think");

	/*if( get_pcvar_num( pCvar_ctf_glows ) )
		if(iFlagTeam == TEAM_RED)
			rg_set_user_rendering( ent, kRenderFxGlowShell, 150, 0, 0, kRenderNormal, 100 );
		else
			rg_set_user_rendering( ent, kRenderFxGlowShell, 0, 0, 150, kRenderNormal, 100 );
	*/
	set_task(get_pcvar_float(cvar_regenerate_time), "regenerate_health", 9876, _, _, "b");

	g_iBaseEntity[iFlagTeam] = ent

	return PLUGIN_CONTINUE
}

public regenerate_health( taskid ) 
{
	if ( !get_pcvar_num( cvar_autoregenerate ) ) 
		return;
	
	for( new id = 1; id <= g_iMaxPlayers; id++ ) 
	{
		if ( !g_bAlive[ id ] || !( TEAM_RED <= g_iTeam[ id ] <= TEAM_BLUE ) ) 
			continue;

		new hp = floatround(get_entvar( id, var_health ));

		if (hp < 100)
		{
			hp += get_pcvar_num(cvar_healh_regenerate);
			set_entvar( id, var_health, float(min(hp, 100)) );
		}
	}
}

public flag_think(ent)
{
	if( !is_entity( ent ) )
		return

	set_entvar( ent, var_nextthink, get_gametime() + FLAG_THINK );


	static id
	static iStatus
	static iFlagTeam
	static iSkip[3]
	static Float:fOrigin[3]
	static Float:fPlayerOrigin[3]

	iFlagTeam = (ent == g_iFlagEntity[TEAM_BLUE] ? TEAM_BLUE : TEAM_RED)

	if(g_iFlagHolder[iFlagTeam] == FLAG_HOLD_BASE)
		fOrigin = g_fFlagBase[iFlagTeam]
	else
		get_entvar( ent, var_origin, fOrigin );

	g_fFlagLocation[iFlagTeam] = fOrigin

	iStatus = 0

	if(++iSkip[iFlagTeam] >= FLAG_SKIPTHINK)
	{
		iSkip[iFlagTeam] = 0

		if(1 <= g_iFlagHolder[iFlagTeam] <= g_iMaxPlayers)
		{
			id = g_iFlagHolder[iFlagTeam]

			set_hudmessage(HUD_HELP)
			show_hudmessage(id, "%L", id, "HUD_YOUHAVEFLAG")

			iStatus = 1
		}
		else if(g_iFlagHolder[iFlagTeam] == FLAG_HOLD_DROPPED)
			iStatus = 2

		message_begin(MSG_BROADCAST, gMsg_HostagePos)
		write_byte(0)
		write_byte(iFlagTeam)
		engfunc(EngFunc_WriteCoord, fOrigin[x])
		engfunc(EngFunc_WriteCoord, fOrigin[y])
		engfunc(EngFunc_WriteCoord, fOrigin[z])
		message_end()

		message_begin(MSG_BROADCAST, gMsg_HostageK)
		write_byte(iFlagTeam)
		message_end()

		static iStuck[3]

		if(g_iFlagHolder[iFlagTeam] >= FLAG_HOLD_BASE && !(get_entvar(ent, var_flags) & FL_ONGROUND))
		{
			if(++iStuck[iFlagTeam] > 4)
			{
				flag_autoReturn(ent)

				log_message("^"%s^" flag is outside world, auto-returned.", g_szTeamName[iFlagTeam])

				return
			}
		}
		else
			iStuck[iFlagTeam] = 0
	}

	for(id = 1; id <= g_iMaxPlayers; id++)
	{
		if(g_iTeam[id] == TEAM_NONE)
			continue

		/* Check flag proximity for pickup */
		if(g_iFlagHolder[iFlagTeam] >= FLAG_HOLD_BASE)
		{
			get_entvar(id, var_origin, fPlayerOrigin)

			if(get_distance_f(fOrigin, fPlayerOrigin) <= FLAG_PICKUPDISTANCE)
				flag_touch(ent, id)
		}

		/* If iFlagTeam's flag is stolen or dropped, constantly warn team players */
		if(iStatus && g_iTeam[id] == iFlagTeam)
		{
			set_hudmessage(HUD_HELP2)
			show_hudmessage(id, "%L", id, (iStatus == 1 ? "HUD_ENEMYHASFLAG" : "HUD_RETURNYOURFLAG"))
		}
	}
}

flag_sendHome(iFlagTeam)
{
	new ent = g_iFlagEntity[iFlagTeam]

	set_entvar( ent, var_aiment, 0 );
	set_entvar( ent, var_origin, g_fFlagBase[iFlagTeam] );
	set_entvar( ent, var_sequence, 0 );
	set_entvar( ent, var_movetype, MOVETYPE_TOSS );
	set_entvar( ent, var_solid, SOLID_TRIGGER );
	set_entvar( ent, var_velocity, FLAG_SPAWN_VELOCITY );
	set_entvar( ent, var_angles, FLAG_SPAWN_ANGLES );

	rg_set_user_rendering(ent);


	REMOVE_BeamEnts(g_iFlagHolder[get_opTeam(iFlagTeam)])
	set_task(0.1, "CREATE_BeamEnts",g_iFlagHolder[get_opTeam(iFlagTeam)]+140)

	g_iFlagHolder[iFlagTeam] = FLAG_HOLD_BASE
}

flag_take(iFlagTeam, id)
{
	if(g_bProtected[id])
		player_removeProtection(id, "PROTECTION_TOUCHFLAG")

	new ent = g_iFlagEntity[iFlagTeam]

	set_entvar( ent, var_aiment, id )
	set_entvar( ent, var_movetype, MOVETYPE_FOLLOW )
	set_entvar( ent, var_solid, SOLID_NOT )

	g_iFlagHolder[iFlagTeam] = id

	message_begin(MSG_BROADCAST, gMsg_ScoreAttrib)
	write_byte(id)
	write_byte(g_iTeam[id] == TEAM_BLUE ? 4 : 2)
	message_end()

	REMOVE_BeamEnts(id)
	set_task(0.1, "CREATE_BeamEnts",id+140)

	if(1 <= g_iFlagHolder[get_opTeam(iFlagTeam)] <= g_iMaxPlayers)
	{
		REMOVE_BeamEnts(g_iFlagHolder[get_opTeam(iFlagTeam)])
		set_task(0.1, "CREATE_BeamEnts",g_iFlagHolder[get_opTeam(iFlagTeam)]+140)
	}
}

public go_spect( id )
{
	if( !is_user_connected( id ) || !is_user_admin( id ) )
		return PLUGIN_HANDLED;

	user_silentkill( id );
	rg_set_user_team( id, TEAM_SPECTATOR );
	return PLUGIN_HANDLED;
}
public reset_score( id )
{
	if( !is_user_connected( id ) )
		return PLUGIN_HANDLED;

	new name[33]; get_user_name(id, name, 32);

	set_entvar( id, var_frags, 0.0 );
	set_member( id, m_iDeaths, 0 );

	message_begin(MSG_BROADCAST, gMsg_ScoreInfo)
	write_byte(id) // id
	write_short(0) // Frags
	write_short(0) // Deaths
	write_short(0) // Class
	write_short(get_member(id, m_iTeam)) // Team
	message_end()

	client_print_color(0, print_team_blue, "^x01 [^x04 reCTF ^x01]^x03 %s^x01 ^x03 ha restablecido su score a^x04 0", name);
	return PLUGIN_HANDLED;
}

public flag_touch(ent, id)
{
	if(!g_bAlive[id] || !is_entity(ent))
		return

	new iFlagTeam = (g_iFlagEntity[TEAM_BLUE] == ent ? TEAM_BLUE : TEAM_RED)

	if(1 <= g_iFlagHolder[iFlagTeam] <= g_iMaxPlayers) // if flag is carried we don't care
		return

	new Float:fGameTime = get_gametime()

	if(g_fLastDrop[id] > fGameTime)
		return

	new iTeam = g_iTeam[id]

	if(!(TEAM_RED <= g_iTeam[id] <= TEAM_BLUE))
		return

	new iFlagTeamOp = get_opTeam(iFlagTeam)
	new szName[32]

	get_user_name(id, szName, charsmax(szName))

	if(iTeam == iFlagTeam) // If the PLAYER is on the same team as the FLAG
	{
		if(g_iFlagHolder[iFlagTeam] == FLAG_HOLD_DROPPED) // if the team's flag is dropped, return it to base
		{
			flag_sendHome(iFlagTeam)

			task_remove(ent)

			player_award(id, REWARD_RETURN, "%L", id, "REWARD_RETURN")

			ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_RETURNED, id, iFlagTeam, false)

			new iAssists = 0

			for(new i = 1; i <= g_iMaxPlayers; i++)
			{
				if(i != id && g_bAssisted[i][iFlagTeam] && g_iTeam[i] == iFlagTeam)
				{
					player_award(i, REWARD_RETURN_ASSIST, "%L", i, "REWARD_RETURN_ASSIST")

					ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_RETURNED, i, iFlagTeam, true)

					iAssists++
				}

				g_bAssisted[i][iFlagTeam] = false
			}

			if(1 <= g_iFlagHolder[iFlagTeamOp] <= g_iMaxPlayers)
				g_bAssisted[id][iFlagTeamOp] = true

			if(iAssists)
			{
				new szFormat[64]

				format(szFormat, charsmax(szFormat), "%s + %d assists", szName, iAssists)

				game_announce(EVENT_RETURNED, iFlagTeam, szFormat)
			}
			else
				game_announce(EVENT_RETURNED, iFlagTeam, szName)

			log_message("<%s>%s returned the ^"%s^" flag.", g_szTeamName[iTeam], szName, g_szTeamName[iFlagTeam])

			set_hudmessage(HUD_HELP)
			show_hudmessage(id, "%L", id, "HUD_RETURNEDFLAG")

			if(g_bProtected[id])
				player_removeProtection(id, "PROTECTION_TOUCHFLAG")
		}
		else if(g_iFlagHolder[iFlagTeam] == FLAG_HOLD_BASE && g_iFlagHolder[iFlagTeamOp] == id) // if the PLAYER has the ENEMY FLAG and the FLAG is in the BASE make SCORE
		{
			message_begin(MSG_BROADCAST, gMsg_ScoreAttrib)
			write_byte(id)
			write_byte(0)
			message_end()

			player_award(id, REWARD_CAPTURE, "%L", id, "REWARD_CAPTURE")

			ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_CAPTURED, id, iFlagTeamOp, false)
			REMOVE_BeamEnts(id)
			dojump[id][ 1 ] = true
			if (get_pcvar_num(cvar_speed)) rg_reset_maxspeed( id );

			new iAssists = 0

			for(new i = 1; i <= g_iMaxPlayers; i++)
			{
				if(i != id && g_iTeam[i] > 0 && g_iTeam[i] == iTeam)
				{
					if(g_bAssisted[i][iFlagTeamOp])
					{
						player_award(i, REWARD_CAPTURE_ASSIST, "%L", i, "REWARD_CAPTURE_ASSIST")

						ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_CAPTURED, i, iFlagTeamOp, true)

						iAssists++
					}
					else
						player_award(i, REWARD_CAPTURE_TEAM, "%L", i, "REWARD_CAPTURE_TEAM")
				}

				g_bAssisted[i][iFlagTeamOp] = false
			}

			set_hudmessage(HUD_HELP)
			show_hudmessage(id, "%L", id, "HUD_CAPTUREDFLAG")

			if(iAssists)
			{
				new szFormat[64]

				format(szFormat, charsmax(szFormat), "%s + %d assists", szName, iAssists)

				game_announce(EVENT_SCORE, iFlagTeam, szFormat)
			}
			else
				game_announce(EVENT_SCORE, iFlagTeam, szName)

			log_message("<%s>%s captured the ^"%s^" flag. (%d assists)", g_szTeamName[iTeam], szName, g_szTeamName[iFlagTeamOp], iAssists)

			emessage_begin(MSG_BROADCAST, gMsg_TeamScore)
			ewrite_string(g_szCSTeams[iFlagTeam])
			ewrite_short(++g_iScore[iFlagTeam])
			emessage_end()

			flag_sendHome(iFlagTeamOp)

			g_fLastDrop[id] = fGameTime + 3.0

			if(g_bProtected[id])
				player_removeProtection(id, "PROTECTION_TOUCHFLAG")
			else
				player_updateRender(id)

			if(0 < get_pcvar_num(pCvar_mp_winlimit) <= g_iScore[iFlagTeam])
			{
				emessage_begin(MSG_ALL, SVC_INTERMISSION) // hookable mapend
				emessage_end()

				return
			}
			new iFlagRoundEnd = 1

			if(iFlagRoundEnd && get_pcvar_num(pCvar_ctf_flagcaptureslay))
			{
				for(new i = 1; i <= g_iMaxPlayers; i++)
				{
					if(g_iTeam[i] == iFlagTeamOp)
					{
						user_kill(i)
						player_print(i, i, "%L", i, "DEATH_FLAGCAPTURED")
					}
				}
			}
		}
	}
	else
	{
		if(g_iFlagHolder[iFlagTeam] == FLAG_HOLD_BASE)
		{
			player_award(id, REWARD_STEAL, "%L", id, "REWARD_STEAL")

			ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_STOLEN, id, iFlagTeam, false)

			dojump[ id ][ 1 ] = false;
			
			if (get_pcvar_num(cvar_speed)) rg_reset_maxspeed( id );

			log_message("<%s>%s stole the ^"%s^" flag.", g_szTeamName[iTeam], szName, g_szTeamName[iFlagTeam])
		}
		else
		{
			player_award(id, REWARD_PICKUP, "%L", id, "REWARD_PICKUP")

			ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_PICKED, id, iFlagTeam, false)
			dojump[ id ][ 1 ] = false;
			
			if (get_pcvar_num(cvar_speed)) rg_reset_maxspeed( id );

			log_message("<%s>%s picked up the ^"%s^" flag.", g_szTeamName[iTeam], szName, g_szTeamName[iFlagTeam])
		}
		//agarro bandera
		set_entvar( ent, var_sequence, 0 );

		set_hudmessage(HUD_HELP)
		show_hudmessage(id, "%L", id, "HUD_YOUHAVEFLAG")

		flag_take(iFlagTeam, id)

		g_bAssisted[id][iFlagTeam] = true

		task_remove(ent)

		if(g_bProtected[id])
			player_removeProtection(id, "PROTECTION_TOUCHFLAG")
		else
			player_updateRender(id)

		game_announce(EVENT_TAKEN, iFlagTeam, szName)
	}
}

public flag_autoReturn(ent)
{
	task_remove(ent)

	new iFlagTeam = (g_iFlagEntity[TEAM_BLUE] == ent ? TEAM_BLUE : (g_iFlagEntity[TEAM_RED] == ent ? TEAM_RED : 0))

	if(!iFlagTeam)
		return

	flag_sendHome(iFlagTeam)

	ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_AUTORETURN, 0, iFlagTeam, false)

	game_announce(EVENT_RETURNED, iFlagTeam, NULL)

	log_message("^"%s^" flag returned automatically", g_szTeamName[iFlagTeam])
}

public base_think(ent)
{
	if(!is_entity(ent))
		return

	if(!get_pcvar_num(pCvar_ctf_flagheal))
	{
		set_entvar( ent, var_nextthink, get_gametime() + 10.0 ); /* recheck each 10s seconds */
		return
	}

	set_entvar( ent, var_nextthink, get_gametime() + BASE_THINK );

	new iFlagTeam = (g_iBaseEntity[TEAM_BLUE] == ent ? TEAM_BLUE : TEAM_RED)

	if(g_iFlagHolder[iFlagTeam] != FLAG_HOLD_BASE)
		return

	static id
	static Float:iHealth

	id = -1

	while((id = find_ent_in_sphere(id, g_fFlagBase[iFlagTeam], BASE_HEAL_DISTANCE)) != 0)
	{
		if(1 <= id <= g_iMaxPlayers && g_bAlive[id] && g_iTeam[id] == iFlagTeam)
		{
			iHealth = get_entvar(id, var_health)

			if(iHealth < 100.0)
			{
				set_entvar(id, var_health, iHealth + 1.0);

				player_healingEffect(id)
			}
		}

		if(id >= g_iMaxPlayers)
			break
	}
}

public client_putinserver(id)
{
	g_iTeam[id] = TEAM_SPEC
	g_bFirstSpawn[id] = true
	g_bRestarted[id] = false

	g_adrenaline[id] = 0;

	jumpnum[id] = 0
	dojump[id][0] = false
	dojump[id][1] = true
}

public client_disconnected(id)
{
	player_dropFlag(id)
	task_remove(id)
	REMOVE_BeamEnts(id)

	g_iTeam[id] = TEAM_NONE

	g_bAlive[id] = false
	g_bFreeLook[id] = false
	g_bAssisted[id][TEAM_RED] = false
	g_bAssisted[id][TEAM_BLUE] = false

	jumpnum[id] = 0;
	dojump[id][0] = false
	dojump[id][1] = false
}

public player_joinTeam()
{
	new id = read_data(1)

	if(g_bAlive[id])
		return

	new szTeam[2]

	read_data(2, szTeam, charsmax(szTeam))

	switch(szTeam[0])
	{
		case 'T':
		{
			if(g_iTeam[id] == TEAM_RED && g_bFirstSpawn[id])
			{
				new iRespawn = get_pcvar_num(pCvar_ctf_respawntime)

				if(iRespawn > 0)
					player_respawn(id - TASK_RESPAWN, iRespawn + 1)

				task_remove(id - TASK_TEAMBALANCE)
				task_set(1.0, "player_checkTeam", id - TASK_TEAMBALANCE)
			}

			g_iTeam[id] = TEAM_RED
		}

		case 'C':
		{
			if(g_iTeam[id] == TEAM_BLUE && g_bFirstSpawn[id])
			{
				new iRespawn = get_pcvar_num(pCvar_ctf_respawntime)

				if(iRespawn > 0)
					player_respawn(id - TASK_RESPAWN, iRespawn + 1)

				task_remove(id - TASK_TEAMBALANCE)
				task_set(1.0, "player_checkTeam", id - TASK_TEAMBALANCE)
			}

			g_iTeam[id] = TEAM_BLUE
		}

		case 'U':
		{
			g_iTeam[id] = TEAM_NONE
			g_bFirstSpawn[id] = true
		}

		default:
		{
			player_screenFade(id, {0,0,0,0}, 0.0, 0.0, FADE_OUT, false)
			player_allowChangeTeam(id)

			g_iTeam[id] = TEAM_SPEC
			g_bFirstSpawn[id] = true
		}
	}
}

@fw_ResetMaxSpeed_Post(id)
{
	if ( !g_bAlive[id] || !get_pcvar_num(cvar_speed) )
		return;

	if( dojump[ id ][ 1 ] && GetCurrentWeapon( id ) == WEAPON_KNIFE )
		set_entvar( id , var_maxspeed, 600.0 ); 
}

@player_spawn(id)
{
	if(!is_user_alive(id) || (!g_bRestarted[id] && g_bAlive[id]) || !(TEAM_TERRORIST <= get_member( id, m_iTeam ) <= TEAM_CT) )
		return
	
	/* make sure we have team right */

	switch( get_member( id, m_iTeam ) )
	{
		case TEAM_TERRORIST: g_iTeam[id] = TEAM_RED
		case TEAM_CT: g_iTeam[id] = TEAM_BLUE
		default: return
	}

	g_bAlive[id] = true
	g_bDefuse[id] = false
	g_bBuyZone[id] = true
	g_bFreeLook[id] = false
	g_fLastBuy[id] = Float:{0.0, 0.0, 0.0, 0.0}

	task_remove(id - TASK_PROTECTION)
	task_remove(id - TASK_EQUIPAMENT)
	task_remove(id - TASK_DAMAGEPROTECTION)
	task_remove(id - TASK_TEAMBALANCE)
	task_remove(id - TASK_ADRENALINE)
	task_remove(id - TASK_DEFUSE)

	new iProtection = get_pcvar_num(pCvar_ctf_protection)

	if(iProtection > 0)
		player_protection(id - TASK_PROTECTION, iProtection)

	message_begin(MSG_BROADCAST, gMsg_ScoreAttrib)
	write_byte(id)
	write_byte(0)
	message_end()

	if(g_bFirstSpawn[id] || g_bRestarted[id])
	{
		g_bRestarted[id] = false
		g_bFirstSpawn[id] = false

		rg_add_account( id, get_pcvar_num(pCvar_mp_startmoney), AS_SET );
	}
	else if(g_bSuicide[id])
	{
		g_bSuicide[id] = false

		player_print(id, id, "%L", id, "SPAWN_NOMONEY")
	}
	
	rg_remove_all_items( id );
	rg_give_item( id, "weapon_knife" );

	if (get_pcvar_num(cvar_weapons)) {

		rg_give_item( id, "weapon_smokegrenade" );

		switch(random_num(0, 1))
		{
			case 0:
			{
				rg_give_item( id, "weapon_ak47" );
				rg_set_user_bpammo( id, WEAPON_AK47, 90 );
			}
			case 1:
			{
				rg_give_item( id, "weapon_m4a1" );
				rg_set_user_bpammo( id, WEAPON_M4A1, 90 );
			}
			case 2:
			{
				rg_give_item( id, "weapon_awp" );
				rg_set_user_bpammo( id, WEAPON_AWP, 90 );
			}
		}
		rg_give_item( id, "weapon_deagle" );
		rg_set_user_bpammo( id, WEAPON_DEAGLE, 90 );
	}
		
	rg_set_user_armor( id, 100, ARMOR_VESTHELM );
}

public player_protection(id, iStart)
{
	id += TASK_PROTECTION

	if(!(TEAM_RED <= g_iTeam[id] <= TEAM_BLUE) || !g_bAlive[ id ])
		return

	static iCount[33]

	if(iStart)
	{
		iCount[id] = iStart + 1

		g_bProtected[id] = true

		player_updateRender(id)
	}

	if(--iCount[id] > 0)
	{
		set_hudmessage(HUD_RESPAWN)
		show_hudmessage(id, "%L", id, "PROTECTION_LEFT", iCount[id])

		task_set(1.0, "player_protection", id - TASK_PROTECTION)	
	}
	else
		player_removeProtection(id, "PROTECTION_EXPIRED")
}

public player_removeProtection(id, szLang[])
{
	if(!(TEAM_RED <= g_iTeam[id] <= TEAM_BLUE))
		return

	g_bProtected[id] = false

	task_remove(id - TASK_PROTECTION)
	task_remove(id - TASK_DAMAGEPROTECTION)

	set_hudmessage(HUD_PROTECTION)
	show_hudmessage(id, "%L", id, szLang)

	player_updateRender(id)
}
@fw_PlayerJump_Pre(id)
{
	if( !dojump[ id ][ 1 ] || !get_pcvar_num(cvar_speed) )
	    return HC_CONTINUE;

	new nbut = get_entvar(id, var_button);
	new obut = get_entvar(id, var_oldbuttons);
	new iFlags = get_entvar(id, var_flags);
	new Float:fVelocity[ 3 ];  

	get_entvar(id, var_velocity, fVelocity);
	if((nbut & IN_JUMP) && (~iFlags & FL_ONGROUND) && (~obut & IN_JUMP))
	{
	    if ( jumpnum[id] < 3 )
	    {
	        fVelocity[2] = random_float(265.0, 285.0);

	    	set_entvar(id, var_velocity, fVelocity);
	    	jumpnum[id]++;
	    }
	}
	if((nbut & IN_JUMP) && (iFlags & FL_ONGROUND))
	{
	    jumpnum[id] = 0
	}

	return HC_CONTINUE;
}

@player_damage(id, iInflictor, attacker, Float:fDamage, bitsDamageType)
{
	if((1 <= id <= g_iMaxPlayers) && g_bProtected[id])
	{
		player_updateRender(id, fDamage)

		task_remove(id - TASK_DAMAGEPROTECTION)
		task_set(0.1, "player_damageProtection", id - TASK_DAMAGEPROTECTION)

		set_entvar( id, var_punchangle, FLAG_SPAWN_ANGLES );

		SetHookChainReturn( ATYPE_INTEGER, true );
		return HC_SUPERCEDE
	}

	return HC_CONTINUE;
}

public player_damageProtection(id)
{
	id += TASK_DAMAGEPROTECTION

	if(g_bAlive[id])
		player_updateRender(id)
}

@player_killed(id, killer)
{
	g_bAlive[id] = false
	g_bBuyZone[id] = false

	task_remove(id - TASK_RESPAWN)
	task_remove(id - TASK_PROTECTION)
	task_remove(id - TASK_EQUIPAMENT)
	task_remove(id - TASK_DAMAGEPROTECTION)
	task_remove(id - TASK_TEAMBALANCE)
	task_remove(id - TASK_ADRENALINE)
	task_remove(id - TASK_DEFUSE)

	REMOVE_BeamEnts(id);

	static hp; hp = floatround( get_entvar( killer, var_health ) );

	if( is_user_alive( killer ) )
	{
		set_entvar( killer, var_health, float( clamp( hp + 10, 0, 100 ) ) );
		set_user_coins(id, get_user_coins(id) + 10);
		g_adrenaline[killer] = clamp( g_adrenaline[killer]+5, 0, 100 );
		rg_instant_reload_weapons( killer );

		if( get_member( id, m_bHeadshotKilled ) )
        	rg_give_item( killer, "weapon_hegrenade" );
	}

	if(id == killer || !(1 <= killer <= g_iMaxPlayers))
	{
		g_bSuicide[id] = true

		player_award(id, PENALTY_SUICIDE, "%L", id, "PENALTY_SUICIDE");
	}
	else if(1 <= killer <= g_iMaxPlayers)
	{
		if(g_iTeam[id] == g_iTeam[killer])
		{
			player_award(killer, PENALTY_TEAMKILL, "%L", killer, "PENALTY_TEAMKILL");
		}
		else
		{

			if(id == g_iFlagHolder[g_iTeam[killer]])
			{
				g_bAssisted[killer][g_iTeam[killer]] = true;

				player_award(killer, REWARD_KILLCARRIER, "%L", killer, "REWARD_KILLCARRIER");

				message_begin(MSG_BROADCAST, gMsg_ScoreAttrib);
				write_byte(id);
				write_byte(0);
				message_end();
			}
			else
			{
				player_award(killer, REWARD_KILL, "%L", killer, "REWARD_KILL");
			}
		}
	}

	new iRespawn = get_pcvar_num(pCvar_ctf_respawntime);

	if(iRespawn > 0)
		player_respawn(id - TASK_RESPAWN, iRespawn);

	player_dropFlag(id);
	player_allowChangeTeam(id);

	task_set(1.0, "player_checkTeam", id - TASK_TEAMBALANCE);
}

public player_checkTeam(id)
{
	id += TASK_TEAMBALANCE

	if(!(TEAM_RED <= g_iTeam[id] <= TEAM_BLUE) || g_bAlive[id] || !get_pcvar_num(pCvar_mp_autoteambalance))
		return

	new iPlayers[3]
	new iTeam = g_iTeam[id]
	new iOpTeam = get_opTeam(iTeam)

	for(new i = 1; i <= g_iMaxPlayers; i++)
	{
		if(TEAM_RED <= g_iTeam[i] <= TEAM_BLUE)
			iPlayers[g_iTeam[i]]++
	}

	if((iPlayers[iTeam] > 1 && !iPlayers[iOpTeam]) || iPlayers[iTeam] > (iPlayers[iOpTeam] + 1))
	{
		player_allowChangeTeam(id)

		engclient_cmd(id, "jointeam", (iOpTeam == TEAM_BLUE ? "2" : "1"))

		set_task(2.0, "player_forceJoinClass", id)

		player_print(id, id, "%L", id, "DEATH_TRANSFER", "^x04", id, g_szMLTeamName[iOpTeam], "^x01")
	}
}

public player_forceJoinClass(id)
{
	engclient_cmd(id, "joinclass", "5")
}

public player_respawn(id, iStart)
{
	id += TASK_RESPAWN;

	if(!(TEAM_TERRORIST <= get_member( id, m_iTeam ) <= TEAM_CT) || g_bAlive[id] || !is_user_connected( id ))
		return;

	static iCount[33];

	if(iStart)
		iCount[id] = iStart + 1;

	set_hudmessage(HUD_RESPAWN);

	if(--iCount[id] > 0)
	{
		show_hudmessage(id, "%L", id, "RESPAWNING_IN", iCount[id]);
		client_print(id, print_console, "%L", id, "RESPAWNING_IN", iCount[id]);

		task_set(1.0, "player_respawn", id - TASK_RESPAWN);
	}
	else
	{
		show_hudmessage(id, "%L", id, "RESPAWNING");
		client_print(id, print_console, "%L", id, "RESPAWNING");

		rg_round_respawn( id );
		
	}
}

public player_cmd_dropFlag(id)//drop
{
	if(!g_bAlive[id] || id != g_iFlagHolder[get_opTeam(g_iTeam[id])])
		player_print(id, id, "%L", id, "DROPFLAG_NOFLAG")

	else
	{
		new iOpTeam = get_opTeam(g_iTeam[id])

		player_dropFlag(id)
		REMOVE_BeamEnts(id)
		player_award(id, PENALTY_DROP, "%L", id, "PENALTY_MANUALDROP")

		ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_MANUALDROP, id, iOpTeam, false)

		dojump[ id ][ 1 ] = true;
		
		if (get_pcvar_num(cvar_speed)) rg_reset_maxspeed( id );

		g_bAssisted[id][iOpTeam] = false
	}

	return PLUGIN_HANDLED
}

public player_dropFlag(id)//drop
{
	new iOpTeam = get_opTeam(g_iTeam[id])

	if(id != g_iFlagHolder[iOpTeam])
		return

	new ent = g_iFlagEntity[iOpTeam]

	if( !is_entity( ent ) )
		return

	g_fLastDrop[id] = get_gametime() + 2.0
	g_iFlagHolder[iOpTeam] = FLAG_HOLD_DROPPED

	set_entvar( ent, var_aiment, -1 );
	set_entvar( ent, var_movetype, MOVETYPE_TOSS );
	set_entvar( ent, var_sequence, 1 );
	set_entvar( ent, var_framerate, 1.0);
	set_entvar( ent, var_solid, SOLID_TRIGGER );
	set_entvar( ent, var_origin, g_fFlagLocation[iOpTeam] );

	new Float:fReturn = get_pcvar_float(pCvar_ctf_flagreturn)

	if( get_pcvar_num( pCvar_ctf_glows ) )
		if(iOpTeam == TEAM_RED)
			rg_set_user_rendering( ent, kRenderFxGlowShell, 150, 0, 0, kRenderNormal, 100 );
		else
			rg_set_user_rendering( ent, kRenderFxGlowShell, 0, 0, 150, kRenderNormal, 100 );

	if(fReturn > 0)
		task_set(fReturn, "flag_autoReturn", ent)

	if(g_bAlive[id])
	{
		new Float:fVelocity[3]

		velocity_by_aim(id, 200, fVelocity) 

		fVelocity[z] = 0.0

		set_entvar( ent, var_velocity, fVelocity );

		player_updateRender(id)

		message_begin(MSG_BROADCAST, gMsg_ScoreAttrib)
		write_byte(id)
		write_byte(0)
		message_end()
	}
	else
		set_entvar( ent, var_velocity, FLAG_DROP_VELOCITY );

	new szName[32]

	get_user_name(id, szName, charsmax(szName))

	game_announce(EVENT_DROPPED, iOpTeam, szName)

	ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_DROPPED, id, iOpTeam, false)

	dojump[ id ][ 1 ] = true
	
	if (get_pcvar_num(cvar_speed)) rg_reset_maxspeed( id );

	g_fFlagDropped[iOpTeam] = get_gametime()

	log_message("<%s>%s dropped the ^"%s^" flag.", g_szTeamName[g_iTeam[id]], szName, g_szTeamName[iOpTeam])
}

public admin_cmd_moveFlag(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED

	new szTeam[2]

	read_argv(1, szTeam, charsmax(szTeam))

	new iTeam = str_to_num(szTeam)

	if(!(TEAM_RED <= iTeam <= TEAM_BLUE))
	{
		switch(szTeam[0])
		{
			case 'r', 'R': iTeam = 1
			case 'b', 'B': iTeam = 2
		}
	}

	if(!(TEAM_RED <= iTeam <= TEAM_BLUE))
		return PLUGIN_HANDLED

	get_entvar( id, var_origin, g_fFlagBase[iTeam] );

	set_entvar(g_iBaseEntity[iTeam], var_origin, g_fFlagBase[iTeam] );
	set_entvar(g_iBaseEntity[iTeam], var_velocity, FLAG_SPAWN_VELOCITY );

	if(g_iFlagHolder[iTeam] == FLAG_HOLD_BASE)
	{
		set_entvar( g_iFlagEntity[iTeam], var_origin, g_fFlagBase[iTeam] );
		set_entvar( g_iFlagEntity[iTeam], var_velocity, FLAG_SPAWN_VELOCITY );
	}

	new szName[32]
	new szSteam[48]

	get_user_name(id, szName, charsmax(szName))
	get_user_authid(id, szSteam, charsmax(szSteam))

	log_amx("Admin %s<%s><%s> moved %s flag to %.2f %.2f %.2f", szName, szSteam, g_szTeamName[g_iTeam[id]], g_szTeamName[iTeam], g_fFlagBase[iTeam][0], g_fFlagBase[iTeam][1], g_fFlagBase[iTeam][2])

	show_activity_key("ADMIN_MOVEBASE_1", "ADMIN_MOVEBASE_2", szName, LANG_PLAYER, g_szMLFlagTeam[iTeam])

	client_print(id, print_console, "%s%L", CONSOLE_PREFIX, id, "ADMIN_MOVEBASE_MOVED", id, g_szMLFlagTeam[iTeam])

	return PLUGIN_HANDLED
}

public admin_cmd_saveFlags(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	new iOrigin[3][3]
	new szFile[96]
	new szBuffer[1024]

	FVecIVec(g_fFlagBase[TEAM_RED], iOrigin[TEAM_RED])
	FVecIVec(g_fFlagBase[TEAM_BLUE], iOrigin[TEAM_BLUE])

	formatex(szBuffer, charsmax(szBuffer), "%d %d %d^n%d %d %d", iOrigin[TEAM_RED][x], iOrigin[TEAM_RED][y], iOrigin[TEAM_RED][z], iOrigin[TEAM_BLUE][x], iOrigin[TEAM_BLUE][y], iOrigin[TEAM_BLUE][z])
	formatex(szFile, charsmax(szFile), FLAG_SAVELOCATION, g_szMap)

	if(file_exists(szFile))
		delete_file(szFile)

	write_file(szFile, szBuffer)

	new szName[32]
	new szSteam[48]

	get_user_name(id, szName, charsmax(szName))
	get_user_authid(id, szSteam, charsmax(szSteam))

	log_amx("Admin %s<%s><%s> saved flag positions.", szName, szSteam, g_szTeamName[g_iTeam[id]])

	client_print(id, print_console, "%s%L %s", CONSOLE_PREFIX, id, "ADMIN_MOVEBASE_SAVED", szFile)

	return PLUGIN_HANDLED
}

public admin_cmd_returnFlag(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED

	new szTeam[2]

	read_argv(1, szTeam, charsmax(szTeam))

	new iTeam = str_to_num(szTeam)

	if(!(TEAM_RED <= iTeam <= TEAM_BLUE))
	{
		switch(szTeam[0])
		{
			case 'r', 'R': iTeam = 1
			case 'b', 'B': iTeam = 2
		}
	}

	if(!(TEAM_RED <= iTeam <= TEAM_BLUE))
		return PLUGIN_HANDLED

	if(g_iFlagHolder[iTeam] == FLAG_HOLD_DROPPED)
	{
		if(g_fFlagDropped[iTeam] < (get_gametime() - ADMIN_RETURNWAIT))
		{
			new szName[32]
			new szSteam[48]

			new Float:fFlagOrigin[3]

			get_entvar( g_iFlagEntity[iTeam], var_origin, fFlagOrigin )

			flag_sendHome(iTeam)

			ExecuteForward(g_iFW_flag, g_iForwardReturn, FLAG_ADMINRETURN, id, iTeam, false)

			game_announce(EVENT_RETURNED, iTeam, NULL)

			get_user_name(id, szName, charsmax(szName))
			get_user_authid(id, szSteam, charsmax(szSteam))

			log_message("^"%s^" flag returned by admin %s<%s><%s>", g_szTeamName[iTeam], szName, szSteam, g_szTeamName[g_iTeam[id]])
			log_amx("Admin %s<%s><%s> returned %s flag from %.2f %.2f %.2f", szName, szSteam, g_szTeamName[g_iTeam[id]], g_szTeamName[iTeam], fFlagOrigin[0], fFlagOrigin[1], fFlagOrigin[2])

			show_activity_key("ADMIN_RETURN_1", "ADMIN_RETURN_2", szName, LANG_PLAYER, g_szMLFlagTeam[iTeam])

			client_print(id, print_console, "%s%L", CONSOLE_PREFIX, id, "ADMIN_RETURN_DONE", id, g_szMLFlagTeam[iTeam])
		}
		else
			client_print(id, print_console, "%s%L", CONSOLE_PREFIX, id, "ADMIN_RETURN_WAIT", id, g_szMLFlagTeam[iTeam], ADMIN_RETURNWAIT)
	}
	else
		client_print(id, print_console, "%s%L", CONSOLE_PREFIX, id, "ADMIN_RETURN_NOTDROPPED", id, g_szMLFlagTeam[iTeam])

	return PLUGIN_HANDLED
}
public weapon_spawn(ent)
{
	if( !is_entity( ent ) )
		return

	new Float:fWeaponStay = get_pcvar_float(pCvar_ctf_weaponstay)

	if(fWeaponStay > 0)
	{
		task_remove(ent)
		task_set(fWeaponStay, "weapon_startFade", ent)
	}
}

public weapon_startFade(ent)
{
	if( !is_entity( ent ) )
		return

	new szClass[32]

	get_entvar(ent, var_classname, szClass, charsmax(szClass))

	if(!equal(szClass, WEAPONBOX))
		return

	set_entvar(ent, var_movetype, MOVETYPE_FLY)
	set_entvar(ent, var_rendermode, kRenderTransAlpha)

	if(get_pcvar_num(pCvar_ctf_glows))
		set_entvar(ent, var_renderfx, kRenderFxGlowShell)

	set_entvar(ent, var_renderamt, 255.0)
	set_entvar(ent, var_rendercolor, Float:{255.0, 255.0, 0.0})
	set_entvar(ent, var_velocity, Float:{0.0, 0.0, 20.0})

	weapon_fadeOut(ent, 255.0)
}

public weapon_fadeOut(ent, Float:fStart)
{
	if( !is_entity( ent ) )
	{
		task_remove(ent)
		return
	}

	static Float:fFadeAmount[4096]

	if(fStart)
	{
		task_remove(ent)
		fFadeAmount[ent] = fStart
	}

	fFadeAmount[ent] -= 25.5

	if(fFadeAmount[ent] > 0.0)
	{
		set_entvar(ent, var_renderamt, fFadeAmount[ent])

		task_set(0.1, "weapon_fadeOut", ent)
	}
	else
	{
		new szClass[32]

		get_entvar(ent, var_classname, szClass, charsmax(szClass))

		if(equal(szClass, WEAPONBOX))
			weapon_remove(ent)
	}
}

public event_restartGame()
	g_bRestarting = true

public event_roundStart()
{
	new ent = -1

	while((ent = rg_find_ent_by_class(ent, WEAPONBOX)) > 0)
	{
		task_remove(ent)
		weapon_remove(ent)
	}

	for(new id = 1; id <= g_iMaxPlayers; id++)
	{
		if(!g_bAlive[id])
			continue

		g_bDefuse[id] = false
		g_bFreeLook[id] = false
		g_fLastBuy[id] = Float:{0.0, 0.0, 0.0, 0.0}

		task_remove(id - TASK_EQUIPAMENT)
		task_remove(id - TASK_TEAMBALANCE)
		task_remove(id - TASK_DEFUSE)

		if(g_bRestarting)
		{
			task_remove(id)
			task_remove(id - TASK_ADRENALINE)

			g_bRestarted[id] = true
		}
	}

	for(new iFlagTeam = TEAM_RED; iFlagTeam <= TEAM_BLUE; iFlagTeam++)
	{
		flag_sendHome(iFlagTeam)

		task_remove(g_iFlagEntity[iFlagTeam])

		log_message("%s, %s flag returned back to base.", (g_bRestarting ? "Game restarted" : "New round started"), g_szTeamName[iFlagTeam])
	}

	if(g_bRestarting)
	{
		g_iScore = {0,0,0}
		g_bRestarting = false
	}
}

public msg_block()
	return PLUGIN_HANDLED

public msg_screenFade(msgid, dest, id)
	return (g_bProtected[id] && g_bAlive[id] && get_msg_arg_int(4) == 255 && get_msg_arg_int(5) == 255 && get_msg_arg_int(6) == 255 && get_msg_arg_int(7) > 199 ? PLUGIN_HANDLED : PLUGIN_CONTINUE)

public msg_scoreAttrib()
	return (get_msg_arg_int(2) & (1<<1) ? PLUGIN_HANDLED : PLUGIN_CONTINUE)

public msg_teamScore()
{
	new szTeam[2]

	get_msg_arg_string(1, szTeam, 1)

	switch(szTeam[0])
	{
		case 'T': set_msg_arg_int(2, ARG_SHORT, g_iScore[TEAM_RED])
		case 'C': set_msg_arg_int(2, ARG_SHORT, g_iScore[TEAM_BLUE])
	}
}

public msg_roundTime()
	set_msg_arg_int(1, ARG_SHORT, get_timeleft())

public msg_sayText(msgid, dest, id)
{
	new szString[32]

	get_msg_arg_string(2, szString, charsmax(szString))

	new iTeam = (szString[14] == 'T' ? TEAM_RED : (szString[14] == 'C' ? TEAM_BLUE : TEAM_SPEC))
	new bool:bDead = (szString[16] == 'D' || szString[17] == 'D')

	if(TEAM_RED <= iTeam <= TEAM_BLUE && equali(szString, "#Cstrike_Chat_", 14))
	{
		formatex(szString, charsmax(szString), "^x01%s(%L)^x03 %%s1^x01 :  %%s2", (bDead ? "*DEAD* " : NULL), id, g_szMLFlagTeam[iTeam])
		set_msg_arg_string(2, szString)
	}
}

public msg_textMsg(msgid, dest, id)
{
	static szMsg[48]

	get_msg_arg_string(2, szMsg, charsmax(szMsg))

	if(equal(szMsg, "#Spec_Mode", 10) && !get_pcvar_num(pCvar_mp_fadetoblack) && (get_pcvar_num(pCvar_mp_forcecamera) || get_pcvar_num(pCvar_mp_forcechasecam)))
	{
		if(TEAM_RED <= g_iTeam[id] <= TEAM_BLUE && szMsg[10] == '3')
		{
			if(!g_bFreeLook[id])
			{
				player_screenFade(id, {0,0,0,255}, 0.25, 9999.0, FADE_IN, true)
				g_bFreeLook[id] = true
			}

			formatex(szMsg, charsmax(szMsg), "%L", id, "DEATH_NOFREELOOK")

			set_msg_arg_string(2, szMsg)
		}
		else if(g_bFreeLook[id])
		{
			player_screenFade(id, {0,0,0,255}, 0.25, 0.0, FADE_OUT, true)
			g_bFreeLook[id] = false
		}
	}
	else if(equal(szMsg, "#Terrorists_Win") || equal(szMsg, "#CTs_Win"))
	{
		static szString[32]

		formatex(szString, charsmax(szString), "%L", LANG_PLAYER, "STARTING_NEWROUND")

		set_msg_arg_string(2, szString)
	}
	else if(equal(szMsg, "#Only_1", 7))
	{
		formatex(szMsg, charsmax(szMsg), "%L", id, "DEATH_ONLY1CHANGE")

		set_msg_arg_string(2, szMsg)
	}

	return PLUGIN_CONTINUE
}

player_print(id, iSender, szMsg[], any:...)
{
	if((id && !g_iTeam[id]))
		return PLUGIN_HANDLED

	new szFormat[192]

	vformat(szFormat, charsmax(szFormat), szMsg, 4)
	format(szFormat, charsmax(szFormat), "%s%s", CHAT_PREFIX, szFormat)

	if(id)
		message_begin(MSG_ONE, gMsg_SayText, _, id)
	else
		message_begin(MSG_ALL, gMsg_SayText)

	write_byte(iSender)
	write_string(szFormat)
	message_end()

	return PLUGIN_HANDLED
}

player_setScore(id, Float:iAddFrags, iAddDeaths)
{
	new Float:iFrags = get_entvar( id, var_frags );
	new iDeaths =  get_member( id, m_iDeaths ); /*cs_get_user_deaths(id)*/

	if(iAddFrags != 0)
	{
		iFrags += iAddFrags

		set_entvar(id, var_frags, iFrags);
	}

	if(iAddDeaths != 0)
	{
		iDeaths += iAddDeaths

		set_member(id, m_iDeaths, iDeaths);
	}

	message_begin(MSG_BROADCAST, gMsg_ScoreInfo)
	write_byte(id) // id
	write_short(floatround(iFrags)) // Frags
	write_short(iDeaths) // Deaths
	write_short(0) // Class
	write_short(get_member(id, m_iTeam)) // Team
	message_end()
}

public getPlayers() {
	new players = 0;
	for(new i=1; i <= 32; i++)
	{
		if (1 <= get_user_team(i) <= 2) {
			++players
		}
	}
	return players;
}

player_award(id, iMoney, iFrags, iAdrenaline, szText[], any:...)
{
	#pragma unused iAdrenaline

	if(!g_iTeam[id] || (!iMoney && !iFrags) || !g_bAlive[ id ])
		return

	new szMsg[48]
	new szMoney[24]
	new szFrags[48]
	new szFormat[192]
	new szAdrenaline[48]

	if(iMoney != 0 && getPlayers() > 2)
	{
		static m; m = iMoney
		iMoney = get_member( id, m_iAccount ) + iMoney;
		rg_add_account( id, clamp(iMoney, 0, 16000), AS_SET );
		//set_user_coins(id, get_user_coins(id) + iAdrenaline);
		g_adrenaline[id] = clamp( g_adrenaline[id] + iAdrenaline, 0, 100)
		
		formatex(szMoney, charsmax(szMoney), "^x03%s%d^x04$^x01", m > 0 ? "+" : NULL, m)
	}
	
	if(iFrags != 0)
	{
		player_setScore(id, float(iFrags), 0)

		formatex(szFrags, charsmax(szFrags), "^x03%s%d^x04 %L^x01", iFrags > 0 ? "+" : NULL, iFrags, id, (iFrags > 1 ? "FRAGS" : "FRAG"))
	}

	vformat(szMsg, charsmax(szMsg), szText, 6)
	formatex(szFormat, charsmax(szFormat), "%s%s%s%s%s %s", szMoney, (szMoney[0] && (szFrags[0] || szAdrenaline[0]) ? ", " : NULL), szFrags, (szFrags[0] && szAdrenaline[0] ? ", " : NULL), szAdrenaline, szMsg)
	player_print(id, id, szFormat)
	
	replace_all(szFormat, charsmax(szFormat), "^x04", "")
	replace_all(szFormat, charsmax(szFormat), "^x03", "")
	replace_all(szFormat, charsmax(szFormat), "^x01", "")
	client_print(id, print_console, "%s%L: %s", CONSOLE_PREFIX, id, "REWARD", szFormat)
	//client_print(id, print_center, szFormat)
}

player_healingEffect(id)
{
	new iOrigin[3]

	get_user_origin(id, iOrigin)

	message_begin(MSG_PVS, SVC_TEMPENTITY, iOrigin)
	write_byte(TE_PROJECTILE)
	write_coord(iOrigin[x] + random_num(-10, 10))
	write_coord(iOrigin[y] + random_num(-10, 10))
	write_coord(iOrigin[z] + random_num(0, 30))
	write_coord(0)
	write_coord(0)
	write_coord(15)
	write_short(gSpr_regeneration)
	write_byte(1)
	write_byte(id)
	message_end()
}

player_updateRender(id, Float:fDamage = 0.0)
{
	new bool:bGlows = (get_pcvar_num(pCvar_ctf_glows) == 1)
	new iTeam = g_iTeam[id]
	new iMode = kRenderNormal
	new iEffect = kRenderFxNone
	new iAmount = 0
	new iColor[3] = {0,0,0}

	if(g_bProtected[id])
	{
		if(bGlows)
			iEffect = kRenderFxGlowShell

		iAmount = 200

		iColor[0] = (iTeam == TEAM_RED ? 155 : 0)
		iColor[1] = (fDamage > 0.0 ? 100 - clamp(floatround(fDamage), 0, 100) : 0)
		iColor[2] = (iTeam == TEAM_BLUE ? 155 : 0)
	}

	if(player_hasFlag(id))
	{
		if(iMode != kRenderTransAlpha)
			iMode = kRenderNormal

		if(bGlows)
			iEffect = kRenderFxGlowShell

		iColor[0] = (iTeam == TEAM_RED ? (iColor[0] > 0 ? 200 : 155) : 0)
		iColor[1] = (iAmount == 160 ? 55 : 0)
		iColor[2] = (iTeam == TEAM_BLUE ? (iColor[2] > 0 ? 200 : 155) : 0)

		iAmount = (iAmount == 160 ? 50 : (iAmount == 10 ? 20 : 30))
	}

	rg_set_user_rendering(id, iEffect, iColor[0], iColor[1], iColor[2], iMode, iAmount)
}

player_screenFade(id, iColor[4] = {0,0,0,0}, Float:fEffect = 0.0, Float:fHold = 0.0, iFlags = FADE_OUT, bool:bReliable = false)
{
	if(id && !g_iTeam[id])
		return

	static iType

	if(1 <= id <= g_iMaxPlayers)
		iType = (bReliable ? MSG_ONE : MSG_ONE_UNRELIABLE)
	else
		iType = (bReliable ? MSG_ALL : MSG_BROADCAST)

	message_begin(iType, gMsg_ScreenFade, _, id)
	write_short(clamp(floatround(fEffect * (1<<12)), 0, 0xFFFF))
	write_short(clamp(floatround(fHold * (1<<12)), 0, 0xFFFF))
	write_short(iFlags)
	write_byte(iColor[0])
	write_byte(iColor[1])
	write_byte(iColor[2])
	write_byte(iColor[3])
	message_end()
}

game_announce(iEvent, iFlagTeam, szName[])
{
	new iColor = iFlagTeam
	new szText[64]

	switch(iEvent)
	{
		case EVENT_TAKEN:
		{
			iColor = get_opTeam(iFlagTeam)
			formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "ANNOUNCE_FLAGTAKEN", szName, LANG_PLAYER, g_szMLFlagTeam[iFlagTeam])
		}

		case EVENT_DROPPED: formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "ANNOUNCE_FLAGDROPPED", szName, LANG_PLAYER, g_szMLFlagTeam[iFlagTeam])

		case EVENT_RETURNED:
		{
			if(strlen(szName) != 0)
				formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "ANNOUNCE_FLAGRETURNED", szName, LANG_PLAYER, g_szMLFlagTeam[iFlagTeam])
			else
				formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "ANNOUNCE_FLAGAUTORETURNED", LANG_PLAYER, g_szMLFlagTeam[iFlagTeam])
		}

		case EVENT_SCORE: formatex(szText, charsmax(szText), "%L", LANG_PLAYER, "ANNOUNCE_FLAGCAPTURED", szName, LANG_PLAYER, g_szMLFlagTeam[get_opTeam(iFlagTeam)])
	}

	set_hudmessage(iColor == TEAM_RED ? 255 : 0, 0, iColor == TEAM_BLUE ? 255 : 0, HUD_ANNOUNCE)
	show_hudmessage(0, szText)

	client_print(0, print_console, "%s%L: %s", CONSOLE_PREFIX, LANG_PLAYER, "ANNOUNCEMENT", szText)

	if(get_pcvar_num(pCvar_ctf_sound[iEvent]))
		client_cmd(0, "mp3 play ^"sound/lwf/%s.mp3^"", g_szSounds[iEvent][iFlagTeam])
}
stock rg_set_user_rendering(id, iRenderFx = kRenderFxNone, flRed = 255, flGreen = 255, flBlue = 255, iRender = kRenderNormal, flAmount = 16)
{
	new Float:flRenderColor[3];
	flRenderColor[0] = float(flRed);
	flRenderColor[1] = float(flGreen);
	flRenderColor[2] = float(flBlue);

	set_entvar(id, var_renderfx, iRenderFx);
	set_entvar(id, var_rendercolor, flRenderColor);
	set_entvar(id, var_rendermode, iRender);
	set_entvar(id, var_renderamt, float(flAmount));
}

WeaponIdType:GetCurrentWeapon( const iId )
{
    new iItem = get_member( iId, m_pActiveItem );
        
    if ( !is_entity( iItem ) )
    {
        return WEAPON_NONE;
    }
    
    new WeaponIdType:iWeapon = get_member( iItem, m_iId );
    
    if ( !( WEAPON_P228 <= iWeapon <= WEAPON_P90 ) )
    {
        return WEAPON_NONE;
    }
    
    return iWeapon;
}

math_mins_maxs(const Float:mins[3], const Float:maxs[3], Float:size[3])
{
    size[0] = (xs_fsign(mins[0]) * mins[0]) + maxs[0]
    size[1] = (xs_fsign(mins[1]) * mins[1]) + maxs[1]
    size[2] = (xs_fsign(mins[2]) * mins[2]) + maxs[2]
}
stock xs_fsign(Float:num)
{
    return (num < 0.0) ? -1 : ((num == 0.0) ? 0 : 1);
}

public CREATE_BeamEnts(idf)
{
	new id = idf-140
	
	if(1 <= id <= g_iMaxPlayers)
	{
		if(g_iTeam[id]!=TEAM_BLUE && g_iTeam[id]!=TEAM_RED)
			return;
		/*
		1= la bandera está en la base enemiga (flag_sendHome)
		2= tengo la bandera (flag_take)
		3= la bandera no está en la base enemiga 
		-----------------
		1= la bandera mia esta en mi base y tengo la bandera
		2= mi bandera no esta en base y tengo bandera*/
		if(g_iFlagHolder[get_opTeam(g_iTeam[id])] == id) // tengo la bandera enemiga
		{
			if(g_iTeam[id]==TEAM_BLUE) { // soy azul
				if (g_iFlagHolder[g_iTeam[id]] == FLAG_HOLD_BASE) // mi bandera esta en base
					UTIL_BeamEnts(id,{0,0,150});
				else UTIL_BeamEnts(id,{255,255,255}); // mi bandera no está en base
			}
			else if(g_iTeam[id]==TEAM_RED) { // soy rojo
				if (g_iFlagHolder[g_iTeam[id]] == FLAG_HOLD_BASE) // mi bandera esta en base
					UTIL_BeamEnts(id,{150,0,0});
				else UTIL_BeamEnts(id,{255,255,255}); // mi bandera anda por ahí xD
			}
		}
	}
}

stock REMOVE_BeamEnts(id)
{
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte(TE_KILLBEAM);
	write_short(id);
	message_end();
}

stock UTIL_BeamEnts(id,rgb[3],team=0)
{
	if (!team) team = g_iTeam[id]
	else team = get_opTeam(g_iTeam[id])

	engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, {0.0, 0.0, 0.0}, id)
	write_byte(TE_BEAMENTPOINT);
	write_short(id);             //Индекс entity
	engfunc( EngFunc_WriteCoord, g_fFlagBase[team][x] );//Конечная точка
	engfunc( EngFunc_WriteCoord, g_fFlagBase[team][y] );//Конечная точка
	engfunc( EngFunc_WriteCoord, g_fFlagBase[team][z] );//Конечная точка
	write_short(gHealingBeam);					//Индекс спрайта 
	write_byte(0) 								//Стартовый кадр
	write_byte(0); 								//Скорость анимации
	write_byte(0); 								//vida en 0.1's
	write_byte(60); 							//Толщина луча
	write_byte(0);		 						//Искажение
	write_byte( rgb[0] ); 						//Цвет красный
	write_byte( rgb[1] ); 						//Цвет зеленый
	write_byte( rgb[2] ); 						//Цвет синий
	write_byte(130); 							//Яркость
	write_byte(0);
	message_end();
}