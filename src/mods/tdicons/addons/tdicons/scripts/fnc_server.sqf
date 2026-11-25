// 3D icons (server): settings, the side of every unit and the name of every UAV as public variables, and starting /
// stopping the icons on every client, including JIP.

TDI_var_serverRunning = false;
TDI_var_entityCreatedEhId = -1;
TDI_var_entityKilledEhId = -1;
TDI_var_remoteExecId = "";

// ---- settings ----
// Game modes and the module overwrite these later.

TDI_var_showAllSides = false;
TDI_var_showAllSidesOnSpectator = false;
TDI_var_drawUnitsOnSpectator = true;
TDI_var_showUnitNames = true;
TDI_var_hideInvisible = true;
TDI_var_showGroupIcons = false;
TDI_var_hideInvisibleGroupMembers = false;
TDI_var_groupUnitsLimitedDistance = false;

{
    publicVariable _x;
} forEach [
    "TDI_var_showAllSides",
    "TDI_var_showAllSidesOnSpectator",
    "TDI_var_drawUnitsOnSpectator",
    "TDI_var_showUnitNames",
    "TDI_var_hideInvisible",
    "TDI_var_showGroupIcons",
    "TDI_var_hideInvisibleGroupMembers",
    "TDI_var_groupUnitsLimitedDistance"
];

// ---- entities ----
// The clients build the unit names themselves (TDI_fnc_unitName) and read the side of living units from their group;
// the server announces the side and controller a unit had at its init and death (for dead units).

TDI_fnc_entityInitServer = {
    params ["_entity"];

    // the name and group of a new unit can be missing for a moment
    private _timeout = time + 3;
    waitUntil {isNull _entity || {name _entity != ""} || {time > _timeout}};

    if (isNull _entity) exitWith {};

    if !(_entity getVariable ["TDI_var_initDone", false]) then {
        _entity setVariable ["TDI_var_initDone", true];

        // UAVs: the vehicle name (a game mode may have set its own)
        if (!(_entity isKindOf "CAManBase") && {(_entity getVariable ["TDI_var_name", ""]) == ""}) then {
            _entity setVariable ["TDI_var_name", getText (configFile >> "CfgVehicles" >> typeOf _entity >> "displayName"), true];
        };

        _entity setVariable ["TDI_var_side", side group _entity, true];
    };

    if (_entity isKindOf "CAManBase") then {
        [[_entity], {
            if (!isNil "TDI_var_clientInitDone") then {
                _this call TDI_fnc_entityInitClient;
            };
        }] remoteExecCall ["call", 0];
    };
};

// a dead unit keeps the side and the controller (player or AI) of its death
TDI_fnc_entityKilled = {
    params ["_unit"];

    if (!(_unit isKindOf "CAManBase") || {!(_unit getVariable ["TDI_var_initDone", false])}) exitWith {};

    if (!isNull group _unit) then {
        _unit setVariable ["TDI_var_side", side group _unit, true];
    };

    _unit setVariable ["TDI_var_wasPlayer", isPlayer _unit, true];
};

// ---- start / stop ----

TDI_fnc_startTdIconsServer = {
    if (missionNamespace getVariable ["TDI_cba_override", false]) then {
        call TDI_fnc_applyCbaSettings;
    };

    if (TDI_var_serverRunning) exitWith {};

    TDI_var_serverRunning = true;

    // UAVs placed before the start get their name as well
    {
        [_x] spawn TDI_fnc_entityInitServer;
    } forEach (entities [["CAManBase"], [""], true, false] + allUnitsUAV);

    TDI_var_entityCreatedEhId = addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        if (_entity isKindOf "CAManBase" || {unitIsUAV _entity}) then {
            [_entity] spawn TDI_fnc_entityInitServer;
        };
    }];

    TDI_var_entityKilledEhId = addMissionEventHandler ["EntityKilled", {_this call TDI_fnc_entityKilled}];

    TDI_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "TDI_var_clientInitDone"};
        call TDI_fnc_startTdIconsClient;
    }] remoteExecCall ["spawn", 0, true];
};

TDI_fnc_stopTdIconsServer = {
    if (!TDI_var_serverRunning) exitWith {};

    TDI_var_serverRunning = false;

    remoteExecCall ["", TDI_var_remoteExecId];
    TDI_var_remoteExecId = "";

    removeMissionEventHandler ["EntityCreated", TDI_var_entityCreatedEhId];
    removeMissionEventHandler ["EntityKilled", TDI_var_entityKilledEhId];
    TDI_var_entityCreatedEhId = -1;
    TDI_var_entityKilledEhId = -1;

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "TDI_var_clientInitDone"};
        call TDI_fnc_stopTdIconsClient;
    }] remoteExecCall ["spawn", 0];
};

TDI_var_serverInitDone = true;
publicVariable "TDI_var_serverInitDone";
