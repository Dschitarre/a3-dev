// Unflip (server): publishes the settings, starts / stops the hold action on every client (including JIP) and
// unflips the vehicles of the AI (UF_var_aiAutoUnflip) once they have been flipped for UF_var_aiDelay seconds.

UF_var_remoteExecId = "";
UF_var_aiScript = scriptNull;
UF_var_aiCheckInterval = 3;    // seconds between two checks of all vehicles

// settings the start publishes (defaults in fnc_clientServer.sqf, which on the server may load after this file)
UF_var_settings = [
    "UF_var_enabled",
    "UF_var_maxDistance",
    "UF_var_minTilt",
    "UF_var_maxSpeed",
    "UF_var_durationMin",
    "UF_var_durationMax",
    "UF_var_massLight",
    "UF_var_massHeavy",
    "UF_var_damageProtection",
    "UF_var_aiAutoUnflip",
    "UF_var_aiDelay"
];

UF_fnc_publishSettings = {
    {
        if (!isNil _x) then {
            publicVariable _x;
        };
    } forEach UF_var_settings;
};

// ---- AI ----

// whether a vehicle belongs to the AI. Its AI crew dismounts when it flips, so the crew inside is not enough: the
// crew the AI check saw in it last decides (UF_var_aiCrewed: no player among it), else the group it is assigned to
// (addVehicle; AI group: no player in it). A vehicle with a player among its last crew stays the players' (they
// have the action), one nobody sat in and no group owns is nobody's.
UF_fnc_isAiVehicle = {
    params ["_vehicle"];

    private _aiCrewed = _vehicle getVariable "UF_var_aiCrewed";

    if (!isNil "_aiCrewed") exitWith {_aiCrewed};

    private _group = assignedGroup _vehicle;

    !isNull _group && {((units _group) findIf {isPlayer _x}) == -1}
};

// a player on foot within the vehicle's box radius: it would turn over right next to (or onto) him, so the AI unflip
// waits until he steps away (or uses the action himself)
UF_fnc_playerNear = {
    params ["_vehicle"];

    ([_vehicle] call UF_fnc_box) params ["_min", "_max"];

    private _radius = (vectorMagnitude (_max vectorDiff _min)) / 2;

    ((_vehicle nearEntities ["CAManBase", _radius]) findIf {isPlayer _x}) != -1
};

// one pass over all land vehicles and boats: notes who sits in each, counts how long each one is flipped (and
// standing still) and unflips the AI vehicles among them after UF_var_aiDelay. The timer runs for every vehicle, so
// one that becomes an AI vehicle later (assigned) does not wait again.
UF_fnc_aiCheck = {
    {
        private _vehicle = _x;
        private _crew = [_vehicle] call UF_fnc_livingCrew;

        if (_crew isNotEqualTo []) then {
            _vehicle setVariable ["UF_var_aiCrewed", (_crew findIf {isPlayer _x}) == -1];
        };

        if ([_vehicle, true] call UF_fnc_canUnflip) then {
            private _flippedSince = _vehicle getVariable ["UF_var_flippedSince", -1];

            if (_flippedSince < 0) then {
                _vehicle setVariable ["UF_var_flippedSince", time];
            } else {
                if (
                    ((time - _flippedSince) >= UF_var_aiDelay) &&
                    {[_vehicle] call UF_fnc_isAiVehicle} &&
                    {!([_vehicle] call UF_fnc_playerNear)}
                ) then {
                    _vehicle setVariable ["UF_var_flippedSince", nil];
                    [_vehicle, true] remoteExecCall ["UF_fnc_unflip", _vehicle];
                };
            };
        } else {
            _vehicle setVariable ["UF_var_flippedSince", nil];
        };
    } forEach (entities [["LandVehicle", "Ship"], [], false, true]);
};

UF_fnc_aiLoop = {
    while {true} do {
        if (UF_var_enabled && {UF_var_aiAutoUnflip}) then {
            call UF_fnc_aiCheck;
        };

        sleep UF_var_aiCheckInterval;
    };
};

// ---- start / stop ----

// also publishes the settings again: a mission or the module may have changed them since the last start
UF_fnc_startUnflipServer = {
    call UF_fnc_publishSettings;

    if (isNull UF_var_aiScript) then {
        UF_var_aiScript = [] spawn UF_fnc_aiLoop;
    };

    if (!isMultiplayer) exitWith {
        call UF_fnc_startUnflipClient;
    };

    if (UF_var_remoteExecId != "") exitWith {};

    UF_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "UF_var_clientInitDone" && {!isNil "UF_var_clientServerInitDone"}};
        call UF_fnc_startUnflipClient;
    }] remoteExecCall ["spawn", 0, true];
};

UF_fnc_stopUnflipServer = {
    if (!isNull UF_var_aiScript) then {
        terminate UF_var_aiScript;
        UF_var_aiScript = scriptNull;
    };

    if (!isMultiplayer) exitWith {
        call UF_fnc_stopUnflipClient;
    };

    if (UF_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", UF_var_remoteExecId];
    UF_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "UF_var_clientInitDone"};
        call UF_fnc_stopUnflipClient;
    }] remoteExecCall ["spawn", 0];
};

UF_var_serverInitDone = true;
publicVariable "UF_var_serverInitDone";
