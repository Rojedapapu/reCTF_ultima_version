#include <amxmodx>
#include <reapi>

const NUKE_TASK = 9999;
const MAX_KILLS = 20;

new const g_NukeExplode[] = "nuke/explode.wav";

#define is_valid_player_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))

new g_Kills[33], g_explode;

public plugin_init() {
	RegisterHookChain( RG_CBasePlayer_Killed, "RG_PlayerKilled_Post", .post = true );

	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
}

public plugin_precache() {
	precache_sound(g_NukeExplode);
}

public client_putinserver(id) {
	g_Kills[id] = 0;
}

public event_round_start() {
	remove_task(NUKE_TASK);
	g_explode = false;
}

public RG_PlayerKilled_Post( victim, attacker, shouldgib ) {
	if( !is_valid_player_alive( attacker ) || victim == attacker || get_member( attacker, m_iTeam ) == get_member( victim, m_iTeam ) )
        return;

	if (++g_Kills[ attacker ] >= MAX_KILLS && !g_explode) {
		make_nuke();
	}
}

public make_nuke() {
	remove_task(NUKE_TASK);

	client_cmd(0, "spk ^"%s^"", g_NukeExplode);
	set_task(0.8, "task_launch_nuke", NUKE_TASK);
	set_task(2.0, "task_nuke_kills_players", NUKE_TASK);

	g_explode = true;
}

public task_launch_nuke()
{
	static g_msgScreenFade;
	if(!g_msgScreenFade)g_msgScreenFade = get_user_msgid("ScreenFade");

	message_begin(MSG_BROADCAST, g_msgScreenFade);
	write_short((1<<12)*4);
	write_short((1<<12)*1);
	write_short(0x0001);
	write_byte (255);
	write_byte (255);
	write_byte (255);
	write_byte (255); 
	message_end();
}

public task_nuke_kills_players()
{
	static id, deathmsg_block, g_msgDeathMsg;

	if(!g_msgDeathMsg) g_msgDeathMsg = get_user_msgid("DeathMsg");
	deathmsg_block = get_msg_block(g_msgDeathMsg);

	set_msg_block(g_msgDeathMsg, BLOCK_SET);

	for (id = 1; id <= MAX_PLAYERS; id++) {
	    if (is_user_alive(id))
	        user_kill(id, 1);

	    g_Kills[id] = 0;
	}
	g_explode = false;
	set_msg_block(g_msgDeathMsg, deathmsg_block);
} 