// Compiles all Battle Royale function files once per machine. Runs at preInit (Description.ext, class BR_bootstrap), so
// every function exists before any init script or remoteExec message; the call in the init files is then a no-op
// fallback. The files only define functions and constants.
if (!isNil "BR_var_functionsCompiled") exitWith {};

{
    call compile preprocessFileLineNumbers _x;
} forEach [
    "common\units.sqf",
    "common\world.sqf",
    "common\view.sqf",
    "ui\ui.sqf",
    "BR\init.sqf",
    "BR\maps\maps.sqf",
    "BR\teams.sqf",
    "BR\groups.sqf",
    "BR\aiFill.sqf",
    "BR\ai.sqf",
    "BR\aiLoot.sqf",
    "BR\aiGear.sqf",
    "BR\aiCombat.sqf",
    "BR\aiVehicles.sqf",
    "BR\downed.sqf",
    "BR\match.sqf",
    "BR\flight.sqf",
    "BR\zone.sqf",
    "BR\landmass.sqf",
    "BR\loot\loot.sqf",
    "BR\airdrops.sqf",
    "BR\vehicles.sqf",
    "BR\uniforms.sqf",
    "BR\items.sqf",
    "BR\hud.sqf",
    "BR\mapDraw.sqf",
    "BR\spectator.sqf",
    "BR\results.sqf"
];

BR_var_functionsCompiled = true;
