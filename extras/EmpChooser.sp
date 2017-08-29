#include <sourcemod>
#include <umc-core>
//#include <nextmap>

#pragma semicolon 1

new bool:g_bVoted;

public Plugin:myinfo =
{
    name = "EmpChooser",
    author = "Joe 'Coffeeburrito' Wakefield",
    description = "Starts a nextmap vote shortly after match start",
    version = SOURCEMOD_VERSION,
    url = "http://www.empiresmod.com/"
};

new Handle:g_Cvar_EmpStartTime = INVALID_HANDLE;

public OnPluginStart()
{
    //LoadTranslations("common.phrases");
    
    g_Cvar_EmpStartTime = CreateConVar("sm_mapvote_empstart", "20", "Specifies how long after the match start to run the vote.", _, true, 1.0);
    g_bVoted = false;
    HookEvent("commander_vote_time", Event_CommanderVoteTime);
}

public OnConfigsExecuted()
{
g_bVoted = false;
}

public Event_CommanderVoteTime(Handle:event, const String:name[], bool:dontBroadcast)
{
    new time = GetEventInt(event, "time");
    if (time == 0 && !g_bVoted)
    {
        new Float:delay = GetConVarFloat(g_Cvar_EmpStartTime);
        CreateTimer(delay, StartVote);
    }
}

public Action:StartVote(Handle:timer)
{
    if (!UMC_IsVoteInProgress())
    {
        g_bVoted = true;
        ServerCommand("sm_umc_mapvote 2");
    }
}