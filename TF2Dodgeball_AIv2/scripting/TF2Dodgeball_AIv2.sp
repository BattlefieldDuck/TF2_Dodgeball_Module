#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

#define BOT_NAME "[AI] DBMaster"


public Plugin myinfo = 
{
	name = "[TF2] Dodgeball - Humanlike AI",
	author = PLUGIN_AUTHOR,
	description = "A humanlike robot",
	version = PLUGIN_VERSION,
	url = "https://github.com/BattlefieldDuck/"
};

Handle g_hHud;
bool g_bEnableAI[MAXPLAYERS + 1];
int g_iFollowTeamate[MAXPLAYERS + 1]; //UserID
int g_iAimTarget[MAXPLAYERS + 1]; //UserID
int g_iAirBlastStyle[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_dbai", Command_AIMENU, ADMFLAG_ROOT, "Let AI control!");
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	g_hHud = CreateHudSynchronizer();
}

public Action Command_AIMENU(int client, int args)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_AIMenu);
	
	Format(menuinfo, sizeof(menuinfo), "AI Control Panel");
	menu.SetTitle(menuinfo);
	
	char strClient[3];
	for (int i = 1; i <= MaxClients; i++)	if (IsClientInGame(i))
	{
		if (g_bEnableAI[i])	Format(menuinfo, sizeof(menuinfo), "ON");
		else Format(menuinfo, sizeof(menuinfo), "OFF");		
		Format(menuinfo, sizeof(menuinfo), "%N %s", i, menuinfo);
		IntToString(i, strClient, sizeof(strClient));
		menu.AddItem(strClient, menuinfo);
	}
	
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);
}

public int Handler_AIMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iClient = StringToInt(info);
		g_bEnableAI[iClient] = !g_bEnableAI[iClient];
		
		Command_AIMENU(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsFakeClient(client))	
	{
		char cName[32];
		GetClientName(client, cName, sizeof(cName));
		if (!StrEqual(cName, BOT_NAME))
			SetClientName(client, BOT_NAME);
			
		g_bEnableAI[client] = true;
	}
}

public Action Command_Say(int client, int args)
{
	if (!IsClientInGame(client) || client == 0)
		return Plugin_Continue;
		
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	char text[2048];
	for (int i = 1; i <= args; i++)
	{
		char strCmd[50];
		GetCmdArg(i, strCmd, sizeof(strCmd));
		Format(text, sizeof(text), "%s %s", text, strCmd);
	}

	if ((StrContains(text, "AI", false) != -1) || (StrContains(text, "Bot", false) != -1))
	{
		int iAI = GetAIIndex();
		if (iAI != -1)
		{
			if (StrContains(text, "kd", false) != -1)	FakeClientCommandEx(iAI, "say kd");
			else if (StrContains(text, "gay", false) != -1)	
			{
				switch(GetRandomInt(0, 3))
				{
					case(0):FakeClientCommandEx(iAI, "say (⟃ ͜ʖ ⟄)");
					case(1):FakeClientCommandEx(iAI, "say I am not gay!!!");
					case(2):FakeClientCommandEx(iAI, "say Shut up!!!");
					case(3):FakeClientCommandEx(iAI, "say ( ͡° ͜ʖ ͡°)");
				}
			}	
			else if ((StrContains(text, "hi", false) != -1)	|| (StrContains(text, "hello", false) != -1) || (StrContains(text, "halo", false) != -1) || (StrContains(text, "hai", false) != -1))
			{
				switch(GetRandomInt(0, 3))
				{
					case(0):FakeClientCommandEx(iAI, "say Hello");
					case(1):FakeClientCommandEx(iAI, "say Hi");
					case(2):FakeClientCommandEx(iAI, "say Ni hao");
					case(3):FakeClientCommandEx(iAI, "say 你好");
				}
			}
			else if ((StrContains(text, "bye", false) != -1) || (StrContains(text, "bai", false) != -1))
			{
				switch(GetRandomInt(0, 3))
				{
					case(0):FakeClientCommandEx(iAI, "say bye");
					case(1):FakeClientCommandEx(iAI, "say see you again next time!");
					case(2):FakeClientCommandEx(iAI, "say Don't leave me!!!'");
					case(3):FakeClientCommandEx(iAI, "say bye bro");
				}
			}			
			else if (StrContains(text, "/dbai", false) == -1)	
			{
				switch(GetRandomInt(0, 3))
				{
					case(0):FakeClientCommandEx(iAI, "say ?");
					case(1):FakeClientCommandEx(iAI, "say ??");
					case(2):FakeClientCommandEx(iAI, "say whats up");
					case(3):FakeClientCommandEx(iAI, "say (͠≖ ͜ʖ͠≖)");
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		g_bEnableAI[i] = false;
	}
	ServerCommand("tf_bot_quota 1");
}

public void OnClientPutInServer(int client)
{
	g_bEnableAI[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_bEnableAI[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_bEnableAI[client])	return Plugin_Continue;
	if (!IsPlayerAlive(client)) return Plugin_Continue;
	if (!(TF2_GetClientTeam(client) == TFTeam_Red || TF2_GetClientTeam(client) == TFTeam_Blue))	return Plugin_Continue;

	int iTeamate = GetClientOfUserId(g_iFollowTeamate[client]);
	if (!(iTeamate > 0 && iTeamate <= MaxClients && IsClientInGame(iTeamate) && IsPlayerAlive(iTeamate)))
	{
		iTeamate = GetClosestClient(client, GetClientTeam(client));
		if (iTeamate != -1)	g_iFollowTeamate[client] = GetClientUserId(iTeamate);
	}
	
	SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 255, 255, 1, 6.0, 0.5, 0.5);
	char strTarget[64] = "---";
	if (iTeamate != -1)	GetClientName(iTeamate, strTarget, sizeof(strTarget));
	ShowSyncHudText(client, g_hHud, "AI Enabled\nFollowing %s\nStyle %i", strTarget, g_iAirBlastStyle[client]);
	
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE)
	{
		float fClientEyesPosition[3], fRocketOrigin[3];
		GetClientEyePosition(client, fClientEyesPosition);
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketOrigin);
		
		float fAimAngle[3];
		GetVectorAnglesTwoPoints(fClientEyesPosition, fRocketOrigin, fAimAngle);
		AnglesNormalize(fAimAngle);
		//PrintCenterText(client, "%f %f %f %f %f %f", fAimAngle[0], fAimAngle[1], fAimAngle[2], angles[0], angles[1], angles[2]);
		
		float fDistance = GetVectorDistance(fClientEyesPosition, fRocketOrigin);
		
		//Follow Aim Rocket
		if (fDistance < 1000.0 && GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1) != GetClientTeam(client))
		{
			//Aim rocket position
			float fTurnRate = (4000.0/fDistance);
			if (angles[0] > fAimAngle[0]+fTurnRate+5.0)				angles[0] -= fTurnRate;
			else if (angles[0] < fAimAngle[0]-fTurnRate+5.0)		angles[0] += fTurnRate;
			if (angles[1] > fAimAngle[1]+fTurnRate+5.0)				angles[1] -= fTurnRate;
			else if (angles[1] < fAimAngle[1]-fTurnRate+5.0) 		angles[1] += fTurnRate;
			
			if (fDistance < 200.0)
			{
				switch(g_iAirBlastStyle[client])
				{
					case(0)://Normal
					{
						buttons |= IN_ATTACK2;
					}
					case(1)://Upspike
					{
						if (fAimAngle[0] < 10.0)
						{
							angles[0] = -35.0;
							TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						}
						buttons |= IN_ATTACK2;
					}
					case(2)://Downspike
					{
						if (fAimAngle[0] > -10.0)
						{
							angles[0] = 35.0;
							TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						}
						buttons |= IN_ATTACK2;
					}	
				}
				
				if (GetEntityFlags(client) & FL_ONGROUND)	buttons |= IN_JUMP;
			}
			AnglesNormalize(angles);
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		}
		else//Angle follow Target + random motion
		{
			g_iAirBlastStyle[client] = GetRandomInt(0, 2);
			
			int iEntityOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
			if (iEntityOwner > 0 && iEntityOwner <= MaxClients && IsClientInGame(iEntityOwner) && IsPlayerAlive(iEntityOwner) && TF2_GetClientTeam(client) != TF2_GetClientTeam(iEntityOwner))
			{
				g_iAimTarget[client] = GetClientUserId(iEntityOwner);
				PrintCenterText(client, "Attacker: %N", iEntityOwner);
			}
			
			int iAimTarget = GetClientOfUserId(g_iAimTarget[client]);
			if (iAimTarget > 0 && iAimTarget <= MaxClients && IsClientInGame(iAimTarget) && IsPlayerAlive(iAimTarget))
			{
				float fOrigin[3], fTOrigin[3];
				GetClientEyePosition(client, fOrigin);
				GetClientEyePosition(iAimTarget, fTOrigin);
				float fAimTargetAngle[3];
				GetVectorAnglesTwoPoints(fOrigin, fTOrigin, fAimTargetAngle);
				AnglesNormalize(fAimTargetAngle);

				if (angles[0] > fAimTargetAngle[0] + 5.0)		angles[0] -= GetRandomFloat(1.0, 1.5); //GetTwoFloatDifference(angles[0], fAimTargetAngle[0]);
				else if (angles[0] < fAimTargetAngle[0] - 5.0)	angles[0] += GetRandomFloat(1.0, 1.5); //GetTwoFloatDifference(angles[0], fAimTargetAngle[0]);
				if (angles[1] > fAimTargetAngle[1] + 5.0)		angles[1] -= GetRandomFloat(1.0, 1.5); //GetTwoFloatDifference(angles[1], fAimTargetAngle[1]);
				else if (angles[1] < fAimTargetAngle[1] - 5.0)	angles[1] += GetRandomFloat(1.0, 1.5); //GetTwoFloatDifference(angles[1], fAimTargetAngle[1]);
				AnglesNormalize(angles);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
		}
	}
	
	float fVec[3];
	//Follow teammate
	if	(iTeamate != INVALID_ENT_REFERENCE)
	{
		if (TF2_GetClientTeam(client) != TF2_GetClientTeam(iTeamate))
		{
			iTeamate = GetClosestClient(client, GetClientTeam(client));
		}

		if	(iTeamate != INVALID_ENT_REFERENCE && GetEntityFlags(client) & FL_ONGROUND)
		{
			float fOrigin[3], fTOrigin[3];
			GetClientEyePosition(client, fOrigin);
			GetClientEyePosition(iTeamate, fTOrigin);
			
			float fTeamateDistance = GetVectorDistance(fOrigin, fTOrigin);
			if (fTeamateDistance > 350.0)
			{
				MakeVectorFromPoints(fOrigin, fTOrigin, fVec);
				//PrintCenterText(client, "%f %f %f %i", fVec[0], fVec[1], fVec[2], seed);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVec);
			}
		}
	}

	return Plugin_Continue;
}


float GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
	static float tmpVec[3];
	tmpVec[0] = vEndPos[0] - vStartPos[0];
	tmpVec[1] = vEndPos[1] - vStartPos[1];
	tmpVec[2] = vEndPos[2] - vStartPos[2];
	GetVectorAngles(tmpVec, vAngles);
}

void AnglesNormalize(float vAngles[3])
{
	while (vAngles[0] > 89.0)vAngles[0] -= 360.0;
	while (vAngles[0] < -89.0)vAngles[0] += 360.0;
	while (vAngles[1] > 180.0)vAngles[1] -= 360.0;
	while (vAngles[1] < -180.0)vAngles[1] += 360.0;
}

public void CopyVector(float vIn[3], float vOut[3])
{
	vOut[0] = vIn[0];
	vOut[1] = vIn[1];
	vOut[2] = vIn[2];
}

int GetClosestClient(int client, int iTeam)
{
	float vPos1[3], vPos2[3];
	GetClientEyePosition(client, vPos1);
	
	int iClosestEntity = -1;
	float flClosestDistance = -1.0;
	float flEntityDistance;
	
	for (int i = 1; i <= MaxClients; i++)	if (IsClientInGame(i))
	{
		if (GetClientTeam(i) == iTeam && IsPlayerAlive(i) && i != client)
		{
			GetClientEyePosition(i, vPos2);
			flEntityDistance = GetVectorDistance(vPos1, vPos2);
			if ((flEntityDistance < flClosestDistance) || flClosestDistance == -1.0)
			{
				flClosestDistance = flEntityDistance;
				iClosestEntity = i;
			}
		}
	}
	return iClosestEntity;
}

float GetTwoFloatDifference(float num1, float num2)
{
	float fDifference = num1 - num2;
	if (num2 > num1)	fDifference = num2 - num1;	
	return fDifference;
}

int GetAIIndex()
{
	for (int i = 1; i <= MaxClients; i++)  if (IsClientInGame(i) && IsFakeClient(i))	return i;
	return -1;
}