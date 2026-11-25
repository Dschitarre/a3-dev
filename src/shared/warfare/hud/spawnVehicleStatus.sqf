// HUD (client): the own side's spawn trucks / helicopters (SC\vehicles\spawnVehicles.sqf) at the bottom of the player
// stats panel's left column (bottom right, SC_fnc_hudLayoutPlayerStats): per spawn vehicle an HP bar labelled with its
// name (no HP number) and left of it a direction arrow that points from the camera towards the vehicle, or the countdown
// until a lost one is replaced.

SC_var_hudSpawnVehicleRows = 3;             // controls in SC\hud\hudDisplay.hpp: fill 9410 + n, whole bar 9420 + n,
                                            // label 9430 + n, arrow 9440 + n, timer 9450 + n, circle 9460 + n
SC_var_hudCompassNeedleAngle = 0;           // the pointer picture points this many degrees clockwise from up
SC_var_hudPointerBoxScale = 1.1;            // arrow box height relative to the row (the arrow fills two thirds of it)
SC_var_hudSpawnTimerWidth = 2;              // respawn countdown width relative to the row height ("8:88" in the bar font)
SC_var_hudSpawnVehicleLostAlpha = 0.5;      // label of a lost spawn vehicle until its replacement arrives
SC_var_hudSpawnVehicles = [];               // vehicles of the rows (objNull while lost), for the compasses

// [[name, vehicle (objNull while lost), server time of its replacement (-1: unknown)], ...] of the player's side in
// the order of SC_var_spawnVehicleKinds; the vehicles are found by the names the server gives them
// (SC_fnc_initSpawnVehiclesServer)
SC_fnc_hudSpawnVehicleRows = {
    private _side = side (group player);
    private _vehicles = (missionNamespace getVariable ["SC_var_spawnVehicles", []]) select {(_x select 1) == _side};
    private _respawns = (missionNamespace getVariable ["SC_var_spawnVehicleRespawns", []]) select {(_x select 0) == _side};
    private _rows = [];

    {
        _x params ["_kind", "_count"];

        private _baseName = SC_var_spawnVehicleNames getOrDefault [_kind, ""];

        for "_i" from 1 to _count do {
            private _name = [_baseName, format ["%1 %2", _baseName, _i]] select (_count > 1);
            private _index = _vehicles findIf {(_x select 2) == _name};
            private _vehicle = if (_index == -1) then {objNull} else {(_vehicles select _index) select 0};

            private _respawnIndex = _respawns findIf {(_x select 1) == _name};
            private _respawnAt = if (_respawnIndex == -1) then {-1} else {(_respawns select _respawnIndex) select 2};

            _rows pushBack [_name, ([objNull, _vehicle] select (alive _vehicle)), _respawnAt];
        };
    } forEach (missionNamespace getVariable ["SC_var_spawnVehicleKinds", []]);

    _rows select [0, SC_var_hudSpawnVehicleRows]
};

/*
    Sizes and places the rows (from SC_fnc_hudLayoutPlayerStats, same units: shares of the safe zone, x from the left,
    top from the bottom edge, right aligned): at the bottom of the panel's left column (user decision 2026-11-13), the
    first spawn vehicle at the top, as wide and high as the bars of the panel (_barWidth, _height, gap _gapY), the names
    in their font (SC_var_hudBarFontHeight), smaller only if the longest name doesn't fit; the direction arrows and the
    respawn countdowns left of the bars. _rowCount rows are used; returns the top of the topmost one (_bottomTop without
    rows). Without animation (user decision), also the health fill.
*/
SC_fnc_hudLayoutSpawnVehicles = {
    params ["_display", "_barWidth", "_height", "_gapX", "_gapY", "_barX", "_bottomTop", "_rowCount"];

    // widest name (with a number, if a kind can come twice), 10 % margin
    private _barWidthAbs = ([0, 0, _barWidth, 0, "RIGHT"] call SC_fnc_transformAlignToSafezone) select 2;
    private _fontHeight = selectMin ((values SC_var_spawnVehicleNames) apply {
        [(_x + " 2"), (0.9 * _barWidthAbs), SC_var_hudBarFontHeight] call SC_fnc_hudFitFontHeight
    });

    SC_var_hudSpawnVehicleRowCount = _rowCount;

    // left of the bar a round panel as wide as the row is high (user decision), the arrow centred in it: the arrow
    // (SC\hud\pointer_ca.paa) fills the middle two thirds of its texture, its box is SC_var_hudPointerBoxScale times the
    // row height (square, see SC_fnc_transformAlignToSafezone), so it stays inside the circle however it is turned
    private _circleWidth = _height * 9 / 16;
    private _circleX = _barX - _gapX - _circleWidth;
    private _arrowHeight = SC_var_hudPointerBoxScale * _height;
    private _arrowWidth = _arrowHeight * 9 / 16;
    private _arrowX = _circleX + 0.5 * _circleWidth - 0.5 * _arrowWidth;

    // unused rows (hidden by SC_fnc_hudUpdateSpawnVehicles) below the used ones
    for "_row" from 0 to (SC_var_hudSpawnVehicleRows - 1) do {
        private _top = _bottomTop + _height + (_rowCount - 1 - _row) * (_height + _gapY);
        private _fill = _display displayCtrl (9410 + _row);

        [_display, [9410 + _row, 9420 + _row, 9430 + _row], [_barX, _top, _barWidth, _height], 0] call SC_fnc_hudPlaceRight;
        [_display, [9460 + _row], [_circleX, _top, _circleWidth, _height], 0] call SC_fnc_hudPlaceRight;
        [_display, [9440 + _row], [_arrowX, _top + 0.5 * (_arrowHeight - _height), _arrowWidth, _arrowHeight], 0] call SC_fnc_hudPlaceRight;

        // the respawn countdown of a lost one where the arrow is, right aligned, room for "8:88"
        [_display,[9450 + _row],
            [_barX - _gapX -(SC_var_hudSpawnTimerWidth * _height), _top,(SC_var_hudSpawnTimerWidth * _height),
            _height], 0] call SC_fnc_hudPlaceRight;

        (_display displayCtrl (9430 + _row)) ctrlSetFontHeight _fontHeight;
        (_display displayCtrl (9450 + _row)) ctrlSetFontHeight _fontHeight;

        // the full bar (100 % health) and the fill at once at its health (unknown yet: by the next update)
        private _fullPos = [_barX, _top, _barWidth, _height, "RIGHT"] call SC_fnc_transformAlignToSafezone;
        _fullPos params ["_fullX", "_fullY", "_fullW", "_fullH"];

        _fill setVariable ["SC_var_fullPos", _fullPos];
        _fill ctrlSetPosition [_fullX, _fullY, _fullW * (0 max (_fill getVariable ["SC_var_health", 0])), _fullH];
        _fill ctrlCommit 0;
    };

    if (isNil "SC_var_hudCompassEh") then {
        SC_var_hudCompassEh = addMissionEventHandler ["EachFrame", {call SC_fnc_hudUpdateSpawnVehicleCompasses}];
    };

    [_bottomTop, _bottomTop + _rowCount * _height + (_rowCount - 1) * _gapY] select (_rowCount > 0)
};

// with the player stats (SC_fnc_hudUpdatePlayerStats): which rows are shown, labels and health
SC_fnc_hudUpdateSpawnVehicles = {
    params ["_display"];

    private _rows = call SC_fnc_hudSpawnVehicleRows;

    // another number of spawn vehicles than laid out (their list arrived, side switch): the left column at once (this
    // runs again from there with the matching layout)
    if ((count _rows) != (missionNamespace getVariable ["SC_var_hudSpawnVehicleRowCount", -1])) exitWith {
        [true, 0] call SC_fnc_hudUpdatePlayerStats;
    };

    SC_var_hudSpawnVehicles = _rows apply {_x select 1};

    for "_row" from 0 to (SC_var_hudSpawnVehicleRows - 1) do {
        (_rows param [_row, []]) params [["_label", ""], ["_vehicle", objNull], ["_respawnAt", -1]];

        private _shown = _label != "";
        private _fill = _display displayCtrl (9410 + _row);
        private _labelCtrl = _display displayCtrl (9430 + _row);

        {
            _x ctrlShow _shown;
        } forEach [_fill, (_display displayCtrl (9420 + _row)), _labelCtrl];

        // the direction arrow and its round panel not on the map (user)
        {
            (_display displayCtrl _x) ctrlShow (_shown && {alive _vehicle} && {!visibleMap});
        } forEach [9440 + _row, 9460 + _row];

        // lost: the time until the replacement is ready at the base ("2:30")
        private _timerCtrl = _display displayCtrl (9450 + _row);
        private _timerShown = _shown && {!(alive _vehicle)} && {_respawnAt >= 0};

        _timerCtrl ctrlShow _timerShown;

        if (_timerShown) then {
            [_timerCtrl, ([0 max (ceil (_respawnAt - serverTime))] call SC_fnc_secondsToMinSec)] call SC_fnc_hudSetText;
        };

        if (_shown) then {
            private _health = if (alive _vehicle) then {1 - (damage _vehicle)} else {0};

            [_labelCtrl, _label] call SC_fnc_hudSetText;
            _labelCtrl ctrlSetTextColor [1, 1, 1, ([SC_var_hudSpawnVehicleLostAlpha, 1] select (alive _vehicle))];

            if ((_fill getVariable ["SC_var_health", -1]) != _health) then {
                _fill setVariable ["SC_var_health", _health];
                (_fill getVariable ["SC_var_fullPos", (ctrlPosition _fill)]) params ["_fullX", "_fullY", "_fullW", "_fullH"];
                _fill ctrlSetPosition [_fullX, _fullY, _fullW * _health, _fullH];
                _fill ctrlCommit 0;
            };
        };
    };

    // the earplugs icon sits above the panel's right column (SC_fnc_earplugsIconPosition): it follows a new layout at once
    if (!isNil "E_fnc_refreshIconPosition") then {
        call E_fnc_refreshIconPosition;
    };
};

// every frame (EachFrame handler of SC_fnc_hudLayoutSpawnVehicles): turns every arrow so that it points towards its
// spawn vehicle, relative to the view direction
SC_fnc_hudUpdateSpawnVehicleCompasses = {
    private _display = uiNamespace getVariable ["SC_var_sectorControlDisplay", displayNull];

    if (isNull _display) exitWith {};

    // the map opened / closed: the arrows go / come back at once (user: no delay), not with the next player stats update
    if (visibleMap != (missionNamespace getVariable ["SC_var_hudSpawnVehicleMapOpen", false])) then {
        SC_var_hudSpawnVehicleMapOpen = visibleMap;
        [_display] call SC_fnc_hudUpdateSpawnVehicles;
    };

    if (SC_var_hudSpawnVehicles isEqualTo []) exitWith {};

    private _cameraPos = positionCameraToWorld [0, 0, 0];
    private _viewDir = (positionCameraToWorld [0, 0, 1]) vectorDiff _cameraPos;
    private _heading = (_viewDir select 0) atan2 (_viewDir select 1);

    {
        if (alive _x) then {
            private _bearing = _cameraPos getDir (getPosWorldVisual _x);
            (_display displayCtrl (9440 + _forEachIndex)) ctrlSetAngle [(_bearing - _heading - SC_var_hudCompassNeedleAngle), 0.5, 0.5];
        };
    } forEach SC_var_hudSpawnVehicles;
};
