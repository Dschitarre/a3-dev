// Shared helpers: unit names, notifications, cached config lookups, formatting and per-world-group
// profile settings (both).

SC_fnc_getName = {
    params ["_unit"];

    private _name = "";

    if (unitIsUAV _unit) then {
        _name = [([typeOf _unit] call SC_fnc_getDisplayName), "(AI)"] joinString " ";
    } else {
        _name = name _unit;

        if !(isPlayer _unit) then {
            // "John Smith" -> "J. Smith", "Jean-Luc Picard" -> "J.-L. Picard"
            private _nameParts = _name splitString " ";

            if ((count _nameParts) > 1) then {
                private _firstNameParts = (_nameParts select 0) splitString "-";

                if ((count _firstNameParts) > 1) then {
                    _name =((_firstNameParts select 0) select [0,
                        1]) + ".-" +((_firstNameParts select 1) select [0,
                        1]) + ". " +(_nameParts select 1);
                } else {
                    _name = ((_nameParts select 0) select [0, 1]) + ". " + (_nameParts select 1);
                };
            };

            _name = _name + " (AI)";
        };
    };

    _name
};

// shows a notification to the players among _units (no remoteExec without targets)
SC_fnc_notifyPlayers = {
    params ["_template", "_arguments", "_units"];

    private _players = _units select {isPlayer _x};

    if (_players isNotEqualTo []) then {
        [_template, _arguments] remoteExec ["BIS_fnc_showNotification", _players];
    };
};

SC_var_configEntryCache = createHashMap;

// config class of a magazine / vehicle / weapon class name (cached)
SC_fnc_getConfigEntry = {
    params ["_typeName"];

    private _entry = SC_var_configEntryCache get _typeName;

    if (isNil "_entry") then {
        _entry = configFile >> (
            switch true do {
                case (_typeName isKindOf [_typeName, (configFile >> "CfgMagazines")]): {"CfgMagazines"};
                case (_typeName isKindOf [_typeName, (configFile >> "CfgVehicles")]): {"CfgVehicles"};
                case (_typeName isKindOf [_typeName, (configFile >> "CfgWeapons")]): {"CfgWeapons"};
                default {"CfgVehicles"};
            }
        ) >> _typeName;

        SC_var_configEntryCache set [_typeName, _entry];
    };

    _entry
};

SC_fnc_getDisplayName = {
    params ["_typeName"];

    getText (([_typeName] call SC_fnc_getConfigEntry) >> "displayName")
};

SC_fnc_getPicture = {
    params ["_typeName"];

    getText (([_typeName] call SC_fnc_getConfigEntry) >> "picture")
};

SC_fnc_getSideString = {
    params ["_side"];

    switch _side do {
        case west: {"Blufor"};
        case east: {"Opfor"};
        case independent: {"Independent"};
    };
};

// returns "MM:SS" (minutes are not padded beyond two digits)
SC_fnc_secondsToMinSec = {
    params ["_time"];

    private _totalSecs = 0 max (round _time);
    private _mins = floor (_totalSecs / 60);
    private _secs = _totalSecs - (_mins * 60);

    format ["%1%2:%3%4", (["", "0"] select (_mins < 10)), _mins, (["", "0"] select (_secs < 10)), _secs]
};

// large counters with three significant digits and a unit: 999 -> "999", 5432 -> "5.43 K", 54321 -> "54.3 K",
// 543210 -> "543 K", 5432100 -> "5.43 M"; cut, not rounded, so a value never shows more than it is
SC_fnc_formatCompactNumber = {
    params ["_number"];

    private _value = floor (abs _number);
    private _sign = ["", "-"] select (_number <= -1);

    if (_value < 1000) exitWith {_sign + (str _value)};

    private _units = [[1e9, "B"], [1e6, "M"], [1e3, "K"]];
    (_units select (_units findIf {_value >= (_x select 0)})) params ["_divisor", "_unit"];

    private _decimals = switch true do {
        case (_value < (10 * _divisor)): {2};
        case (_value < (100 * _divisor)): {1};
        default {0};
    };

    // integer division first: (_value / _divisor) * 100 is not exact as a float
    private _digits = floor (_value / (_divisor / (10 ^ _decimals)));

    format ["%1%2 %3", _sign, ((_digits / (10 ^ _decimals)) toFixed _decimals), _unit]
};

SC_fnc_removeNullsInPlace = {
    params ["_objects"];

    for "_i" from ((count _objects) - 1) to 0 step -1 do {
        if (isNull (_objects select _i)) then {
            _objects deleteAt _i;
        };
    };

    _objects
};

// _this: config entry [className, rank]
SC_fnc_isConfigEntryValid = {
    params ["_class"];

    if SC_var_wgFilterDlcItems then {
        _class = toLowerANSI _class;

        (SC_var_lxwsActive || {(_class select [(count _class) - 5, 5]) != "_lxws"}) &&
        {SC_var_rfActive || {(_class select [(count _class) - 3, 3]) != "_rf"}} &&
        {SC_var_efActive || {(_class select [0, 3]) != "ef_"}}
    } else {
        true
    }
};

SC_fnc_filterConfigArr = {
    if SC_var_wgFilterDlcItems then {
        _this select {_x call SC_fnc_isConfigEntryValid}
    } else {
        _this
    }
};

// profile values that are stored per world group: [[worldGroup, value], ...] (XP / rank / perks / statistics can be
// stored on the server, see SC\progressStorage.sqf)
SC_fnc_getWorldGroupProfileEntry = {
    params ["_varName", "_default"];

    private _data = [_varName] call SC_fnc_getProgressList;
    private _idx = _data findIf {(_x select 0) == SC_var_currentWorldGroup};

    if (_idx == -1) then {_default} else {(_data select _idx) select 1}
};

SC_fnc_setWorldGroupProfileEntry = {
    params ["_varName", "_entry"];

    private _data = [_varName] call SC_fnc_getProgressList;
    private _idx = _data findIf {(_x select 0) == SC_var_currentWorldGroup};

    if (_idx == -1) then {
        _idx = count _data;
    };

    _data set [_idx, [SC_var_currentWorldGroup, _entry]];
    [_varName, _data] call SC_fnc_setProgressList;
};

// server: whether a remote executed request comes from the client of the player with this UID
SC_fnc_isRequestFromUid = {
    params ["_uid"];

    if !isRemoteExecuted exitWith {true};

    (allPlayers findIf {((getPlayerUID _x) == _uid) && {(owner _x) == remoteExecutedOwner}}) != -1
};
