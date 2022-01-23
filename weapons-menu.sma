#include <amxmodx>
#include <reapi>

public stock g_szPlugin[ ] = "Wpn Menu";
public stock g_szVersion[ ] = "0.1b";
public stock g_szAuthor[ ] = "Hypnotize";

#define is_alive_valid_player(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive( %0 ))

enum 
{ 
	M4A1 = 0/*NO MODIFICAR ESTE*/,  
	AK47, 
	//aca se agregan mas armas, todo va con base en este orden
	AWP,

	WEAPONS_MAX //NO AGREGAR NADA DESPUES DE ESTE
};

new const szNameWeapons[ WEAPONS_MAX ][] = { "M4A1", "AK47", "AWP" };//aca se agregan mas armas

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
	{ "M4a1 Normal", WEAPON_M4A1, "default", "default", 0, ADMIN_ALL, M4A1 },
	{ "M4a1 1", WEAPON_M4A1, "v_m4a11", "p_m4a11", 10, ADMIN_ALL, M4A1 },
	{ "M4a1 2", WEAPON_M4A1, "v_m4a12", "p_m4a12", 20, ADMIN_ALL, M4A1 },
	{ "M4a1 3", WEAPON_M4A1, "v_m4a13", "p_m4a13", 30, ADMIN_ALL, M4A1 },
	{ "M4a1 4", WEAPON_M4A1, "v_m4a14", "p_m4a14", 40, ADMIN_ALL, M4A1 },

	//ak
	{ "Ak-47 Normal", WEAPON_AK47, "default", "default", 0, ADMIN_ALL, AK47 },
	{ "Ak-47 Wint", WEAPON_AK47, "v_ak47wint", "p_ak47wint", 10, ADMIN_ALL, AK47 },
	{ "Ak-47", WEAPON_AK47, "v_ak47", "p_ak47", 20, ADMIN_ALL, AK47 },
	{ "Ak-47 GR", WEAPON_AK47, "v_ak47gr", "p_ak47gr", 30, ADMIN_ALL, AK47 },
	{ "Ak-47 Sum", WEAPON_AK47, "v_ak47sum", "p_ak47sum", 40, ADMIN_ALL, AK47 },

	//other..

	//aca se agregan mas armas EJ

	//AWP
	{ "Awp Normal", WEAPON_AWP, "default", "default", 0, ADMIN_ALL, AWP },
	{ "Awp 1", WEAPON_AWP, "v_awp1", "p_awp1", 10, ADMIN_ALL, AWP },
	//{ "Awp 2", WEAPON_AWP, "v_awp2", "p_awp2", 0, ADMIN_ALL, AWP },
	{ "Awp 3", WEAPON_AWP, "v_awp3", "p_awp3", 30, ADMIN_ALL, AWP }

	//deagle, en el orden que esta arriba

}

new g_iWeapon[ 33 ][ WEAPONS_MAX ];

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
			if( floatround( get_entvar( id, var_frags ) ) >= aWeapons[ i ][ wpn_kills ] )
				formatex( szData, charsmax( szData ), "%s", aWeapons[ i ][ wpn_name ] );
			else
				formatex( szData, charsmax( szData ), "\d%s KILLS \y[ \r%d \y]", aWeapons[ i ][ wpn_name ], aWeapons[ i ][ wpn_kills ] );
		}
		else
		{
			if( get_user_flags( id ) & aWeapons[ i ][ wpn_type ] )
			{
				if( floatround( get_entvar( id, var_frags ) ) >= aWeapons[ i ][ wpn_kills ] )
					formatex( szData, charsmax( szData ), "%s", aWeapons[ i ][ wpn_name ] );
				else
					formatex( szData, charsmax( szData ), "\d%s KILLS \y[ \r%d \y]", aWeapons[ i ][ wpn_name ], aWeapons[ i ][ wpn_kills ] );
			}
			else
				formatex( szData, charsmax( szData ), "\d%s KILLS \y[ \rADMIN \y]", aWeapons[ i ][ wpn_name ] );	
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
	
	if( floatround( get_entvar( id, var_frags ) ) < aWeapons[ item2 ][ wpn_kills ] )
	{
		client_print_color( id, print_team_default, "NO TIENES LAS KILLS SUFICIENTES!" );
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
	client_print_color( id, print_team_default, "%s", aWeapons[ g_iWeapon[ id ][ aWeapons[ item2 ][ wpn_id ] ] ][ wpn_name ] );
	return PLUGIN_HANDLED;
}

@fw_Deploy_Pre( const entity, sViewModel[], sWeaponModel[], iAnim, sAnimExt[], skiplocal )
{
    if( !is_entity( entity ) )
        return HC_CONTINUE;

    new WeaponIdType:iWeaponId = get_member( entity, m_iId );

    new id = get_member( entity, m_pPlayer ), szEntPoint[ 100 ];
    new weapon_id = get_weapon( entity, id ) + 1;
    
    if( is_alive_valid_player( id ) && weapon_id )
    {
    	weapon_id -= 1;

        if( iWeaponId == aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_weapon ] && 
    		!equal( "default", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_v ] ) )
    	{
			formatex( szEntPoint, charsmax( szEntPoint ), "models/ffasvl/%s.mdl", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_v ] );
			SetHookChainArg( 2, ATYPE_STRING, szEntPoint );
    	}

    	if( iWeaponId == aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_weapon ] && 
    		!equal( "default", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_p ] ) )
    	{
			formatex( szEntPoint, charsmax( szEntPoint ), "models/ffasvl/%s.mdl", aWeapons[ g_iWeapon[ id ][ weapon_id ] ][ wpn_p ] );
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

public client_putinserver( id )
{
	for( new i = 0; i < WEAPONS_MAX; ++i ) 
		g_iWeapon[ id ][ i ] = 0;
}

public plugin_precache( )
{
	static szEntPoint[ 100 ];

	for( new i = 0; i < sizeof( aWeapons ); ++i )
	{
		if( !equal( "default", aWeapons[ i ][ wpn_v ] ) )
		{
			formatex( szEntPoint, charsmax( szEntPoint ), "models/ffasvl/%s.mdl", aWeapons[ i ][ wpn_v ] );
			precache_model( szEntPoint );
		}

		if( !equal( "default", aWeapons[ i ][ wpn_p ] ) )
		{
			formatex( szEntPoint, charsmax( szEntPoint ), "models/ffasvl/%s.mdl", aWeapons[ i ][ wpn_p ] );
			precache_model( szEntPoint );
		}
	}
}

public plugin_init( )
{
	register_plugin(
	    .plugin_name = g_szPlugin, 
	    .version = g_szVersion, 
	    .author = g_szAuthor
	);

	RegisterHookChain( RG_CBasePlayerWeapon_DefaultDeploy,  "@fw_Deploy_Pre",  .post = false );

	register_clcmd( "say /skins", "show_Weapons" );
	register_clcmd( "say skins", "show_Weapons" );
	register_clcmd( "say_team /skins", "show_Weapons" );
	register_clcmd( "say_team skins", "show_Weapons" );
}

