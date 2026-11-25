// Compiles all GunGame function files once per machine. Runs at preInit (Description.ext, class GG_bootstrap), so every
// function exists before any init script or remoteExec message; the call in the init files is then a no-op fallback.
// The files only define functions and constants.
if (!isNil "GG_var_functionsCompiled") exitWith {};

{
    call compile preprocessFileLineNumbers _x;
} forEach [
    "common\units.sqf",
    "common\world.sqf",
    "common\view.sqf",
    "common\vote.sqf",
    "ui\ui.sqf",
    "GG\init.sqf",
    "GG\weapons.sqf",
    "GG\teams.sqf",
    "GG\rounds.sqf",
    "GG\hud.sqf",
    "GG\ai.sqf",
    "GG\spawning.sqf",
    "GG\maps\maps.sqf"
];

GG_var_functionsCompiled = true;
