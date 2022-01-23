/*=====================================
* 		[ Preproccesor ]
* =====================================*/

#include <amxmodx>
//#include <dhudmessage>

new g_streak[33], g_playername[33][32], SyncHUDMsg, FirstKiLL, g_announcing
new color_hud[3], cvar_color
//
enum
{
	MODE_HEADSHOT = 0,
	MODE_GRENADE,
	MODE_KNIFE,
	MODE_LAG,
	MODE_CARHIT
}

/*=====================================
* 		[ Customization ]
* =====================================*/

new level_streak[] = { 2, 4, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23 }
new const firstkill[] = "svenmod/firstkill.wav"
new const prepare[] = "svenmod/prepare.wav"

// Streak sounds
new const streak_sounds[][] =
{
	"svenmod/doublekill.wav",
	"svenmod/triplekill.wav",
	"svenmod/multikill.wav",
	"svenmod/excellent.wav",
	"svenmod/impressive.wav",
	"svenmod/crazy.wav",
	"svenmod/incredible.wav",
	"svenmod/perfect.wav",
	"svenmod/ownage.wav",
	"svenmod/outofworld.wav",
	"svenmod/wickedsick.wav",
	"svenmod/godlike.wav"
}

// Streak Messages!=
new const streak_messages[][] =
{
	"%s Double Kill!",
	"%s Triple Kill!",
	"%s Multi Kill!",
	"%s is Excellent!",
	"%s Impresive!",
	"%s Crazy!",
	"%s Incredible!",
	"%s Perfect!",
	"%s Rampage!!",
	"%s Out of This World!",
	"%s Wicked Sick!",
	"%s Godlike!"
}

// Fun sounds haha
new const fun_sounds[][] =
{
	"svenmod/bheadshot.wav",
	"svenmod/donativum.wav",
	"svenmod/humililation.wav",
	"svenmod/jihad.wav",
	"svenmod/shitlag.wav",
	"svenmod/borracha.wav"
}

// Funny Messaging
new const fun_messages[][] =
{
	"%s Headshot!",
	"%s le mando un regalito a %s..",
	"%s es veloz y silencioso.. tanto que se chingo a %s",
	"%s Jihad!",
	"%s esta lag JAJAJAJA!",
	"%s esta borracho JAJAJAJA!"
}

/*=====================================
* 		[ Precaching ]
* =====================================*/

public plugin_precache()
{
	new i
	
	for(i = 0; i < sizeof streak_sounds; i++)
		precache_sound(streak_sounds[i])
	for(i = 0; i < sizeof fun_sounds; i++)
		precache_sound(fun_sounds[i])
	
	precache_sound(firstkill)
	precache_sound(prepare)
}

/*=====================================
* 		[ Initialization ]
* =====================================*/

public plugin_init()
{
	// Amx Mod X
	register_plugin("Advanced Sounds", "1.1", "[S]ven'H.")
	register_event("DeathMsg", "event_deathmsg", "a")
	register_event("ResetHUD", "event_resethud", "be")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	
	cvar_color = register_cvar("amx_as_hudcolor", "200200200") // rrrgggbbb
	
	// Other
	SyncHUDMsg = CreateHudSyncObj()
}

/*=====================================
* 		[ AMXX ]
* =====================================*/

// Death message event
public event_deathmsg()
{
	new victim, attacker, headshot, kweap[6]
	attacker = read_data(1); victim = read_data(2); headshot = read_data(3) // victim/attacker/headshot'd
	read_data(4, kweap, charsmax(kweap)) // killweapon
	
	// First Kill
	if(!FirstKiLL && !g_announcing && is_user_connected(attacker))
	{
		FirstKiLL = true
		g_announcing = true
		
		set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.60, 0, 0.0, 2.0, 0.0, 0.0)
		show_dhudmessage(0, "%s First Kill!", g_playername[attacker])
		
		// Play Sound
		client_cmd(0, "spk %s", firstkill)
		set_task(2.0, "remove_announcing")
	}
	
	// Headshot'd
	if(headshot)
		announce_funmod(0, attacker, MODE_HEADSHOT, 2.0)
	
	// Custom weap death
	if(contain(kweap, "knif")) // knife
		announce_funmod(victim, attacker, MODE_KNIFE, 2.0)
	else if (contain(kweap, "gren")) // grenade
		announce_funmod(victim, attacker, MODE_GRENADE, 2.0)
	else if (contain(kweap, "vehi") || contain(kweap, "worl")) // vehicle or worldspawn (always 0)
		announce_funmod(victim, attacker, MODE_CARHIT, 2.0)
	
	new ping, lul
	get_user_ping(victim, ping, lul)
	
	// Lagged?
	if(ping > 200)
		announce_funmod(victim, 0, MODE_LAG, 2.0)
	
	// Frags up for attacker, frags removed for victim
	g_streak[attacker]++
	g_streak[victim] = 0
	
	// He touched a streak level
	if(streak_available(attacker) && !g_announcing)
	{
		new i, level
		
		// Check
		for(i = 0; i < sizeof streak_messages; i++)
		{
			if(g_streak[attacker] == level_streak[i])
			{
				level = i
				break;
			}
		}
		
		announce_advanced(attacker, level, 2.0)
	}
}

// Player Spawn forward
public event_resethud(id)
{
	set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.60, 2, 0.01, 2.0, 0.01, 1.0)
	show_dhudmessage(id, "Preparate para la batalla!")
	
	client_cmd(id, "spk %s", prepare)
}

// Client Putinserver forward
public client_putinserver(id)
{
	// Cache name
	get_user_name(id, g_playername[id], charsmax(g_playername[]))
	
	// Clear streak
	g_streak[id] = 0
}

// Round start event
public event_round_start()
{
	// Reset First Kill
	FirstKiLL = false
}

/*=====================================
* 		[ Functions ]
* =====================================*/

// Is streak avaiable to play?
bool:streak_available(id)
{
	static i
	
	for(i = 0; i < sizeof streak_sounds; i++)
	{
		if(g_streak[id] == level_streak[i])
			return true;
		
	}
	
	return false;
}

// Announce something (for streak)
announce_advanced(attacker, level, Float:duration)
{
	if(g_announcing)
		return;
	
	// We're announcing something, so don't show another messages
	g_announcing = true
	
	// Show it
	set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0)
	show_dhudmessage(0, streak_messages[level], g_playername[attacker])
	
	// Play it
	client_cmd(0, "spk %s", streak_sounds[level])
	
	// Remove the announcing message
	set_task(duration, "remove_announcing")
}

// Announce something (for fun mod)
announce_funmod(victim, attacker, mode, Float:duration)
{
	if(g_announcing)
		return;
	
	// We're announcing something, so don't show another messages
	g_announcing = true
	
	// Switch the mode to see what are we are going to do
	switch(mode)
	{
		case MODE_HEADSHOT: // Headshot
		{
			// Show it
			set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0)
			show_dhudmessage(0, fun_messages[0], g_playername[attacker])		
			
			// Play it
			client_cmd(0, "spk %s", fun_sounds[0])
		}
		case MODE_GRENADE: // Owned by a grenade
		{
			if(victim == attacker)
			{
				// Show it
				set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0)
				show_dhudmessage(0, fun_messages[3], g_playername[attacker])
				
				// Play it
				client_cmd(0, "spk %s", fun_sounds[3])
			}
			else
			{
				// Show it
				set_hudmessage(200, 200, 200, -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0, -1)
				ShowSyncHudMsg(0, SyncHUDMsg, fun_messages[1], g_playername[attacker], g_playername[victim])
				
				// Play it
				client_cmd(0, "spk %s", fun_sounds[1])
				
			}
		}
		case MODE_KNIFE: // Knifed
		{
			// Show it
			set_hudmessage(200, 200, 200, -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0, -1)
			ShowSyncHudMsg(0, SyncHUDMsg, fun_messages[2], g_playername[attacker], g_playername[victim])
			
			// Play it
			client_cmd(0, "spk %s", fun_sounds[2])
		}
		case MODE_LAG: // Lagged idiot
		{
			// Show it
			set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0)
			show_dhudmessage(0, fun_messages[4], g_playername[victim])
			
			// Play it
			client_cmd(0, "spk %s", fun_sounds[4])
		}
		case MODE_CARHIT: // Pwned by a vehicle
		{
			// Show it
			set_dhudmessage(color_hud[0], color_hud[1], color_hud[2], -1.0, 0.15, 0, 0.0, duration, 0.0, 0.0)
			show_dhudmessage(0, fun_messages[5], g_playername[victim])
			
			// Play it
			client_cmd(0, "spk %s", fun_sounds[5])
		}
	}
	
	// Remove the announcing message
	set_task(duration, "remove_announcing")
}

// Remove announcing
public remove_announcing()
{
	g_announcing = false
	
	new mycol[12]
	get_pcvar_string(cvar_color, mycol, charsmax(mycol))
	color_hud[2] = str_to_num(mycol[6])
	
	mycol[6] = 0
	color_hud[1] = str_to_num(mycol[3])
	
	mycol[3] = 0
	color_hud[0] = str_to_num(mycol[0])
}
