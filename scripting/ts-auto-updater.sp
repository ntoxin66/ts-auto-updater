#include <dynamic>
#include <steamworks>

static File s_LogFile = null;
static Dynamic s_Settings = INVALID_DYNAMIC_OBJECT;
static ConVar s_HibernateWhenEmpty = null;
static bool s_RenableHibernateWhenEmpty = false;

public Plugin myinfo =
{
	name = "TokenStash Automatic Token Updater",
	author = "Neuro Toxin - Toxic Gaming",
	description = "Updates a servers GSLT token using TokenStash API",
	version = "0.0.10",
	url = "http://tokenstash.com/"
}

public void OnAllPluginsLoaded()
{
	s_HibernateWhenEmpty = FindConVar("sv_hibernate_when_empty");
	s_HibernateWhenEmpty.AddChangeHook(OnHibernateWhenEmptyChanged);
	
	s_Settings = Dynamic();
	LoadSettings(true);
	
	s_HibernateWhenEmpty.BoolValue = s_Settings.GetBool("tokenstash_hibernate");
	if (s_HibernateWhenEmpty.BoolValue)
	{
		s_RenableHibernateWhenEmpty = true;
		s_HibernateWhenEmpty.BoolValue = false;
	}
	
	CreateTimer(0.01, OnValidateTokenRequired, false);
	CreateTimer(300.0, OnValidateTokenRequired, true, TIMER_REPEAT);
}

stock void Sleep(float seconds)
{
	Database db; char err[1];
	float timeouttime = GetEngineTime() + seconds;
	while (GetEngineTime() < timeouttime)
	{
		// we want to do something that takes time here to be friendly on the CPU
		db = SQL_Connect("default", false, err, sizeof(err));
		if (db != null)
			delete db;
	}
}

public void OnHibernateWhenEmptyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!s_Settings.IsValid)
		return;
		
	if (s_RenableHibernateWhenEmpty)
		return;
	
	bool hibernate = s_Settings.GetBool("tokenstash_hibernate", false);
	if (view_as<bool>(StringToInt(newValue)) == hibernate)
		return;
	
	s_HibernateWhenEmpty.BoolValue = hibernate;
}

public Action OnValidateTokenRequired(Handle timer, any async)
{
	char[] url = "http://api.tokenstash.com/gslt_getservertoken.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (request == null)
	{
		OpenLog();
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.10");
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** SteamWorks is unable to create HTTP request.");
		CloseLog();
		return Plugin_Continue;
	}
	
	if (async) LoadSettings();
	char steamid[32]; char apikey[64]; char serverkey[64];
	GetConfigValues(steamid, sizeof(steamid), apikey, sizeof(apikey), serverkey, sizeof(serverkey));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "version", "0.09");
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "apikey", apikey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "serverkey", serverkey);
	if (view_as<bool>(async))
		SteamWorks_SetHTTPCallbacks(request, OnInfoReceived);
	SteamWorks_PrioritizeHTTPRequest(request);
	
	for (int i = 0; i < 5; i++)
	{
		steamid[i] = 'X';
		apikey[i] = 'X';
	}
	for (int i = 0; i < 10; i++)
		apikey[i] = 'X';
	for (int i = 0; i < 10; i++)
		serverkey[i] = 'X';
	
	OpenLog();
	PrintToServer("*** tokenstash.com: Validating server token via HTTP...");
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.10");
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** -> tokenstash_steamid:\t'%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey:\t'%s'", apikey);
	TS_LogMessage("*** -> tokenstash_serverkey:\t'%s'", serverkey);
	SteamWorks_SendHTTPRequest(request);
	
	if (view_as<bool>(async))
		return Plugin_Continue;
	
	Database db; char err[1];
	float timeouttime = GetEngineTime() + 8.0; int responsesize = 0;
	while (GetEngineTime() < timeouttime)
	{
		// we want to do something that takes time here to be friendly on the CPU
		db = SQL_Connect("default", false, err, sizeof(err));
		if (db != null)
			delete db;
		
		SteamWorks_GetHTTPResponseBodySize(request, responsesize);
		if (responsesize > 0)
		{
			OnInfoReceived(request, false, true, k_EHTTPStatusCode200OK)
			return Plugin_Continue;
		}
	}
	
	OnInfoReceived(request, true, false, k_EHTTPStatusCode5xxUnknown);
	return Plugin_Continue;
}

public int OnInfoReceived(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, APIWebResponse);
	else
	{
		CloseLog();
	}
	delete request;
	return;
}

public APIWebResponse(char[] token)
{
	ValidateToken(token);
	CloseLog();
}

stock void ValidateToken(char[] token)
{
	if (StrEqual(token, "ERROR"))
	{
		PrintToServer("*** tokenstash.com: Unable to retrieve token.");
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'ERROR'");
	}
	
	else if (StrEqual(token, "INVALID_AUTH"))
	{
		PrintToServer("*** tokenstash.com: Unable to retrieve token.");
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'INVALID_AUTH'");
	}
	
	else if (StrEqual(token, "NO_TOKEN"))
	{
		PrintToServer("*** tokenstash.com: Unable to retrieve token.");
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'NO_TOKEN'");
	}
	
	else if (StrContains(token, "SERVER_TOKEN ") == 0)
	{
		char configtoken[128];
		GetToken(configtoken, sizeof(configtoken));
		
		if (StrEqual(token[13], configtoken))
		{
			for (int i = 0; i < 10; i++)
				configtoken[i] = 88;
			
			PrintToServer("*** tokenstash.com: Current token is valid.");
			TS_LogMessage("*** -> tokenstash_token:\t'%s'", configtoken);
			TS_LogMessage("*** CURRENT GSLT TOKEN IS VALID");
		}
		else
		{		
			WriteToken(token[13]);
			
			for (int i = 0; i < 10; i++)
				token[i] = 88;

			PrintToServer("*** tokenstash.com: Token updated to '%s'.", token[13]);
			TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'", token[13]);
			RestartServer();
		}
	}
	
	else if (StrContains(token, "SERVER_KEY ") == 0)
	{
		s_Settings.SetString("tokenstash_serverkey", token[11]);
		SaveSettings();
		
		PrintToServer("*** tokenstash.com: Server token key updated to '%s'.", token[11]);
		TS_LogMessage("*** SERVER KEY UPDATED TO '%s'", token[11]);
		RestartServer();
	}
	
	else
	{
		TS_LogMessage("*** ERROR DETECTED!");
	}
	
	if (s_RenableHibernateWhenEmpty)
	{
		s_HibernateWhenEmpty.BoolValue = true;
		s_RenableHibernateWhenEmpty = false;
	}
}

stock bool LoadSettings(bool settoken=false)
{
	s_Settings.Reset();
	if (!s_Settings.ReadConfig("cfg\\sourcemod\\tokenstash.cfg"))
	{
		LogError("Unable to read config `cfg\\sourcemod\\tokenstash.cfg`");
		return false;
	}
	
	if (settoken)
	{
		char token[64];
		GetToken(token, sizeof(token));
		ServerCommand("sv_setsteamaccount \"%s\"", token);
	}
	return true;
}

stock bool SaveSettings()
{
	s_Settings.WriteConfig("cfg\\sourcemod\\tokenstash.cfg");
}

stock bool GetConfigValues(char[] steamid, int steamidlength, char[] apikey, int apikeylength, char[] serverkey, int serverkeylength)
{
	s_Settings.GetString("tokenstash_steamid", steamid, steamidlength);
	s_Settings.GetString("tokenstash_apikey", apikey, apikeylength);
	s_Settings.GetString("tokenstash_serverkey", serverkey, serverkeylength);
}

stock bool GetToken(char[] token, int length)
{
	return s_Settings.GetString("tokenstash_token", token, length);
}

stock bool WriteToken(char[] token)
{
	s_Settings.SetString("tokenstash_token", token, 128);
	SaveSettings();
}

public void RestartServer()
{
	PrintToServer("*** tokenstash.com: Server restarting!");
	PrintToChatAll("> [tokenstash.com] \x05Server is restarting.");
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		KickClientEx(client, "Server is restarting...\r\nThis servers GSLT Token has been updated by tokenstash.com.");
	}
	ServerCommand("quit");
}

stock void TS_LogMessage(const char[] message, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 2);
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
}