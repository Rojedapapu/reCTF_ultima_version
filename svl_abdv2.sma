#include <amxmodx>
#include <fakemeta>
 
#define PLUGIN  "Re-Advanced Bullet Damage"
#define VERSION "1.0"
#define AUTHOR  "Sn!ff3r"
 
new g_hudmsg1, g_hudmsg2
new g_iMaxPlayers
new pcvar_show_spec, g_spec, g_enabled, g_type
 
const OFFSET_A = 75
const OFFSET_B = 5
 
public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    g_iMaxPlayers = get_maxplayers()
    g_hudmsg1 = CreateHudSyncObj()
    g_hudmsg2 = CreateHudSyncObj()
    register_event("Damage", "on_damage", "b", "2!0", "3=0", "4!0")
    register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
    
    pcvar_show_spec = register_cvar("amx_bulletdamage_spec", "1")
    g_type = register_cvar("amx_bulletdamage","1")
}
public on_new_round()
{
    if((g_enabled = get_pcvar_num(g_type)))
    {
        g_spec = get_pcvar_num(pcvar_show_spec);
    }
}
public on_damage(id)
{
    /*if(g_enabled < 1)
    {
        return;
    }*/
    static attacker; attacker = get_user_attacker(id)
    if(!is_user_connected(attacker))
    {
        return;
    }
    static damage; damage = read_data(2)
 
    set_hudmessage(71, 75, 78, 0.45, 0.50, 1, 0.1, 4.0, 0.1, 0.1, -1)
    ShowSyncHudMsg(id, g_hudmsg2, "%i^n", damage)
 
    if(get_pdata_int(id, OFFSET_A, OFFSET_B) == 1)
    {
        set_hudmessage(225, 0, 0, -1.0, 0.55, 1, 0.1, 4.0, 0.02, 0.02, -1);
        ShowSyncHudMsg(attacker, g_hudmsg1, "%i Headshot!^n", damage)
    }
    else
    {
        set_hudmessage(255, 233, 0, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1);
        ShowSyncHudMsg(attacker, g_hudmsg1, "%i^n", damage)
    }
 
    if(g_spec < 1)
    {
        return;
    }
 
    static i;
    for(i = 1 ; i <= g_iMaxPlayers ; i++)
    {
        if(!is_user_alive(i) && is_user_connected(i))
        {
            if(pev(i, pev_iuser2) == id)
            {
                set_hudmessage(71, 75, 78, 0.45, 0.50, 1, 0.1, 4.0, 0.1, 0.1, -1)
                ShowSyncHudMsg(i, g_hudmsg2, "%i^n", damage)
            }
            else if(pev(i, pev_iuser2) == attacker)
            {
                if(get_pdata_int(id, OFFSET_A, OFFSET_B) == 1)
                    set_hudmessage(225, 0, 0, -1.0, 0.55, 1, 0.1, 4.0, 0.02, 0.02, -1);
                else
                    set_hudmessage(255, 233, 0, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1);
 
                ShowSyncHudMsg(i, g_hudmsg1, "%i^n", damage)
            }
        }
    }
} 
