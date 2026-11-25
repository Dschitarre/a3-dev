// Compiles all TDM function files once per machine. Runs at preInit (Description.ext, class DM_bootstrap), so every
// function exists before any init script or remoteExec message; the call in the init files is then a no-op fallback.
// The files only define functions and constants.
if (!isNil "DM_var_functionsCompiled") exitWith {};

{
    call compile preprocessFileLineNumbers _x;
} forEach [
    "common\units.sqf",
    "common\world.sqf",
    "common\view.sqf",
    "common\vote.sqf",
    "ui\ui.sqf",
    "vaOverride\vaOverride.sqf",
    "vaOverride\limits.sqf",
    "vaOverride\selection.sqf",
    "vaOverride\templates.sqf",
    "TDM\init.sqf",
    "TDM\rounds.sqf",
    "TDM\score.sqf",
    "TDM\hud.sqf",
    "TDM\maps\maps.sqf",
    "TDM\zone.sqf",
    "TDM\ai.sqf",
    "TDM\spawning.sqf",
    "TDM\vehicles.sqf",
    "TDM\loadout.sqf"
];

DM_var_functionsCompiled = true;
