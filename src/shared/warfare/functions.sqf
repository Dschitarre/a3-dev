// Compiles all SC files once per machine (function definitions and constant tables only).
// Called by CfgFunctions preInit (SC_fnc_compileFunctions) and again by initServer.sqf / initPlayerLocal.sqf (no-op).
isNil {
    if (isNil "SC_var_functionsCompiled") then {
        {
            call compile preprocessFileLineNumbers _x;
        } forEach [
            "ui\ui.sqf",
            "ui\vehicleSymbols.sqf",
            "common\world.sqf",
            "vaOverride\vaOverride.sqf",
            "vaOverride\limits.sqf",
            "vaOverride\selection.sqf",
            "vaOverride\templates.sqf",
            "SC\init\common.sqf",
            "SC\helpers.sqf",
            "SC\init\server.sqf",
            "SC\init\client.sqf",
            "SC\mapSetup.sqf",
            "SC\baseActions.sqf",
            "SC\infoBoards.sqf",
            "SC\sectors.sqf",
            "SC\playZone.sqf",
            "SC\units.sqf",
            "SC\cleanup.sqf",
            "SC\groups.sqf",
            "SC\groupMenu.sqf",
            "SC\player\respawn.sqf",
            "SC\player\spectator.sqf",
            "SC\player\systems.sqf",
            "SC\vehicles\spawning.sqf",
            "SC\vehicles\handling.sqf",
            "SC\vehicles\spawnVehicles.sqf",
            "SC\vehicles\service.sqf",
            "SC\vehicles\harbors.sqf",
            "SC\airdrops.sqf",
            "SC\statistics.sqf",
            "SC\progressStorage.sqf",
            "SC\killfeed.sqf",
            "SC\roundEnd.sqf",
            "SC\teamplayXp.sqf",
            "SC\ai\ai.sqf",
            "SC\ai\suspend.sqf",
            "SC\ai\objectives.sqf",
            "SC\ai\squads.sqf",
            "SC\ai\fireTeams.sqf",
            "SC\ai\vehicles.sqf",
            "SC\ai\boats.sqf",
            "SC\ai\delivery.sqf",
            "SC\ai\spawnAI.sqf",
            "SC\rankSystem\ranks.sqf",
            "SC\rankSystem\perks.sqf",
            "SC\rankSystem\items.sqf",
            "SC\rankSystem\loadout.sqf",
            "SC\rankSystem\arsenal.sqf",
            "SC\rankSystem\sideTransfer.sqf",
            "SC\rankSystem\storedLoadouts.sqf",
            "SC\hud\hud.sqf",
            "SC\hud\spawnVehicleStatus.sqf",
            "SC\hud\icons.sqf",
            "SC\hud\settings.sqf"
        ];

        SC_var_functionsCompiled = true;
    };
};
