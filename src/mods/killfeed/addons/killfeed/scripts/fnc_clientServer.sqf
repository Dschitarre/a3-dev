// Killfeed, every machine (server and clients): event handlers on all units and vehicles, and the text size and name
// format the server's texts and the clients' drawing share. Hits are captured where the shot is local (projectile
// event handlers on the shooter's machine), damage without a projectile where the victim is local; both are sent to
// the server.

KF_var_ammoTraits = createHashMap;   // ammo class -> [explodes, has submunitions]
KF_var_pendingHits = [];             // hits of the current frame, sent to the server in one message
KF_var_textSizeCells = 0.8;          // text size of all feeds in GUI grid cells: as large as the HUD texts of the missions
KF_var_maxNameLength = 20;           // characters of a name in the feeds; longer names are cut with "..."
KF_var_aiNameSuffix = " (AI)";

// ---- names in the feeds ----

KF_fnc_replaceAll = {
    params ["_text", "_search", "_replacement"];

    private _result = "";
    private _index = _text find _search;

    while {_index != -1} do {
        _result = _result + (_text select [0, _index]) + _replacement;
        _text = _text select [_index + count _search];
        _index = _text find _search;
    };

    _result + _text
};

// A name as the feeds show it: cut to KF_var_maxNameLength characters with "..." (an AI suffix is kept) and escaped
// for structured text. The server builds the name tags with it and the clients their highlighted names, so
// KF_fnc_colorize still finds cut names.
KF_fnc_formatName = {
    params ["_name"];

    // characters, not bytes (string commands count bytes): names may contain umlauts
    private _characters = toArray _name;
    private _suffix = "";
    private _suffixStart = count _characters - count toArray KF_var_aiNameSuffix;

    if (_suffixStart > 0 && {(toString (_characters select [_suffixStart])) isEqualTo KF_var_aiNameSuffix}) then {
        _suffix = KF_var_aiNameSuffix;
        _characters resize _suffixStart;
    };

    if (count _characters > KF_var_maxNameLength) then {
        _name = (trim toString (_characters select [0, KF_var_maxNameLength - 3])) + "..." + _suffix;
    };

    // after the cut, so it never splits an entity
    {
        _x params ["_character", "_entity"];

        _name = [_name, _character, _entity] call KF_fnc_replaceAll;
    } forEach [["&", "&amp;"], ["<", "&lt;"], [">", "&gt;"]];

    _name
};

// ---- helpers (also used by the game modes) ----

KF_fnc_isTypeUnmanned = {
    params ["_type"];

    ("UAV" in _type) || {"UGV" in _type}
};

KF_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in typeOf _unit
};

// The color key of a side. Texts carry color keys ('kf:west', 'kf:you', ...), each client fills in its own
// profile colors when it draws them (KF_fnc_colorize).
KF_fnc_sideColorKey = {
    params [["_side", sideUnknown]];

    switch (_side) do {
        case west: {"kf:west"};
        case east: {"kf:east"};
        case independent: {"kf:guer"};
        case civilian: {"kf:civ"};
        default {"kf:unknown"};
    }
};

// The side color on a client (from its profile). The server, whose texts are shown on the clients, gets the color key.
KF_fnc_getSidesHexColor = {
    params [["_side", sideUnknown]];

    private _key = [_side] call KF_fnc_sideColorKey;

    if (isServer || {isNil "KF_var_colors"}) exitWith {_key};

    KF_var_colors get _key
};

// The player controlling the UAV seat of _crewUnit, else the player in the other seat, else the UAV itself.
KF_fnc_getUavOperator = {
    params ["_uav", "_crewUnit"];

    private _control = UAVControl _uav;
    private _roles = if ((driver _uav) isEqualTo _crewUnit) then {["DRIVER", "GUNNER"]} else {["GUNNER", "DRIVER"]};
    private _index = _control find (_roles select 0);

    if (_index == -1) then {
        _index = _control find (_roles select 1);
    };

    if (_index < 1) exitWith {_uav};

    _control select (_index - 1)
};

// The person behind damage or a kill: the operator of a UAV, else the instigator, else the unit itself or the
// driver of the vehicle (the engine reports road kills without instigator).
KF_fnc_getInstigator = {
    params ["_causedBy", "_instigator", "_victim"];

    if (unitIsUAV _causedBy) exitWith {
        if (_victim isEqualTo _causedBy) then {_causedBy} else {[_causedBy, driver _causedBy] call KF_fnc_getUavOperator}
    };

    if (!isNull _instigator) exitWith {_instigator};
    if (_causedBy isKindOf "CAManBase") exitWith {_causedBy};

    driver _causedBy
};

// ---- event handlers on every unit and vehicle ----
// Event handlers stay on a respawned unit only where it is local, while its variables are copied everywhere. So each
// handler checks that it is the one registered last (KF_var_eh<event>) and removes itself when it is a stale copy.

KF_fnc_isCurrentHandler = {
    params ["_entity", "_event", "_id"];

    if ((_entity getVariable ("KF_var_eh" + _event)) isEqualTo _id) exitWith {true};

    _entity removeEventHandler [_event, _id];
    false
};

KF_fnc_setEventHandler = {
    params ["_entity", "_event", "_code"];

    _entity setVariable ["KF_var_eh" + _event, _entity addEventHandler [_event, _code]];
};

KF_fnc_addEntityEventHandlers = {
    params ["_entity"];

    if (isNull _entity || {!(_entity isKindOf "AllVehicles")} || {_entity isKindOf "Animal"}) exitWith {};

    // Observe the engine's projectile context without replacing damage or interfering with AIS/other handlers.
    [_entity, "HandleDamage", {
        params ["_entity", "", "", "_source", "_projectile"];
        if (local _entity && {[_entity, "HandleDamage", _thisEventHandler] call KF_fnc_isCurrentHandler}) then {
            _entity setVariable ["KF_var_damageContext", [diag_frameNo, _projectile, _source]];
        };
        nil
    }] call KF_fnc_setEventHandler;

    [_entity, "Hit", {
        params ["_entity"];

        if ([_entity, "Hit", _thisEventHandler] call KF_fnc_isCurrentHandler) then {
            _this call KF_fnc_onDamage;
        };
    }] call KF_fnc_setEventHandler;

    // fires where the healer is local
    [_entity, "HandleHeal", {
        params ["_entity"];

        if ([_entity, "HandleHeal", _thisEventHandler] call KF_fnc_isCurrentHandler) then {
            [_entity] spawn KF_fnc_watchHeal;
        };

        false
    }] call KF_fnc_setEventHandler;

    if !(_entity isKindOf "CAManBase") exitWith {};

    [_entity, "FiredMan", {
        params ["_unit"];

        if (local _unit && {[_unit, "FiredMan", _thisEventHandler] call KF_fnc_isCurrentHandler}) then {
            _this call KF_fnc_firedMan;
        };
    }] call KF_fnc_setEventHandler;

    // the engine's rating changes are disabled, kills add rating instead (KF_fnc_addKillScores)
    [_entity, "HandleRating", {
        params ["_unit"];

        [_unit, "HandleRating", _thisEventHandler] call KF_fnc_isCurrentHandler;
        0
    }] call KF_fnc_setEventHandler;
};

#include "hitCapture.sqf"

// ---- healing: clears the hits collected on the server ----

// runs where the healer is local; reports the heal once any hit point of the injured got better
KF_fnc_watchHeal = {
    params ["_entity"];

    private _oldDamage = (getAllHitPointsDamage _entity) param [2, []];

    if (_oldDamage isEqualTo []) exitWith {};

    private _timeout = time + 20;   // an interrupted heal never lowers the damage

    waitUntil {
        private _newDamage = (getAllHitPointsDamage _entity) param [2, []];
        private _isHealed = false;

        {
            if (_x < (_oldDamage select _forEachIndex)) exitWith {
                _isHealed = true;
            };
        } forEach _newDamage;

        if (_isHealed) then {
            [_entity] remoteExecCall ["KF_fnc_entityHealed", 2];
        };

        _isHealed || {!alive _entity} || {time > _timeout} || {_newDamage isEqualTo []}
    };
};

// ---- start: once the server started the killfeed ----

[] spawn {
    waitUntil {!isNil "KF_var_running" && {KF_var_running}};

    addMissionEventHandler ["EntityCreated", {
        params ["_entity"];

        [_entity] call KF_fnc_addEntityEventHandlers;
    }];

    // after the variables were copied to the new unit (EntityCreated comes before that)
    addMissionEventHandler ["EntityRespawned", {
        params ["_newEntity"];

        [_newEntity] call KF_fnc_addEntityEventHandlers;
    }];

    {
        [_x] call KF_fnc_addEntityEventHandlers;
    } forEach (entities [["AllVehicles"], ["Animal"], true, false]);
};
