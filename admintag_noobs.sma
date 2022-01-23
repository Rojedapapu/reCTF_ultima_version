#include <amxmodx>
#include <amxmisc>

native get_roleUser(id, dest[], len);
native get_rango(id, dest[], len);

new gSzTag[ 33 ][ 32 ], gszRango[33][32], gPlayerName[ 33 ][ 32 ], gMaxPlayers;

public plugin_init()
{
	register_plugin( "Admin Tag(Para noobs)" , "0.1" , "kikizon" );
	
	register_clcmd( "say" , "clcmdSay" );
	register_clcmd( "say_team" , "clcmdSayTeam" );

	gMaxPlayers = get_maxplayers();
}

public client_putinserver( index )
{
	get_user_name( index , gPlayerName[index], 31 );
	gSzTag[index][0] = EOS;
	gszRango[index][0] = EOS;

	get_roleUser(index, gSzTag[index], 31);
	get_rango(index, gszRango[index], 31);
}

public client_infochanged( index )
{
	new oldname[32], newname[32];
	get_user_name( index , oldname, 31 );
	get_user_info( index , "name", newname, 31 );

	if( !equal(oldname, newname))
		copy( gPlayerName[index], 31, newname );
}

public clcmdSay(index)
{
	static said[191]; read_args(said, 190); remove_quotes(said); replace_all(said, 190, "%", ""); replace_all(said, 190, "#", "");

	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;

	get_rango(index, gszRango[index], 31);

	static color[11], prefix[128]; get_user_team(index, color, 10);
	formatex(prefix, 127, "%s^x04%s^x01[ ^x04%s^x01 ] ^x03%s", is_user_alive(index)?"^x01":"^x01*MUERTO* ", gSzTag[index], gszRango[index], gPlayerName[index]);

	if (is_user_admin(index)) format(said, charsmax(said), "^x04%s", said);

	format(said, charsmax(said), "%s^x01 : %s", prefix, said);

	static i, team[11];

	for (i = 1; i <= gMaxPlayers; ++i)
	{
		if (!is_user_connected(i)) continue;

		get_user_team(i, team, 10);
		changeTeamInfo(i, color);
		writeMessage(i, said);
		changeTeamInfo(i, team);
	}
    
	return PLUGIN_HANDLED_MAIN;
}

public clcmdSayTeam( index )
{
	static said[191]; read_args(said, 190); remove_quotes(said); replace_all(said, 190, "%", ""); replace_all(said, 190, "#", "");

	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;

	static playerTeam, playerTeamName[20]; playerTeam = get_user_team(index);

	switch (playerTeam)
	{
		case 1: formatex( playerTeamName, 19, "^x01(^x03 CT^x01 ) " );
		case 2: formatex( playerTeamName, 19, "^x01(^x03 TT^x01 ) " );
		default: formatex( playerTeamName, 19, "^x01(^x03 SPEC^x01 ) " );
	}

	static color[11], prefix[128]; get_user_team(index, color, 10); 
	formatex(prefix, 127, "%s%s^x04%s^x03 %s", is_user_alive(index)?"^x01":"^x01*DEAD* ", playerTeamName, gSzTag[index], gPlayerName[index]);

	if (is_user_admin(index)) format(said, charsmax(said), "^x04%s", said);

	format(said, charsmax(said), "%s^x01 : %s", prefix, said);

	static i, team[11];
	for (i = 1; i <= gMaxPlayers; ++i)
	{
		if (!is_user_connected(i) || get_user_team(i) != playerTeam) continue;

		get_user_team(i, team, 10);
		changeTeamInfo(i, color);
		writeMessage(i, said);
		changeTeamInfo(i, team);
	}	

	return PLUGIN_HANDLED_MAIN;
}

stock ValidMessage(text[], maxcount) 
{
	static len, i, count;
	len = strlen(text);
	count = 0;

	if (!len) return false;

	for (i = 0; i < len; ++i) 
	{
		if (text[i] != ' ') 
		{
			++count;
			
			if (count >= maxcount)
				return true;
		}
	}

	return false;
}

public changeTeamInfo(player, team[])
{
	static msgteamInfo;
	if( !msgteamInfo ) msgteamInfo = get_user_msgid( "TeamInfo" );

	message_begin(MSG_ONE, msgteamInfo, _, player);
	write_byte(player);
	write_string(team);
	message_end();
}

public writeMessage(player, message[])
{
	static msgSayText;
	if( !msgSayText ) msgSayText = get_user_msgid( "SayText" );

	message_begin(MSG_ONE, msgSayText, {0, 0, 0}, player);
	write_byte(player);
	write_string(message);
	message_end();
}