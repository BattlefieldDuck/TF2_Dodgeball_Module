/**********************************************************************

Credits

Pelipoika:
https://forums.alliedmods.net/showthread.php?p=2452962



**********************************************************************/


Handle hAdminMenu = INVALID_HANDLE;
Handle hPlayTaunt;
Handle g_hHud;
Handle g_Timer;
Handle g_CoolDownTimer;

int g_iPlayerGlowEntity[MAXPLAYERS + 1];
ConVar g_hRainbowCycleRate;

ConVar g_bBotEnable;
ConVar g_bPlayerOutline;
ConVar g_bRainOutline;
Handle g_cBotName;
ConVar g_iBotHackMode;
ConVar g_iVoteRate;
ConVar g_iVoteRateCoolDown;

bool g_bVoteCount[MAXPLAYERS + 1];

bool g_bRoundStart;
int g_iBallDirection; // (0 = Normal, 1 = high ball, 2= down ball)
int g_iDirectionPer;
int g_iHackType; //(0 = traditional(Aimbot), 1 = taunt + traditional(skillbot), 2 = Spinhack(SpinBot))
int g_iPlayerHackType[MAXPLAYERS + 1];
int g_iCooldown;

//Plugin---------------------------------------------
public void OnPluginStart()
{
	//Other's plugins
	{
		Handle conf = LoadGameConfigFile("tf2.duckbot");
		if (conf == INVALID_HANDLE)
		{
			SetFailState("Unable to load gamedata/tf2.duckbot.txt");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		hPlayTaunt = EndPrepSDKCall();
		if (hPlayTaunt == INVALID_HANDLE)
		{
			SetFailState("Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Wait patiently for a fix.");
			CloseHandle(conf);
			return;
		}
		CloseHandle(conf);
	}
	
	//Adminmenu
	
	//HookEvent
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("round_start", OnRoundStart, EventHookMode_Post);
	
	CreateConVar("tfdb_dbot_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	
	g_bBotEnable = CreateConVar("tfdb_dbot_enable", "1", "Enable Duck's Bot Plugin.", 0, true, 0.0, true, 1.0);
	g_cBotName = CreateConVar("tfdb_dbot_name", "[BOT] DUCK's BOT", "The Dodgeball DBOT name.");
	
	g_bPlayerOutline = CreateConVar("tfdb_dbot_enable_player_outline", "1", "Enable Rainbow outline on player?", 0, true, 0.0, true, 1.0);
	
	g_bRainOutline = CreateConVar("tfdb_dbot_enable_raindow_outline", "1", "Enable Rainbow outline on DBOT?", 0, true, 0.0, true, 1.0);
	g_hRainbowCycleRate = CreateConVar("tfdb_dbot_rainbow_rate", "5.0", "Control the speed of which the rainbow glow changes color.");
	
	g_iBotHackMode = CreateConVar("tfdb_dbot_hackmode", "2", "DBOT HackMode:  0=Random Mode. 1=Fix AimBot Mode. 2=Fix SkillBot Mode. 3=Fix SpinBot Mode.", 0, true, 0.0, true, 3.0);
	
	g_iVoteRate = CreateConVar("tfdb_dbot_vote_percentage", "0.5", "Default: 0.5 = 50%, for sm_votedbot sucessful voting percentage rate is 60%.", 0, true, 0.0, true, 1.0);
	g_iVoteRateCoolDown = CreateConVar("tfdb_dbot_vote_cooldown", "60", "Cooldown for Voting. Default 60 = 60 seconds.", 0, true, 0.0, true, 360.0);
	
	RegAdminCmd("sm_votedbot", Command_VoteBot, 0);
	RegAdminCmd("sm_spawndbot", Command_SpawnBot, ADMFLAG_BAN);
	RegAdminCmd("sm_removedbot", Command_RemoveBot, ADMFLAG_BAN);
	RegAdminCmd("sm_dbotmenu", Command_BotMenu, ADMFLAG_BAN);
	RegAdminCmd("sm_dbothack", Command_HackMenu, ADMFLAG_BAN);
	RegAdminCmd("sm_dbotcheck", Command_CheckHackMenu, ADMFLAG_ROOT);
	
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	g_hHud = CreateHudSynchronizer();
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if (StrEqual(strName, "RainbowGlow"))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		g_iPlayerHackType[i] = -1;
		g_bVoteCount[i] = false;
	}
}

public void OnClientPutInServer(int client)
{
	g_iPlayerHackType[client] = -1;
	g_bVoteCount[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_iPlayerHackType[client] = -1;
	g_bVoteCount[client] = false;
}
//---------------------------------------------------

//Main Menu--------------------------------------------------------------------------------
public Action Command_CheckHackMenu(int client, int args) //Bot
{
	if (g_bBotEnable.BoolValue)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_CheckHackMenu);
		
		Format(menuinfo, sizeof(menuinfo), "Duck's BOT Control Panel v%s - Check Hack", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		menu.AddItem("REFERSH", "Refresh");
		
		for (int i = 1; i < MAXPLAYERS; i++) if (IsValidClient(i))
		{
			if(IsFakeClient(i) && g_iHackType != -1)
			{
				switch(g_iHackType)
				{
					case(0):Format(menuinfo, sizeof(menuinfo), "[BOT]<%N> - AIMBOT", client);
					case(1):Format(menuinfo, sizeof(menuinfo), "[BOT]<%N> - SKILLBOT", client);
					case(2):Format(menuinfo, sizeof(menuinfo), "[BOT]<%N> - SPINBOT", client);
				}
				menu.AddItem("", menuinfo, ITEMDRAW_DISABLED);
			}
			else if(g_iPlayerHackType[i] != -1)
			{
				switch(g_iPlayerHackType[i])
				{
					case(0):Format(menuinfo, sizeof(menuinfo), "<%N> - AIMBOT", client);
					case(1):Format(menuinfo, sizeof(menuinfo), "<%N> - SKILLBOT", client);
					case(2):Format(menuinfo, sizeof(menuinfo), "<%N> - SPINBOT", client);
					case(3):Format(menuinfo, sizeof(menuinfo), "<%N> - TRIGGERBOT", client);
					case(4):Format(menuinfo, sizeof(menuinfo), "<%N> - FOLLOWTHEROCKET", client);
				}
				menu.AddItem("", menuinfo, ITEMDRAW_DISABLED);
			}
		}

		
		menu.ExitBackButton = false;
		menu.ExitButton = true;
		menu.Display(client, -1);
	}
	return Plugin_Handled;
}

public int Handler_CheckHackMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		if (StrEqual(info, "REFERSH"))
		{
			Command_CheckHackMenu(client, 0);
		}
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

public Action Command_BotMenu(int client, int args) //Bot
{
	if (g_bBotEnable.BoolValue)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_BotMenu);
		
		Format(menuinfo, sizeof(menuinfo), "Duck's BOT Control Panel v%s", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		char botname[32];
		GetConVarString(g_cBotName, botname, sizeof(botname));
		
		Format(menuinfo, sizeof(menuinfo), "Spawn %s", botname);
		menu.AddItem("SPAWN", menuinfo);
		Format(menuinfo, sizeof(menuinfo), "Remove %s", botname);
		menu.AddItem("REMOVE", menuinfo);
		menu.AddItem("", "Choose Bot Type:", ITEMDRAW_DISABLED);
		menu.AddItem("AIMBOT", "AimBot");
		menu.AddItem("SKILLBOT", "SkillBot");
		menu.AddItem("SPINBOT", "SpinBot");
		
		//menu.AddItem("CIRCLEBOT", "Testing CircleBot");
		
		menu.ExitBackButton = false;
		menu.ExitButton = true;
		menu.Display(client, -1);
	}
	return Plugin_Handled;
}

public int Handler_BotMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "SPAWN"))
		{
			Command_SpawnBot(client, 0);
		}
		else if (StrEqual(info, "REMOVE"))
		{
			Command_RemoveBot(client, 0);
		}
		else if (StrEqual(info, "AIMBOT"))
		{
			g_iHackType = 0;
		}
		else if (StrEqual(info, "SKILLBOT"))
		{
			g_iHackType = 1;
		}
		else if (StrEqual(info, "SPINBOT"))
		{
			g_iHackType = 2;
		}
		//else if (StrEqual(info, "CIRCLEBOT"))
		//{
			//g_iHackType = 3;
		//}
		
		if(StrContains(info, "BOT", false) != -1 && g_Timer == INVALID_HANDLE)
		{
			g_Timer = CreateTimer(5.0, Timer_BallDirection, 0, TIMER_REPEAT);
		}		
		Command_BotMenu(client, -1);
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

public Action Command_HackMenu(int client, int args) //HackMenu
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_HackMenu);
	
	Format(menuinfo, sizeof(menuinfo), "Duck's BOT - Hack Menu v%s \nChoose Hack Type:", PLUGIN_VERSION);
	menu.SetTitle(menuinfo);
	
	menu.AddItem("AIMBOT", "AimBot");
	menu.AddItem("SKILLBOT", "SkillBot");
	menu.AddItem("SPINBOT", "SpinBot");
	menu.AddItem("TRIGGERBOT", "TriggerBot");
	menu.AddItem("FOLLOW", "Follow the Rocket");
	menu.AddItem("DISABLE", "Disable");
	
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);
	return Plugin_Handled;
}

public int Handler_HackMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		char SteamID64[64];
		GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64), true);
		
		if (StrEqual(info, "AIMBOT"))
		{
			g_iPlayerHackType[client] = 0;
		}
		else if (StrEqual(info, "SKILLBOT"))
		{
			g_iPlayerHackType[client] = 1;
		}
		else if (StrEqual(info, "SPINBOT"))
		{
			g_iPlayerHackType[client] = 2;
		}
		else if (StrEqual(info, "TRIGGERBOT"))
		{
			g_iPlayerHackType[client] = 3;
		}
		else if (StrEqual(info, "FOLLOW"))
		{
			g_iPlayerHackType[client] = 4;
		}
		else if (StrEqual(info, "DISABLE"))
		{
			g_iPlayerHackType[client] = -1;
		}
		LogMessage("\"%N\"<[%s]> : %s ON", client, SteamID64, info);
		for (int i = 1; i <= MaxClients; i++) if(IsValidClient(i) && i != client)
		{
			PrintCenterText(i, "\"%N\"<[%s]> : %s ON", client, SteamID64, info);
		}
		
		if(StrContains(info, "BOT", false) != -1 && g_Timer == INVALID_HANDLE)
		{
			g_Timer = CreateTimer(5.0, Timer_BallDirection, client, TIMER_REPEAT);
		}
		
		Command_HackMenu(client, -1);
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

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == hAdminMenu)	return;
	
	hAdminMenu = topmenu;

	TopMenuObject player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_SERVERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hAdminMenu, "sm_dbotmenu", TopMenuObject_Item, AdminMenu_DuckBotMenu, player_commands, "sm_dbotmenu", ADMFLAG_BAN);
	}
}
 
public void AdminMenu_DuckBotMenu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Duck's BOT Control Panel");
	}
	else if( action == TopMenuAction_SelectOption)
	{
		Command_BotMenu(param, 0);
	}
}
//-----------------------------------------------------------------------------------------

//HookEvent------------------------------------------
public Action OnRoundStart(Handle event, char[] name, bool dontBroadcast)//@
{
	g_bRoundStart = true;
	if(IsBotInGame())
	{
		ServerCommand("rank_enable 0");
		switch(g_iBotHackMode.IntValue)
		{
			case (0):g_iHackType = GetRandomInt(0, 2);
			case (1):g_iHackType = 0;
			case (2):g_iHackType = 1;
			case (3):g_iHackType = 2;
			case (4):g_iHackType = 3;
		}		
		CreateTimer(9.9, Timer_ChangeTeam, 0); //Round ready = 10sec
		if (g_Timer == INVALID_HANDLE)	g_Timer = CreateTimer(5.0, Timer_BallDirection, 0, TIMER_REPEAT);
	}
	else	ServerCommand("rank_enable 1");
}

/*
public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	g_bRoundStart = false;
	if (g_Timer != INVALID_HANDLE)
	{
		KillTimer(g_Timer);
		g_Timer = INVALID_HANDLE;
	}
}*/

public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		if (IsFakeClient(client))
		{
			char bot[32];
			GetConVarString(g_cBotName, bot, sizeof(bot));
			char cName[32];
			GetClientName(client, cName, sizeof(cName));
			if (!StrEqual(cName, bot))
				SetClientName(client, bot);
			if (GetEntityMoveType(client) != MOVETYPE_NONE)
				SetEntityMoveType(client, MOVETYPE_NONE);
			
			if (!TF2_HasGlow(client) && g_bRainOutline.BoolValue) //Rainbow glow
			{
				int iGlow = TF2_CreateGlow(client);
				if (IsValidEntity(iGlow))
				{
					g_iPlayerGlowEntity[client] = EntIndexToEntRef(iGlow);
					SDKHook(client, SDKHook_PreThink, OnPlayerThink);
				}
			}
		}
		else if(g_bPlayerOutline.BoolValue)
		{
			if(GetEntProp(client, Prop_Send, "m_bGlowEnabled") == 0)
				SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
		}
	}
	return Plugin_Continue;
}
//---------------------------------------------------


//Command--------------------------------------------
public Action Command_VoteBot(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	if( g_iCooldown > 0)
	{
		CPrintToChat(client, "{gold}[DUCK BOT]{default} Voting System is currently cooling down. Please wait {green}%i {default}seconds",  g_iCooldown);
		return Plugin_Continue;
	}
	
	if(g_bVoteCount[client])
	{
		if(IsBotInGame())
			CPrintToChat(client, "{gold}[DUCK BOT]{default} You had voted already! Need {green}%i{default} more to disable.", GetVoteCount());
		else
			CPrintToChat(client, "{gold}[DUCK BOT]{default} You had voted already! Need {green}%i{default} more to enable.", GetVoteCount());
	}
	else
	{
		g_bVoteCount[client] = true;
		
		if(GetVoteCount() <= 0)
		{
			if(IsBotInGame())
				Command_RemoveBot(client, 0);
			else
				Command_SpawnBot(client, 0);
		}
		else
		{
			if(IsBotInGame())
				CPrintToChatAll("{gold}[DUCK BOT]{green} %N {default}vote for enable {gold}DUCK BOT{default}. Need {green}%i{default} more votes for enable.", client, GetVoteCount());
			else
				CPrintToChatAll("{gold}[DUCK BOT]{green} %N {default}vote for disable {gold}DUCK BOT{default}. Need {green}%i{default} more votes for disable.", client, GetVoteCount());
		}
	}
	
	return Plugin_Continue;
}

int GetVoteCount()
{
	int iVotedCount = 0;
	for (int i = 1; i <= MaxClients; i++)	if (IsValidClient(i))
	{
		if (g_bVoteCount[i])	iVotedCount++;
	}
	
	int iClientCount = GetRealClientCount();
	float fVoteRate = g_iVoteRate.FloatValue;
	//Cal
	int ReturnValue = RoundToCeil(float(iClientCount) * fVoteRate) - iVotedCount;
	
	return ReturnValue;
}

public Action Command_SpawnBot(int client, int args)
{
	ServerCommand("rank_enable 0");
	ServerCommand("tf_bot_add 1");
	ServerCommand("mp_autoteambalance 0");
	for (int i = 1; i <= MaxClients; i++)	g_bVoteCount[i] = false;
	CreateTimer(1.0, Timer_Spawndoctor, client); //tf_bot_add 1 need some times
	if(g_CoolDownTimer == INVALID_HANDLE)
	{
		g_iCooldown = g_iVoteRateCoolDown.IntValue;
		g_CoolDownTimer = CreateTimer(1.0, Timer_CoolDown, 0);
	}
	return Plugin_Continue;
}

public Action Command_RemoveBot(int client, int args)
{
	for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i) && IsFakeClient(i))
	{
		FakeClientCommandEx(i, "say Bye, I will be back!");
	}
	ServerCommand("tf_bot_quota 0");
	ServerCommand("rank_enable 1");
	ServerCommand("mp_scrambleteams");
	ServerCommand("mp_autoteambalance 1");
	for (int i = 1; i <= MaxClients; i++)	g_bVoteCount[i] = false;
	if(g_CoolDownTimer == INVALID_HANDLE)
	{
		g_iCooldown = g_iVoteRateCoolDown.IntValue;
		g_CoolDownTimer = CreateTimer(1.0, Timer_CoolDown, 0);
	}
	return Plugin_Continue;
}
//---------------------------------------------------


//MainFunction--------------------------------------------------------------------------
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)//@
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if(GetRealClientCount() <= 1 && !IsBotInGame())
	{
		char BotName[32];
		GetConVarString(g_cBotName, BotName, sizeof(BotName));
		PrintCenterText(client, "Type !votedbot to play with %s!", BotName);
	}
	
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
	
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if (iActiveWeapon == GetPlayerWeaponSlot(client, 0) && TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		float fEntityOrigin[3], fClientEyes[3], fCamAngle[3], fDistance, fiClientEyes[3];
		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "tf_projectile_*")) != INVALID_ENT_REFERENCE)
		{
			//-------------------------------[ BOT ]-----------------------------------
			if (IsFakeClient(client))
			{
				GetClientEyePosition(client, fClientEyes);
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityOrigin);
				
				fDistance = GetVectorDistance(fClientEyes, fEntityOrigin);
				
				if (fDistance < 200.0 && GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1) != GetClientTeam(client))// && CanSeeRocket(client, iEntity))
				{
					if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
						TF2_RemoveCondition(client, TFCond_Taunting);
					
					GetVectorAnglesTwoPoints(fClientEyes, fEntityOrigin, fCamAngle);
					AnglesNormalize(fCamAngle);
					TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
					CopyVector(fCamAngle, angles);
					ModRateOfFire(iActiveWeapon);
					buttons |= IN_ATTACK2;
				}
				else
				{
					switch (g_iHackType)
					{
						case (0): //AimBot
						{
							GetVectorAnglesTwoPoints(fClientEyes, fEntityOrigin, fCamAngle);
							AnglesNormalize(fCamAngle);
							TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
							CopyVector(fCamAngle, angles);
						}
						case (1): //SkillBot
						{
							int iLevel;
							int iClient = GetClosestClient(client); /*
							switch(g_iBallDirection)
							{
								case(0):iClient = GetClosestClient(client);
								case(1):iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
								case(2):iClient = GetClosestClient(client);
							}*/
							if (IsValidClient(iClient) && IsPlayerAlive(iClient)) //Chok ball
							{
								GetClientEyePosition(iClient, fiClientEyes);
								GetVectorAnglesTwoPoints(fClientEyes, fiClientEyes, fCamAngle);
								AnglesNormalize(fCamAngle);
								switch (g_iDirectionPer)
								{
									case (0):iLevel = 1;
									case (1):iLevel = 1;
									case (2):iLevel = 4;
									case (3):iLevel = 8;
								}
								switch (g_iBallDirection)
								{
									case (0):fCamAngle[0] = 0.0; //Normal
									case (1):fCamAngle[0] = -float((11 * iLevel) + 1); //Up -89.0
									case (2):fCamAngle[0] = float((11 * iLevel) + 1); //Down 89.0
									//case(3):fCamAngle[1] += 89.0; //left
									//case(4):fCamAngle[1] -= 89.0; //right
								}
								AnglesNormalize(fCamAngle);
								TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
								CopyVector(fCamAngle, angles);
							}
							if (!TF2_IsPlayerInCondition(client, TFCond_Taunting)) //Taunting
							{
								int itemdef = 1157;
								int particle = StringToInt("3005");
								int ent = MakeCEIVEnt(client, itemdef, particle);
								Address pEconItemView = GetEntityAddress(ent) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
								
								if (hPlayTaunt != INVALID_HANDLE)
									SDKCall(hPlayTaunt, client, pEconItemView);
								
								AcceptEntityInput(ent, "Kill");
							}
						}
						case (2): //SpinBot
						{
							fCamAngle[0] = GetRandomFloat(-89.0, 89.0);
							fCamAngle[1] = GetRandomFloat(-179.9, 179.9);
							fCamAngle[2] = 0.0;
							AnglesNormalize(fCamAngle);
							TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
							CopyVector(fCamAngle, angles);
						}
						case (3): //CircleBot
						{
							
						}
					}
				}
			}
			//-------------------------------------------------------------------------
			else if(g_iPlayerHackType[client] != -1)
			//-------------------------------[ Human ]---------------------------------
			{
				GetClientEyePosition(client, fClientEyes);
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityOrigin);
				
				fDistance = GetVectorDistance(fClientEyes, fEntityOrigin);
				
				if (fDistance < 200.0 && GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1) != GetClientTeam(client) && g_iPlayerHackType[client] != 3)// && CanSeeRocket(client, iEntity))
				{
					if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
						TF2_RemoveCondition(client, TFCond_Taunting);
					
					GetVectorAnglesTwoPoints(fClientEyes, fEntityOrigin, fCamAngle);
					AnglesNormalize(fCamAngle);
					TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
					CopyVector(fCamAngle, angles);
					ModRateOfFire(iActiveWeapon);
					buttons |= IN_ATTACK2;
				}
				else
				{
					switch (g_iPlayerHackType[client])
					{
						case (0): //AimBot
						{
							GetVectorAnglesTwoPoints(fClientEyes, fEntityOrigin, fCamAngle);
							AnglesNormalize(fCamAngle);
							TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
							CopyVector(fCamAngle, angles);
						}
						case (1): //SkillBot
						{
							int iLevel;
							int iClient = GetClosestClient(client); /*
							switch(g_iBallDirection)
							{
								case(0):iClient = GetClosestClient(client);
								case(1):iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
								case(2):iClient = GetClosestClient(client);
							}*/
							if (IsValidClient(iClient) && IsPlayerAlive(iClient)) //Chok ball
							{
								GetClientEyePosition(iClient, fiClientEyes);
								GetVectorAnglesTwoPoints(fClientEyes, fiClientEyes, fCamAngle);
								AnglesNormalize(fCamAngle);
								switch (g_iDirectionPer)
								{
									case (0):iLevel = 1;
									case (1):iLevel = 1;
									case (2):iLevel = 4;
									case (3):iLevel = 8;
								}
								switch (g_iBallDirection)
								{
									case (0):fCamAngle[0] = 0.0; //Normal
									case (1):fCamAngle[0] = -float((11 * iLevel) + 1); //Up -89.0
									case (2):fCamAngle[0] = float((11 * iLevel) + 1); //Down 89.0
									//case(3):fCamAngle[1] += 89.0; //left
									//case(4):fCamAngle[1] -= 89.0; //right
								}
								AnglesNormalize(fCamAngle);
								TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
								CopyVector(fCamAngle, angles);
							}
							if (!TF2_IsPlayerInCondition(client, TFCond_Taunting)) //Taunting
							{
								int itemdef = 1157;
								int particle = StringToInt("3005");
								int ent = MakeCEIVEnt(client, itemdef, particle);
								Address pEconItemView = GetEntityAddress(ent) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
								
								if (hPlayTaunt != INVALID_HANDLE)
									SDKCall(hPlayTaunt, client, pEconItemView);
								
								AcceptEntityInput(ent, "Kill");
							}
						}
						case (2): //SpinBot
						{
							fCamAngle[0] = GetRandomFloat(-89.0, 89.0);
							fCamAngle[1] = GetRandomFloat(-179.9, 179.9);
							fCamAngle[2] = 0.0;
							AnglesNormalize(fCamAngle);
							TeleportEntity(client, NULL_VECTOR, fCamAngle, NULL_VECTOR);
							CopyVector(fCamAngle, angles);
						}
						case (3): //TriggerBot
						{
							GetVectorAnglesTwoPoints(fClientEyes, fEntityOrigin, fCamAngle);
							AnglesNormalize(fCamAngle);
							float fClientAngle[3];
							GetClientAbsAngles(client, fClientAngle);
							//PrintCenterText(client, "X: %f    Y: %f    Distance: %f", FloatAbs(fCamAngle[0] - fClientAngle[0]), FloatAbs(fCamAngle[1] - fClientAngle[1]), fDistance);
							if ((FloatAbs(fCamAngle[0] - fClientAngle[0]) <= 30 || FloatAbs(fCamAngle[0] - fClientAngle[0]) >= 140) && (FloatAbs(fCamAngle[1] - fClientAngle[1]) <= 100 || FloatAbs(fCamAngle[1] - fClientAngle[1]) >= 300) && fDistance < 200.0)
							{
								if (GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1) != GetClientTeam(client) && CanSeeRocket(client, iEntity))
								{
									ModRateOfFire(iActiveWeapon);	
									buttons |= IN_ATTACK2;
								}
							}
						}
						case (4): //FollowTheBall
						{
							float iBallPositionUP[3];
							iBallPositionUP[0] = fEntityOrigin[0];
							iBallPositionUP[1] = fEntityOrigin[1];
							iBallPositionUP[2] = (fEntityOrigin[2] + 50.0);
							TeleportEntity(client, iBallPositionUP, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}
			}
			//-------------------------------------------------------------------------
		}
	}
	
	return Plugin_Continue;
}
//--------------------------------------------------------------------------------------


//Timer---------------------------------
public Action Timer_ChangeTeam(Handle timer, int client)
{
	if (IsBotInGame())
	{
		for (int i = 1; i <= MaxClients; i++) if(IsValidClient(i))
		{
			if(IsFakeClient(i) && TF2_GetClientTeam(i) != TFTeam_Blue)
			{
				TF2_ChangeClientTeam(i, TFTeam_Blue);
				TF2_RespawnPlayer(i);
			}
			else	if(!IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				TF2_ChangeClientTeam(i, TFTeam_Red);
				TF2_RespawnPlayer(i);
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_BallDirection(Handle timer, int iType)//@ iType = 0 is BOT,1 <= Player
{
	if (g_bRoundStart && IsBotInGame())
	{
		char cDirection[32];
		if (g_iHackType == 1 || g_iPlayerHackType[iType] == 1)
		{
			g_iBallDirection = GetRandomInt(0, 2);
			switch (g_iBallDirection)
			{
				case (0):
				{
					cDirection = "Normal";
				}
				case (1):
				{
					cDirection = "Up";
				}
				case (2):
				{
					cDirection = "Down";
				}
			}
			g_iDirectionPer = GetRandomInt(1, 3);
		}
		
		char cHackType[32];
		SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 0, 255, 1, 6.0, 0.5, 0.5);
		
		if(iType == 0)
		{
			switch (g_iHackType)
			{
				case (0):
				{
					cHackType = "AimBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (1):
				{
					cHackType = "SkillBot";
					SetHudTextParams(0.02, 0.08, 6.0, 255, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (2):
				{
					cHackType = "SpinBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (3):
				{
					cHackType = "TriggerBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 255, 255, 1, 6.0, 0.5, 0.5);
				}
			}
			for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i))
			{
				if (g_iHackType == 1)
				{
					ShowSyncHudText(i, g_hHud, "BOT Type: %s \nRocket Direction: %s (Level: %i)", cHackType, cDirection, g_iDirectionPer);
				}
				else
				{
					ShowSyncHudText(i, g_hHud, "BOT Type: %s", cHackType);
				}
			}
		}
		/*
		else if(IsValidClient(iType))
		{
			switch (g_iPlayerHackType[iType])
			{
				case (0):
				{
					cHackType = "AimBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (1):
				{
					cHackType = "SkillBot";
					SetHudTextParams(0.02, 0.08, 6.0, 255, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (2):
				{
					cHackType = "SpinBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 0, 255, 1, 6.0, 0.5, 0.5);
				}
				case (3):
				{
					cHackType = "TriggerBot";
					SetHudTextParams(0.02, 0.08, 6.0, 0, 255, 255, 255, 1, 6.0, 0.5, 0.5);
				}
			}
		}
		*/
	}
	return Plugin_Continue;
}

public Action Timer_Spawndoctor(Handle timer, int client)
{
	ServerCommand("rank_enable 0");
	
	for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i) && IsFakeClient(i))
	{
		char bot[32];
		GetConVarString(g_cBotName, bot, sizeof(bot));
		SetClientName(i, bot);
		
		if(TF2_GetClientTeam(i) != TFTeam_Blue)
			TF2_ChangeClientTeam(i, TFTeam_Blue);
		
		TF2_RespawnPlayer(i);
		SetEntityMoveType(i, MOVETYPE_NONE);
		FakeClientCommandEx(i, "Hi, I am back!");
		break;
	}
	return Plugin_Continue;
}

public Action Timer_CoolDown(Handle timer, int client)
{
	g_iCooldown--;
	if(g_iCooldown > 0)	CreateTimer(1.0, Timer_CoolDown, 0);
	return Plugin_Continue;
}
//--------------------------------------



//Rainbow-------------------------------  https://forums.alliedmods.net/showthread.php?p=2452962 by Pelipoika <3
public Action OnPlayerThink(int client)
{
	int iGlow = EntRefToEntIndex(g_iPlayerGlowEntity[client]);
	if (iGlow != INVALID_ENT_REFERENCE)
	{
		float flRate = g_hRainbowCycleRate.FloatValue;
		
		int color[4];
		color[0] = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 0) * 127.5 + 127.5);
		color[1] = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 2) * 127.5 + 127.5);
		color[2] = RoundToNearest(Cosine((GetGameTime() * flRate) + client + 4) * 127.5 + 127.5);
		color[3] = 255;
		
		SetVariantColor(color);
		AcceptEntityInput(iGlow, "SetGlowColor");
	}
}

stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	
	AcceptEntityInput(ent, "Enable");
	
	//Change name back to old name because we don't need it anymore.
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	
	return false;
}
//--------------------------------------



//stock-----------------------------------------------------------------------------------------------------------------------------
bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

bool CanSeeRocket(int client, int rocketindex)
{
	float fClientPosition[3], fRocketPosition[3];
	GetClientEyePosition(client, fClientPosition);
	GetEntPropVector(rocketindex, Prop_Send, "m_vecOrigin", fRocketPosition);
	
	TR_TraceRayFilter(fClientPosition, fRocketPosition, MASK_SOLID, RayType_EndPoint, TraceRayFilterClients, rocketindex);
	if (TR_GetEntityIndex() == rocketindex)
	{
		return true;
	}
	return false;
}

public bool TraceRayFilterClients(int entity, int mask, any data)
{
	if (entity > 0 && entity <= MaxClients)
	{
		if (entity == data)
			return true;
		else
			return false;
	}
	return true;
}

public void CopyVector(float vIn[3], float vOut[3])
{
	vOut[0] = vIn[0];
	vOut[1] = vIn[1];
	vOut[2] = vIn[2];
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

int GetClosestClient(int client)
{
	float vPos1[3], vPos2[3];
	GetClientEyePosition(client, vPos1);
	
	int iTeam = GetClientTeam(client);
	int iClosestEntity = -1;
	float flClosestDistance = -1.0;
	float flEntityDistance;
	
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
	{
		if (GetClientTeam(i) != iTeam && IsPlayerAlive(i) && i != client)
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

int ModRateOfFire(int iWeapon)
{
	float m_flNextPrimaryAttack = GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack");
	float m_flNextSecondaryAttack = GetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack");
	SetEntPropFloat(iWeapon, Prop_Send, "m_flPlaybackRate", 10.0);
	
	float fGameTime = GetGameTime();
	float fPrimaryTime = ((m_flNextPrimaryAttack - fGameTime) - 0.99);
	float fSecondaryTime = ((m_flNextSecondaryAttack - fGameTime) - 0.99);
	
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fPrimaryTime + fGameTime);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", fSecondaryTime + fGameTime);
}

int MakeCEIVEnt(int client, int itemdef, int particle = 0)
{
	static Handle hItem;
	if (hItem == INVALID_HANDLE)
	{
		hItem = TF2Items_CreateItem(OVERRIDE_ALL | PRESERVE_ATTRIBUTES | FORCE_GENERATION | OVERRIDE_ITEM_QUALITY | OVERRIDE_ITEM_LEVEL);
		TF2Items_SetClassname(hItem, "tf_wearable_vm");
		TF2Items_SetQuality(hItem, 6);
		TF2Items_SetLevel(hItem, 100);
	}
	TF2Items_SetItemIndex(hItem, itemdef);
	TF2Items_SetNumAttributes(hItem, 1);
	TF2Items_SetAttribute(hItem, 0, 2041, float(particle));
	return TF2Items_GiveNamedItem(client, hItem);
}

bool IsBotInGame()
{
	for (int i = 1; i < MAXPLAYERS; i++)	if (IsValidClient(i) && IsFakeClient(i))
		return true;
	return false;
} 

int GetRealClientCount()
{
	int iCount = 0;
	for (int i = 1; i < MAXPLAYERS; i++)	if (IsValidClient(i) && !IsFakeClient(i) && (GetClientTeam(i) == 2 || GetClientTeam(i) == 3))
	{
		iCount++;
	}
	return iCount;
}
