#include <amxmodx>
#include <fakemeta>
#include <fun>
#include <engine>

#define GIVE_HEALTH 60 	// Cuánto HP restaurar
#define EXPLODE_TIME 1.0 	// Después de cuántos segundos explotará la granada
#define HEAL_RADIUS 300.0 	// Radio
#define GENERAL_EXPLODE 	// Enciende el Sprite de explosión principal
#define TWO_EXPLODE 	// habilita desechos adicionales de la explosión
//#define SHOKWAVE 		// Gire a Shokwave alrededor de la granada cuando explote
//#definir SCREENFADE 	// Activar screenfade
#define STATUSICON 		// mostrar icono
#define TOUCH_EXPLODE 	// Si explotar inmediatamente al entrar en contacto con objetos

//-------------------------------------
#define V_MODEL	"models/v_he_mk_nade.mdl"
#define P_MODEL	"models/p_he_mk_nade.mdl"
#define W_MODEL	"models/w_he_mk_nade.mdl"

#if defined GENERAL_EXPLODE
#define EXPLODE_SPRITE	"sprites/heal_explode.spr"
#endif

#if defined TWO_EXPLODE
#define EXPLODE_SPRITE2	"sprites/heal_shape.spr"
#endif

#define HEAL_SOUND	"woomen_expr.wav"
//--------------------------------------

#if defined GENERAL_EXPLODE
new ExplSpr;
#endif

#if defined TWO_EXPLODE
new ExplSpr2;
#endif

#if defined SHOKWAVE
new g_iSpriteCircle;
#endif

#if defined STATUSICON
new g_IconStatus;
#endif

new const g_sound_explosion[] = "weapons/sg_explode.wav";
new const g_classname_grenade[] = "grenade";
new g_eventid_createsmoke;

public plugin_init() 
{
	register_plugin("Nade Health", "1.2", "medusa");

	#if defined STATUSICON
	g_IconStatus = get_user_msgid("StatusIcon");
	#endif

	register_forward(FM_EmitSound, "FMForward_EmitSound");
	register_forward(FM_PlaybackEvent, "FMForward_PlaybackEvent");
	register_event("CurWeapon", "EVCurWeapon", "be", "1=1");
	register_forward(FM_SetModel, "FMForward_SetModel", 1);

	register_think("grenade", "FMForward_Think" )

	#if defined TOUCH_EXPLODE
	register_touch("grenade", "*", "FMForward_Touch")
	#endif
	g_eventid_createsmoke = engfunc(EngFunc_PrecacheEvent, 1, "events/createsmoke.sc");
}

public plugin_precache()
{
	#if defined GENERAL_EXPLODE
	ExplSpr = precache_model(EXPLODE_SPRITE);
	#endif

	#if defined TWO_EXPLODE
	ExplSpr2 = precache_model(EXPLODE_SPRITE2);
	#endif

	precache_model(V_MODEL);
	precache_model(W_MODEL);
	precache_model(P_MODEL);

	precache_sound(HEAL_SOUND);

	#if defined SHOKWAVE
	g_iSpriteCircle = precache_model("sprites/shockwave.spr");
	#endif
}

public EVCurWeapon(id)
{
	if(is_user_connected(id) && is_user_alive(id))
	{
		if(get_user_weapon(id) == CSW_SMOKEGRENADE)
		{
			set_pev(id, pev_viewmodel2, V_MODEL);
			set_pev(id, pev_weaponmodel2, P_MODEL);

			#if defined STATUSICON
			message_begin(MSG_ONE_UNRELIABLE, g_IconStatus, {0,0,0}, id);
			write_byte(2)
			write_string("cross");
			write_byte(0);
			write_byte(255);
			write_byte(0);
			message_end();
			#endif
		}
		#if defined STATUSICON
		else
		{
			message_begin(MSG_ONE_UNRELIABLE, g_IconStatus, {0,0,0}, id);
			write_byte(0)
			write_string("cross");
			message_end();
		}
		#endif
	}
}

public FMForward_SetModel(entity, const model[])
{
	if(!pev_valid(entity)) return FMRES_IGNORED;
	
	if(equal(model, "models/w_smokegrenade.mdl"))
	{
		engfunc(EngFunc_SetModel, entity, W_MODEL);
		set_pev(entity, pev_dmgtime, get_gametime() + EXPLODE_TIME);
	}
	return FMRES_IGNORED;
}

#if defined TOUCH_EXPLODE
public FMForward_Touch(entity)
{
	if(~get_pdata_int(entity, 114) & (1<<1))
		return;

	set_pev(entity, pev_dmgtime, get_gametime());
}
#endif


public FMForward_Think(entity)
{
	if(get_pdata_int(entity, 114) & (1<<1))
		set_pev( entity, pev_flags, FL_ONGROUND ) 
}


public FMForward_EmitSound(entity, channel, const sound[])
{
	if (!equal(sound, g_sound_explosion) || !is_grenade(entity))
		return FMRES_IGNORED;

	static Float:origin[3];
	static id; id = pev(entity, pev_owner);
	pev(entity, pev_origin, origin);
	engfunc(EngFunc_EmitSound, entity, CHAN_WEAPON, HEAL_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

	#if defined GENERAL_EXPLODE
	message_begin(MSG_PVS,SVC_TEMPENTITY,{0,0,0});
	write_byte(TE_EXPLOSION);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2])+65);
	write_short(ExplSpr);
	write_byte(30);
	write_byte(20);
	write_byte(TE_EXPLFLAG_NOSOUND|TE_EXPLFLAG_NOPARTICLES);
	message_end();
	#endif
	
	#if defined TWO_EXPLODE
	message_begin(MSG_ALL,SVC_TEMPENTITY,{0,0,0});
	write_byte(TE_SPRITETRAIL);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2])+20);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2])+80);
	write_short(ExplSpr2);
	write_byte(20);
	write_byte(20);
	write_byte(4);
	write_byte(20);
	write_byte(10);
	message_end();
	#endif

	#if defined SHOKWAVE
	message_begin(MSG_ALL, SVC_TEMPENTITY, {0,0,0});
	write_byte(TE_BEAMCYLINDER);
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2]));
	write_coord(floatround(origin[0]));
	write_coord(floatround(origin[1]));
	write_coord(floatround(origin[2] + HEAL_RADIUS));
	write_short(g_iSpriteCircle);
	write_byte(0);
	write_byte(1);
	write_byte(5);
	write_byte(30);
	write_byte(1);
	write_byte(10);
	write_byte(255);
	write_byte(40);
	write_byte(255);	
	write_byte(5);
	message_end();
	#endif
	
	new user
	while((user = find_ent_in_sphere(user,origin,HEAL_RADIUS)) != 0)
	{
		if(is_user_alive(user) && get_user_team(user) == get_user_team(id))
		{
			#if defined SCREENFADE
			message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, user);
			write_short(1<<10);
			write_short(1<<10);
			write_short(0x0000);
			write_byte(170);
			write_byte(255);
			write_byte(0);
			write_byte(75);
			message_end();
			#endif
		
			new health[32];
   			health[user] = get_user_health(user);

   			if (health[user] <= 100 - GIVE_HEALTH)
				set_user_health(user,health[user] + GIVE_HEALTH);
			else if(health[user] > 100 - GIVE_HEALTH)
				set_user_health(user,100);
		}
	}

	return FMRES_SUPERCEDE;
}

public FMForward_PlaybackEvent(flags, invoker, eventindex) {
	if (eventindex == g_eventid_createsmoke)
		return FMRES_SUPERCEDE;

	return FMRES_IGNORED;
}

bool:is_grenade(entity) 
{
	if (!pev_valid(entity))
		return false;

	static classname[sizeof g_classname_grenade + 1]
	pev(entity, pev_classname, classname, sizeof g_classname_grenade);

	if (equal(classname, g_classname_grenade))
		return true;

	return false;
}
