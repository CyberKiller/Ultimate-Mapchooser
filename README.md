# What is this?:
This is a version of ultimate map chooser that has been modified to work properly with empires mod.
Changes are:
 * umc-emp-mapvote: a new module for umc that enables start or end of match map votes for empires mod.
 * umc-randomcycle: will now set the next map at the end of rounds correctly on empires mod.
 * umc-core: fixed instant map change votes putting the server in limbo on empires mod (this affects all umc modules)

Based off git commit: https://github.com/Steell/Ultimate-Mapchooser/commit/d22c65bb8b12c5e338ff80c0cebb151d75ca375d
Built using sourcemod-1.6.0-hg4310-windows.
    

## How to install:
Remove all old umc plugins from sourcemod\addons and sourcemod\addons\disabled.
If you are moving from a very old version of umc then I recommend backing up the old config files for it then reconfiguring from scratch. (I recommend backing up your old config files anyway)
Extract the zip to your empires folder and install and configure umc as normal as detailed here: https://code.google.com/p/sourcemod-ultimate-mapchooser/wiki/HelpFAQ?tm=6
Do not use this with any other version of umc or it's plugins.

The empires game directory must be called 'empires' for instant map changes on vote success to work correctly.
Failure to have the correct game directory name will result in the server getting stuck in limbo on end of map votes map changes!
In other words it has to be like this: 

    "..\empires\maps\emp_canyon.bsp".
    
NOT like this:

    "..\EmpMainServer\maps\emp_canyon.bsp".

## umc-emp-mapvote documentation:
Edit the config file for it in: \cfg\sourcemod\umc-emp-mapvote.cfg
I recommend enabling the umc-randomcycle plugin which will act as a fail-safe and set the next map just before the map changes if a vote has not happened.
There is also the command !umc_emp_enablemapvote to re-enable the map vote if it has been disabled by !setnextmap.

## Credits:
 * Steell + other umc contributors: for making umc in the first place.
 * CyberKiller: for the changes listed at the top of this readme.

# Ultimate Mapchooser

> <b>ul·ti·mate</b>  _/ˈəltəmit/_  
> _Noun_: The best achievable or imaginable of its kind: "the ultimate in decorative luxury".  
> _Adjective_: Being or happening at the end of a process; final: "their ultimate aim was to force his resignation"

Basically, this is the last mapchooser you will ever need.

## About:
Ultimate Mapchooser allows for increased control over map selection. This includes:
  * Random selection of the next map.
  * Which maps are added to votes
  * Which maps are available for nominations
You can control how the randomization works by dividing your map rotation into groups, and controlling the weights of each group or each individual map, specify a minimum or maximum number of players allowed on the server for the map to be available, specify how many maps from a group are allowed in a vote, etc.
 
In order for this to work, I had to completely bypass RTV, Mapchooser, and Nominations, which means I rewrote each's functionality into this plugin. You can control each of these features via Ultimate Mapchooser's cvars.


## Features:
Any and all features can be turned on and off.

### Map Exclusion
  Maps can have a defined minimum and maximum amount of players, as well as a minimum and maximum time of day they can be played. If the server does not presently fit the criteria defined by the map, then the map will not be selected.


### Random Selection of the Next Map
  Similar to the functionality built into randomcycle.smx, but random maps are selected at the END of the map, rather than the beginning, and maps are checked for exclusion before being selected (see Map Exclusion).


### End of Map Vote
  Similar to the functionality built into mapchooser.smx, but you are given more control over how these votes are populated. Maps can be divided up into groups which are then distributed in the vote how you see fit. Want to make sure some maps always appear in the vote? Totally possible.


### Rock The Vote
  Similar to the functionality built into rockthevote.smx, but has the same customization features as Ultimate Mapchooser's End of Map vote.


### Nominations
  Similar to the functionality built into nominations.smx. Map Exclusion does not apply to the nominations menu; nominated maps are checked for exclusion at the time of a vote.


### Player Count Checking
  If the map being currently played has defined player limits, and the limits are broken by players joining/leaving the server, Ultimate Mapchooser can perform actions to change the map to one that does match the number of players.


### Vote Warnings
  You can define various times before an end of map vote starts where notifications to the server are displayed, warning them of an impending vote.


### Vote Sounds
  You can define sounds that are played at the start and end of votes.


### Vote Slot Blocking
  You have the option to block the first three slots in a vote, in order to prevent accidental votes.


### Runoff Votes
  If a vote ends and the winning option doesn't have a majority, then another vote will be held between the winners (until there is a majority).
