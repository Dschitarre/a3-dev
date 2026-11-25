// Statistics: player stats and kill / death history in the profile, statistics dialog (client).

// Statistics: player stats and kill / death history in the profile (client),
// killfeed mod integration (server).

// ---- statistics ----

// player data: [xp, rank, kills, deaths, other, headshotRate, heals, selfHeals, revives, revived, capturedSectors]
SC_fnc_getPlayerData = {
    ["SC_var_playerData", [0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0]] call SC_fnc_getWorldGroupProfileEntry
};

SC_fnc_setPlayerData = {
    params ["_entry"];

    ["SC_var_playerData", _entry] call SC_fnc_setWorldGroupProfileEntry;
};

SC_fnc_incrementPlayerData = {
    params ["_index"];

    private _data = call SC_fnc_getPlayerData;
    _data set [_index, (_data select _index) + 1];
    [_data] call SC_fnc_setPlayerData;
};

SC_fnc_getKillHistory = {
    ["SC_var_killHistory", []] call SC_fnc_getWorldGroupProfileEntry
};

SC_fnc_setKillHistory = {
    params ["_entry"];

    ["SC_var_killHistory", _entry] call SC_fnc_setWorldGroupProfileEntry;
};

SC_fnc_getDeathHistory = {
    ["SC_var_deathHistory", []] call SC_fnc_getWorldGroupProfileEntry
};

SC_fnc_setDeathHistory = {
    params ["_entry"];

    ["SC_var_deathHistory", _entry] call SC_fnc_setWorldGroupProfileEntry;
};

SC_fnc_addToKillHistory = {
    params ["_source", "_distance", "_isRealKill", "_isHeadShot", "_xpToAdd"];

    (call SC_fnc_getPlayerData) params ["_xp", "_rank", "_kills", "_deaths", "_other", "_headshotRate",
        "_numHeals", "_numSelfHeals", "_numRevives", "_numRevived", "_numCapturedSectors"];

    if _isRealKill then {
        _kills = _kills + 1;
    } else {
        _other = _other + 1;
    };

    private _all = _kills + _other;
    _headshotRate = (_headshotRate * _all + ([0, 1] select _isHeadShot)) / (_all + 1);

    [[_xp, _rank, _kills, _deaths, _other, _headshotRate,
        _numHeals, _numSelfHeals, _numRevives, _numRevived, _numCapturedSectors]] call SC_fnc_setPlayerData;

    private _killHistory = call SC_fnc_getKillHistory;
    private _idx = _killHistory findIf {(_x select 0) == _source};

    if (_idx == -1) then {
        _killHistory pushBack [_source, 0, 0, 0, 0, 0];
        _idx = (count _killHistory) - 1;
    };

    (_killHistory select _idx) params ["", "_kills", "_other", "_numHeadshots", "_oldAvgDis", "_oldXp"];

    private _numAll = _kills + _other;
    private _newAvgDis = ((_oldAvgDis * _numAll) + _distance) / (_numAll + 1);

    _killHistory set [_idx, [
        _source,
        _kills + ([0, 1] select _isRealKill),
        _other + ([0, 1] select !_isRealKill),
        _numHeadshots + ([0, 1] select _isHeadShot),
        _newAvgDis,
        _oldXp + _xpToAdd
    ]];

    [_killHistory] call SC_fnc_setKillHistory
};

SC_fnc_addToDeathHistory = {
    params ["_source", "_distance", "_isRealKill", "_isHeadshot"];

    (call SC_fnc_getPlayerData) params ["_xp", "_rank", "_kills", "_deaths", "_other", "_headshotRate",
        "_numHeals", "_numSelfHeals", "_numRevives", "_numRevived", "_numCapturedSectors"];

    if _isRealKill then {
        _deaths = _deaths + 1;
    };

    [[_xp, _rank, _kills, _deaths, _other, _headshotRate,
        _numHeals, _numSelfHeals, _numRevives, _numRevived, _numCapturedSectors]] call SC_fnc_setPlayerData;

    private _deathHistory = call SC_fnc_getDeathHistory;
    private _idx = _deathHistory findIf {(_x select 0) == _source};

    if (_idx == -1) then {
        _deathHistory pushBack [_source, 0, 0, 0, 0];
        _idx = (count _deathHistory) - 1;
    };

    (_deathHistory select _idx) params ["", "_kills", "_other", "_numHeadshots", "_oldAvgDis"];

    private _numAll = _kills + _other;
    private _newAvgDis = ((_oldAvgDis * _numAll) + _distance) / (_numAll + 1);

    _deathHistory set [_idx, [
        _source,
        _kills + ([0, 1] select _isRealKill),
        _other + ([0, 1] select !_isRealKill),
        _numHeadshots + ([0, 1] select _isHeadShot),
        _newAvgDis
    ]];

    [_deathHistory] call SC_fnc_setDeathHistory;
};

SC_fnc_addHeal = {
    [6] call SC_fnc_incrementPlayerData;
};

SC_fnc_addSelfHeal = {
    [7] call SC_fnc_incrementPlayerData;
};

SC_fnc_addCapturedSector = {
    [10] call SC_fnc_incrementPlayerData;
};

SC_fnc_addRevive = {
    params ["_reviver"];

    if (_reviver isEqualTo player) then {
        [8] call SC_fnc_incrementPlayerData;
    };
};

SC_fnc_addRevived = {
    params ["_revived"];

    if (_revived isEqualTo player) then {
        [9] call SC_fnc_incrementPlayerData;
    };
};

SC_fnc_addHandleHeal = {
    params ["_unit"];

    private _id = _unit getVariable ["SC_var_handleHealEhId", -1];
    if (_id != -1) then {_unit removeEventHandler ["HandleHeal", _id];};
    _id = _unit addEventHandler ["HandleHeal", {_this spawn SC_fnc_onHeal; false}];
    _unit setVariable ["SC_var_handleHealEhId", _id];
};

SC_fnc_onHeal = {
    params ["_injured", "_healer"];

    if (!((isPlayer _injured) || (isPlayer _healer)) || {_injured getVariable ["SC_var_isBeingHealed", false]}) exitWith {};

    private _damage = damage _injured;
    private _timeout = time + 30;
    _injured setVariable ["SC_var_isBeingHealed", true];

    // the heal may be interrupted (damage rises or never changes), so always reset the flag
    waitUntil {((damage _injured) != _damage) || {time > _timeout}};
    _injured setVariable ["SC_var_isBeingHealed", false];

    if ((damage _injured) < _damage) then {
        if (_healer isEqualTo _injured) then {
            remoteExecCall ["SC_fnc_addSelfHeal", _injured];
        } else {
            if (isPlayer _healer) then {
                remoteExecCall ["SC_fnc_addHeal", _healer];
            };
        };
    };
};

SC_fnc_showStatistics = {
    params ["_showDeaths", "_sortByIndex"];

    private _settingsDialog = uiNamespace getVariable "SC_var_statisticsDialog";

    (call SC_fnc_getPlayerData) params ["", "", "_numKills", "_numDeaths", "_numOther", "_headshotRate",
        "_numHeals", "_numSelfHeals", "_numUnitsRevived", "_numRevived", "_numCapturedSectors"];

    // values of the stat tiles (labels in SC\dialogs.hpp)
    {
        _x params ["_idc", "_value"];

        (_settingsDialog displayCtrl _idc) ctrlSetText _value;
    } forEach [
        [1003, str _numKills],
        [1004, str _numDeaths],
        [1008, ((_numKills / (1 max _numDeaths)) toFixed 2)],
        [1006, (((100 * _headshotRate) toFixed 1) + "%")],
        [1005, str _numOther],
        [1007, str _numCapturedSectors],
        [1009, str _numUnitsRevived],
        [1010, str _numRevived],
        [1011, str _numHeals],
        [1012, str _numSelfHeals]
    ];

    private _controlsTable = _settingsDialog displayCtrl 1500;
    ctClear _controlsTable;
    (ctAddHeader _controlsTable) params ["", "_header"];

    _header params ["",
        "_ctrlHeaderColumn1", "_ctrlHeaderColumn2", "_ctrlHeaderColumn3",
        "_ctrlHeaderColumn4", "_ctrlHeaderColumn5", "_ctrlHeaderColumn6"
    ];

    [_header] call SC_fnc_styleTableHeader;
    _ctrlHeaderColumn1 ctrlSetText "Picture";
    _ctrlHeaderColumn2 ctrlSetText (["Kills", "Deaths"] select _showDeaths);
    _ctrlHeaderColumn3 ctrlSetText "Assists";
    _ctrlHeaderColumn4 ctrlSetText "Headshots";
    _ctrlHeaderColumn5 ctrlSetText "Avg. Distance";
    _ctrlHeaderColumn6 ctrlSetText (["XP", ""] select _showDeaths);

    // clicking a column header sorts by that column
    {
        _x setVariable ["SC_var_sortParams", [_showDeaths, _forEachIndex + 1]];
        _x ctrlAddEventHandler ["ButtonClick", {params ["_ctrl"]; (_ctrl getVariable "SC_var_sortParams") call SC_fnc_showStatistics;}];
    } forEach [_ctrlHeaderColumn2, _ctrlHeaderColumn3, _ctrlHeaderColumn4, _ctrlHeaderColumn5, _ctrlHeaderColumn6];

    private _history = if _showDeaths then {call SC_fnc_getDeathHistory} else {call SC_fnc_getKillHistory};

    _history = _history select {(((_x select 0) select [0, 4]) == "CUP_") isEqualTo SC_var_wgUsesCupClasses};

    _history = [_history, [_sortByIndex], {
        if (_input0 != 3) then {
            _x select _input0
        } else {
            _x params ["", "_numKills", "_numOther", "_numHeadshots"];
            _numHeadshots / (_numKills + _numOther)
        }
    }, "DESCEND"] call BIS_fnc_sortBy;

    private _vehiclePictures = [];   // [picture control, picture] of the rows of vehicles (the others: weapons)

    {
        _x params ["_source", "_numKills", "_numOther", "_numHeadshots", "_avgDis", ["_xp", 0]];
        private _picture = [_source] call SC_fnc_getPicture;

        if (_picture != "") then {
            (ctAddRow _controlsTable) params ["", "_row"];

            _row params ["",
                "_ctrlColumn1", "_ctrlColumn2", "_ctrlColumn3",
                "_ctrlColumn4", "_ctrlColumn5", "_ctrlColumn6"
            ];

            if (_avgDis < 0) then {
                _avgDis = 0;
            };

            [_row] call SC_fnc_styleTableRow;

            if ((_source isKindOf "LandVehicle") || {_source isKindOf "Air"} || {_source isKindOf "Ship"}) then {
                _vehiclePictures pushBack [_ctrlColumn1, _picture];
            } else {
                _ctrlColumn1 ctrlSetText _picture;
            };

            _ctrlColumn2 ctrlSetText (str _numKills);
            _ctrlColumn3 ctrlSetText (str _numOther);
            _ctrlColumn4 ctrlSetText ((str (round (100 * _numHeadshots / (_numKills + _numOther)))) + "%");
            _ctrlColumn5 ctrlSetText ((str (round _avgDis)) + "m");
            _ctrlColumn6 ctrlSetText ([(str _xp), ""] select _showDeaths);
        };
    } forEach _history;

    // vehicle pictures sized by their opaque area, once all rows exist (in case adding a row lays out the others again)
    {
        _x call UI_fnc_setVehiclePicture;
    } forEach _vehiclePictures;
};
