// Battle Royale on-screen HUD (client, RscTitles BR_rscHud of BR\ui.hpp): match counters and zone timer at the top
// center, health / boost / distance to the safe zone at the bottom right, the team mates at the bottom left. The map
// and 3D drawing is in BR\mapDraw.sqf. Colors follow the player's own UI settings (ui\ui.sqf), so they are built here
// and not on the server.

BR_var_hudInterval = 0.2;
BR_var_hudLowHealth = 25;           // HP below which a health bar is filled in the error color (as in SC)
BR_var_hudRowHeight = 0.8;          // grid cells: BR_HUD_ROW_H of BR\ui.hpp
BR_var_hudRowGap = 0.1;             // grid cells between the rows of the bottom corners (UI_GAP)
BR_var_hudBottomOffset = 1.5;       // grid cells from the bottom edge to the top of the lowest row (BR_HUD_BOTTOM_Y)
BR_var_hudTeamBarHeight = 0.12;     // grid cells: BR_HUD_TEAM_BAR_H
BR_var_hudBoostDuration = 60;       // s of a full boost when only its end time is known (BR_var_boostEnd)
BR_var_hudPhaseStarts = createHashMap;  // phase key -> serverTime this client first saw it (BR_fnc_hudRemainingShare)

// 75 -> "1:15"
BR_fnc_formatTime = {
    params ["_seconds"];

    // ceil of a small negative value is -0, and 0 max -0 stays -0: the timer showed "-0:00" (user 2026-11-23)
    _seconds = ceil _seconds;
    if (_seconds <= 0) then {_seconds = 0};
    private _secs = _seconds mod 60;

    format ["%1:%2%3", floor (_seconds / 60), ["", "0"] select (_secs < 10), _secs]
};

// the player's team in the roster, the player included (BR_var_myTeammates is refreshed by the HUD loop)
BR_fnc_myTeammates = {
    private _teamId = player getVariable ["BR_var_teamId", -1];

    BR_var_rosterUnits select {(_x getVariable ["BR_var_teamId", -2]) == _teamId}
};

BR_fnc_initMapColors = {
    BR_var_colorAccent = ["accent"] call UI_fnc_color;
    BR_var_colorTeam = [independent] call UI_fnc_sideColor;
    BR_var_colorDanger = ["error"] call UI_fnc_color;
    BR_var_colorWarning = ["warning"] call UI_fnc_color;
    BR_var_colorHudText = ["hudText"] call UI_fnc_color;
    BR_var_colorHealth = ["health"] call UI_fnc_color;
    BR_var_colorZoneNext = [1, 1, 1, 0.8];
    BR_var_myTeammates = [];
};

// ---- HUD contents ----

// share 0..1 of a phase that is still left; without _startTime the phase starts when this client first saw it (the
// zone data has no start of the waiting time)
BR_fnc_hudRemainingShare = {
    params ["_key", "_endTime", ["_startTime", -1]];

    if (_startTime < 0) then {
        _startTime = BR_var_hudPhaseStarts getOrDefault [_key, -1];

        if (_startTime < 0) then {
            _startTime = serverTime;
            BR_var_hudPhaseStarts set [_key, _startTime];
        };
    };

    private _duration = _endTime - _startTime;

    if (_duration <= 0) exitWith {0};

    0 max (1 min ((_endTime - serverTime) / _duration))
};

// the top center: [left number, left label, timer, its remaining share (-1: no fill), status, status as a warning,
// right number, right label]; warmup: players | countdown | AI, later: alive | zone timer | kills
BR_fnc_hudTop = {
    if (BR_var_state == "warmup") exitWith {
        private _players = {isPlayer _x} count BR_var_rosterUnits;
        private _ai = str ((count BR_var_rosterUnits) - _players);

        if (BR_var_stateEndTime < 0) then {
            [str _players, "Players", "--", -1, "Waiting for players", false, _ai, "AI"]
        } else {
            private _share = [format ["warmup:%1", BR_var_stateEndTime], BR_var_stateEndTime] call BR_fnc_hudRemainingShare;

            [str _players, "Players", [BR_var_stateEndTime - serverTime] call BR_fnc_formatTime, _share, "Match starts", false, _ai, "AI"]
        }
    };

    BR_var_aliveCounts params ["_aliveUnits"];
    BR_var_zone params ["_phase", "_phaseCount", "", "", "", "", "_shrinkStart", "_shrinkEnd"];
    // phase 1 is the whole play area (BR_fnc_zonePhases): the circles are counted from phase 2 on
    private _zoneNumber = _phase - 1;
    private _zoneCount = _phaseCount - 1;

    private _zone = switch (true) do {
        case (BR_var_state == "ended"): {["--", -1, "Match over", false]};
        // aboard: the time until everyone jumps at the end of the route (BR_var_flightEndTime, serverTime, BR\flight.sqf);
        // the jump prompt itself is at the bottom center (BR_fnc_hudLoop)
        case (player getVariable ["BR_var_aboard", false]): {
            private _flightEnd = missionNamespace getVariable ["BR_var_flightEndTime", -1];

            if (_flightEnd > serverTime) then {
                [[_flightEnd - serverTime] call BR_fnc_formatTime,
                    [format ["flight:%1", _flightEnd], _flightEnd] call BR_fnc_hudRemainingShare, "Forced jump",
                    false]
            } else {
                ["--", -1, "In flight", false]
            }
        };
        case (_phase == 0): {["--", -1, "First zone soon", false]};
        // no zone number before the first circle is marked (BR_fnc_nextZoneShown)
        case (!(call BR_fnc_nextZoneShown)): {
            if (serverTime < _shrinkStart) then {[
                [_shrinkStart - serverTime] call BR_fnc_formatTime,
                [format ["wait:%1", _shrinkStart], _shrinkStart] call BR_fnc_hudRemainingShare,
                "First zone soon",
                false
            ]} else {["--", -1, "First zone soon", false]}
        };
        case (serverTime < _shrinkStart): {[
            [_shrinkStart - serverTime] call BR_fnc_formatTime,
            [format ["wait:%1", _shrinkStart], _shrinkStart] call BR_fnc_hudRemainingShare,
            format ["Zone %1/%2", _zoneNumber, _zoneCount],
            false
        ]};
        case (serverTime < _shrinkEnd): {[
            [_shrinkEnd - serverTime] call BR_fnc_formatTime,
            [format ["shrink:%1", _shrinkEnd], _shrinkEnd, _shrinkStart] call BR_fnc_hudRemainingShare,
            "Zone shrinking",
            true
        ]};
        case (_phase >= _phaseCount): {["--", -1, "Final zone", false]};
        default {["--", -1, format ["Zone %1/%2", _zoneNumber, _zoneCount], false]};
    };

    _zone params ["_timer", "_share", "_status", "_warning"];

    [str _aliveUnits, "Alive", _timer, _share, _status, _warning, str (player getVariable ["BR_var_kills", 0]), "Kills"]
};

// the distance line: [text, as a warning]; empty (hidden) inside the next safe zone and while not on the ground
BR_fnc_hudZoneDistance = {
    if (!alive player || {BR_var_state != "fight"} || {player getVariable ["BR_var_aboard", false]}) exitWith {["", false]};

    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];
    ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];

    private _outside = (player distance2D _center) > _radius;
    // the next zone is not shown before the first shrink (BR_fnc_nextZoneShown): the distance to the current one
    if !(call BR_fnc_nextZoneShown) then {
        _nextCenter = _center;
        _nextRadius = _radius;
    };
    private _toSafeZone = round ((player distance2D _nextCenter) - _nextRadius);

    switch (true) do {
        case (_outside): {[format ["Outside the zone | %1 m", 0 max _toSafeZone], true]};
        case (_toSafeZone > 0): {[format ["Safe zone %1 m", _toSafeZone], false]};
        default {["", false]};
    }
};

// fill 0..1 of the boost bar, 0 = hidden: the player variable BR_var_boost, else from the boost's end time
// (BR_var_boostEnd, serverTime) and length (BR_var_boostDuration) as player or mission variables
BR_fnc_hudBoost = {
    if (!alive player) exitWith {0};

    private _boost = player getVariable "BR_var_boost";

    if (!isNil "_boost") exitWith {0 max (1 min _boost)};

    private _end = player getVariable ["BR_var_boostEnd", missionNamespace getVariable ["BR_var_boostEnd", -1]];

    if (_end <= serverTime) exitWith {0};

    private _duration = player getVariable ["BR_var_boostDuration", missionNamespace getVariable ["BR_var_boostDuration", BR_var_hudBoostDuration]];

    0 max (1 min ((_end - serverTime) / (1 max _duration)))
};

// a team mate's row: [name, value, health 0..1 (-1: no bar), alpha of the texts, value as a warning]
BR_fnc_hudMateRow = {
    params ["_mate"];

    private _name = _mate getVariable ["BR_var_name", name _mate];

    switch (true) do {
        case (!alive _mate): {[_name, "dead", -1, 0.5, false]};
        case (_mate getVariable ["ais_unconscious", false]): {[_name, "down", 1 - damage _mate, 1, true]};
        default {[_name, format ["%1 m", round (player distance _mate)], 1 - damage _mate, 1, false]};
    }
};

// ---- HUD ----

// a control at row _row of a bottom corner (0 = the lowest), keeping its x, width and height; _offset: cells below the
// row's top edge (the thin health bar of a team row)
BR_fnc_hudPlaceRow = {
    params ["_control", "_row", ["_offset", 0]];

    (call UI_fnc_gridCell) params ["", "_cellH"];
    (ctrlPosition _control) params ["_x", "", "_w", "_h"];

    private _y = safeZoneY + safeZoneH - _cellH * (BR_var_hudBottomOffset + _row * (BR_var_hudRowHeight + BR_var_hudRowGap) - _offset);

    _control ctrlSetPosition [_x, _y, _w, _h];
    _control ctrlCommit 0;
};

// a fill control at _share of its panel's width
BR_fnc_hudSetFill = {
    params ["_fill", "_panel", "_share"];

    (ctrlPosition _panel) params ["_x", "_y", "_w", "_h"];

    _fill ctrlSetPosition [_x, _y, _w * (0 max (1 min _share)), _h];
    _fill ctrlCommit 0;
};

// true (and remembered in _shown) when _value differs from what was set last under _key
BR_fnc_hudChanged = {
    params ["_shown", "_key", "_value"];

    if ((_shown getOrDefault [_key, "<none>"]) isEqualTo _value) exitWith {false};

    _shown set [_key, _value];
    true
};

// RscTitles BR_rscHud (BR\ui.hpp); texts, positions and colors are only set when they change
BR_fnc_hudLoop = {
    disableSerialization;

    // view distances of flight and ground, the settings dialog on F4 (below)
    call BR_fnc_initSettings;

    private _hud = uiNamespace getVariable "BR_rscHud";
    private _shown = createHashMap;     // key -> what was set last (BR_fnc_hudChanged)

    private _healthControls = [1200, 1201, 1202] apply {_hud displayCtrl _x};
    private _boostControls = [1210, 1211, 1212] apply {_hud displayCtrl _x};
    private _distanceControl = _hud displayCtrl 1220;
    private _mateControls = [0, 1, 2] apply {
        private _base = 1400 + 10 * _x;
        [_base, _base + 1, _base + 2, _base + 3] apply {_hud displayCtrl _x}
    };

    waitUntil {
        BR_var_myTeammates = call BR_fnc_myTeammates;

        // ---- top center ----
        (call BR_fnc_hudTop) params ["_left", "_leftLabel", "_timer", "_share", "_status", "_warning", "_right", "_rightLabel"];

        {
            _x params ["_idc", "_text"];

            if ([_shown, _idc, _text] call BR_fnc_hudChanged) then {
                (_hud displayCtrl _idc) ctrlSetText _text;
            };
        } forEach [[1300, _left], [1310, _leftLabel], [1303, _timer], [1311, _status], [1304, _right], [1312, _rightLabel]];

        if ([_shown, "timerShare", _share] call BR_fnc_hudChanged) then {
            (_hud displayCtrl 1302) ctrlShow (_share >= 0);
            [_hud displayCtrl 1302, _hud displayCtrl 1301, _share] call BR_fnc_hudSetFill;
        };

        if ([_shown, "statusWarning", _warning] call BR_fnc_hudChanged) then {
            (_hud displayCtrl 1311) ctrlSetTextColor ([BR_var_colorHudText, BR_var_colorWarning] select _warning);
        };

        // ---- bottom center: the jump prompt while aboard ----
        // (after the fade in to the aircraft: BR_fnc_flightClient)
        private _aboard = alive player && {player getVariable ["BR_var_aboard", false]} &&
            {missionNamespace getVariable ["BR_var_flightViewReady", false]};

        if ([_shown, "jumpPrompt", _aboard] call BR_fnc_hudChanged) then {
            (_hud displayCtrl 1230) ctrlSetText "Press Space to jump";
            (_hud displayCtrl 1230) ctrlShow _aboard;
        };

        // ---- bottom right: health, boost, distance; rows that are hidden leave no gap ----
        private _alive = alive player;
        private _hp = [0, ceil ((1 - damage player) * 100)] select _alive;
        private _boost = call BR_fnc_hudBoost;
        ([] call BR_fnc_hudZoneDistance) params ["_distance", "_outside"];

        if ([_shown, "health", [_alive, _hp]] call BR_fnc_hudChanged) then {
            _healthControls params ["_panel", "_fill", "_text"];

            {_x ctrlShow _alive} forEach _healthControls;
            _text ctrlSetText format ["%1 HP", _hp];
            [_fill, _panel, _hp / 100] call BR_fnc_hudSetFill;
            _fill ctrlSetBackgroundColor ([BR_var_colorHealth,
                ((BR_var_colorDanger select [0,
                3]) +[BR_var_colorHealth select 3])] select (_hp < BR_var_hudLowHealth));
        };

        private _boostShown = _boost > 0;

        if ([_shown, "boost", round (_boost * 100)] call BR_fnc_hudChanged) then {
            _boostControls params ["_panel", "_fill", "_text"];

            {_x ctrlShow _boostShown} forEach _boostControls;
            _text ctrlSetText "Boost";
            [_fill, _panel, _boost] call BR_fnc_hudSetFill;
        };

        if ([_shown, "distance", [_distance, _outside]] call BR_fnc_hudChanged) then {
            _distanceControl ctrlSetText _distance;
            _distanceControl ctrlShow (_distance != "");
            _distanceControl ctrlSetTextColor ([BR_var_colorHudText, BR_var_colorWarning] select _outside);
        };

        if ([_shown, "rightRows", _boostShown] call BR_fnc_hudChanged) then {
            // the boost bar did not show for the user (2026-11-23): its visibility to the client RPT
            diag_log format ["BR hud: boost bar %1 (fill %2, end in %3 s)", ["hidden", "shown"] select _boostShown, _boost toFixed 2,
                round ((player getVariable ["BR_var_boostEnd", 0]) - serverTime)];
            {[_x, 1] call BR_fnc_hudPlaceRow} forEach _boostControls;
            [_distanceControl, [1, 2] select _boostShown] call BR_fnc_hudPlaceRow;

            // the fill again at the panel's new place
            _shown deleteAt "boost";
        };

        // ---- bottom left: the team mates, the first one on top ----
        private _mates = (BR_var_myTeammates - [player]) select [0, 3];
        private _mateCount = count _mates;

        {
            private _index = _forEachIndex;
            private _mate = _mates param [_index, objNull];
            private _row = if (isNull _mate) then {[]} else {[_mate] call BR_fnc_hudMateRow};

            if ([_shown, format ["mate%1", _index], [_row, _mateCount]] call BR_fnc_hudChanged) then {
                _x params ["_panel", "_bar", "_name", "_value"];

                {_x ctrlShow (_row isNotEqualTo [])} forEach _x;

                if (_row isNotEqualTo []) then {
                    _row params ["_mateName", "_mateValue", "_health", "_alpha", "_valueWarning"];

                    private _rowIndex = _mateCount - 1 - _index;

                    {[_x, _rowIndex] call BR_fnc_hudPlaceRow} forEach [_panel, _name, _value];

                    _name ctrlSetText (" " + _mateName);
                    _value ctrlSetText (_mateValue + " ");
                    _name ctrlSetTextColor ((BR_var_colorHudText select [0, 3]) + [_alpha]);
                    _value ctrlSetTextColor ([(BR_var_colorHudText select [0, 3]) + [_alpha], BR_var_colorWarning] select _valueWarning);

                    _bar ctrlShow (_health >= 0);

                    // the health as a thin bar along the panel's bottom edge
                    if (_health >= 0) then {
                        (call UI_fnc_gridCell) params ["", "_cellH"];
                        (ctrlPosition _panel) params ["_panelX", "_panelY", "_panelW", "_panelH"];

                        private _barH = BR_var_hudTeamBarHeight * _cellH;

                        _bar ctrlSetPosition [_panelX, _panelY + _panelH - _barH, _panelW * (0 max (1 min _health)), _barH];
                        _bar ctrlCommit 0;
                        _bar ctrlSetBackgroundColor ([BR_var_colorHealth,
                            ((BR_var_colorDanger select [0,
                            3]) +[BR_var_colorHealth select 3])] select (_health <(BR_var_hudLowHealth / 100)
                            ));
                    };
                };
            };
        } forEach _mateControls;

        sleep BR_var_hudInterval;
        false
    };
};

// ---- view distance: the common ground/flight settings of src\shared\ui\settings.sqf (F4) ----

BR_fnc_inFlight = UI_fnc_inFlight;

// scheduled: applies the settings of the flight or the ground whenever they change

// once per client (from BR_fnc_hudLoop): the view loop and the settings key
BR_fnc_initSettings = {
    call UI_fnc_initViewDistance;
    call UI_fnc_initSettings;
};
