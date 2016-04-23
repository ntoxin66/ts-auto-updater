#include <dynamic>
#pragma semicolon 1
#pragma newdecls required

static Dynamic s_AutoExecConfig = view_as<Dynamic>(INVALID_DYNAMIC_OBJECT);
static int s_SetsteamaccountOffset = INVALID_DYNAMIC_OFFSET;
static ConVar cvar_tokenstash_steamid;
static ConVar cvar_tokenstash_apikey;

public Plugin myinfo =
{
	name = "Token Stash Auto Updater",
	author = "Neuro Toxin",
	description = "Updates a servers GSLT token using Token Stash",
	version = "0.0.1",
	url = "https://csgo.tokenstash.com/"
}

public void OnPluginStart()
{
	cvar_tokenstash_steamid = CreateConVar("tokenstash_steamid", "");
	cvar_tokenstash_apikey = CreateConVar("tokenstash_apikey", "");
}

public void OnMapStart()
{
	// Load sv_setsteamaccount from autoexec.cfg
	LoadGameServerLoginToken();
	
	// Begin creating a new token
	BeginValidateGameServerLoginToken();
}

public void OnPluginEnd()
{
	PrintToServer("--> OnPluginEnd()");
	s_AutoExecConfig.Dispose();
}

stock void LoadGameServerLoginToken()
{
	// Reload config on each map change
	if (s_AutoExecConfig.IsValid)
		s_AutoExecConfig.Dispose();
		
	// Global dynamic object to store `autoexec.cfg`
	s_AutoExecConfig = Dynamic(256);
	
	// Attemp to load `autoexec.cfg` and exit on failure
	if (!s_AutoExecConfig.ReadConfig("cfg/autoexec.cfg", false, 256))
	{
		// Create offset and exit as failed
		s_SetsteamaccountOffset = s_AutoExecConfig.SetString("sv_setsteamaccount", "", 256);
		return;
	}
	
	// Get `sv_setsteamaccount` offset
	s_SetsteamaccountOffset = s_AutoExecConfig.GetMemberOffset("sv_setsteamaccount");
	
	// Check if `sv_setsteamaccount` offset is valid
	if (s_SetsteamaccountOffset == INVALID_DYNAMIC_OFFSET)
	{
		// Create offset and exit as failed
		s_SetsteamaccountOffset = s_AutoExecConfig.SetString("sv_setsteamaccount", "", 256);
	}
}

stock void BeginValidateGameServerLoginToken()
{
	Database.Connect(OnDatabaseConnected, "tokenstash");
}

public void OnDatabaseConnected(Database db, const char[] error, any action)
{
	if (db == null)
	{
		LogError("MySQL Error: %s", error);
		return;
	}
	
	char serverip[32]; int serverport;
	GetServerIpAddress(serverip, sizeof(serverip));
	serverport = GetServerPort();
	
	char steamid[32]; char apikey[64];
	cvar_tokenstash_steamid.GetString(steamid, sizeof(steamid));
	cvar_tokenstash_apikey.GetString(apikey, sizeof(apikey));
	
	char query[1024];
	Format(query, sizeof(query), "SELECT GSLT_GETSERVERTOKEN(%s, '%s', '%s:%d');", steamid, apikey, serverip, serverport);
	db.Query(OnDatabaseEndQuery, query);
}

public void OnDatabaseEndQuery(Database db, DBResultSet results, const char[] error, any action)
{
	if (results == null)
	{
		LogError("MySQL Error: %s", error);
		delete db;
		return;
	}
	
	if (results.FetchRow())
	{
		char token[128];
		results.FetchString(0, token, sizeof(token));
		ValidateToken(token);
	}
	
	delete db;
}

stock void ValidateToken(const char[] token)
{
	if (StrEqual(token, "INVALID_AUTH"))
	{
		LogMessage("[TOKENSTASH] Unable to retrieve token. API MSG: 'INVALID_AUTH'");
		return;
	}
	
	if (StrEqual(token, "NO_TOKEN"))
	{
		LogMessage("[TOKENSTASH] Unable to retrieve token. API MSG: 'NO_TOKEN'");
		return;
	}	
	
	char configtoken[128];
	s_AutoExecConfig.GetStringByOffset(s_SetsteamaccountOffset, configtoken, sizeof(configtoken));
	
	if (StrEqual(token, configtoken))
	{
		LogMessage("[TOKENSTASH] CURRENT TOKEN IS VALID!!!");
		return;
	}
		
	s_AutoExecConfig.SetStringByOffset(s_SetsteamaccountOffset, token);
	s_AutoExecConfig.WriteConfig("cfg/autoexec.cfg");
	LogMessage("[TOKENSTASH] TOKEN UPDATED TO '%s'!!!", token);
	
	ServerCommand("sm_msay -=[ Server is restarting... ]=-");
	PrintToChatAll("CSGO.TOKENSTASH.COM: Server restarting after GSLT token update...");
	
	CreateTimer(10.0, OnRestartServerRequired);
}

public Action OnRestartServerRequired(Handle timer, any data)
{
	ServerCommand("quit");
}

stock void GetServerIpAddress(char[] buffer, int length)
{
	ConVar cvar = FindConVar("hostip");
	int longip = cvar.IntValue;
	delete cvar;
	
	int pieces[4];
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(buffer, length, "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
}

stock int GetServerPort()
{
	ConVar cvar = FindConVar("hostport");
	int port = cvar.IntValue;
	delete cvar;
	return port;
}