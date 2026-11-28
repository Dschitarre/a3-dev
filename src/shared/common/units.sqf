// Shared TDM/GunGame units (CMN_): AI pool, taking over a unit as player, spawn helpers.
// Copied into each mission as common\ (cfg\sharedLibs.txt: common|common); compiled by the mode's <TAG>unctions.sqf.

// ---- AI pool and player takeover (server) ----

// [min, range] of the random AI skill per value of the aiSkill param (CMN_PARAM_AI_SKILL in common\config.hpp)
CMN_var_aiSkillLevels = [
    [0.25, 0.2],    // Easy
    [0.5, 0.3],     // Normal
    [0.8, 0.2]      // Hard
];

/*
    [min, range] of the random AI skill: a mode may set its own range (CMN_var_aiSkillMin, CMN_var_aiSkillRange, e.g.
    battleRoyale, offensive), otherwise the level of the aiSkill param applies.
*/
CMN_fnc_aiSkillLevel = {
    if (!isNil "CMN_var_aiSkillMin") exitWith {
        [CMN_var_aiSkillMin, missionNamespace getVariable ["CMN_var_aiSkillRange", 0.3]]
    };

    CMN_var_aiSkillLevels select ("aiSkill" call BIS_fnc_getParamValue)
};

/*
    [display name, first name, last name] for setName: "John Doe" -> ["J. Doe (AI)", "J.", "Doe (AI)"].
    One-word names (players whose unit becomes AI): "Koopa" -> ["Koopa (AI)", "", "Koopa (AI)"]. A unit that already
    has an AI name keeps it.
*/
CMN_fnc_getAiNameArr = {
    params ["_unit"];

    private _nameParts = ((name _unit) splitString " ") - ["(AI)"];

    if (count _nameParts < 2) exitWith {
        private _name = (_nameParts joinString "") + " (AI)";
        [_name, "", _name]
    };

    private _firstNameParts = (_nameParts select 0) splitString "-";
    private _firstName = if (count _firstNameParts > 1) then {
        ((_firstNameParts select 0) select [0, 1]) + ".-" + ((_firstNameParts select 1) select [0, 1]) + "."
    } else {
        ((_nameParts select 0) select [0, 1]) + "."
    };
    private _lastName = ((_nameParts select [1, count _nameParts - 1]) joinString " ") + " (AI)";

    [_firstName + " " + _lastName, _firstName, _lastName]
};

// The name set (CfgWorlds >> GenericNames) of the AI on a map whose people have their own names (CUP names on the CUP
// maps): CUP's Chernarus factions (civilians, CDF, ChDKZ, NAPA) all use CUP_Names_CzechMen; other
// maps keep the engine's name of the unit's class (A3 classes: Greek for the I_soldier_F of BR)
CMN_var_worldNameSets = createHashMapFromArray [
    ["cup_chernarus_a3", "CUP_Names_CzechMen"], ["chernarus", "CUP_Names_CzechMen"], ["chernarus_summer", "CUP_Names_CzechMen"],
    ["chernarus_winter", "CUP_Names_CzechMen"], ["utes", "CUP_Names_CzechMen"], ["takistan", "CUP_Names_TakistaniMen"],
    ["zargabad", "CUP_Names_TakistaniMen"], ["mountains_acr", "CUP_Names_TakistaniMen"], ["sara", "SahraniNames"],
    ["sara_dbe1", "SahraniNames"], ["saralite", "SahraniNames"], ["porto", "SahraniNames"]
];

/*
    On a map of CMN_var_worldNameSets: a random name of its set for a base-game unit (CUP units keep their faction's
    CUP names) that still has the engine's name of its class (its last name is one of the class's set) - never a
    player's name or an AI name given before. Local (setName), so
    before CMN_fnc_initAiUnit builds the "(AI)" name from it for every machine.
*/
CMN_fnc_applyWorldName = {
    params ["_unit"];

    private _set = configFile >> "CfgWorlds" >> "GenericNames" >> (CMN_var_worldNameSets getOrDefault [toLowerANSI worldName, ""]);
    if (!isClass _set || {((typeOf _unit) find "CUP_") == 0}) exitWith {};

    private _own = configFile >> "CfgWorlds" >> "GenericNames" >> getText (configOf _unit >> "genericNames");
    private _parts = (name _unit) splitString " ";
    private _lastName = _parts param [count _parts - 1, ""];
    if (count _parts < 2 || {((configProperties [_own >> "LastNames", "isText _x"]) findIf {getText _x == _lastName}) < 0}) exitWith {};

    private _firstNames = configProperties [_set >> "FirstNames", "isText _x"];
    private _lastNames = configProperties [_set >> "LastNames", "isText _x"];
    if (_firstNames isEqualTo [] || {_lastNames isEqualTo []}) exitWith {};

    private _first = getText selectRandom _firstNames;
    private _last = getText selectRandom _lastNames;
    _unit setName [_first + " " + _last, _first, _last];
};

/*
    AI-only setup of a pool unit, also for a unit a player left: "(AI)" name on every machine (JIP entry tied to the
    unit, a second call replaces it), skill of the aiSkill param, own group.
*/
CMN_fnc_initAiUnit = {
    params ["_unit"];

    ([] call CMN_fnc_aiSkillLevel) params ["_skillMin", "_skillRange"];

    [_unit] call CMN_fnc_applyWorldName;

    _unit setVariable ["CMN_var_aiNameJipId", [_unit, [_unit] call CMN_fnc_getAiNameArr] remoteExecCall ["setName", 0, _unit]];
    _unit setVariable ["CMN_var_aiSkill", _skillMin + random _skillRange];

    // a group local here: at once - a remoteExec can arrive late and throw the unit out of a group the mode has put it
    // into meanwhile
    if (local (group _unit)) then {
        [_unit] joinSilent grpNull;

        // never flee: a lone AI that everyone is hostile to breaks its morale at once, lowers its weapon and runs instead
        // of fighting (setSkill with one value also sets courage)
        (group _unit) allowFleeing 0;
    } else {
        [[_unit], grpNull] remoteExecCall ["join", groupOwner (group _unit)];
    };
};

// units that never were set up as AI get the mean skill of the aiSkill param
CMN_fnc_aiSkill = {
    params ["_unit"];

    ([] call CMN_fnc_aiSkillLevel) params ["_skillMin", "_skillRange"];

    _unit getVariable ["CMN_var_aiSkill", _skillMin + _skillRange / 2]
};

/*
    Turns a unit into a player unit; call from the mode's player takeover. Idempotent, and a no-op for units that
    never were AI: removes the AI name (its JIP entry and on all clients) and the AI skill, then removes leftover units.
*/
CMN_fnc_initPlayerUnit = {
    params ["_unit", ["_playerName", ""]];

    private _jipId = _unit getVariable ["CMN_var_aiNameJipId", ""];

    if (_jipId isNotEqualTo "") then {
        remoteExec ["", _jipId];

        if (_playerName isNotEqualTo "") then {
            [_unit, _playerName] remoteExecCall ["setName", 0];
        };
    };

    _unit setVariable ["CMN_var_aiNameJipId", nil];
    _unit setVariable ["CMN_var_aiSkill", nil];

    call CMN_fnc_deleteOrphanUnits;
};

// Deletes leftover nameless units. Only server-local units (their identity is always known here), never players,
// playable slots or UAV crews (a client could see units whose name has not reached it yet).
CMN_fnc_deleteOrphanUnits = {
    {
        deleteVehicle _x;
    } forEach ((entities [["CAManBase"], [], true, false]) select {
        name _x == "" &&
        {local _x} &&
        {!isPlayer _x} &&
        {!(_x in playableUnits)} &&
        {!unitIsUAV (vehicle _x)}
    });
};

/*
    Parks a unit at [0, 0, 10], disables its simulation and puts it back into its pool.
    _poolVarName: missionNamespace variable of the pool array (written back sorted by the unit variable _idVarName).
    _keepCondition ([_unit] call): false deletes the unit instead. _disableAi: disableAI "ALL" while parking.
    The unit's AI behaviour script (unit variable CMN_var_aiScript, set by the mode) is stopped first, so it cannot
    move the parked unit again.
*/
CMN_fnc_suspendUnit = {
    params ["_unit", "_poolVarName", "_idVarName", ["_keepCondition", {true}], ["_disableAi", false]];

    private _aiScript = _unit getVariable ["CMN_var_aiScript", scriptNull];

    if (!isNull _aiScript) then {
        terminate _aiScript;
    };

    [_unit, _poolVarName, _idVarName, _keepCondition, _disableAi] spawn {
        params ["_unit", "_poolVarName", "_idVarName", "_keepCondition", "_disableAi"];

        waitUntil {
            if (isNull _unit) exitWith {true};

            [_unit, [0, 0, 10]] remoteExecCall ["setPos", -2];
            _unit setPos [0, 0, 10];

            if (_disableAi) then {
                _unit disableAI "ALL";
            };

            if (_unit distance [0, 0, 0] > 100) exitWith {
                sleep 1;
                false
            };

            while {simulationEnabled _unit} do {
                _unit enableSimulationGlobal false;
            };

            if ([_unit] call _keepCondition) then {
                // "-" and BIS_fnc_sortBy return new arrays, so the pool is written back
                private _pool = (missionNamespace getVariable [_poolVarName, []]) - [objNull];
                _pool pushBackUnique _unit;
                missionNamespace setVariable [_poolVarName, [_pool, [_idVarName], {_x getVariable _input0}, "ASCEND"] call BIS_fnc_sortBy];
            } else {
                [_unit] remoteExecCall ["deleteVehicle", _unit];
            };

            true
        };
    };
};

// ---- spawning ----

// true if nothing (roof, tree, ...) is above the position; _posAGL may be 2D or 3D and is not modified
CMN_fnc_isUnderOpenSky = {
    params ["_posAGL"];

    private _posASL = AGLToASL [_posAGL select 0, _posAGL select 1, 0];
    _posASL set [2, (_posASL select 2) + 0.5];

    ([objNull, "VIEW"] checkVisibility [_posASL, _posASL vectorAdd [0, 0, 100]]) != 0
};

// enableSimulationGlobal only works on the server: a client applies it locally at once and lets the server broadcast it
CMN_fnc_setSimulationGlobal = {
    params ["_object", "_state"];

    if (isServer) exitWith {
        _object enableSimulationGlobal _state;
    };

    _object enableSimulation _state;
    [_object, _state] remoteExecCall ["enableSimulationGlobal", 2];
};
