// Vehicle handling: locking, moving AI out, damage, UAV control, safe deletion and pose reset (both).

// ---- vehicles ----

// Locking (client actions): players of the vehicle's (owner) side or its spawner may lock an unlocked vehicle; only the
// player who locked it (its owner) may unlock it. The server unlocks the vehicles of a player who disconnects.
// UIDs are compared as strings: as (float) numbers, SteamIDs lose their last digits and collide.
SC_fnc_canLockVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) <= 1) &&
    {(_vehicle getVariable ["SC_var_lockerUid", ""]) == ""} &&
    {
        ((side (group player)) == (_vehicle getVariable ["SC_var_vehicleSide", sideUnknown])) ||
        {(getPlayerUID player) == (_vehicle getVariable ["SC_var_spawnerUid", ""])}
    }
};

SC_fnc_lockVehicle = {
    params ["_vehicle"];

    [_vehicle, 3] remoteExecCall ["lock", _vehicle];
    _vehicle setVariable ["SC_var_lockerUid", (getPlayerUID player), true];

    {
        _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

        if ((alive _assignedUnit) && {(_assignedUnit isNotEqualTo _crewUnit)}) then {
            (group _assignedUnit) leaveVehicle _vehicle;
        };
    } forEach (fullCrew _vehicle);
};

SC_fnc_canUnlockVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) > 1) &&
    {(getPlayerUID player) == (_vehicle getVariable ["SC_var_lockerUid", ""])}
};

// client action and server (vehicles of a player who disconnected)
SC_fnc_unlockVehicle = {
    params ["_vehicle"];

    [_vehicle, 1] remoteExecCall ["lock", _vehicle];
    _vehicle setVariable ["SC_var_lockerUid", "", true];
};

// server: unlocks the vehicles locked by a player who disconnected
SC_fnc_unlockVehiclesOfPlayer = {
    params ["_uid"];

    if (_uid == "") exitWith {};

    {
        if ((_x getVariable ["SC_var_lockerUid", ""]) == _uid) then {
            [_x] call SC_fnc_unlockVehicle;
        };
    } forEach (SC_var_vehicles select {!(isNull _x)});
};

SC_fnc_canMoveAiOutOfVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) > 1) &&
    {(getPlayerUID player) == (_vehicle getVariable ["SC_var_lockerUid", ""])} &&
    {
        (
            (crew _vehicle) findIf {
                (alive _x) &&
                {!(isPlayer _x)} &&
                {_x isKindOf "CAManBase"} &&
                {!(unitIsUAV _x)}
            }
        ) != -1
    }
};

SC_fnc_moveAiOutOfVehicle = {
    params ["_vehicle"];

    private _unitsToSetOut = (crew _vehicle) select {(alive _x) && {!(isPlayer _x)} && {_x isKindOf "CAManBase"} && {!(unitIsUAV _x)}};
    doGetOut _unitsToSetOut;

    {
        (group _x) leaveVehicle _vehicle;
    } forEach _unitsToSetOut;

    {
        _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

        if ((alive _assignedUnit) && {(_assignedUnit isNotEqualTo _crewUnit)}) then {
            (group _assignedUnit) leaveVehicle _vehicle;
        };
    } forEach (fullCrew _vehicle);
};

// ---- lock key (J instead of scroll actions) ----

SC_var_vehicleLockKey = 36;          // DIK_J (vanilla: tasks overview; only swallowed when it locks / unlocks)
SC_var_vehicleLockDistance = 5;      // m outside the vehicle's bounding sphere

// the vehicle the key acts on: the lockable one the player sits in, else the lockable one he looks at within reach
// (SC_var_lockable: set by SC_fnc_initSpawnedVehicle on every machine)
SC_fnc_vehicleLockTarget = {
    private _vehicle = objectParent player;

    if (isNull _vehicle) then {
        private _target = cursorObject;

        if (
            !(isNull _target) &&
            {((player distance _target) - ((boundingBoxReal _target) select 2)) <= SC_var_vehicleLockDistance}
        ) then {
            _vehicle = _target;
        };
    };

    [objNull, _vehicle] select (!(isNull _vehicle) && {_vehicle getVariable ["SC_var_lockable", false]})
};

// client (KeyDown of display 46): J locks / unlocks, Shift + J orders the AI out of the locked vehicle; a short text
// confirms it
SC_fnc_keyVehicleLock = {
    params ["", "_key", "_shift", "_ctrl", "_alt"];

    if ((_key != SC_var_vehicleLockKey) || {_ctrl} || {_alt} || {!(alive player)} || {player getVariable ["AIS_unconscious", false]}) exitWith {false};

    private _vehicle = call SC_fnc_vehicleLockTarget;

    if (isNull _vehicle) exitWith {false};

    private _text = switch true do {
        case _shift: {
            if ([_vehicle] call SC_fnc_canMoveAiOutOfVehicle) then {
                [_vehicle] call SC_fnc_moveAiOutOfVehicle;
                "AI ordered to leave the vehicle"
            } else {
                ""
            }
        };
        case ([_vehicle] call SC_fnc_canLockVehicle): {
            [_vehicle] call SC_fnc_lockVehicle;
            "Vehicle locked"
        };
        case ([_vehicle] call SC_fnc_canUnlockVehicle): {
            [_vehicle] call SC_fnc_unlockVehicle;
            "Vehicle unlocked"
        };
        default {""};
    };

    if (_text == "") exitWith {false};

    [
        ("SC_vehicleLock" call BIS_fnc_rscLayer),
        format ["<t align='center'>%1</t>", _text],
        [safeZoneX + safeZoneW / 2, safeZoneY + 0.7 * safeZoneH, 0.5, 0.5],
        1.5
    ] call UI_fnc_showTextBlocks;

    true
};

SC_var_launcherAmmos = createHashMapFromArray ((getArray (SC_var_worldGroupConfig >> "launcherAmmos")) apply {[_x, true]});

SC_fnc_handleVehicleDamage = {
    params ["_unit", "", "_newDamage", "", "_projectile", "_hitPartIndex", "", "", "_directHit"];

    if ((_directHit && {_projectile == ""}) || {SC_var_launcherAmmos getOrDefault [_projectile, false]}) then {
        private _oldDamage = _unit getHitIndex _hitPartIndex;
        _oldDamage + ((_newDamage - _oldDamage) * SC_var_vehicleDamageFactor)
    }
};

SC_fnc_addHandleDamageToVehicle = {
    params ["_vehicle"];

    _vehicle addEventHandler ["HandleDamage", {params ["_vehicle"]; if (local _vehicle) then {_this call SC_fnc_handleVehicleDamage}}];
};

SC_fnc_uavControl = {
    params ["_unit", "_mode", ["_altMode", ""]];
    private _ret = objNull;

    private _UAVControl = UAVControl _unit;
    private _UAVControls = [_UAVControl select [0, 2]];

    if ((count _UAVControl) == 4) then {
        _UAVControls pushBack (_UAVControl select [2, 2]);
    };

    private _pos = (_UAVControls apply {_x select 1}) find _mode;

    if (_pos != -1) then {
        _ret = (_UAVControls select _pos) select 0;
    } else {
        if (_altMode != "") then {
            _pos = (_UAVControls apply {_x select 1}) find _altMode;

            if (_pos != -1) then {
                _ret = (_UAVControls select _pos) select 0;
            };
        };
    };

    _ret
};

SC_fnc_uavControlUnits = {
    params ["_vehicle", ["_onlyControlling", false]];

    private _UAVControl = UAVControl _vehicle;
    private _UAVControls = [_UAVControl select [0, 2]];

    if ((count _UAVControl) == 4) then {
        _UAVControls pushBack (_UAVControl select [2, 2]);
    };

    if _onlyControlling then {
        (_UAVControls select {(_x select 1) != ""}) apply {_x select 0}
    } else {
        (_UAVControls select {!(isNull (_x select 0))}) apply {_x select 0}
    }
};

// client: the UI "Action" handler (inGameUISetEventHandler is not stackable, so it also runs the one of AIS, which
// blocks the heal action on unconscious units): equips the AI crew of a UAV and watches toolkit repairs (teamplay
// XP); true blocks the engine action
SC_fnc_onUiAction = {
    params ["_target", "", "", "_action"];

    if (unitIsUAV _target) then {
        {
            _x linkItem "itemMap";
            _x linkItem "itemGPS";
            _x linkItem "H_PilotHelmetFighter_B";
        } forEach (crew _target);
    };

    if (_action == "RepairVehicle") then {
        [_target] spawn SC_fnc_watchRepair;
    };

    _this call AIS_System_fnc_overrideHealAction
};

SC_fnc_safelyDeleteVehicle = {
    params ["_vehicle"];

    private _startTime = time;
    waitUntil {((crew _vehicle) isEqualTo []) || {(time - _startTime) > 1}};

    private _posVehicle = getPos _vehicle;

    {
        _x setPos _posVehicle;
    } forEach (crew _vehicle);

    // remaining crew that belongs to the vehicle (e.g. UAV AI) is deleted with it; players and playable units are kept
    {
        if (!(isPlayer _x) && {!(_x in playableUnits)}) then {
            _vehicle deleteVehicleCrew _x;
        };
    } forEach (crew _vehicle);

    if isServer then {
        [_vehicle] call SC_fnc_deregisterEntityServer;
    } else {
        [_vehicle] remoteExecCall ["SC_fnc_deregisterEntityServer", 2];
        sleep 0.5;
    };

    deleteVehicle _vehicle;
};

// executed (scheduled) on the vehicle owner to put a flipped helicopter back on its wheels
SC_fnc_resetVehiclePose = {
    params ["_vehicle", "_pos", "_surfaceNormal"];

    _vehicle setVectorUp _surfaceNormal;
    _vehicle setPos _pos;
    _vehicle setVelocity [0, 0, 0];

    sleep 0.1;

    _vehicle setVectorUp _surfaceNormal;
    _vehicle setPos _pos;
    _vehicle setVelocity [0, 0, 0];
};
