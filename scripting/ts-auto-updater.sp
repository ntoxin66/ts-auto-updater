#include <dynamic>
#pragma semicolon 1
#pragma newdecls required

static float TS_TIMER_INTERVAL = 300.0;

static Dynamic s_AutoExecConfig = view_as<Dynamic>(INVALID_DYNAMIC_OBJECT);
static File s_LogFile = null;
static bool s_DynamicLoaded = false;
static bool s_Threaded = false;
static bool s_RestartRequired = false;
static float s_NextValidateTime = 0.0;

public Plugin myinfo =
{
	name = "Token Stash Auto Updater",
	author = "Neuro Toxin",
	description = "Updates a servers GSLT token using Token Stash",
	version = "0.0.6",
	url = "http://tokenstash.com/"
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "dynamic"))
	{
		s_DynamicLoaded = false;
	}
}
 
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "dynamic"))
	{
		s_DynamicLoaded = true;
	}
}

public void OnAllPluginsLoaded()
{
	if (!s_DynamicLoaded)
		SetFailState("Plugin dependancy `dynamic.smx` not found!");
		
	OnValidateGameServerLoginToken(null, false);
}

public void OnPluginEnd()
{
	if (s_DynamicLoaded && s_AutoExecConfig.IsValid)
		s_AutoExecConfig.Dispose();
}

public Action OnValidateGameServerLoginToken(Handle timer, any async)
{
	if (!s_DynamicLoaded)
		return Plugin_Stop;
		
	float now = GetEngineTime();
	if (now < s_NextValidateTime)
		return Plugin_Continue;
		
	s_NextValidateTime = (now - 1.0) + TS_TIMER_INTERVAL;
	
	OpenLog();
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.06");
	TS_LogMessage("******************************************************************");
	
	if (LoadGameServerLoginToken())
	{
		s_RestartRequired = false;
		ValidateGameServerLoginToken(async);
		
		if (!async && !s_RestartRequired)
			CreateTimer(TS_TIMER_INTERVAL, OnValidateGameServerLoginToken, true, TIMER_REPEAT);
	}
	
	return Plugin_Continue;
}

public void RestartServerIfRequired()
{
	if (!s_RestartRequired)
		return;
	
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		KickClientEx(client, "Server is restarting...");
	}
	
	PrintToServer("Server restarting!");
	PrintToChatAll("> \x05Server is graciously restarting.");
	ServerCommand("quit");
}

stock bool LoadGameServerLoginToken()
{
	TS_LogMessage("*** LoadGameServerLoginToken...");

	// Global dynamic object to store `autoexec.cfg`
	if (!s_AutoExecConfig.IsValid)
		s_AutoExecConfig = Dynamic();
	
	// Attemp to load `autoexec.cfg` and exit on failure
	if (!s_AutoExecConfig.ReadConfig("cfg/autoexec.cfg", false, 512))
	{
		TS_LogMessage("*** Unable to read 'cfg/autoexec.cfg'!");
		s_AutoExecConfig.Dispose();
		s_AutoExecConfig = INVALID_DYNAMIC_OBJECT;
		return false;
	}
	
	// Get `sv_setsteamaccount` offset
	int offset = s_AutoExecConfig.GetMemberOffset("sv_setsteamaccount");
	
	// Check if `sv_setsteamaccount` offset is valid
	if (offset == INVALID_DYNAMIC_OFFSET)
	{
		// Create offset and exit as failed
		s_AutoExecConfig.SetString("sv_setsteamaccount", "", 256);
	}
	return true;
}

stock void ValidateGameServerLoginToken(bool async=false)
{
	s_Threaded = async;
	TS_LogMessage("*** BeginValidateGameServerLoginToken...");
	
	if (s_Threaded)
		Database.Connect(OnDatabaseConnected, "tokenstash", async);
	else
	{
		char error[1024];
		Database db = SQL_Connect("tokenstash", false, error, sizeof(error));
		OnDatabaseConnected(db, error, async);
	}
}

public void OnDatabaseConnected(Database db, const char[] error, any async)
{
	if (db == null)
	{
		TS_LogMessage("*** -> MySQL Error: %s", error);
		CloseLog();
		return;
	}
		
	char serverip[32]; int serverport;
	GetServerIpAddress(serverip, sizeof(serverip));
	serverport = GetServerPort();
	
	char steamid[32]; char apikey[64];
	s_AutoExecConfig.GetString("tokenstash_steamid", steamid, sizeof(steamid));
	s_AutoExecConfig.GetString("tokenstash_apikey", apikey, sizeof(apikey));
	
	char query[1024];
	Format(query, sizeof(query), "SELECT GSLT_GETSERVERTOKEN(%s, '%s', '%s:%d');", steamid, apikey, serverip, serverport);
	
	for (int i = 0; i < 5; i++)
	{
		steamid[i] = 'X';
		apikey[i] = 'X';
	}
	for (int i = 5; i < 10; i++)
		apikey[i] = 'X';
	
	TS_LogMessage("*** -> tokenstash_steamid:\t'%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey:\t'%s'", apikey);
	
	if (s_Threaded)
		db.Query(OnDatabaseEndQuery, query, async);
	else
	{
		DBResultSet results = SQL_Query(db, query);
		if (results == null)
		{
			char err[1024];
			SQL_GetError(db, err, sizeof(err));
			OnDatabaseEndQuery(db, results, err, async);
		}
		else
			OnDatabaseEndQuery(db, results, "", async);
	}
}

stock void OnDatabaseEndQuery(Database db, DBResultSet results, const char[] error, any async)
{
	if (results == null)
	{
		TS_LogMessage("MySQL Error: %s", error);
	}
	else if (results.FetchRow())
	{
		char token[128];
		results.FetchString(0, token, sizeof(token));
		ValidateToken(token);
	}
	
	CloseLog();
	delete db;
}

stock void ValidateToken(char[] token)
{
	if (StrEqual(token, "INVALID_AUTH"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'INVALID_AUTH'");
		s_RestartRequired = false;
		return;
	}
	
	if (StrEqual(token, "NO_TOKEN"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'NO_TOKEN'");
		s_RestartRequired = false;
		return;
	}	
	
	char configtoken[128];
	s_AutoExecConfig.GetString("sv_setsteamaccount", configtoken, sizeof(configtoken));
	
	if (StrEqual(token, configtoken))
	{
		for (int i = 0; i < 10; i++)
			configtoken[i] = 88;
			
		TS_LogMessage("*** -> sv_setsteamaccount:\t'%s'", configtoken);
		TS_LogMessage("*** CURRENT GSLT TOKEN IS VALID");
		s_RestartRequired = false;
		return;
	}
	
	s_AutoExecConfig.SetString("sv_setsteamaccount", token);
	s_AutoExecConfig.WriteConfig("cfg/autoexec.cfg");

	for (int i = 0; i < 10; i++)
		token[i] = 88;

	TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'", token);
	s_RestartRequired = true;
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
	AppendToLog(buffer);
}

stock void OpenLog()
{
	s_LogFile = OpenFile("addons/sourcemod/logs/tokenstash.txt", "w");
}

stock void AppendToLog(const char[] message)
{
	s_LogFile.WriteLine(message);
}

stock void CloseLog()
{
	TS_LogMessage("******************************************************************");
	s_LogFile.Close();
	
	RestartServerIfRequired();
}