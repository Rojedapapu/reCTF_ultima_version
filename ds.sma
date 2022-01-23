#include <amxmodx>
#include <grip>

#pragma semicolon 1

#define var new
#define function public

//https://discord.com/api/webhooks/844335552068321342/jBPY30p4Ia1v4ZOmd4z4QWYYHoYC_yBb1Dyfg-M-D_oVzfdDpakNHW695kV1e6qdRF_t

new const server[] = "https://discord.com/api/webhooks/880590414686613644/eyf7z9Hau1B64fEVKDdvXiOS_4N8HtCT9ipT4LgteZ7svYLLKzWmdWBmfJpOMRiIAujt";
new const g_discord[] = "https://discord.gg/TafwJA8K37";

function plugin_init() {
	register_plugin("Discord WebHook", "0.1b", "Hypnotize");
	register_clcmd("say test", "sendToHook");
	set_task(60.0, "sendToHook");

	//set_task(60.0, "sendToHook");
	set_task(600.0, "sendToHook", _, _, _, "b");
}

function sendToHook() {
	client_print(0, print_chat, "Estadisticas del servidor enviadas a Discord [%s]", g_discord);
	var host[128],ip[32];
	get_cvar_string("hostname", host, 127);
	get_cvar_string("net_address", ip, 31);
	var map[32]; get_mapname(map, 31);
	/*var GripJSONValue:author = grip_json_init_object();
	grip_json_object_set_string(author, "name", "");
	grip_json_object_set_string(author, "url", "https://www.svlmexico.com/");
	grip_json_object_set_string(author, "icon_url", "https://pics.me.me/thumb_buenas-noches-pendejos-est%C3%BApidos-ahahah-61587168.png");
	*/
	var GripJSONValue:url = grip_json_init_object();
	grip_json_object_set_string(url, "url", "https://www.gametracker.com/images/game_icons64/cs.png");

	var GripJSONValue:url2 = grip_json_init_object();
	grip_json_object_set_string(url2, "url", fmt("https://image.gametracker.com/images/maps/160x120/cs/%s.jpg", map));

	var GripJSONValue:footer = grip_json_init_object();
	grip_json_object_set_string(footer, "text", "¡No dejes que el miedo te invada!");
	grip_json_object_set_string(footer, "icon_url", "https://www.svlmexico.com/img/profile2.jpg");


	var GripJSONValue:arrayField = grip_json_init_array();
	setField(arrayField, "Server Name", host, false);
	
	setField(arrayField, "Map", map, true);
	static pl; pl = players();
	setField(arrayField, "Judadores", fmt("%d/32", pl), true);
	setField(arrayField, "IP:", ip, true);

	var GripJSONValue:embedData = grip_json_init_object();
	//grip_json_object_set_value(embedData, "author", author);//
	grip_json_object_set_string(embedData, "title", host);//nameserver
	grip_json_object_set_string(embedData, "url", "https://www.svlmexico.com");
	grip_json_object_set_string(embedData, "description", "Unete a la partida");
	grip_json_object_set_string(embedData, "color", "15258703");
	grip_json_object_set_value(embedData, "fields", arrayField);
	grip_json_object_set_value(embedData, "thumbnail", url);
	grip_json_object_set_value(embedData, "image", url2);
	grip_json_object_set_value(embedData, "footer", footer);
	new GripJSONValue:arrayEmbed = grip_json_init_array();
	grip_json_array_append_value(arrayEmbed, embedData);


	var GripJSONValue:objectData = grip_json_init_object();
	grip_json_object_set_string(objectData, "username", "Jonas BOT");
	grip_json_object_set_string(objectData, "avatar_url", "https://www.svlmexico.com/img/profile2.jpg");
	//grip_json_object_set_string(objectData, "content", "Status Server");
	grip_json_object_set_value(objectData, "embeds", arrayEmbed);


	new GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/json");
	grip_options_add_header(options, "User-Agent", "Grip");

 	new GripBody:body = objectData != Invalid_GripJSONValue ? grip_body_from_json(objectData) : Empty_GripBody;

	grip_request(
    server,
    body,
    GripRequestTypePost,
    "handlerResponse",
    options
  );
}

public handlerResponse() {
	new GripHTTPStatus:status = grip_get_response_status_code();
	if (!(GripHTTPStatusOk  <= status <= GripHTTPStatusPartialContent )) {
	  server_print("Status Code Failed: [ %d ]", status);
	  return;
	}
	server_print("Status OK: [ %d ]", status);
}
setField(GripJSONValue:array, name[], value[], bool:inline)
{
	var GripJSONValue:FielData = grip_json_init_object();

	grip_json_object_set_string(FielData, "name", name);
	grip_json_object_set_string(FielData, "value", value);
	grip_json_object_set_bool(FielData, "inline", inline);
	grip_json_array_append_value(array, FielData);
	grip_destroy_json_value(FielData);
}



public players() {
	new pl;
	for(new i=1; i <= 32; i++)
	{
		if (is_user_connected(i)) {
			++pl;
		}
	}
	return pl;
}