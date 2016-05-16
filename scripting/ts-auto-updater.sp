#include <dynamic>
#pragma semicolon 1
#pragma newdecls required

static Dynamic s_AutoExecConfig = view_as<Dynamic>(INVALID_DYNAMIC_OBJECT);
static int s_SetsteamaccountOffset = INVALID_DYNAMIC_OFFSET;

public Plugin myinfo =
{
	name = "Token Stash Auto Updater",
	author = "Neuro Toxin",
	description = "Updates a servers GSLT token using Token Stash",
	version = "0.0.2",
	url = "https://csgo.tokenstash.com/"
}

public void OnPluginStart()
{
	TS_LogMessage("*****************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.02 ***");
	TS_LogMessage("*****************************************");
	
	// Load sv_setsteamaccount from autoexec.cfg
	LoadGameServerLoginToken();
	
	// Begin creating a new token
	BeginValidateGameServerLoginToken();
	
	TS_LogMessage("*****************************************");
}

public void OnPluginEnd()
{
	s_AutoExecConfig.Dispose();
}

stock void LoadGameServerLoginToken()
{
	TS_LogMessage("*** LoadGameServerLoginToken...");

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
	TS_LogMessage("*** BeginValidateGameServerLoginToken...");
	
	char error[1024];
	Handle db = SQL_Connect("tokenstash", false, error, sizeof(error));
	
	if (db == null)
	{
		LogError("MySQL Error: %s", error);
		return;
	}
	
	TS_OnDatabaseConnected(db);
}

stock void TS_OnDatabaseConnected(Handle db)
{
	char serverip[32]; int serverport;
	GetServerIpAddress(serverip, sizeof(serverip));
	serverport = GetServerPort();
	
	char steamid[32]; char apikey[64];
	s_AutoExecConfig.GetString("tokenstash_steamid", steamid, sizeof(steamid));
	s_AutoExecConfig.GetString("tokenstash_apikey", apikey, sizeof(apikey));
	
	char query[1024];
	Format(query, sizeof(query), "SELECT GSLT_GETSERVERTOKEN(%s, '%s', '%s:%d');", steamid, apikey, serverip, serverport);
	
	DBResultSet results = SQL_Query(db, query);
	TS_OnDatabaseEndQuery(db, results);
}

stock void TS_OnDatabaseEndQuery(Handle db, DBResultSet results)
{
	if (results == null)
	{
		char db_err[1024];
		SQL_GetError(db, db_err, sizeof(db_err));
		LogError("MySQL Error: %s", db_err);
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
		TS_LogMessage("*** Unable to retrieve token. API MSG: 'INVALID_AUTH'");
		return;
	}
	
	if (StrEqual(token, "NO_TOKEN"))
	{
		TS_LogMessage("*** Unable to retrieve token. API MSG: 'NO_TOKEN'");
		return;
	}	
	
	char configtoken[128];
	s_AutoExecConfig.GetStringByOffset(s_SetsteamaccountOffset, configtoken, sizeof(configtoken));
	
	if (StrEqual(token, configtoken))
	{
		TS_LogMessage("*** CURRENT TOKEN IS VALID!!!");
		return;
	}
		
	s_AutoExecConfig.SetStringByOffset(s_SetsteamaccountOffset, token);
	s_AutoExecConfig.WriteConfig("cfg/autoexec.cfg");
	TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'!!!", token);
	
	ServerCommand("sm_msay -=[ Server is restarting... ]=-");
	PrintToChatAll("\x01\x07CSGO.TOKENSTASH.COM: Server restarting after GSLT token update...");
	
	TS_LogMessage("*** Restarting server in 10 seconds");
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

stock void TS_LogMessage(const char[] message, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 2);
	
	PrintToServer(buffer);
	//LogMessage(buffer);
}