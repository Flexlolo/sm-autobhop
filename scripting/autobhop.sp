/*
COMPILE OPTIONS
*/

#pragma semicolon 1
#pragma newdecls required

/*
INCLUDES
*/

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <morecolors>
#include <lololib>

/*
PLUGIN INFO
*/

public Plugin myinfo = 
{
	name			= "Autobhop",
	author			= "Flexlolo",
	description		= "Autobhop with extra features",
	version			= "1.0.0",
	url				= "github.com/Flexlolo/"
}

/*
GLOBAL VARIABLES
*/

//#define STAMINA_RESET

#define CHAT_AUTOBHOP 	"\x072f4f4f[\x07ff6347Autobhop\x072f4f4f]:"
#define CHAT_TEXT 		"\x07FFC0CB"

Handle g_hCookie;
int g_iCookie[MAXPLAYERS + 1];

enum
{
	Cookie_Usage,
	Cookie_Fix,

	Cookies_List
}

#define Cookie_Default (1<<Cookie_Usage)

/*
NATIVES AND FORWARDS
*/

public void OnPluginStart()
{
	// Commands
	RegConsoleCmd("sm_autobhop", 		Command_Bhop, 			"Toggle autobhop");
	RegConsoleCmd("sm_bhop", 			Command_Bhop, 			"Toggle autobhop");
	RegConsoleCmd("sm_auto", 			Command_Bhop, 			"Toggle autobhop");

	RegConsoleCmd("sm_autobhopfix", 	Command_BhopFix, 		"Toggle autobhop scroll fix");
	RegConsoleCmd("sm_autofix", 		Command_BhopFix, 		"Toggle autobhop scroll fix");
	RegConsoleCmd("sm_bhopfix", 		Command_BhopFix, 		"Toggle autobhop scroll fix");

	// Events
	#if defined STAMINA_RESET
	HookEvent("player_jump", 		Event_PlayerJump, 		EventHookMode_Pre);
	#endif

	// Cookies
	g_hCookie = RegClientCookie("autobhop", "autobhop", CookieAccess_Protected);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (lolo_IsClientValid(client))
		{
			if (AreClientCookiesCached(client))
			{
				OnClientCookiesCached(client);
			}
		}
	}
}



/*
COOKIES
*/

public void OnClientCookiesCached(int client)
{
	char sCookie[32];
	GetClientCookie(client, g_hCookie, sCookie, sizeof(sCookie));

	if (strlen(sCookie) == 0)
	{
		g_iCookie[client] = Cookie_Default;
	}
	else
	{
		g_iCookie[client] = StringToInt(sCookie);
	}
}

public void Cookie_Set(int client, int cookie)
{
	g_iCookie[client] = cookie;
	
	if (AreClientCookiesCached(client))
	{
		char sCookie[32];
		IntToString(g_iCookie[client], sCookie, sizeof(sCookie));
		SetClientCookie(client, g_hCookie, sCookie);
	}
}



/*
COMMANDS
*/

public Action Command_Bhop(int client, int args)
{
	if (lolo_IsClientValid(client))
	{
		if (!args)
		{
			Cookie_Set(client, g_iCookie[client] ^ 1<<Cookie_Usage);

			if (g_iCookie[client] & 1<<Cookie_Usage)
			{
				CPrintToChat(client, "%s %sEnabled.", CHAT_AUTOBHOP, CHAT_TEXT);
			}
			else
			{
				CPrintToChat(client, "%s %sDisabled.", CHAT_AUTOBHOP, CHAT_TEXT);
			}
		}
	}

	return Plugin_Handled;
}

public Action Command_BhopFix(int client, int args)
{
	if (lolo_IsClientValid(client))
	{
		if (!args)
		{
			Cookie_Set(client, g_iCookie[client] ^ 1<<Cookie_Fix);

			if (g_iCookie[client] & 1<<Cookie_Fix)
			{
				CPrintToChat(client, "%s %sScroll fix enabled.", CHAT_AUTOBHOP, CHAT_TEXT);
			}
			else
			{
				CPrintToChat(client, "%s %sScroll fix disabled.", CHAT_AUTOBHOP, CHAT_TEXT);
			}
		}
	}

	return Plugin_Handled;
}



/*
AUTOBHOP
*/

bool g_bSpam[MAXPLAYERS + 1];

bool g_bJump[MAXPLAYERS + 1];
float g_fJump_Start[MAXPLAYERS + 1];
float g_fJump_End[MAXPLAYERS + 1];
int g_iJump_Count[MAXPLAYERS + 1];

#define SPAM_MIN 3
#define SPAM_MAX_TICKS 10

public void OnClientPutInServer(int client)
{
	g_bSpam[client] = false;

	g_bJump[client] = false;
	g_fJump_Start[client] = 0.0;
	g_fJump_End[client] = 0.0;
	g_iJump_Count[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (lolo_IsClientValid(client))
	{
		if (IsPlayerAlive(client))
		{
			// new jump
			if (buttons & IN_JUMP)
			{
				if (!g_bJump[client])
				{
					float time = GetEngineTime();
					float time_delta = time - g_fJump_Start[client];

					if (time_delta <= float(SPAM_MAX_TICKS) * GetTickInterval())
					{
						g_iJump_Count[client]++;

						if (g_iJump_Count[client] > SPAM_MIN)
						{
							g_bSpam[client] = true;
						}
					}

					g_fJump_Start[client] = time;
				}

				g_bJump[client] = true;
			}
			// release jump
			else
			{
				float time = GetEngineTime();

				if (g_bJump[client])
				{
					g_fJump_End[client] = time;
				}

				g_bJump[client] = false;

				if (g_bSpam[client])
				{
					float time_delta = time - g_fJump_End[client];

					if (time_delta > float(SPAM_MAX_TICKS) * GetTickInterval())
					{
						g_bSpam[client] = false;
					}
				}
			}

			if (g_iCookie[client] & 1<<Cookie_Usage)
			{
				bool spam;

				if (g_iCookie[client] & 1<<Cookie_Fix)
				{
					spam = g_bSpam[client];
				}

				if (buttons & IN_JUMP || spam)
				{
					bool release;

					if (!(GetEntityFlags(client) & FL_ONGROUND))
					{
						if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
						{
							if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
							{
								buttons &= ~IN_JUMP;
								release = true;
							}
						}
					}

					if (!release)
					{
						buttons |= IN_JUMP;
					}
				}
			}
		}
	}
}



/*
STAMINA
*/

#if defined STAMINA_RESET
public Action Event_PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
}
#endif