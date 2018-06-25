#include <dynamic>
#include <steamworks>
#include <dynamic/methodmaps/ts-auto-updater>

#define VERSION "1.0.0"
static File s_LogFile = null;
static Config s_Config = view_as<Config>(INVALID_DYNAMIC_OBJECT);
static ConVar s_HibernateWhenEmpty = null;
static ConVar s_HostName = null;
static ConVar s_HostIP = null;
static ConVar s_HostPort = null;
static bool s_RenableHibernateWhenEmpty = false;

public Plugin myinfo =
{
	name = "TokenStash Automatic Token Updater",
	author = "Neuro Toxin - Toxic Gaming",
	description = "Updates a servers GSLT token using TokenStash API",
	version = VERSION,
	url = "http://tokenstash.com/"
}

public void OnAllPluginsLoaded()
{
	s_HibernateWhenEmpty = FindConVar("sv_hibernate_when_empty");
	s_HibernateWhenEmpty.AddChangeHook(OnHibernateWhenEmptyChanged);
	
	s_HostName = FindConVar("hostname");
	s_HostIP = FindConVar("hostip");
	s_HostPort = FindConVar("hostport");
	
	s_Config = Config();
	LoadSettings(true);
	
	s_HibernateWhenEmpty.BoolValue = s_Config.Hibernate;
	if (s_HibernateWhenEmpty.BoolValue)
	{
		s_RenableHibernateWhenEmpty = true;
		s_HibernateWhenEmpty.BoolValue = false;
	}
	
	CreateTimer(0.01, OnValidateTokenRequired, s_Config.OnStartAsync);
	CreateTimer(60.0, OnValidateTokenRequired, true, TIMER_REPEAT);
}

stock void Sleep(float seconds)
{
	static float sleependtime;
	sleependtime = GetEngineTime() + seconds;
	while (GetEngineTime() < sleependtime) {}
}

public void OnHibernateWhenEmptyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!s_Config.IsValid)
		return;
		
	if (s_RenableHibernateWhenEmpty)
		return;
	
	if (view_as<bool>(StringToInt(newValue)) == s_Config.Hibernate)
		return;
	
	s_HibernateWhenEmpty.BoolValue = s_Config.Hibernate;
}

public Action OnValidateTokenRequired(Handle timer, any async)
{
	char[] url = "http://api.tokenstash.com/gslt_getservertoken.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (request == null)
	{
		OpenLog();
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V?", VERSION);
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** SteamWorks is unable to create HTTP request.");
		CloseLog();
		return Plugin_Continue;
	}
	
	if (async) LoadSettings();
	char steamid[32]; char apikey[64]; char serverkey[64]; char hostname[64]; char endpoint[32];
	GetConfigValues(steamid, sizeof(steamid), apikey, sizeof(apikey), serverkey, sizeof(serverkey));
	
	s_HostName.GetString(hostname, sizeof(hostname));
	GetServerEndPoint(endpoint, sizeof(endpoint));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "version", "0.09");
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "apikey", apikey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "serverkey", serverkey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "hostname", hostname);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "endpoint", endpoint);
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
	
	OpenLog();
	PrintToServer("*** tokenstash.com: Validating server token via HTTP...");
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V?", VERSION);
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** -> tokenstash_steamid:\t'%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey:\t'%s'", apikey);
	TS_LogMessage("*** -> tokenstash_serverkey:\t'%s'", serverkey);
	SteamWorks_SendHTTPRequest(request);
	
	if (view_as<bool>(async))
		return Plugin_Continue;
	
	// This is a hack for a threaded http request
	float timeouttime = GetEngineTime() + s_Config.RequestTimeout; int responsesize = 0;
	while (GetEngineTime() < timeouttime)
	{
		// we want to do something that takes time here to be friendly on the CPU
		Sleep(s_Config.RequestSleep);
		
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
		s_Config.SetServerKey(token[11]);
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
	if (!s_Config.ReadConfig("cfg\\sourcemod\\tokenstash.cfg"))
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
	s_Config.WriteConfig("cfg\\sourcemod\\tokenstash.cfg");
}

stock bool GetConfigValues(char[] steamid, int steamidlength, char[] apikey, int apikeylength, char[] serverkey, int serverkeylength)
{
	s_Config.GetSteamID(steamid, steamidlength);
	s_Config.GetAPIKey(apikey, apikeylength);
	s_Config.GetServerKey(serverkey, serverkeylength);
}

stock bool GetToken(char[] token, int length)
{
	return s_Config.GetToken(token, length);
}

stock bool WriteToken(char[] token)
{
	s_Config.SetToken(token);
	SaveSettings();
}

public void RestartServer()
{
	PrintToServer("*** tokenstash.com: Server restarting!");
	PrintToChatAll("> [tokenstash.com] \x05Server is restarting...");
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
			
		if (IsFakeClient(client))
			continue;
			
		KickClientEx(client, "Server is restarting...\r\nThis servers GSLT Token has been updated by tokenstash.com.");
	}
	ServerCommand("quit");
}

stock void GetServerEndPoint(char[] buffer, int length)
{
	int longip = s_HostIP.IntValue;
	int pieces[4];
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;

	Format(buffer, length, "%d.%d.%d.%d:%d", pieces[0], pieces[1], pieces[2], pieces[3], s_HostPort.IntValue);
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