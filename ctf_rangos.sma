/*

    CREATE TABLE csgo_table2 
    (
        id_cuenta INT PRIMARY KEY NOT NULL,
        rango int(2) NOT NULL DEFAULT '0',
        frags int(10) NOT NULL DEFAULT '0',
        hs int(10) NOT NULL DEFAULT '0',
        kills int(10) NOT NULL DEFAULT '0',
        deaths int(10) NOT NULL DEFAULT '0'
    );
    
    hacer hud de top15 mejores players
    mostrar rango y rank
    recoger skins de los muertos-
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <accsys>
#include <reapi>
#include <sqlx>

native set_user_coins(id, cant);
native get_user_coins(id);

native set_user_adrenaline(id, cant);
native get_user_adrenaline(id);

#pragma semicolon 1

#define is_valid_player_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))

#define ID_SHOWHUD (taskid - TASK_SHOWHUD)

#if AMXX_VERSION_NUM > 182
    #define client_disconnect client_disconnected
#endif

/*** menu teams **/
#define FILE_NAME     "team_select_menu.ini"
#define MODEL         "model"
#define MAX_NUM_TEAMS 2
#define MAX_PLAYERS   32

#define KEYS          ( 1<<0 | 1<<1 | 1<<2 | 1<<3 | 1<<4 | 1<<5 | 1<<6 | 1<<7 | 1<<8 | 1<<9 )

#define EXTRAOFFSET   5
#define OFFSET_ISVIP  209
#define PLAYER_IS_VIP ( 1<<8 )

#define USER_TEAM     114
#define cste_get_user_team(%0) (get_pdata_int(%0, USER_TEAM) - 1)

enum {
    CSTE_UNASSIGNED = -1,
    CSTE_TEAM_T     = 0,
    CSTE_TEAM_CT,
    CSTE_SPECTATOR
}

enum _:NumDatas {
    CLASS_NAME = 0,
    CLASS_TAG,
    CLASS_ACCESS
}

new g_szConfigFile[128];
new g_szClassesT[32][NumDatas][64],
    g_szClassesCT[32][NumDatas][64],
    g_szClassAccess[MAX_NUM_TEAMS][32];
new g_szTeamName[2][128];
new g_iCount[MAX_NUM_TEAMS];
new g_iUserTeam[MAX_PLAYERS+1];
new g_szPlayerModel[MAX_PLAYERS+1][128];

new g_pCvarAllowSpec,
    g_pCvarLimitTeams,
    g_pCvarTeamBalance;


/*** menu teams **/

public stock g_szPlugin[ ] = "Rangos CS:GO";
public stock g_szVersion[ ] = "1.0b";
public stock g_szAuthor[ ] = "Hypnotize";

const Float:HUD_STATS_X = 0.02;
const Float:HUD_STATS_Y = 0.02;

enum _:eRangos
{
    rango_name[ 80 ],
    level_req,
    url_rango[ 120 ]
};

new const g_aRangos[ 19 ][ eRangos ] = 
{
    { "Unranked", 200, "https://i.ibb.co/HHzfg5T/0.png" },
    { "Silver I", 888, "https://i.ibb.co/hDWSG8d/1.png" },
    { "Silver II", 1200, "https://i.ibb.co/dgSPLD9/2.png" },
    { "Silver III", 1800, "https://i.ibb.co/Bc6jsjM/3.png" },
    { "Silver IV", 2300, "https://i.ibb.co/3pnjRS7/4.png" },
    { "Silver Elite", 3700, "https://i.ibb.co/GpkgZq0/5.png" },
    { "Silver Elite Master", 4500, "https://i.ibb.co/b6F3PPF/6.png" },
    { "Gold Nova I", 4900, "https://i.ibb.co/JjB8JYH/7.png" },
    { "Gold Nova II", 5700, "https://i.ibb.co/kmrfpqH/8.png" },
    { "Gold Nova III", 6300, "https://i.ibb.co/HVzW4jF/9.png" },
    { "Gold Nova Master", 7500, "https://i.ibb.co/7XMCzyV/10.png" },
    { "Master Guardian I", 8700, "https://i.ibb.co/q7s3Syr/11.png" },
    { "Master Guardian II", 10000, "https://i.ibb.co/hWSbXfh/12.png" },
    { "Master Guardian Elite", 10700, "https://i.ibb.co/P9GNsTk/13.png" },
    { "Distinguished Master Guardian", 11600, "https://i.ibb.co/6Dr0D41/14.png" },
    { "Legendary Eagle", 13000, "https://i.ibb.co/qd5J8Rh/15.png" },
    { "Legendary Eagle Master",14300, "https://i.ibb.co/fX5nPZx/16.png" },
    { "Supreme Master First Class", 17600, "https://i.ibb.co/xFgd2jg/17.png" },
    { "The Global Elite", 0, "https://i.ibb.co/WVqzsg7/18.png" }
};

enum 
{ 
    M4A1 = 0/*NO MODIFICAR ESTE*/,  
    AK47, 
    AWP,
    //aca se agregan mas armas, todo va con base en este orden
    DEAGLE,
    KNIFE,

    WEAPONS_MAX //NO AGREGAR NADA DESPUES DE ESTE
};

new const szNameWeapons[ WEAPONS_MAX ][] = { "M4A1", "AK47", "AWP", "DEAGLE", "KNIFE" };//aca se agregan mas armas

enum _:myWeapons
{
    wpn_name[ 60 ],
    WeaponIdType:wpn_weapon,
    wpn_v[ 120 ],
    wpn_p[ 120 ],
    wpn_kills,
    wpn_type,
    wpn_id
}

/*
models/v_m4a19.mdl
models/v_m4a18.mdl
models/v_usp1.mdl
models/v_usp2.mdl
models/v_ak477
models/v_ak478
models/v_deagle1.mdl
models/v_deagle2.mdl
*/

new const aWeapons[ ][ myWeapons ] =
{
    //m4a1
    { "Normal", WEAPON_M4A1, "default", "default", 0, ADMIN_ALL, M4A1 },
    { "Halloowin", WEAPON_M4A1, "v_m4_lwf1", "default", 4, ADMIN_ALL, M4A1 },
    { "Fallout", WEAPON_M4A1, "v_m4_lwf2", "default", 10, ADMIN_ALL, M4A1 },
    { "Camo", WEAPON_M4A1, "v_m4_lwf3", "default", 13, ADMIN_ALL, M4A1 },
    { "Lwf Premium", WEAPON_M4A1, "v_m4_lwf4", "default", 0, ADMIN_BAN, M4A1 },
    //ak
    { "Normal", WEAPON_AK47, "default", "default", 0, ADMIN_ALL, AK47 },
    { "Tactical", WEAPON_AK47, "v_ak_lwf1", "default", 6, ADMIN_ALL, AK47 },
    { "Mafia", WEAPON_AK47, "v_ak_lwf2", "default", 10, ADMIN_ALL, AK47 },
    { "Asiimov", WEAPON_AK47, "v_ak_lwf3", "default", 12, ADMIN_ALL, AK47 },
    { "Lwf Premium", WEAPON_AK47, "v_ak_lwf4", "default", 0, ADMIN_BAN, AK47 },

    //awp
    /*{ "Normal", WEAPON_AWP, "default", "default", 0, ADMIN_ALL, AWP },
    { "Artic", WEAPON_AWP, "v_awp_artic", "default", 8, ADMIN_ALL, AWP },
    { "Ohka", WEAPON_AWP, "v_awp_ohka", "default", 14, ADMIN_ALL, AWP },
    { "PWE", WEAPON_AWP, "v_awp_pwe", "default", 0, ADMIN_BAN, AWP },*/

    //deagle
    { "Normal", WEAPON_DEAGLE, "default", "default", 0, ADMIN_ALL, DEAGLE },
    { "Armik", WEAPON_DEAGLE, "v_dg_lwf1", "default", 6, ADMIN_ALL, DEAGLE },
    { "Revolver", WEAPON_DEAGLE, "v_dg_lwf2", "default", 16, ADMIN_ALL, DEAGLE },
    { "Debra", WEAPON_DEAGLE, "v_dg_lwf3", "default", 18, ADMIN_ALL, DEAGLE },
    { "Lwf Premium", WEAPON_DEAGLE, "v_dg_lwf4", "default", 0, ADMIN_BAN, DEAGLE },

    { "Normal", WEAPON_KNIFE, "default", "default", 0, ADMIN_ALL, KNIFE },
    { "Letal", WEAPON_KNIFE, "v_kn_lwf1", "default", 6, ADMIN_ALL, KNIFE },
    { "Empuñadura", WEAPON_KNIFE, "v_kn_lwf2", "default", 16, ADMIN_ALL, KNIFE },
    { "Cuchillo", WEAPON_KNIFE, "v_kn_lwf3", "default", 18, ADMIN_ALL, KNIFE },
    { "Lwf Premium", WEAPON_KNIFE, "v_kn_lwf4", "default", 0, ADMIN_BAN, KNIFE }

    //deagle, en el orden que esta arriba

};

new g_iWeapon[ 33 ][ WEAPONS_MAX ];

const m_LastHitGroup = 75; 
const TASK_SHOWHUD = 55555;

new cvar_hs, cvar_knife, cvar_kill, cvar_hegreande, cvar_shop;
new g_msgHud, g_iHudTeam, g_iMsgSayText, g_iMsgText, buy_shop, g_iMenuMsgid;

new g_iRango[ 33 ], g_iFrags[ 33 ], g_iTeam[ 33 ], g_iHs[ 33 ], g_iDeaths[ 33 ], g_iKills[ 33 ];
new g_szPlayerName[ 33 ][ 32 ];
new activeHud[33];

new const szTable[] = "csgo_table2";

new g_id[ 33 ];
new Handle:g_hTuple;


enum
{
    REGISTRAR_USUARIO,
    LOGUEAR_USUARIO,
    GUARDAR_DATOS,
    SQL_RANK,
    TOP15
};

new g_iStatus[33];
enum
{
    NO_LOGUEADO = 0,
    LOGUEADO
};

public advacc_guardado_login_success( id )
{
    if( is_user_connected( id ) )
    {
        g_id[ id ] = advacc_guardado_id( id );

        team_menu(id);
    }
}
public team_menu(id) {
    new szItem[512], len, bitKeys;
    bitKeys = ( 1<<0 | 1<<1 | 1<<4 | 1<<9 );

    len = format(
        szItem, 511,"\ySelecciona un Equipo^n^n\r1. \w%s^n\r2. \w%s^n^n\r5. \wAuto-selec^n",
        g_szTeamName[0], g_szTeamName[1]
    );

    if(get_pcvar_num(g_pCvarAllowSpec) && !is_user_alive(id)) {
        bitKeys |= 1<<5;
        len += format(szItem[len], 511-len, "\r6. \wEspectador \r[ \wADMIN \r]\w^n");
    }

    len += format(szItem[len], 511-len, "^n\r0. \wSalir^n");
    show_menu(id, bitKeys, szItem, -1, "TeamMenu");
}

// Handle teams menu -----------------------------------------------------------
public team_menu_handler(id, key) {
    switch(key+1) {
        case 1, 2: {
            if(join_allow(id) != key+1 && join_allow(id) != 3) {
                g_iUserTeam[id] = key;
                team_join(id, key);
                create_classes_menu(id, key);
            }
        }
        case 5: {
            new iRand;
            iRand = random(2);
            g_iUserTeam[id] = iRand;
            team_join(id, iRand);
            create_classes_menu(id, iRand);
        }
        case 6: {
            if(get_pcvar_num(g_pCvarAllowSpec) && !is_user_alive(id)) 
            {
                if(has_flag(id, "t"))
                {
                    g_iUserTeam[id] = CSTE_SPECTATOR;
                    engclient_cmd(id, "jointeam", "6");
                }
                else
                {
                    client_print(id, print_chat, "Modo espectador solo para Administradores y VIP.");
                    team_menu(id);
                }
            }else
                team_menu(id);
        }
    }

    return PLUGIN_HANDLED;
}

// Opening classes menu --------------------------------------------------------
public create_classes_menu(id, iTeam) {
    new szItem[512], len, bitKeys = 1<<(g_iCount[iTeam]), bAccess;

    len = format(szItem, 511,"\ySelecciona un Personaje^n^n");
    for(new i=0; i<g_iCount[iTeam];i++) {
        bAccess = (get_user_flags(id) & g_szClassAccess[iTeam][i]);

        if(bAccess || g_szClassAccess[iTeam][i] == ADMIN_ALL) {
            len += format(
                szItem[len], 511-len, "%s%d. %s^n",
                (bAccess ? "\y" : "\w"), i + 1,
                get_class_info(iTeam, i, CLASS_NAME)
            );

            bitKeys |= 1<<i;
        }else
            len += format(
                szItem[len], 511-len, "\d%d. %s\R\rNO ACCESO^n",
                i+1, get_class_info(iTeam, i, CLASS_NAME)
            );

    }
    len += format(
        szItem[len], 511-len, "^n\r%d. \wAuto-selec",
        g_iCount[iTeam] + 1
    );

    show_menu(id, bitKeys, szItem, -1, "ClassMenu");

    return PLUGIN_HANDLED;
}

// Handle classes menu ---------------------------------------------------------
public class_menu_handler(id, key) {
    new iMsgBlock  = get_msg_block(g_iMenuMsgid);

    set_msg_block(g_iMenuMsgid, BLOCK_SET);
    engclient_cmd(id, "joinclass", "1");
    set_msg_block(g_iMenuMsgid, iMsgBlock);

    format(
        g_szPlayerModel[id], 127, "%s",
        get_class_info(g_iUserTeam[id], key, CLASS_TAG)
    );

    // Auto-select
    if(key == g_iCount[g_iUserTeam[id]] )
        get_random_class_tag(id, g_iUserTeam[id], g_szPlayerModel[id], 127);

    set_user_info(id, MODEL, g_szPlayerModel[id]);

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];

    iData[ 0 ] = id;
    iData[ 1 ] = LOGUEAR_USUARIO;

    formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
    

    return PLUGIN_HANDLED;
}

new const g_szHeGrenadeTT[][] = { "csgomod/t_grenade01.wav", "csgomod/t_grenade02.wav", "csgomod/t_grenade03.wav" };
new const g_szSmokeGrenadeTT[][] = { "csgomod/t_smoke01.wav", "csgomod/t_smoke02.wav", "csgomod/t_smoke03.wav" };
new const g_szFlashGrenadeTT[][] = { "csgomod/t_flashbang01.wav", "csgomod/t_flashbang02.wav", "csgomod/t_flashbang03.wav" };

new const g_szHeGrenadeCT[][] = { "csgomod/ct_grenade01.wav", "csgomod/ct_grenade02.wav", "csgomod/ct_grenade03.wav" };
new const g_szSmokeGrenadeCT[][] = { "csgomod/ct_smoke01.wav", "csgomod/ct_smoke02.wav", "csgomod/ct_smoke03.wav" };
new const g_szFlashGrenadeCT[][] = { "csgomod/ct_flashbang01.wav", "csgomod/ct_flashbang02.wav", "csgomod/ct_flashbang03.wav" };

public plugin_init( )
{
    register_plugin(
        .plugin_name = g_szPlugin, 
        .version = g_szVersion, 
        .author = g_szAuthor
    );

    RegisterHookChain( RG_CBasePlayer_Killed, "@Killed_OnPlayer", .post = true );
    RegisterHookChain( RG_CBasePlayer_SetClientUserInfoName, "@changeName_OnPlayer" );
    RegisterHookChain( RG_CBasePlayerWeapon_DefaultDeploy,  "@fw_Deploy_Pre",  .post = false );
    RegisterHookChain(RG_CBasePlayer_Spawn, "@fw_Player_spawn", .post = true);
    register_event("HLTV", "startRound_OnPlayer", "a", "1=0", "2=0");
    
    register_event( "StatusValue", "Status_team", "be", "1=1" );
    register_event( "StatusValue", "Status_team_info", "be", "1=2", "2!0" );
    register_event( "StatusValue", "OcultarInfoPlayer", "be", "1=1", "2=0" );

    register_message( get_user_msgid( "TextMsg" ) , "message_textmsg" );
    register_message( get_user_msgid( "SendAudio" ) , "message_sendaudio");
    register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse");
    register_message(get_user_msgid("ShowMenu"), "TeamMenu_Hook");
    register_message(get_user_msgid("VGUIMenu"), "TeamMenuVGUI_Hook");

    register_forward(FM_SetClientKeyValue, "SetClientKeyValue");

    register_clcmd("nightvision", "clcmd_changeteam");
    //register_clcmd("jointeam", "clcmd_changeteam");
    //register_clcmd("jointeam", "nightvision");
    register_clcmd( "say /csgorank", "checkRank" );
    register_clcmd( "say_team /csgorank", "checkRank" );
    register_clcmd( "say /csgotop", "checkTop" );
    register_clcmd( "say_team /csgotop", "checkTop" );
    register_clcmd( "say /csgotop", "checkTop" );
    register_clcmd( "say_team /csgotop", "checkTop" );
    register_clcmd("say /hud", "offHud");

    buy_shop = CreateMultiForward("buy_shop", ET_STOP, FP_CELL);

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_normal",
            .string = "2"
        ), cvar_kill
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_shop",
            .string = "1"
        ), cvar_shop
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_knife",
            .string = "4"
        ), cvar_knife
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_hs",
            .string = "3"
        ), cvar_hs
    );

    bind_pcvar_num(
        create_cvar(
            .name = "csgo_kill_knife_hegrenade",
            .string = "5"
        ), cvar_hegreande
    );

    register_menucmd(register_menuid("TeamMenu"), KEYS, "team_menu_handler");
    register_menucmd(register_menuid("ClassMenu"), KEYS, "class_menu_handler");

    g_pCvarAllowSpec   = get_cvar_pointer("allow_spectators");
    g_pCvarLimitTeams  = get_cvar_pointer("mp_limitteams");
    g_pCvarTeamBalance = get_cvar_pointer("mp_autoteambalance");

    g_iMsgSayText = get_user_msgid( "SayText" );
    g_iMsgText = get_user_msgid( "TextMsg" );
    g_iMenuMsgid = get_user_msgid ("ShowMenu");

    g_msgHud = CreateHudSyncObj( );
    g_iHudTeam = CreateHudSyncObj( );

    MySQL_Init();
}

public plugin_precache( )
{
    static szEntPoint[ 100 ];
    get_configsdir(g_szConfigFile, 127);
    format(g_szConfigFile, 127, "%s/%s", g_szConfigFile, FILE_NAME);

    for( new i = 0; i < sizeof( aWeapons ); ++i )
    {
        if( !equal( "default", aWeapons[ i ][ wpn_v ] ) )
        {
            formatex( szEntPoint, charsmax( szEntPoint ), "models/lwf_skins/%s.mdl", aWeapons[ i ][ wpn_v ] );
            precache_model( szEntPoint );
        }

        if( !equal( "default", aWeapons[ i ][ wpn_p ] ) )
        {
            formatex( szEntPoint, charsmax( szEntPoint ), "models/lwf_skins/%s.mdl", aWeapons[ i ][ wpn_p ] );
            precache_model( szEntPoint );
        }
    }

    for( new i = 0; i < sizeof(g_szFlashGrenadeTT); ++i ) precache_sound(g_szFlashGrenadeTT[i]);
    for( new i = 0; i < sizeof(g_szHeGrenadeTT); ++i ) precache_sound(g_szHeGrenadeTT[i]);
    for( new i = 0; i < sizeof(g_szSmokeGrenadeTT); ++i ) precache_sound(g_szSmokeGrenadeTT[i]);

    for( new i = 0; i < sizeof(g_szFlashGrenadeCT); ++i ) precache_sound(g_szFlashGrenadeCT[i]);
    for( new i = 0; i < sizeof(g_szHeGrenadeCT); ++i ) precache_sound(g_szHeGrenadeCT[i]);
    for( new i = 0; i < sizeof(g_szSmokeGrenadeCT); ++i ) precache_sound(g_szSmokeGrenadeCT[i]);

    new dFile = fopen(g_szConfigFile, "rt");
    new szModelFile[128], szErrorMsg[128];
    new szData[256];
    new iTeam = -1;

    if(!dFile) {
        format(
            szErrorMsg, 127, "El complemento no puede encontrar el archivo ^"%s^"",
            g_szConfigFile
        );

        return set_fail_state(szErrorMsg);
    }


    while(!feof(dFile)) {
        fgets(dFile, szData, 255);
        if(szData[0] == '/' && szData[1] == '/'
        || szData[0] == ';' || szData[0] == '^n')
            continue;

        replace(szData, 255, "^n", "");

        if(szData[0] == '[') {
            iTeam++;
            if(iTeam > MAX_NUM_TEAMS)
                break;

            replace(szData, 255, "]", "");
            replace(szData, 255, "[", "");
            format(g_szTeamName[iTeam], 127, "%s", szData);
        }
        else {
            if(iTeam < 0)
                continue;

            new szClassData[NumDatas][64];

            parse(
                szData, szClassData[CLASS_NAME], 63,
                szClassData[CLASS_TAG], 63,
                szClassData[CLASS_ACCESS], 63
            );

            format(
                szModelFile, 127, "models/player/%s/%s.mdl",
                szClassData[CLASS_TAG],  szClassData[CLASS_TAG]
            );
            if(!file_exists(szModelFile) || !szClassData[CLASS_TAG][0] ) {
                server_print(
                    "[svl] ¡Advertencia! Articulo ^"%s^" no fue creado: archivo^"%s^" no existe.",
                    szClassData[CLASS_NAME], szModelFile
                );
                continue;
            }
            precache_generic(szModelFile);

            new iClassId = g_iCount[iTeam];
            for(new i = 0; i < NumDatas; i++) {
                if(iTeam == CSTE_TEAM_T)
                    g_szClassesT[iClassId][i] = szClassData[i];
                else if(iTeam == CSTE_TEAM_CT)
                    g_szClassesCT[iClassId][i] = szClassData[i];
            }

            if(szClassData[CLASS_ACCESS][0])
                g_szClassAccess[iTeam][iClassId] = read_flags(
                    szClassData[CLASS_ACCESS]
                );
            else
                g_szClassAccess[iTeam][iClassId] = ADMIN_ALL;

            g_iCount[iTeam]++;
        }
    }

    return PLUGIN_CONTINUE;
}

public message_sendaudio(msgid, dest, id)
{
    static audio[18], wpn, TeamName:team;
    get_msg_arg_string(2, audio, charsmax(audio));
    
    if(equal(audio[7], "terwin") || equal(audio[7], "ctwin") || equal(audio[7], "rounddraw"))
        return PLUGIN_HANDLED;
    
    if(equal(audio,"%!MRAD_FIREINHOLE"))//granada sound
    {
        if(is_valid_player_alive(id))
        {
            wpn = get_user_weapon(id);
            team = get_member(id, m_iTeam);

            switch(team)
            {
                case TEAM_TERRORIST:
                {
                    if(wpn == CSW_HEGRENADE)
                    {
                        emit_sound(id, CHAN_VOICE, g_szHeGrenadeTT[ random_num(0, charsmax(g_szHeGrenadeTT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                    else if(wpn == CSW_FLASHBANG)
                    {
                        emit_sound(id, CHAN_VOICE, g_szFlashGrenadeTT[ random_num(0, charsmax(g_szFlashGrenadeTT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                    if(wpn == CSW_SMOKEGRENADE)
                    {
                        emit_sound(id, CHAN_VOICE, g_szSmokeGrenadeTT[ random_num(0, charsmax(g_szSmokeGrenadeTT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                }
                case TEAM_CT:
                {
                    if(wpn == CSW_HEGRENADE)
                    {
                        emit_sound(id, CHAN_VOICE, g_szHeGrenadeCT[ random_num(0, charsmax(g_szHeGrenadeCT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                    else if(wpn == CSW_FLASHBANG)
                    {
                        emit_sound(id, CHAN_VOICE, g_szFlashGrenadeCT[ random_num(0, charsmax(g_szFlashGrenadeCT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                    if(wpn == CSW_SMOKEGRENADE)
                    {
                        emit_sound(id, CHAN_VOICE, g_szSmokeGrenadeCT[ random_num(0, charsmax(g_szSmokeGrenadeCT)) ], 0.5, ATTN_NORM, 0, PITCH_NORM);
                    }
                }
            }
        }
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public message_textmsg(msgid, dest, id)
{
    static textmsg[22];
    get_msg_arg_string(2, textmsg, charsmax(textmsg));

    if (get_msg_args() == 5 && get_msg_argtype(5) == ARG_STRING)
    {
        get_msg_arg_string(5, textmsg, sizeof textmsg - 1);
        if (equal(textmsg, "#Fire_in_the_hole"))
            return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}


public plugin_natives() {
    register_native("get_rango", "hn_rango", 0);
}
public hn_rango(plugin, params)
{
    set_string(2, g_aRangos[ g_iRango[ get_param(1) ] ][ rango_name ], get_param(3));
    return -1;
}

public MySQL_Init()
{
    g_hTuple = advacc_guardado_get_handle( );
    
    if( !g_hTuple ) 
    {
        log_to_file( "SQL_ERROR.txt", "No se pudo conectar con la base de datos." );
        return pause( "a" );
    }

    return PLUGIN_CONTINUE;
}

public startRound_OnPlayer() {
    for(new i = 1; i <= MAX_PLAYERS; ++i) {
        if( !advacc_user_logged(i) || g_iStatus[ i ] != LOGUEADO )
                continue;

        guardar_datos( i );
    }
}

public client_disconnect(id)
{
    if( g_iStatus[ id ] == LOGUEADO )
    {
        guardar_datos( id );
        g_iStatus[ id ] = NO_LOGUEADO;
    }
    g_iRango[ id ] = 0; 
    g_iFrags[ id ] = 0;
    g_iHs[ id ] = 0;
    g_iKills[ id ] = 0;
    g_iDeaths[ id ] = 0;
}

public client_connect(id) {
    g_iUserTeam[id] = CSTE_UNASSIGNED;
}

public client_putinserver(id)
{
    g_iStatus[id] = NO_LOGUEADO;
    activeHud[id] = 1;
    g_iRango[ id ] = 0; 
    g_iFrags[ id ] = 0;
    g_iHs[ id ] = 0;
    g_iKills[ id ] = 0;
    g_iDeaths[ id ] = 0;

    for( new i = 0; i < WEAPONS_MAX; ++i ) 
        g_iWeapon[ id ][ i ] = 0;
}

public offHud(id) {
    activeHud[id] = !activeHud[id];
    if (activeHud[id]) {
        set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b");
    } else {
        remove_task(id+TASK_SHOWHUD);
    }
}

public clcmd_changeteam(id)
{
    if(!advacc_user_logged(id))
    {
        open_cuenta_menu( id );
        return PLUGIN_HANDLED;
    }
    if (!g_iStatus[id]) {
        team_menu(id);
        return PLUGIN_HANDLED;
    }
    menu_team( id );
    return PLUGIN_HANDLED;
}

public menu_team(id) {
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }
    new name[32], menut[150]; get_user_name(id, name, 31);
    formatex(menut, charsmax(menut), "\yPERSONAJE: \r%s^n\wTe faltan %i EXP para \r%s", 
        name, (g_aRangos[ g_iRango[ id ] ][ level_req ] - g_iFrags[ id ]), 
        g_aRangos[ g_iRango[ id ] >= charsmax(g_aRangos) ? charsmax(g_aRangos) : g_iRango[ id ]+1 ][ rango_name ] );
    new menu = menu_create(menut, "team_hn");
    menu_additem(menu, "TEAM \yTERRORISTA");
    menu_additem(menu, "TEAM \yANTITERRORISTA^n");
    
    menu_additem(menu, "ARMAS \rESPECIALES");
    if (cvar_shop) menu_additem(menu, fmt("%sCTIVAR \rHUD\w", activeHud[id] ? "DESA" : "A"));
    menu_additem(menu, "CAMBIAR \rSKINS");
    //menu_additem(menu, "Player Models");

    menu_display(id, menu, 0);
    return PLUGIN_HANDLED;
}

public team_hn(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    switch (item) {
        case 0: engclient_cmd(id, "jointeam", "1"), engclient_cmd(id, "joinclass", "5");
        case 1: engclient_cmd(id, "jointeam", "2"), engclient_cmd(id, "joinclass", "5");
        case 2: 
            if (cvar_shop) {
                new ret; 
                ExecuteForward(buy_shop, ret, id);
            }
        case 3: offHud(id);
        case 4: show_Weapons(id);
        //case 5: skins_type(id);
    }

    return PLUGIN_HANDLED;
}

public guardar_datos( id ) 
{
    if(!advacc_user_logged(id) || g_iStatus[ id ] != LOGUEADO)
        return;

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
    iData[ 0 ] = id;
    iData[ 1 ] = GUARDAR_DATOS;
    
    formatex( szQuery, charsmax( szQuery ), "UPDATE %s SET rango='%d', frags='%d', hs='%d', kills='%d', deaths='%d' WHERE id_cuenta='%d'", 
        szTable, g_iRango[ id ], g_iFrags[ id ], g_iHs[ id ], g_iKills[ id ], g_iDeaths[ id ], g_id[ id ] );
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
}

public Status_team( id ) 
    g_iTeam[ id ] = read_data( 2 );

public OcultarInfoPlayer( id )
    ClearSyncHud( id, g_iHudTeam );

public Status_team_info( id ) 
{ 
    if( is_valid_player_alive( id ) ) 
    { 
        new target = read_data( 2 );
        if ( g_iTeam[ id ] == 1 ) 
        { 
            if( get_member( target, m_iTeam ) == TEAM_TERRORIST ) set_hudmessage( 255, 0, 10, -1.0, 0.55, 0, 6.0, 12.0 );
            else set_hudmessage(0, 255, 255, -1.0, 0.55, 0, 6.0, 12.0);
            ShowSyncHudMsg(id, g_iHudTeam, "[%s]^n%s", g_aRangos[ g_iRango[ target ] ][ rango_name ], g_szPlayerName[ target ] );
        }
        else 
        { 
            if ( get_member( target, m_iTeam ) == TEAM_TERRORIST ) set_hudmessage(255, 0, 10, -1.0, 0.55, 0, 6.0, 12.0);
            else set_hudmessage(0, 255, 225, -1.0, 0.55, 0, 6.0, 12.0);
            ShowSyncHudMsg(id, g_iHudTeam, "[%s]^n%s", g_aRangos[ g_iRango[ target ] ][ rango_name ], g_szPlayerName[ target ]);
        }
    }
}
@fw_Player_spawn(id) {
    if (!is_user_alive(id)) {
        return;
    }

    if( advacc_user_logged(id) && g_iStatus[ id ] == LOGUEADO ) {
        guardar_datos( id );
    }    
}
@Killed_OnPlayer( victim, attacker, shouldgib )
{
    if( !is_valid_player_alive( attacker ) || victim == attacker || get_member( attacker, m_iTeam ) == get_member( victim, m_iTeam ) )
        return;

    new ganancia = 0;
    if (is_user_admin(victim) && 1 <= victim <= 32) {
        ganancia = 2;
        client_print_color(attacker, print_team_blue, "^x01GANASTE^x04 2^x01 EXP POR MATAR A UN^x04 ADMIN^x01!.");
    }

    if( get_member( attacker, m_LastHitGroup ) == HITGROUP_HEAD ) 
    {
        setLevel( attacker, cvar_hs + ganancia );
        //setLevel( victim, -1 * cvar_hs );

        ++g_iHs[ attacker ];
    }
    else
    {
        if( GetCurrentWeapon( attacker ) == WEAPON_HEGRENADE )
        {
            setLevel( attacker, cvar_hegreande + ganancia );
            //setLevel( victim, -1 * cvar_hegreande );
        }
        else if( GetCurrentWeapon( attacker ) == WEAPON_KNIFE )
        {
            setLevel( attacker, cvar_knife + ganancia );
            //setLevel( victim, -1 * cvar_knife );
        }
        else
        {
            setLevel( attacker, cvar_kill + ganancia );
            //setLevel( victim, -1 * cvar_kill );
        }
    }
    ++g_iKills[ attacker ];
    ++g_iDeaths[ victim ];
}

public setLevel( id, value )
{
    if( g_iRango[ id ] >= charsmax( g_aRangos ) || g_iRango[ id ] < 0 )
        return;
    
    new iLevel = g_iRango[ id ];

    g_iFrags[ id ] += value;

    while( g_iFrags[ id ] >= g_aRangos[ g_iRango[ id ] >= charsmax(g_aRangos) ? charsmax(g_aRangos) : g_iRango[ id ] ][ level_req ] && g_iRango[ id ] < charsmax(g_aRangos)+1 )
        ++g_iRango[ id ];
    
    if( iLevel < g_iRango[ id ] )
        client_print_color( id, print_team_blue, "^x01Subiste al rango ^x04%s", g_aRangos[ g_iRango[ id ] ][ rango_name ] );

    /*while( g_iFrags[ id ] < g_aRangos[ g_iRango[ id ]-1 <= 0 ? 0 : g_iRango[ id ]  ][ level_req ] && g_iRango[ id ] > 0 )
        --g_iRango[ id ];

    iLevel = g_iRango[ id ];

    if( iLevel > g_iRango[ id ] )
        client_print_color( id, print_team_blue, "^x01Bajaste al rango ^x04%s", g_aRangos[ g_iRango[ id ] ][ rango_name ] );
    
    if( g_iFrags[ id ] <= 0)
        g_iFrags[ id ] = 0;*/

}

@changeName_OnPlayer(id, infobuffer[], szNewName[]) 
{
    if (!is_user_connected(id) )
        return HC_SUPERCEDE;
    
    new szOldName[32];
    get_entvar(id, var_netname, szOldName, charsmax(szOldName));
 
    SetHookChainArg(3, ATYPE_STRING, szOldName);
    set_msg_block( get_entvar(id, var_deadflag) != DEAD_NO ? g_iMsgText : g_iMsgSayText, BLOCK_ONCE );
    return HC_SUPERCEDE;
} 

public ShowHUD( taskid )
{
    static id;
    id = ID_SHOWHUD;
    
    if ( !is_valid_player_alive( id ) )
    {
        id = get_entvar( id, var_iuser2 );
        if ( !is_valid_player_alive( id ) ) return;
    }

    set_hudmessage( 255, 0, 0, 0.93, 0.09, 0, 0.0, 2.0 );

    if ( id != ID_SHOWHUD )
        ShowSyncHudMsg(ID_SHOWHUD, g_msgHud, "Observando al jugador: ^n%s^n^nRango: %s^nNivel: %d | Exp: %s", g_szPlayerName[ id ], g_aRangos[ g_iRango[ id ] ][ rango_name ], g_iRango[ id ], xAddPoint( g_iFrags[ id ] ) );
    else
        ShowSyncHudMsg(ID_SHOWHUD, g_msgHud, "Vida: %d^nRango: %s^nNivel: %d - Exp: %s^nCoins: %s - Adrenalina: %d", floatround(get_entvar(id, var_health)), g_aRangos[ g_iRango[ id ] ][ rango_name ], g_iRango[ id ], xAddPoint( g_iFrags[ id ] ), xAddPoint(get_user_coins(id)), get_user_adrenaline(id) );
    
}

public DataHandler( failstate, Handle:Query, error[ ], error2, data[ ], datasize, Float:flTime ) 
{
    switch( failstate ) 
    {
        case TQUERY_CONNECT_FAILED: 
        {
            log_to_file( "SQL_LOG_TQ.txt", "Error en la conexion al MySQL [%i]: %s", error2, error );
            return;
        }
        case TQUERY_QUERY_FAILED:
        log_to_file( "SQL_LOG_TQ.txt", "Error en la consulta al MySQL [%i]: %s", error2, error );
    }
    
    new id = data[ 0 ];
    
    if( !is_user_connected( id ) )
        return;
    
    switch( data[ 1 ] ) 
    {
        case LOGUEAR_USUARIO: 
        {
            if( SQL_NumResults( Query ) )
            {
                /*

                    CREATE TABLE csgo_table2 
                    (
                        id_cuenta INT PRIMARY KEY NOT NULL,
                        rango int(2) NOT NULL DEFAULT '0',
                        frags int(10) NOT NULL DEFAULT '0',
                        hs int(10) NOT NULL DEFAULT '0',
                        kills int(10) NOT NULL DEFAULT '0',
                        deaths int(10) NOT NULL DEFAULT '0'
                    );

                */
                g_iRango[ id ] = SQL_ReadResult( Query, 1 );
                g_iFrags[ id ] = SQL_ReadResult( Query, 2 );
                g_iHs[ id ] = SQL_ReadResult( Query, 3 );
                g_iKills[ id ] = SQL_ReadResult( Query, 4 );
                g_iDeaths[ id ] = SQL_ReadResult( Query, 5 );

                set_task(1.0, "ShowHUD", id+TASK_SHOWHUD, _, _, "b");//muestras tu hud de zp
                //ForceJoinTeam(id);

                g_iStatus[ id ] = LOGUEADO;
            }
            else
            {
                g_iRango[ id ] = 0; 
                g_iFrags[ id ] = 0;
                g_iHs[ id ] = 0;
                g_iKills[ id ] = 0;
                g_iDeaths[ id ] = 0;

                new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
                
                iData[ 0 ] = id;
                iData[ 1 ] = REGISTRAR_USUARIO;
                
                formatex( szQuery, charsmax( szQuery ), "INSERT INTO %s (id_cuenta, rango, frags, hs, kills, deaths) VALUES (%d, %d, %d, %d, %d, %d)", 
                    szTable, g_id[ id ], g_iRango[ id ], g_iFrags[ id ], g_iHs[ id ], g_iKills[ id ], g_iDeaths[ id ]);
                SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
            }
        }
        case REGISTRAR_USUARIO: 
        {
            if( failstate < TQUERY_SUCCESS ) 
            {
                console_print( id, "Error al crear un usuario: %s.", error );
            }
            else
            {
                new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
                
                iData[ 0 ] = id;
                iData[ 1 ] = LOGUEAR_USUARIO;

                formatex( szQuery, charsmax( szQuery ), "SELECT * FROM %s WHERE id_cuenta='%d'", szTable, g_id[ id ] );
                SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 );
            }
        }
        case GUARDAR_DATOS:
        {
            if( failstate < TQUERY_SUCCESS )
                console_print( id, "Error en el guardado de datos." );
            else
            console_print( id, "Datos guardados." );
        }
        case SQL_RANK:
        {
            if( SQL_NumResults( Query ) )
            {
                client_print(id, print_chat, "Tu Rank es %i con el Rango [ %s ] %d Frags & %d Deaths.",
                SQL_ReadResult( Query, 0 ), 
                g_aRangos[ g_iRango[ id ] ][ rango_name ], 
                g_iKills[ id ], 
                g_iDeaths[ id ] );
            }
        }
        case TOP15:
        {
            if( SQL_NumResults( Query ) )
            {
                static len, szBuffer[ MAX_MOTD_LENGTH-1 ], i, szName[ 32 ];
                len = 0, i = 0;

                len = format(szBuffer[len], charsmax(szBuffer) - len, "<meta charset=UTF-8>\
            <style>*{margin:0px;}body{color:#fff;background: rgba(2, 0, 0, 0.2) url(https://images7.alphacoders.com/570/570405.png); background-repeat: no-repeat; background-size: cover; background-attachment: fixed;}table{border-collapse:collapse;border: 1px solid #ffff;text-align:center;}</style>\
            <body><table width=100%% border=1><tr bgcolor=#4c4c4c style=^"color:#fff;^"><th width=5%%>#<th width=50%%>Usuario<th width=15%%>Rango\
            <th width=15%%>EXP<th width=15%%>Insignea");
                while( SQL_MoreResults( Query ) )
                {
                    SQL_ReadResult( Query, 0, szName, charsmax( szName ) );
                    len += format( szBuffer[len], charsmax(szBuffer) - len, "<tr><td>%i<td>%s<td>%s<td>%d<td><img src=^"%s^" width=80 hight=30/>",
                        i+1, szName, g_aRangos[ SQL_ReadResult( Query, 1 ) ][ rango_name ], SQL_ReadResult( Query, 2 ), g_aRangos[ SQL_ReadResult( Query, 1 ) ][ url_rango ] );
                    ++i;
                    SQL_NextRow( Query );
                }
                show_motd( id, szBuffer, "Top 8 Rangos" );
            }
        }
    }
}

public checkRank( id )
{
    if(  g_iStatus[ id ] != LOGUEADO )
        return;

    new szQuery[ MAX_MENU_LENGTH ], iData[ 2 ];
    
    iData[ 0 ] = id;
    iData[ 1 ] = SQL_RANK;

    formatex( szQuery, charsmax( szQuery ), "SELECT (COUNT(*) + 1) FROM `%s` WHERE `rango` > '%d' OR (`rango` = '%d' AND `frags` > '%d')", szTable, g_iRango[ id ], g_iRango[ id ], g_iFrags[ id ] );
    SQL_ThreadQuery( g_hTuple, "DataHandler", szQuery, iData, 2 ); 
}

public checkTop( id )
{
    new szTabla[ 200 ], iData[ 2 ];
    
    iData[ 0 ] = id;
    iData[ 1 ] = TOP15;
    formatex( szTabla, charsmax( szTabla ), "SELECT Pj, rango, frags FROM %s INNER JOIN zp_cuentas ON id = id_cuenta ORDER BY rango DESC, frags DESC LIMIT 8", szTable );
    
    SQL_ThreadQuery(g_hTuple, "DataHandler", szTabla, iData, 2 );
    
}


public show_Weapons( id )
{
    new Item[ 3 ], menu = menu_create( "MENU DE SKINS", "handler_menu" );

    for( new i = M4A1; i < WEAPONS_MAX; i++ )
    {
        formatex( Item, charsmax( Item ), "%d", i );
        menu_additem( menu, szNameWeapons[ i ], Item );
    }

    menu_display( id, menu );
    return PLUGIN_HANDLED;
}

public handler_menu( id, menu, item )
{
    if( item == MENU_EXIT ) 
    {
        menu_destroy( menu );
        return PLUGIN_HANDLED;
    }

    new szData[ 20 ], Item[ 400 ];
    new item_access, item_callback;
    menu_item_getinfo( menu, item, item_access, szData,charsmax( szData ), Item, charsmax(Item), item_callback );
    
    new item2 = str_to_num( szData );

    menu_armas( id, item2 );
    return PLUGIN_HANDLED;
}

public menu_armas( id, item )
{
    new menu = menu_create( "Menu Skins", "handler_skins" );
    new Item[ 30 ], szData[ 80 ];
    
    for( new i = 0; i < sizeof aWeapons; i++ )
    {
        formatex( Item, charsmax( Item ), "%d", i );
        
        if( aWeapons[ i ][ wpn_id ] != item ) 
            continue;

        if( aWeapons[ i ][ wpn_type ] == ADMIN_ALL )
        {
            if( g_iRango[id] >= aWeapons[ i ][ wpn_kills ] )
                formatex( szData, charsmax( szData ), "%s", aWeapons[ i ][ wpn_name ] );
            else
                formatex( szData, charsmax( szData ), "\d%s \y[ \r%s \y]", aWeapons[ i ][ wpn_name ], g_aRangos[ aWeapons[ i ][ wpn_kills ] ][ rango_name ] );
        }
        else
        {
            if( get_user_flags( id ) & aWeapons[ i ][ wpn_type ] )
            {
                if( g_iRango[id] >= aWeapons[ i ][ wpn_kills ] )
                    formatex( szData, charsmax( szData ), "%s", aWeapons[ i ][ wpn_name ] );
                else
                    formatex( szData, charsmax( szData ), "\d%s \y[ \r%s \y]", aWeapons[ i ][ wpn_name ], g_aRangos[ aWeapons[ i ][ wpn_kills ] ][ rango_name ] );
            }
            else
                formatex( szData, charsmax( szData ), "\d%s \y[ \rADMIN \y]", aWeapons[ i ][ wpn_name ] );    
        }
        
        menu_additem( menu, szData, Item );
    }
    menu_display( id, menu );
    return PLUGIN_HANDLED;
} 
public handler_skins( id, menu, item ) 
{
    if( item == MENU_EXIT ) 
    {
        menu_destroy( menu );
        return PLUGIN_HANDLED;
    }
    new szData[ 20 ], Item[ 400 ];
    new item_access, item_callback;
    menu_item_getinfo( menu, item, item_access, szData,charsmax( szData ), Item, charsmax(Item), item_callback );
    
    new item2 = str_to_num( szData );
    
    if( g_iRango[id] < aWeapons[ item2 ][ wpn_kills ] )
    {
        client_print_color( id, print_team_default, "NO TIENES EL RANGO SUFICIENTE!" );
        return PLUGIN_HANDLED;
    }

    if( aWeapons[ item2 ][ wpn_type ] == ADMIN_ALL )
    {
        g_iWeapon[ id ][ aWeapons[ item2 ][ wpn_id ] ] = item2;
    }
    else
    {
        if( get_user_flags( id ) & aWeapons[ item2 ][ wpn_type ] )
        {
            g_iWeapon[ id ][ aWeapons[ item2 ][ wpn_id ] ] = item2;
        }
        else
            client_print_color( id, print_team_default, "ESTA SKINS ES DE ADMIN!" );
    }
    client_print_color( id, print_team_default, "Escogiste el skin: %s", aWeapons[ g_iWeapon[ id ][ aWeapons[ item2 ][ wpn_id ] ] ][ wpn_name ] );
    return PLUGIN_HANDLED;
}

@fw_Deploy_Pre( const entity, sViewModel[], sWeaponModel[], iAnim, sAnimExt[], skiplocal )
{
    if( !is_entity( entity ) )
        return HC_CONTINUE;

    new WeaponIdType:iWeaponId = get_member( entity, m_iId );

    new id = get_member( entity, m_pPlayer ), szEntPoint[ 100 ];
    new weapon_id = get_weapon( entity, id ) + 1;
    
    if( is_valid_player_alive( id ) && weapon_id )
    {
        weapon_id -= 1;

        if( iWeaponId == aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_weapon ] && 
            !equal( "default", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_v ] ) )
        {
            formatex( szEntPoint, charsmax( szEntPoint ), "models/lwf_skins/%s.mdl", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_v ] );
            SetHookChainArg( 2, ATYPE_STRING, szEntPoint );
        }

        if( iWeaponId == aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_weapon ] && 
            !equal( "default", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_p ] ) )
        {
            formatex( szEntPoint, charsmax( szEntPoint ), "models/lwf_skins/%s.mdl", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_p ] );
            SetHookChainArg( 3, ATYPE_STRING, szEntPoint );
        }
    }
        
    return HC_CONTINUE;
}

public get_weapon( entity, id )
{
    new iVal = -1;

    for( new i = 0; i < WEAPONS_MAX; ++i )
        if( get_member( entity, m_iId ) == aWeapons[ g_iWeapon[ id ][ i ] ][ wpn_weapon ] )
        {
            iVal = i;
            break;
        }

    return iVal;
}

public TeamMenu_Hook(iMsgid, dest, id) {
    static szTeamSelect[] = "#Team_Select";
    static szMenuTextCode[32];
    get_msg_arg_string(4, szMenuTextCode, sizeof szMenuTextCode - 1);

    if(contain(szMenuTextCode, szTeamSelect) > -1) {
        //team_menu(id);
        return PLUGIN_HANDLED;
    }

    //g_iMsgId[id] = iMsgid;

    return PLUGIN_CONTINUE;
}

// VGUI menu hook
public TeamMenuVGUI_Hook(iMsgid, dest, id) {
    if(get_msg_arg_int(1) == 2) {
        team_menu(id);
        return PLUGIN_HANDLED;
    }
    else    if(get_msg_arg_int(1) == 26) {
        create_classes_menu(id, CSTE_TEAM_T);
        return PLUGIN_HANDLED;
    }
    else if(get_msg_arg_int(1) == 27) {
        create_classes_menu(id, CSTE_TEAM_CT);
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

// Message ClCorpse ------------------------------------------------------------
public Message_ClCorpse() {
    new id = get_msg_arg_int(12);

    // if user is not VIP
    if(!(get_pdata_int(id, OFFSET_ISVIP, EXTRAOFFSET) & PLAYER_IS_VIP)) {
        set_msg_arg_string(1, g_szPlayerModel[id]);
    }
}

// SetClientKeyValue forward ---------------------------------------------------
public SetClientKeyValue(id, szInfoBuffer[], szKey[], szValue[]) {
    if(equal(szKey, MODEL) && is_user_connected(id)) {
        g_iUserTeam[id] = cste_get_user_team(id);

        if(g_iUserTeam[id] == get_class_team_by_tag(g_szPlayerModel[id])
        && !equal(szValue, g_szPlayerModel[id])) {
            set_user_info(id, MODEL, g_szPlayerModel[id]);
            return FMRES_SUPERCEDE;
        }
    }

    return FMRES_IGNORED;
}


// Stocks ----------------------------------------------------------------------
stock get_class_info(iTeam, iClass, iData) {
    new szReturn[64];

    if(iTeam == CSTE_TEAM_T)
         szReturn = g_szClassesT[iClass][iData];
    else if(iTeam == CSTE_TEAM_CT)
        szReturn = g_szClassesCT[iClass][iData];

    return szReturn;
}

stock get_random_class_tag(id, iTeam, szOutput[], len) {
    new bool:bDone = false;
    while(!bDone) {
        new iCount = g_iCount[iTeam];
        new iRandomClassNum = random_num(0, iCount);

        if(g_szClassAccess[iTeam][iRandomClassNum] != ADMIN_ALL
        && (!(get_user_flags(id) & g_szClassAccess[iTeam][iRandomClassNum])
        || is_user_bot(id)))
            continue;

        copy(szOutput, len, get_class_info(iTeam, iRandomClassNum, CLASS_TAG));
        bDone = true;
    }
}

stock get_class_team_by_tag(const szTag[]) {
    for(new iTeam=0; iTeam<MAX_NUM_TEAMS; iTeam++)
        for(new i=0; i<g_iCount[iTeam]; i++) {
            if(equal(szTag, get_class_info(iTeam, i, CLASS_TAG)))
            return iTeam;
        }

    return -2;
}

stock join_allow(id) {
    new iNumT, iNumCT;
    new iPlayers[32];

    get_players(iPlayers, iNumT, "eh", "TERRORIST");
    get_players(iPlayers, iNumCT, "eh", "CT");

    if(cste_get_user_team(id) == CSTE_TEAM_CT)
        iNumCT--;
    else if(cste_get_user_team(id) == CSTE_TEAM_T)
        iNumT--;

    new iTeamsLimit = get_pcvar_num(g_pCvarLimitTeams);

    if(get_pcvar_num(g_pCvarTeamBalance) && iTeamsLimit != 0) {
        if(iNumT-iNumCT >= iTeamsLimit && iNumCT-iNumT >= iTeamsLimit)
            return 3;
        else if(iNumT-iNumCT >= iTeamsLimit)
            return 1;
        else if (iNumCT-iNumT >= iTeamsLimit)
            return 2;
    }

    return 0;
}

stock team_join(id, iTeam) {
    new szTeam[2];
    new iMsgBlock = get_msg_block(g_iMenuMsgid);

    g_iUserTeam[id] = iTeam;

    num_to_str(iTeam+1, szTeam, 1);
    set_msg_block(g_iMenuMsgid, BLOCK_SET);
    engclient_cmd(id, "jointeam", szTeam);
    set_msg_block(g_iMenuMsgid, iMsgBlock);
}

stock xAddPoint(number)
{
    new count, i, str[29], str2[35], len;
    num_to_str(number, str, charsmax(str));
    len = strlen(str);

    for (i = 0; i < len; i++)
    {
        if(i != 0 && ((len - i) %3 == 0))
        {
            add(str2, charsmax(str2), ".", 1);
            count++;
            add(str2[i+count], 1, str[i], 1);
        }
        else add(str2[i+count], 1, str[i], 1);
    }
    
    return str2;
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

stock precache_player_model( const modelname[] )
{
    static longname[128]; // Precache normal type model 
    formatex(longname, charsmax(longname), "models/player/%s/%s.mdl", modelname, modelname); 
    precache_generic(longname); 
     
    // Check TFiles inquiries 
    copy(longname[strlen(longname)-4], charsmax(longname) - (strlen(longname)-4), "T.mdl") ;
    if (file_exists(longname)) precache_generic(longname); 
}