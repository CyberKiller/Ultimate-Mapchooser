#pragma semicolon 1

#include <sourcemod>
#include <umc-core>
#include <umc_utils>
#include <umc-emp-mapvote>

#undef REQUIRE_PLUGIN
#include <mapchooser>

public Plugin:myinfo =
{
    name = "UMC Empires Map Vote",
    author = "CyberKiller",
    description = "Starts a map vote after commander vote ends or the end of a map. Based off umc-votecommand by Steell and EmpChooser by Joe 'Coffeeburrito' Wakefield",
    version = "Beta 0.5",
    url = ""
};

        ////----CONVARS-----/////
new Handle:cvar_filename             = INVALID_HANDLE;
new Handle:cvar_scramble             = INVALID_HANDLE;
new Handle:cvar_vote_time            = INVALID_HANDLE;
new Handle:cvar_strict_noms          = INVALID_HANDLE;
new Handle:cvar_runoff               = INVALID_HANDLE;
new Handle:cvar_runoff_sound         = INVALID_HANDLE;
new Handle:cvar_runoff_max           = INVALID_HANDLE;
new Handle:cvar_vote_allowduplicates = INVALID_HANDLE;
new Handle:cvar_vote_threshold       = INVALID_HANDLE;
new Handle:cvar_fail_action          = INVALID_HANDLE;
new Handle:cvar_runoff_fail_action   = INVALID_HANDLE;
new Handle:cvar_vote_mem             = INVALID_HANDLE;
new Handle:cvar_vote_type            = INVALID_HANDLE;
new Handle:cvar_vote_startsound      = INVALID_HANDLE;
new Handle:cvar_vote_endsound        = INVALID_HANDLE;
new Handle:cvar_vote_catmem          = INVALID_HANDLE;
new Handle:cvar_flags                = INVALID_HANDLE;
new Handle:cvar_vote_delay           = INVALID_HANDLE;
new Handle:cvar_vote_endvote         = INVALID_HANDLE;

//non emp-mapvote cvars
new Handle:cvar_mp_chattime          = INVALID_HANDLE;
        ////----/CONVARS-----/////

//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues. Used to store the previously played maps.
new Handle:vote_mem_arr    = INVALID_HANDLE;
new Handle:vote_catmem_arr = INVALID_HANDLE;

//Sounds to be played at the start and end of votes.
new String:vote_start_sound[PLATFORM_MAX_PATH], String:vote_end_sound[PLATFORM_MAX_PATH],
    String:runoff_sound[PLATFORM_MAX_PATH];
    
//Can we start a vote (is the mapcycle valid?)
new bool:can_vote;

//Has the map vote already occurred?
new bool:g_bVoted;

//Has the vote already been triggered?
new bool:g_bVoteTriggered = false; 

//Has the vote been disabled by setnextmap?
new bool:g_bMapVoteDisabled = false;

new bool:g_bEndVotesEnabled;

//timer used to delay votes
new Handle:voteDelayTimer = INVALID_HANDLE;

new Float:g_oldChatTimeValue = 0.0;

//Is mp_chattime change blocking enabled?
new bool:g_bChatTimeBlocking;

const MP_CHATTIME_MAX_VALUE = 120;

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//

//Called before the plugin loads, sets up our natives.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    RegPluginLibrary("mapchooser");

    CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
    CreateNative("EndOfMapVoteEnabled", Native_EmpMapVoteEnabled);
    
    RegPluginLibrary("umc-emp-mapvote");
    
    return APLRes_Success;
}

//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_flags = CreateConVar(
        "sm_umc_emp_mapvote_adminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );

    cvar_fail_action = CreateConVar(
        "sm_umc_emp_mapvote_failaction",
        "1",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing (not recommended for end of map votes),\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_emp_mapvote_runoff_failaction",
        "1",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing (not recommended for end of map votes),\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_max = CreateConVar(
        "sm_umc_emp_mapvote_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );

    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_emp_mapvote_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_emp_mapvote_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_emp_mapvote_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff = CreateConVar(
        "sm_umc_emp_mapvote_runoffs",
        "2",
        "Specifies a maximum number of runoff votes to run for a vote.\n 0 = unlimited (using 0 is not recommended for end of map votes).",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_emp_mapvote_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound."
    );
    
    cvar_vote_catmem = CreateConVar(
        "sm_umc_emp_mapvote_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from votes.",
        0, true, 0.0
    );
    
    cvar_vote_startsound = CreateConVar(
        "sm_umc_emp_mapvote_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of a vote."
    );
    
    cvar_vote_endsound = CreateConVar(
        "sm_umc_emp_mapvote_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of a vote."
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_emp_mapvote_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_vote_type = CreateConVar(
        "sm_umc_emp_mapvote_type",
        "0",
        "Controls vote type:\n 0 - Maps,\n 1 - Groups,\n 2 - Tiered Vote (vote for a group, then vote for a map from the group).",
        0, true, 0.0, true, 2.0
    );

    cvar_vote_time = CreateConVar(
        "sm_umc_emp_mapvote_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );

    cvar_filename = CreateConVar(
        "sm_umc_emp_mapvote_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );

    cvar_vote_mem = CreateConVar(
        "sm_umc_emp_mapvote_mapexclude",
        "4",
        "Specifies how many past maps to exclude from votes. 1 = Current Map Only",
        0, true, 0.0
    );

    cvar_scramble = CreateConVar(
        "sm_umc_emp_mapvote_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_delay = CreateConVar(
        "sm_umc_emp_mapvote_delay",
        "10",
        "Specifies how long after the match start or match end to wait before starting the vote.",
        _, true, 1.0
    );
    
    cvar_vote_endvote = CreateConVar(
        "sm_umc_emp_mapvote_endvote",
        "1",
        "Do an end of map vote instead of after the comm vote.",
        0, true, 0.0, true, 1.0
    );
    
    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-emp-mapvote");
    
    //Admin commmand to re-enable map vote.
    RegAdminCmd(
        "sm_umc_emp_enablemapvote",
        Command_Enable_Vote,
        ADMFLAG_CHANGEMAP,
        "Re-enables empires map vote after it has been disabled by the next map being set."
    );
    
    //Get convar
    cvar_mp_chattime = FindConVar("mp_chattime"); 
    
    //Hook events
    HookEvent("commander_vote_time", Event_CommanderVoteTime); //fired when comm vote begins
    HookEvent("game_end", Event_GameEnd); //Fired when round ends
    
    //Hook cvar change
    HookConVarChange(cvar_mp_chattime, Handle_mp_chattimeChange);
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
}

//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//

//Called after all config files were executed.
public OnConfigsExecuted()
{
    DEBUG_MESSAGE("Executing EmpMapVote OnConfigsExecuted")
    
    g_bEndVotesEnabled = GetConVarBool(cvar_vote_endvote); //Are end votes enabled?
    
    if (cvar_mp_chattime == INVALID_HANDLE)
    {
        LogUMCMessage("ERROR: Could not set mp_chattime, cvar handle is invalid.");
        LogError("Could not set mp_chattime, cvar handle is invalid.");
    }
    
    //Get the original value of mp_chattime
    g_oldChatTimeValue = GetConVarFloat(cvar_mp_chattime);
    
    //Set mp_chattime for end votes and enable mp_chattime change blocking
    if (g_bEndVotesEnabled)
    {
        SetMaxMpChatTime();
        g_bChatTimeBlocking = true;
    }
    else
        g_bChatTimeBlocking = false;

    CheckChatTime(); //Warn if mp_chattime is wrong
    
    can_vote = ReloadMapcycle();
    
    SetupVoteSounds();
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    
    decl String:groupName[MAP_LENGTH];
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (can_vote && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_vote_mem);
    new catmem = GetConVarInt(cvar_vote_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem);
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (can_vote)
        RemovePreviousMapsFromCycle();
    
    //Reset bools so new map vote can be started on map change
    g_bVoted = false; 
    g_bVoteTriggered = false;
    g_bMapVoteDisabled = false;
}

public OnMapEnd()
{
ResetMpChatTime();
}

//Called each second of the comm vote timer?
public Event_CommanderVoteTime(Handle:event, const String:name[], bool:dontBroadcast)
{
    DEBUG_MESSAGE("commander_vote_time event fired.")
    
    if (g_bEndVotesEnabled)
        return; //Exit function if end votes are enabled.
        
    new time = GetEventInt(event, "time");
    if (time == 0 && !g_bVoted && !g_bVoteTriggered && !g_bMapVoteDisabled)
    {
        CreateEmpVoteDelay();
        g_bVoteTriggered = true; //stop event from being caught multiple times...
    }
}

//Called at round end
public Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    DEBUG_MESSAGE("game_end event fired.")
    
    //If not already voted and not already vote triggered and end votes are enabled
    if(!g_bVoted && !g_bVoteTriggered && g_bEndVotesEnabled && !g_bMapVoteDisabled)
    {
        CreateEmpVoteDelay();
        g_bVoteTriggered = true; //stop event from being caught multiple times...
    }
}

//************************************************************************************************//
//                                            NATIVES                                             //
//************************************************************************************************//

// native HasEndOfMapVoteFinished();
public Native_CheckVoteDone(Handle:plugin, numParams)
{
    return g_bVoted;
}

// native EndOfMapVoteEnabled();
public Native_EmpMapVoteEnabled(Handle:plugin, numParams)
{
    return true; //It's going to be enabled as long as the plugin is loaded!
}
//************************************************************************************************//
//                                              SETUP                                             //
//************************************************************************************************//

//Parses the mapcycle file and returns a KV handle representing the mapcycle.
Handle:GetMapcycle()
{
    //Grab the file name from the cvar.
    decl String:filename[PLATFORM_MAX_PATH];
    GetConVarString(cvar_filename, filename, sizeof(filename));
    
    //Get the kv handle from the file.
    new Handle:result = GetKvFromFile(filename, "umc_rotation");
    
    //Log an error and return empty handle if...
    //    ...the mapcycle file failed to parse.
    if (result == INVALID_HANDLE)
    {
        LogError("SETUP: Mapcycle failed to load!");
        return INVALID_HANDLE;
    }
    
    //Success!
    return result;
}


//Reloads the mapcycle. Returns true on success, false on failure.
bool:ReloadMapcycle()
{
    if (umc_mapcycle != INVALID_HANDLE)
    {
        CloseHandle(umc_mapcycle);
        umc_mapcycle = INVALID_HANDLE;
    }
    if (map_kv != INVALID_HANDLE)
    {
        CloseHandle(map_kv);
        map_kv = INVALID_HANDLE;
    }
    umc_mapcycle = GetMapcycle();
    
    return umc_mapcycle != INVALID_HANDLE;
}


//
RemovePreviousMapsFromCycle()
{
    map_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(umc_mapcycle, map_kv);
    FilterMapcycleFromArrays(map_kv, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_vote_catmem));
}


//Sets up the vote sounds.
SetupVoteSounds()
{
    //Grab sound files from cvars.
    GetConVarString(cvar_vote_startsound, vote_start_sound, sizeof(vote_start_sound));
    GetConVarString(cvar_vote_endsound, vote_end_sound, sizeof(vote_end_sound));
    GetConVarString(cvar_runoff_sound, runoff_sound, sizeof(runoff_sound));
    
    //Gotta cache 'em all!
    CacheSound(vote_start_sound);
    CacheSound(vote_end_sound);
    CacheSound(runoff_sound);
}

//************************************************************************************************//
//                                            Functions                                           //
//************************************************************************************************//

//Initiates the map vote. Also called by MakeRetryVoteTimer() (that's why it's a public function)
public StartEmpMapVote()
{
    g_bVoted = true; //map vote has happened
    
    if (!can_vote)
    {
        PrintToChatAll("\x03[UMC]\x04 ERROR: \x01 Mapcycle is invalid, cannot start a vote.");
        LogUMCMessage("ERROR: Mapcycle is invalid, cannot start a vote.");
        DoMapChangeFailSafe();
        return;
    }
    //Log a message
    LogUMCMessage("Starting a map vote.");
    
    //Log an error and retry vote if...
    //    ...another vote is currently running for some reason.
    if (!UMC_IsNewVoteAllowed("core")) 
    {
        LogUMCMessage("There is a vote already in progress, cannot start a new vote.");
        PrintToChatAll("\x03[UMC]\x01 Map voting was blocked by another vote!");
        PrintToChatAll("\x03[UMC]\x01 Retrying map vote after vote in progress finishes...");
        MakeRetryVoteTimer(StartEmpMapVote);
        return;
    }
    
    //Warn if mp_chattime is wrong
    CheckChatTime();
    
    //Whether or not to change map now or at end of map based on if end vote is enabled
    new UMC_ChangeMapTime:changetime;
    if (g_bEndVotesEnabled)
        changetime = ChangeMapTime_Now;
    else
        changetime = ChangeMapTime_MapEnd;
    
    new String:flags[64];
    GetConVarString(cvar_flags, flags, sizeof(flags));
    
    new clients[MAXPLAYERS+1];
    new numClients;
    GetClientsWithFlags(flags, clients, sizeof(clients), numClients);

#if UMC_DEBUG
    for (new i = 0; i < numClients; i++)
        DEBUG_MESSAGE("Sending EmpMapVote to client: %i", clients[i])
#endif
    
    //Start the UMC vote.
    new bool:result = UMC_StartVote(
        "core",
        map_kv,                                                     //Mapcycle
        umc_mapcycle,                                               //Full mapcycle
        UMC_VoteType:GetConVarInt(cvar_vote_type),                  //Vote Type (map, group, tiered)
        GetConVarInt(cvar_vote_time),                               //Vote duration
        GetConVarBool(cvar_scramble),                               //Scramble
        vote_start_sound,                                           //Start Sound
        vote_end_sound,                                             //End Sound
        false,                                                      //Extend option
        0.0,                                                        //How long to extend the timelimit by,
        0,                                                          //How much to extend the roundlimit by,
        0,                                                          //How much to extend the fraglimit by,
        false,                                                      //Don't Change option
        GetConVarFloat(cvar_vote_threshold),                        //Threshold
        UMC_ChangeMapTime:changetime,                               //Success Action (when to change the map)
        UMC_VoteFailAction:GetConVarInt(cvar_fail_action),          //Fail Action (runoff / nothing)
        GetConVarInt(cvar_runoff),                                  //Max Runoffs
        GetConVarInt(cvar_runoff_max),                              //Max maps in the runoff
        UMC_RunoffFailAction:GetConVarInt(cvar_runoff_fail_action), //Runoff Fail Action
        runoff_sound,                                               //Runoff Sound
        GetConVarBool(cvar_strict_noms),                            //Nomination Strictness
        GetConVarBool(cvar_vote_allowduplicates),                   //Ignore Duplicates
        clients,
        numClients
    );
    
    if (!result)
    {
        LogUMCMessage("Could not start UMC vote.");
        DoMapChangeFailSafe();
    }
}

//Checks if the map could get changed before the end of map vote has time to complete
CheckChatTime()
{
    if (cvar_mp_chattime == INVALID_HANDLE)
    {
        LogUMCMessage("ERROR: Could not get the value of mp_chattime, cvar handle is invalid.");
        return; //The other checks can't be done if cvar_mp_chattime is invalid.
    }
    
    //Warn if mp_chattime is still set to MP_CHATTIME_MAX_VALUE when endvotes aren't enabled.
    if (GetConVarInt(cvar_mp_chattime) == MP_CHATTIME_MAX_VALUE && !g_bEndVotesEnabled)
    {
        LogUMCMessage("ERROR: Failed to reset mp_chattime after end of map votes were disabled.");
        PrintToChatAll("\x03[UMC]\x04 ERROR: \x01Failed to reset mp_chattime after end of map votes were disabled. Please notify an admin!");
        return; //Don't do the other checks if end votes aren't enabled
    }
    else if (!g_bEndVotesEnabled)
        return; //Don't do the other checks if end votes aren't enabled
    
    //Warn if mp_chattime was not set for end of map votes.
    if (GetConVarInt(cvar_mp_chattime) != MP_CHATTIME_MAX_VALUE)
    {
        LogUMCMessage("ERROR: Failed to set the value of mp_chattime. The map could change before the end of map voting finishes.");
        PrintToChatAll("\x03[UMC]\x04 WARNING: \x01Failed to set the value of mp_chattime. The map could change before the end of map voting finishes.");
    }
    //Check if the round could possibly end before the vote had time to finish.
    else
    {
        new voteDelay = GetConVarInt(cvar_vote_delay); //Time the vote will be delayed for.
        new voteTime = GetConVarInt(cvar_vote_time) + 8; //Time a vote can last for (add 8 seconds for map change/run-off vote timer).
        new bool:runoffsEnabled = GetConVarBool(cvar_fail_action); //Are runoff votes enabled?
        new maxRunoffVotes = GetConVarInt(cvar_runoff); //Max number of run off votes.
        new roundEndTime = GetConVarInt(cvar_mp_chattime) * 2 - 2; //Calculate round end time (subtract 2 seconds to be on the safe side).

        //Warn if runoff votes are enabled with unlimited runoffs.
        if (runoffsEnabled && GetConVarInt(cvar_runoff) == 0)
        {
            LogUMCMessage("WARNING: Having an unlimited maximum runoff votes is not recommended for end of map votes. Please change sm_umc_emp_mapvote_runoffs in the cfg file.");
            PrintToChatAll("\x03[UMC]\x04 WARNING: \x01Having an unlimited max runoff votes is not recommended for end of map votes. Please change sm_umc_emp_mapvote_runoffs.");
        }
        //Check if the total amount of time a vote could last for is greater than the round end time. (Two conditions for whether or not runoff votes are enabled.)
        else if (!runoffsEnabled && voteDelay + voteTime >= roundEndTime || runoffsEnabled && voteDelay + voteTime * (maxRunoffVotes + 1) >= roundEndTime)
        {
            LogUMCMessage("WARNING: Server cvar mp_chattime is not set high enough. The map could change before the end of map voting finishes.");
            PrintToChatAll("\x03[UMC]\x04 WARNING: \x01Server cvar mp_chattime is not set high enough. The map could change before the end of map voting finishes.");
        }
    }
}

ResetMpChatTime()
{
    //Reset mp_chattime because if end votes are disabled the server won't always change mp_chattime back when it execs it's configs....
    DEBUG_MESSAGE("Resetting mp_chattime to: %f", g_oldChatTimeValue)
    g_bChatTimeBlocking = false; //stop mp_chattime from getting reset back to 120
    SetConVarFloat(cvar_mp_chattime, g_oldChatTimeValue);
    DEBUG_MESSAGE("mp_chattime is now: %f", GetConVarFloat(cvar_mp_chattime))
}

SetMaxMpChatTime()
{
    SetConVarInt(cvar_mp_chattime, MP_CHATTIME_MAX_VALUE);
}

public Action:EmpVoteDelay(Handle:timer)
{
    StartEmpMapVote();
}

CreateEmpVoteDelay()
{
    new Float:delay = GetConVarFloat(cvar_vote_delay);
    LogUMCMessage("Map vote will appear in %i seconds.", RoundToNearest(delay));
    PrintToChatAll("\x03[UMC]\x01 Map vote will appear in %i seconds.", RoundToNearest(delay));
    voteDelayTimer = CreateTimer(delay, EmpVoteDelay);
}

DoMapChangeFailSafe()
{
    LogUMCMessage("WARNING: Map Voting failure. Initiating random map fail-safe.");
    PrintToChatAll("\x03[UMC]\x04 MAP VOTING FAILURE! \x01Initiating random map fail-safe.");
    if (g_bEndVotesEnabled)
    {
        DoRandomNextMap(ChangeMapTime_Now);
    }
    else
    {
        DoRandomNextMap(ChangeMapTime_MapEnd);
    }
}

DoRandomNextMap(UMC_ChangeMapTime:changeTime) 
{    
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    if (UMC_GetRandomMap(map_kv, umc_mapcycle, INVALID_GROUP, nextMap, sizeof(nextMap), nextGroup,
                         sizeof(nextGroup), false, true))
    {
        DEBUG_MESSAGE("Random map: %s %s", nextMap, nextGroup)
        UMC_SetNextMap(map_kv, nextMap, nextGroup, changeTime);
    }
    else
    {
        LogUMCMessage("Failed to find a suitable random map.");
    }
}

//************************************************************************************************//
//                                          CVAR CHANGES                                          //
//************************************************************************************************//

//Called when mp_chattime changes
public Handle_mp_chattimeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    //don't do anything if chattime blocking is not enabled or if end votes are not enabled or if map vote disable by manual map change or if setting to MP_CHATTIME_MAX_VALUE
    if (g_bChatTimeBlocking && g_bEndVotesEnabled && !g_bMapVoteDisabled && StringToInt(newValue) != MP_CHATTIME_MAX_VALUE)
    {
        LogUMCMessage("WARNING: Server cvar mp_chattime was changed while end of map voting is enabled. Resetting mp_chattime to %i.", MP_CHATTIME_MAX_VALUE);
        PrintToChatAll("\x03[UMC]\x04 WARNING: \x01Server cvar mp_chattime was changed while end of map voting is enabled. Resetting mp_chattime to %i.", MP_CHATTIME_MAX_VALUE);
        SetConVarInt(cvar_mp_chattime, MP_CHATTIME_MAX_VALUE);
    }
}

//************************************************************************************************//
//                                            COMMANDS                                            //
//************************************************************************************************//

//Called when the command to pick a random nextmap is called
public Action:Command_Enable_Vote(client, args)
{
    new String:word[6];
    if (g_bEndVotesEnabled)
        word = "end";
    else 
        word = "start";
    if (!g_bMapVoteDisabled)
        ReplyToCommand(client, "\x03[UMC]\x01 The %s of map vote is already enabled.", word);
    else
    {
        SetMaxMpChatTime();
        g_bMapVoteDisabled = false;
        ReplyToCommand(client, "\x03[UMC]\x01 Re-enabling %s of map vote.", word);
    }
    return Plugin_Handled;
}

//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//

//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    can_vote = ReloadMapcycle();
    if (can_vote)
        RemovePreviousMapsFromCycle();
}

//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    ResetMpChatTime();
    if (voteDelayTimer != INVALID_HANDLE)
    {
        KillTimer(voteDelayTimer);
        voteDelayTimer = INVALID_HANDLE;
    }
    g_bMapVoteDisabled = true;
    
    new String:word[6];
    if (g_bEndVotesEnabled)
        word = "end";
    else 
        word = "start";
    PrintToChatAll("\x03[UMC]\x01 Next map was set to: %s. Disabling %s of map vote.", map, word);
}

//Called when UMC requests that the mapcycle is printed to the console.
public UMC_DisplayMapCycle(client, bool:filtered)
{
    PrintToConsole(client, "Module: Empires Map Vote");
    if (filtered)
    {
        new Handle:filteredMapcycle = UMC_FilterMapcycle(
            map_kv, umc_mapcycle, false, true
        );
        PrintKvToConsole(filteredMapcycle, client);
        CloseHandle(filteredMapcycle);
    }
    else
    {
        PrintKvToConsole(umc_mapcycle, client);
    }
}

//Called when a vote has failed.
public UMC_OnVoteFailed()
{
    //only do fail-safe if end of map votes are enabled and vote has happened otherwise it could be triggered by other map votes.
    if (g_bVoted && g_bEndVotesEnabled && g_bVoteTriggered && !g_bMapVoteDisabled) 
        DoMapChangeFailSafe();
}
