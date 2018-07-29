#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Block Rainbow Tauntkill",
	author = PLUGIN_AUTHOR,
	description = "Block Rainbow Tauntkill",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

public void OnPluginStart()
{
	CreateConVar("sm_tfdb_brt_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
}

public void OnMapStart()
{
	for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i))
	{
		OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, TauntCheck);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, TauntCheck);
}

public Action TauntCheck(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	switch (damagecustom)
	{
		case TF_CUSTOM_TAUNT_ARMAGEDDON:
		{
			damage = 0.0;
			return Plugin_Changed;
		}
		
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}
