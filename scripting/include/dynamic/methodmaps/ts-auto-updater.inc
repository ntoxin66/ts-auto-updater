/**
 * =============================================================================================
 * TokenStash Automatic Updater for SourceMod (C)2016 Matthew J Dunn.   All rights reserved.
 * =============================================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
#if defined _dynamic_class_config_
  #endinput
#endif
#define _dynamic_class_config_

methodmap Config < Dynamic
{
	public Config()
	{
		Dynamic myclass = Dynamic(64, 0);
		myclass.SetString("tokenstash_apikey", "", 64);
		myclass.SetString("tokenstash_steamid", "", 32);
		myclass.SetString("tokenstash_serverkey", "", 64);
		myclass.SetString("tokenstash_token", "", 64);
		myclass.SetBool("tokenstash_hibernate", false);
		myclass.SetFloat("tokenstash_requesttimeout", 5.0000000);
		myclass.SetFloat("tokenstash_requestsleep", 0.10000000);
		myclass.SetBool("tokenstash_onstart_async", false);
		myclass.SetString("tokenstash_restartcommand", "_restart", 128);
		return view_as<Config>(myclass);
	}
	
	public bool GetAPIKey(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_apikey");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic methodmap @ Config.GetAPIKey!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetAPIKey(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_apikey");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("tokenstash_apikey", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}

	public bool GetSteamID(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_steamid");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic methodmap @ Config.GetSteamID!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetSteamID(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_steamid");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("tokenstash_steamid", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}

	public bool GetServerKey(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_serverkey");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic methodmap @ Config.GetServerKey!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetServerKey(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_serverkey");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("tokenstash_serverkey", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}

	public bool GetToken(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_token");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic methodmap @ Config.GetToken!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetToken(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_token");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("tokenstash_token", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}
	
	property bool Hibernate
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_hibernate");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic methodmap @ Config.Hibernate!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_hibernate");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("tokenstash_hibernate", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}
	
	property float RequestTimeout
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_requesttimeout");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic methodmap @ Config.RequestTimeout!");
			}
			return this.GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_requesttimeout");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetFloat("tokenstash_requesttimeout", value);
					return;
				}
			}
			this.SetFloatByOffset(offset, value);
		}
	}
	
	property float RequestSleep
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_requestsleep");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic methodmap @ Config.RequestSleep!");
			}
			return this.GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_requestsleep");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetFloat("tokenstash_requestsleep", value);
					return;
				}
			}
			this.SetFloatByOffset(offset, value);
		}
	}
	
	property bool OnStartAsync
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_onstart_async");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic methodmap @ Config.OnStartAsync!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("tokenstash_onstart_async");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("tokenstash_onstart_async", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}
	
	public bool GetRestartCommand(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_restartcommand");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic methodmap @ Config.GetRestartCommand!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}
	
	public void SetRestartCommand(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("tokenstash_restartcommand");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("tokenstash_restartcommand", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}
}