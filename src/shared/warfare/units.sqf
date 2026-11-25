// Unit registry: units / vehicles per side, killed and disconnect handling (server); the reset of a unit whose slot
// changes between player and AI also runs on the client.

// ---- registry ----

SC_fnc_getSidesUnits = {
    params ["_side"];

    missionNamespace getVariable ("SC_var_units" + (str _side))
};

SC_fnc_getSidesUavAiUnits = {
    params ["_side"];

    missionNamespace getVariable ("SC_var_uavAiUnits" + (str _side))
};

// registry arrays are modified in place, so every reference to them stays valid
SC_fnc_updateRegistry = {
    params ["_entity", "_side", "_add"];

    private _varStr = "SC_var_vehicles";
    private _numVarStr = "SC_var_numVehicles";

    if (_entity isKindOf "CAManBase") then {
        if ([_entity] call SC_fnc_isUavAi) then {
            _varStr = "SC_var_uavAiUnits" + (str _side);
            _numVarStr = "SC_var_numUavAiUnits" + (str _side);
        } else {
            _varStr = "SC_var_units" + (str _side);
            _numVarStr = "SC_var_numUnits" + (str _side);
        };
    };

    private _arr = missionNamespace getVariable _varStr;
    [_arr] call SC_fnc_removeNullsInPlace;

    if _add then {
        _arr pushBackUnique _entity;
    } else {
        private _idx = _arr find _entity;

        if (_idx != -1) then {
            _arr deleteAt _idx;
        };
    };

    // the published count of men is the living ones (the registry keeps a dead body until it despawns, which takes
    // minutes on huge maps; SC_fnc_entityKilled updates it as well)
    private _count = if (_entity isKindOf "CAManBase") then {{alive _x} count _arr} else {count _arr};

    if (_count != (missionNamespace getVariable [_numVarStr, -1])) then {
        missionNamespace setVariable [_numVarStr, _count];
        publicVariable _numVarStr;
    };
};

// server: the published number of a side's living men (SC_fnc_updateRegistry)
SC_fnc_updateUnitCount = {
    params ["_side"];

    if !(_side in SC_var_sides) exitWith {};

    private _numVarStr = "SC_var_numUnits" + (str _side);
    private _count = {alive _x} count (missionNamespace getVariable [("SC_var_units" + (str _side)), []]);

    if (_count != (missionNamespace getVariable [_numVarStr, -1])) then {
        missionNamespace setVariable [_numVarStr, _count];
        publicVariable _numVarStr;
    };
};

SC_fnc_registerEntityServer = {
    params ["_entity"];

    private _side = sideUnknown;

    if (_entity isKindOf "CAManBase") then {
        _side = side (group _entity);
        _entity setVariable ["SC_var_side", _side];
    };

    [_entity, _side, true] call SC_fnc_updateRegistry;
};

SC_fnc_deregisterEntityServer = {
    params ["_entity"];

    private _side = _entity getVariable ["SC_var_side", sideUnknown];

    // units are only registered once their side is known
    if ((_entity isKindOf "CAManBase") && {_side == sideUnknown}) exitWith {};

    [_entity, _side, false] call SC_fnc_updateRegistry;
};

SC_fnc_entityKilled = {
    params ["_unit", "_killer", "_instigator", "_useEffects"];

    if (_unit isKindOf "CAManBase") then {
        [_unit, "deaths"] call SC_fnc_addRoundStat;

        // an AI killer in the round statistics (a player's kill and its XP are counted by the killfeed hook,
        // SC\killfeed.sqf); no team kills
        private _killerUnit = [_instigator, effectiveCommander _killer] select (isNull _instigator);

        if (
            !(isNull _killerUnit) && {_killerUnit != _unit} && {!(isPlayer _killerUnit)} && {_killerUnit isKindOf "CAManBase"} &&
            {(_killerUnit getVariable ["SC_var_side", side (group _killerUnit)]) != (_unit getVariable ["SC_var_side", sideUnknown])}
        ) then {
            [_killerUnit, "kills"] call SC_fnc_addRoundStat;
            [_killerUnit, "xp", SC_var_aiRoundStatKillXp] call SC_fnc_addRoundStat;
        };

        private _group = group _unit;

        if ((units _group) isEqualTo [_unit]) then {
            {_group leaveVehicle _x;} forEach (assignedVehicles _group);
        };

        if (!(isPlayer _unit) && {[_unit] call SC_fnc_isUavAi}) then {
            [_unit] call SC_fnc_deregisterEntityServer;
        } else {
            [_unit getVariable ["SC_var_side", sideUnknown]] call SC_fnc_updateUnitCount;
        };
    } else {
        private _vehicle = _unit;

        {
            _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

            {
                private _group = group _x;

                if ((units _group) isEqualTo []) then {
                    _group leaveVehicle _vehicle;
                };
            } forEach [_crewUnit, _assignedUnit];
        } forEach (fullCrew _vehicle);

        private _aiGroup = _vehicle getVariable ["SC_var_aiVehicleGroup", grpNull];

        if !(isNull _aiGroup) then {
            [_aiGroup, _vehicle, "destroyed"] call SC_fnc_aiReleaseVehicle;
        };
    };
};

// ---- slot handover between player and AI ----

// server: a player disconnected; the event handler returns true, so his slot unit stays as AI on the server and is
// turned back into a pool AI. A dead unit keeps its body in the registry until it despawns, its slot comes back
// as AI when it respawns (SC_fnc_entityRespawned).
SC_fnc_handleDisconnect = {
    params ["_unit", "_id", "_uid", "_name"];

    [_uid] call SC_fnc_unlockVehiclesOfPlayer;

    // only the soldier of the player (not a headless client)
    if (!(_unit isKindOf "CAManBase") || {(name _unit) != _name}) exitWith {};

    // the AI loop leaves the unit alone until it is an AI of the pool (it doesn't have an AI name yet)
    _unit setVariable ["SC_var_handover", true];

    [_unit] spawn {
        params ["_unit"];

        private _timeout = time + 30;
        waitUntil {(isNull _unit) || {!(isPlayer _unit) && {local _unit}} || {time > _timeout}};

        if ((isNull _unit) || {isPlayer _unit}) exitWith {
            _unit setVariable ["SC_var_handover", nil];
        };

        [_unit] call SC_fnc_removeFromGroup;

        if (alive _unit) then {
            [_unit] call SC_fnc_deregisterEntityServer;
            [_unit] call SC_fnc_returnUnitToPool;
        };

        _unit setVariable ["SC_var_handover", nil];
    };
};

// heals a unit, ends its AIS unconscious state and moves it out of its vehicle; executed where the unit is local
// (handover of a slot unit: JIP takeover of an active AI on the client, disconnect on the server)
SC_fnc_resetUnitState = {
    params ["_unit"];

    if (_unit getVariable ["ais_unconscious", false]) then {
        _unit setVariable ["ais_unconscious", false, true];
        _unit setVariable ["ais_unconscious_since", -999, true];
        _unit setVariable ["ais_stabilized", false, true];
        _unit setVariable ["ais_hasHelper", objNull, true];
        _unit setBleedingRemaining 0;
        detach _unit;
        _unit stop false;
        _unit enableAI "all";
        _unit playActionNow "agonyStop";
    };

    if !(isNull (objectParent _unit)) then {
        unassignVehicle _unit;
        moveOut _unit;
    };

    if ((damage _unit) > 0) then {
        _unit setDamage 0;
    };
};
