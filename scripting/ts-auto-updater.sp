#include <dynamic>
#pragma semicolon 1
#pragma newdecls required

static Dynamic s_AutoExecConfig = view_as<Dynamic>(INVALID_DYNAMIC_OBJECT);
static File s_LogFile = null;
static bool s_DynamicLoaded = false;

public Plugin myinfo =
{
	name = "Token Stash Auto Updater",
	author = "Neuro Toxin",
	description = "Updates a servers GSLT token using Token Stash",
	version = "0.0.4",
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
	
	OpenLog();
	
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.03");
	TS_LogMessage("******************************************************************");
	
	bool restart = false;
	if (LoadGameServerLoginToken())
		restart = ValidateGameServerLoginToken();
	
	TS_LogMessage("******************************************************************");
	CloseLog();
	
	if (restart)
	{
		PrintToServer("Server restarting!");
		ServerCommand("crash");
	}
}

public void OnPluginEnd()
{
	s_AutoExecConfig.Dispose();
}

stock bool LoadGameServerLoginToken()
{
	TS_LogMessage("*** LoadGameServerLoginToken...");

	// Reload config on each map change
	if (s_AutoExecConfig.IsValid)
		s_AutoExecConfig.Dispose();
		
	// Global dynamic object to store `autoexec.cfg`
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

stock bool ValidateGameServerLoginToken()
{
	TS_LogMessage("*** BeginValidateGameServerLoginToken...");
	
	char error[1024];
	Handle db = SQL_Connect("tokenstash", false, error, sizeof(error));
	
	if (db == null)
	{
		LogError("MySQL Error: %s", error);
		return false;
	}
	
	char serverip[32]; int serverport;
	GetServerIpAddress(serverip, sizeof(serverip));
	serverport = GetServerPort();
	
	char steamid[32]; char apikey[64];
	s_AutoExecConfig.GetString("tokenstash_steamid", steamid, sizeof(steamid));
	s_AutoExecConfig.GetString("tokenstash_apikey", apikey, sizeof(apikey));
	
	TS_LogMessage("*** -> tokenstash_steamid: '%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey: '%s'", apikey);
	
	char query[1024];
	Format(query, sizeof(query), "SELECT GSLT_GETSERVERTOKEN(%s, '%s', '%s:%d');", steamid, apikey, serverip, serverport);
	
	DBResultSet results = SQL_Query(db, query);
	if (results == null)
	{
		char db_err[1024];
		SQL_GetError(db, db_err, sizeof(db_err));
		LogError("MySQL Error: %s", db_err);
		delete db;
		return false;
	}
	
	if (results.FetchRow())
	{
		char token[128];
		results.FetchString(0, token, sizeof(token));
		delete db;
		return ValidateToken(token);
	}
	
	delete db;
	return false;
}

stock bool ValidateToken(const char[] token)
{
	if (StrEqual(token, "INVALID_AUTH"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'INVALID_AUTH'");
		return false;
	}
	
	if (StrEqual(token, "NO_TOKEN"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'NO_TOKEN'");
		return false;
	}	
	
	char configtoken[128];
	s_AutoExecConfig.GetString("sv_setsteamaccount", configtoken, sizeof(configtoken));
	TS_LogMessage("*** -> sv_setsteamaccount: '%s'", configtoken);
	
	if (StrEqual(token, configtoken))
	{
		TS_LogMessage("*** CURRENT TOKEN IS VALID");
		return false;
	}
	
	s_AutoExecConfig.SetString("sv_setsteamaccount", token);
	s_AutoExecConfig.WriteConfig("cfg/autoexec.cfg");
	TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'", token);
	return true;
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
	s_LogFile.Close();
}