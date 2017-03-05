/**
 * =============================================================================
 * Dynamic for SourceMod (C)2016 Matthew J Dunn.   All rights reserved.
 * =============================================================================
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

#if defined _dynamic_database_included
  #endinput
#endif
#define _dynamic_database_included

typedef DSQLConnectCallback = function void(DynamicDatabase ddb, const char[] error, any data)

methodmap DynamicDatabase < Dynamic
{
	public DynamicDatabase()
	{
		Dynamic ddb = Dynamic(256, 0);
		ddb.SetHandle("Database", null);
		ddb.SetBool("Connected", false);
		ddb.SetString("Name", "", 128);
		ddb.SetInt("Data", 0);
		ddb.SetHandle("Forward", CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Any));
		return view_as<DynamicDatabase>(ddb);
	}
	
	property Database Handle
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Database");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return view_as<Database>(this.GetHandleByOffset(offset));
		}
		public set(Database value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Database");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetHandle("Database", value);
					return;
				}
			}
			this.SetHandleByOffset(offset, value);
		}
	}
	
	property bool Connected
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Connected");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Connected");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("Connected", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}
	
	public bool GetName(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("Name");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetName(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("Name");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("Name", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}
	
	property any Data
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Data");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(any value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Data");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("Data", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}
	
	property Handle Forward
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Forward");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetHandleByOffset(offset);
		}
		public set(Handle value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Forward");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetHandle("Forward", value);
					return;
				}
			}
			this.SetHandleByOffset(offset, value);
		}
	}
	
	public static DynamicDatabase Connect(DSQLConnectCallback callback, const char[] name, any data)
	{
		return _Dynamic_Database_Connect(callback, name, data);
	}
	
	public bool Escape(const char[] string, char[] buffer, int maxlength, int &written)
	{
		return this.Handle.Escape(string, buffer, maxlength, written);
	}
	
	// UPDATE `table` SET `column2`=? WHERE `column2`=?;
	
	public void RunFastQuery(const char[] query, Dynamic parameters, int buffersize=1024)
	{
		_Dynamic_Database_RunFastQuery(this, query, parameters, buffersize);
	}
}

public DynamicDatabase _Dynamic_Database_Connect(DSQLConnectCallback callback, const char[] name, any data)
{
	DynamicDatabase ddb = DynamicDatabase();
	ddb.SetName(name);
	ddb.Data = data;
	AddToForward(ddb.Forward, INVALID_HANDLE, callback);
	Database.Connect(_Dynamic_Database_ConnectCallback, name, ddb);
	return ddb;
}

public void _Dynamic_Database_ConnectCallback(Database db, const char[] error, any data)
{
	DynamicDatabase ddb = view_as<DynamicDatabase>(data);
	ddb.Handle = db;
	if (db == null)
		ddb.Connected = false;
	else
		ddb.Connected = true;
	
	Call_StartForward(ddb.Forward);
	Call_PushCell(ddb);
	Call_PushString(error);
	Call_PushCell(ddb.Data);
	Call_Finish();
	
	delete ddb.Forward;
	ddb.Forward = null;
	
	if (!ddb.Connected)
		ddb.Dispose();
}

stock void _Dynamic_Database_RunFastQuery(DynamicDatabase db, const char[] query, Dynamic parameters, int buffersize=1024)
{
	char[] querybuffer = new char[buffersize];
	char[] valuebuffer = new char[buffersize];
	char[] escapebuffer = new char[buffersize];
	int querybufferposition = 0;
	bool instr1 = false;
	bool instr2 = false;
	int memberindex = 0;
	DynamicOffset memberoffset;
	int valuebufferlength;
	char byte;
	
	// Find each ? which is not a in a string
	for (int i=0; (byte = query[i])!='\0'; i++)
	{
		byte = query[i];
		switch (byte)
		{
			case 39: // '
			{
				if (instr2)
				{
					querybuffer[querybufferposition++] = byte;
					continue;
				}
				
				instr1 = !instr1;
				querybuffer[querybufferposition++] = byte;
			}
			case 34: // "
			{
				if (instr1)
				{
					querybuffer[querybufferposition++] = byte;
					continue;
				}
				
				instr2 = !instr2;
				querybuffer[querybufferposition++] = byte;
			}
			
			case 63: // ?
			{
				if (instr1 || instr2)
				{
					querybuffer[querybufferposition++] = byte;
					continue;
				}
				
				memberoffset = parameters.GetMemberOffsetByIndex(memberindex++);
				switch (parameters.GetMemberType(memberoffset))
				{
					case DynamicType_Int:
					{
						valuebufferlength = IntToString(parameters.GetIntByOffset(memberoffset), valuebuffer, buffersize);
						strcopy(querybuffer[querybufferposition], buffersize-querybufferposition, valuebuffer);
						querybufferposition+=valuebufferlength;
					}
					case DynamicType_Bool:
					{
						if (parameters.GetBoolByOffset(memberoffset))
							querybuffer[querybufferposition++] = 49; // 1
						else
							querybuffer[querybufferposition++] = 48; // 0
					}
					case DynamicType_Float:
					{
						valuebufferlength = FloatToString(parameters.GetFloatByOffset(memberoffset), valuebuffer, buffersize);
						strcopy(querybuffer[querybufferposition], buffersize-querybufferposition, valuebuffer);
						querybufferposition+=valuebufferlength;
					}
					case DynamicType_String:
					{
						querybuffer[querybufferposition++] = 39;
						parameters.GetStringByOffset(memberoffset, valuebuffer, buffersize);
						db.Escape(valuebuffer, escapebuffer, buffersize, valuebufferlength);
						valuebufferlength = strlen(escapebuffer);
						strcopy(querybuffer[querybufferposition], buffersize-querybufferposition, escapebuffer);
						querybufferposition+=valuebufferlength;
						querybuffer[querybufferposition++] = 39;
					}
					case DynamicType_Dynamic:
					{
						
					}
					case DynamicType_Handle:
					{
						
					}
					case DynamicType_Vector:
					{
						
					}
				}
			}
			default:
			{
				querybuffer[querybufferposition++] = byte;
			}
		}
	}
	
	PrintToChatAll("> Query='%s'", query);
	PrintToChatAll("> Output='%s'", querybuffer);
}