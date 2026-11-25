// Killfeed kill info (server): longest kill and most kills in a row, shown on request (KF_fnc_displayKillInfo).
// Included by fnc_server.sqf.

// ---- kill info: longest kill and most kills in a row, shown on request (KF_fnc_displayKillInfo) ----
// A record list holds every entry with the best value so far, one per name; entries are [name, side, ..., value].

KF_fnc_resetKillInfo = {
    KF_var_longestKills = [["", civilian, "", civilian, [], 0]];   // [killer name, killer side, victim name, victim side, causes, distance]
    KF_var_mostKillsInARow = [["", civilian, 0]];                  // [name, side, kills]
};

call KF_fnc_resetKillInfo;

KF_fnc_updateRecord = {
    params ["_records", "_entry"];

    private _value = _entry select (count _entry - 1);
    private _best = (_records select 0) select (count (_records select 0) - 1);

    if (_value < _best) exitWith {_records};
    if (_value > _best) exitWith {[_entry]};

    (_records select {(_x select 0) != (_entry select 0)}) + [_entry]
};

KF_fnc_updateKillInfo = {
    params ["_unit", "_killer", "_isTeamKill", "", "_killData", "", "", "", "_isUnitDeath"];
    _killData params ["", "_killerCauses", "_killDistance"];

    if ((KF_var_killInfoIncludeTK || !_isTeamKill) && {!_isUnitDeath || KF_var_showUnitDeathsInKillInfo}) then {
        private _killsInARow = (_killer getVariable ["KF_var_killsInARow", 0]) + 1;
        private _killerName = _killer getVariable ["KF_var_name", "Error: no unit"];
        private _killerSide = [_killer] call KF_fnc_unitSide;

        _killer setVariable ["KF_var_killsInARow", _killsInARow];
        KF_var_mostKillsInARow = [KF_var_mostKillsInARow, [_killerName, _killerSide, _killsInARow]] call KF_fnc_updateRecord;

        if (_killDistance != -1) then {
            KF_var_longestKills = [KF_var_longestKills, [
                _killerName,
                _killerSide,
                _unit getVariable ["KF_var_name", "Error: no unit"],
                [_unit] call KF_fnc_unitSide,
                _killerCauses,
                _killDistance
            ]] call KF_fnc_updateRecord;
        };
    };

    _unit setVariable ["KF_var_killsInARow", 0];
};

// shows the kill info to everybody (also to players joining) for KF_var_killInfoDuration seconds
// the kill info text (color keys, see KF_fnc_colorize), "" without kills; game modes with an end screen of their own
// show it there instead of calling KF_fnc_displayKillInfo
KF_fnc_formatKillInfo = {
    if (((KF_var_mostKillsInARow select 0) select 2) == 0 || {((KF_var_longestKills select 0) select 5) == 0}) exitWith {""};

    private _longestKills = KF_var_longestKills apply {
        _x params ["_killerName", "_killerSide", "_victimName", "_victimSide", "_causes", "_distance"];

        format [
            "%1 %2 %3 %4m",
            [_killerName, _killerSide] call KF_fnc_nameTag,
            [_causes, 0.87, true] call KF_fnc_formatHitsPicture,
            [_victimName, _victimSide] call KF_fnc_nameTag,
            [_distance, 1] call BIS_fnc_cutDecimals
        ]
    };
    private _mostKills = KF_var_mostKillsInARow apply {
        _x params ["_name", "_side", "_kills"];

        format ["%1 %2 Kills", [_name, _side] call KF_fnc_nameTag, _kills]
    };
    // font, size and alignment come from the clients (KF_fnc_formatEntry)
    format [
        "Longest Kill: %1<br/>Most Kills in a row: %2",
        _longestKills joinString "<br/>",
        _mostKills joinString ", "
    ]
};

KF_fnc_displayKillInfo = {
    private _text = call KF_fnc_formatKillInfo;

    if (_text == "") exitWith {};

    // a joining client gets this before its client part is loaded
    private _jipId = [[_text, KF_var_killInfoDuration], {
        if (hasInterface) then {
            _this spawn {
                waitUntil {!isNil "KF_fnc_showKillInfo"};
                _this call KF_fnc_showKillInfo;
            };
        };
    }] remoteExecCall ["call", 0, true];

    if (isNil "_jipId") exitWith {};

    [_jipId] spawn {
        params ["_jipId"];

        sleep KF_var_killInfoDuration;
        remoteExecCall ["", _jipId];

        // also hides it on the clients that joined meanwhile (they got it with the full duration)
        ["KF_fnc_hideKillInfo", [], 0] call KF_fnc_callClients;
    };
};
