#include <dynamic>
#include <steamworks>

static File s_LogFile = null;
static bool s_TimersCreated = false;

public Plugin myinfo =
{
	name = "Token Stash Auto Updater",
	author = "Neuro Toxin",
	description = "Updates a servers GSLT token using TokenStash API",
	version = "0.0.8",
	url = "http://tokenstash.com/"
}

public void OnAllPluginsLoaded()
{
	if (s_TimersCreated)
		return;
	
	CreateTimer(0.01, OnValidateTokenRequired);
	CreateTimer(300.0, OnValidateTokenRequired, _, TIMER_REPEAT);
	s_TimersCreated = true;
}

public Action OnValidateTokenRequired(Handle timer)
{
	char[] url = "http://api.tokenstash.com/gslt_getservertoken.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (request == null)
	{
		OpenLog();
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.08");
		TS_LogMessage("******************************************************************");
		TS_LogMessage("*** SteamWorks is unable to create HTTP request.");
		CloseLog();
		return Plugin_Continue;
	}
	
	char steamid[32]; char apikey[64]; char serverhost[128];
	GetConfigValues(steamid, sizeof(steamid), apikey, sizeof(apikey), serverhost, sizeof(serverhost));
	Format(serverhost, sizeof(serverhost), "%s_%s", steamid, serverhost);
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "version", "0.08");
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "steamid", steamid);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "apikey", apikey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "serverhost", serverhost);
	SteamWorks_SetHTTPCallbacks(request, OnInfoReceived);
	SteamWorks_PrioritizeHTTPRequest(request);
	
	for (int i = 0; i < 5; i++)
	{
		steamid[i] = 'X';
		apikey[i] = 'X';
	}
	for (int i = 5; i < 10; i++)
		apikey[i] = 'X';
	
	OpenLog();
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** TOKENSTASH.COM AUTO UPDATER V0.08");
	TS_LogMessage("******************************************************************");
	TS_LogMessage("*** -> tokenstash_steamid:\t'%s'", steamid);
	TS_LogMessage("*** -> tokenstash_apikey:\t'%s'", apikey);
	TS_LogMessage("*** -> tokenstash_serverhost:\t'%s'", serverhost);
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
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'ERROR'");
		return;
	}
	
	if (StrEqual(token, "INVALID_AUTH"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'INVALID_AUTH'");
		return;
	}
	
	if (StrEqual(token, "NO_TOKEN"))
	{
		TS_LogMessage("*** Unable to retrieve token.");
		TS_LogMessage("*** -> API MSG: 'NO_TOKEN'");
		return;
	}
	
	if (StrContains(token, "TOKEN ") != 0)
	{
		TS_LogMessage("*** ERROR DETECTED!");
		return;
	}
	
	char configtoken[128];
	GetToken(configtoken, sizeof(configtoken));
	
	if (StrEqual(token[6], configtoken))
	{
		for (int i = 0; i < 10; i++)
			configtoken[i] = 88;
			
		TS_LogMessage("*** -> sv_setsteamaccount:\t'%s'", configtoken);
		TS_LogMessage("*** CURRENT GSLT TOKEN IS VALID");
		return;
	}
	
	WriteToken(token[6]);
	
	for (int i = 0; i < 10; i++)
		token[i] = 88;

	TS_LogMessage("*** GSLT TOKEN UPDATED TO '%s'", token[6]);
	RestartServer();
}

stock bool GetConfigValues(char[] steamid, int steamidlength, char[] apikey, int apikeylength, char[] serverhost, int serverhostlength)
{
	Dynamic s_AutoExecConfig = Dynamic();
	s_AutoExecConfig.ReadConfig("cfg/autoexec.cfg", false, 512);
	
	s_AutoExecConfig.GetString("tokenstash_steamid", steamid, steamidlength);
	s_AutoExecConfig.GetString("tokenstash_apikey", apikey, apikeylength);
	
	GetServerIpAddress(serverhost, serverhostlength);
	Format(serverhost, serverhostlength, "%s:%d", serverhost, GetServerPort());
	
	s_AutoExecConfig.Dispose();
}

stock bool GetToken(char[] token, int length)
{
	Dynamic s_AutoExecConfig = Dynamic();
	s_AutoExecConfig.ReadConfig("cfg/autoexec.cfg", false, 512);
	s_AutoExecConfig.GetString("sv_setsteamaccount", token, length);
	s_AutoExecConfig.Dispose();
}

stock bool WriteToken(char[] token)
{
	Dynamic s_AutoExecConfig = Dynamic();
	s_AutoExecConfig.ReadConfig("cfg/autoexec.cfg", false, 512);
	s_AutoExecConfig.SetString("sv_setsteamaccount", token, 128);
	s_AutoExecConfig.WriteConfig("cfg/autoexec.cfg");
	s_AutoExecConfig.Dispose();
}

stock void GetServerIpAddress(char[] buffer, int length)
{
	ConVar cvar = FindConVar("ip");
	cvar.GetString(buffer, length);
	delete cvar;
}

stock int GetServerPort()
{
	ConVar cvar = FindConVar("hostport");
	int port = cvar.IntValue;
	delete cvar;
	return port;
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
	PrintToChatAll("> \x05Server is graciously restarting.");
	ServerCommand("quit");
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
}