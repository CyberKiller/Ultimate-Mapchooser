#if defined _umc_emp_mapvote_included
    #endinput
#endif
#define _umc_emp_mapvote_included

//SourceMod Malarky
public SharedPlugin:__pl_umc_endvote =
{
    name = "umc-emp-mapvote",
    file = "umc-emp-mapvote.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_umc_emp_mapvote_SetNTVOptional()
{

}