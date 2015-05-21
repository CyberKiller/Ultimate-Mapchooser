What is this?:
    This is a version of ultimate map chooser that has been modified to work properly with empires mod.
    Changes are:
    umc-emp-mapvote: a new module for umc that enables start or end of match map votes for empires mod.
    umc-randomcycle: will now set the next map at the end of rounds correctly on empires mod.
    umc-core: fixed instant map change votes putting the server in limbo on empires mod (this affects all umc modules)
    
    Based off git commit: https://github.com/Steell/Ultimate-Mapchooser/commit/d22c65bb8b12c5e338ff80c0cebb151d75ca375d
    Built using sourcemod-1.6.0-hg4310-windows.
    

How to install:
    Remove all old umc plugins from sourcemod\addons and sourcemod\addons\disabled.
    If you are moving from a very old version of umc then I recommend backing up the old config files for it then reconfiguring from scratch. (I recommend backing up your old config files anyway)
    Extract the zip to your empires folder and install and configure umc as normal as detailed here: https://code.google.com/p/sourcemod-ultimate-mapchooser/wiki/HelpFAQ?tm=6
    Do not use this with any other version of umc or it's plugins.
    
    The empires game directory must be called 'empires' for instant map changes on vote success to work correctly.
    Failure to have the correct game directory name will result in the server getting stuck in limbo on end of map votes map changes!
    In other words it has to be like this: "..\empires\maps\emp_canyon.bsp".
    NOT like this: "..\EmpMainServer\maps\emp_canyon.bsp".

umc-emp-mapvote documentation:
    Edit the config file for it in: \cfg\sourcemod\umc-emp-mapvote.cfg
    I recommend enabling the umc-randomcycle plugin which will act as a fail-safe and set the next map just before the map changes if a vote has not happened.
    There is also the command !umc_emp_enablemapvote to re-enable the map vote if it has been disabled by !setnextmap.

Credits:
    Steell + other umc contributors: for making umc in the first place.
    CyberKiller: for the changes listed at the top of this readme.