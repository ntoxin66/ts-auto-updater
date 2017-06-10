#include <dynamic>
#include <steamworks>

static File s_LogFile = null;
static Dynamic s_Settings = INVALID_DYNAMIC_OBJECT;

public Plugin myinfo =
{
	name = "TokenStash Automatic Token Updater",
	author = "Neuro Toxin - Toxic Gaming",
	description = "Updates a servers GSLT token using TokenStash API",
	version = "0.0.9",
	url = "http://tokenstash.com/"
}

public void OnAllPluginsLoaded()
{
	s_Settings = Dynamic();
	LoadSettings(true);
	
	if (s_Settings.GetBool("tokenstash_hibernate", false))
		ServerCommand("sv_hibernate_when_empty 0");
	else
		ServerCommand("sv_hibernate_when_empty 1");
	
	CreateTimer(0.01, OnValidateTokenRequired);
	CreateTimer(300.0, OnValidateTokenRequired, _, TIMER_REPEAT);
}

public Action OnValidateTokenRequired(Handle timer)
{
	char[] url = "http://api.tokenstash.com/gslt_getservertoken.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (request == null)
	{
		OpenLog();
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.09");
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** SteamWorks is unable to create HTTP request.");
		CloseLog();
		return Plugin_Continue;
	}
	
	char steamid[32]; char apikey[64]; char serverkey[64];
	LoadSettings();
	GetConfigValues(steamid, sizeof(steamid), apikey, sizeof(apikey), serverkey, sizeof(serverkey));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "version", "0.09");
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "apikey", apikey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "serverkey", serverkey);
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
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.09");
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** -> tokenstash_steamid:\t'%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey:\t'%s'", apikey);
	TS_LogMessage("*** -> tokenstash_serverkey:\t'%s'", serverkey);
	SteamWorks_SendHTTPRequest(request);
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
			return;
		}
		
		WriteToken(token[13]);
		
		for (int i = 0; i < 10; i++)
			token[i] = 88;

		PrintToServer("*** tokenstash.com: Token updated to '%s'.", token[13]);
		TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'", token[13]);
		RestartServer();
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
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		KickClientEx(client, "Server is restarting...");
	}
	
	PrintToServer("Server restarting!");
	PrintToChatAll("> \x05Server is restarting.");
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