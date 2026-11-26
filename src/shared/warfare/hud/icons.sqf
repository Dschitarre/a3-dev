// Icons: base / sector / unit icons on the map and in 3D, built from cached draw arrays (client).

// ---- icons ----

// The icon hooks run in the background gather passes of the mapmarker / tdicons mods (about 10 per second, not per
// frame). Static data (objects, icon paths) is cached; a pass yields after SC_var_iconFrameBudget seconds of work.
SC_var_iconFrameBudget = 0.001;

SC_var_iconMaxAlphaSize = 0.7;

SC_var_iconMinSize = 0.55;

SC_var_baseIconMaxDistance = 15;

SC_var_baseIconIcons = [
    ["inf", "Information", "\A3\ui_f\data\Map\MapControl\powersolar_CA.paa", 1],
    ["tp", "Teleport", "\A3\ui_f\data\IGUI\Cfg\Actions\unloadVehicle_ca.paa", 1],
    ["cs", "Perks", "\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa", 1],
    ["equip", "Loadout", "\A3\ui_f\data\IGUI\Cfg\Actions\gear_ca.paa", 1.5],
    ["veh", "Vehicles", "\A3\ui_f\data\Map\Markers\NATO\c_car.paa", 1]
];

SC_var_baseIconsCache = createHashMap;

SC_var_sectorIconsCache = createHashMap;

// [object, text, icon, size factor] of the base objects of a side and the airfield vehicle shops
SC_fnc_getBaseIcons = {
    params ["_side"];

    private _sideStr = str _side;
    private _icons = SC_var_baseIconsCache get _sideStr;

    if (isNil "_icons") then {
        _icons = SC_var_baseIconIcons apply {
            _x params ["_objectName", "_text", "_icon", "_sizeFactor"];

            [missionNamespace getVariable ("SC_var_" + _sideStr + _objectName), _text, _icon, _sizeFactor]
        } select {!isNil {_x select 0}};

        {
            _icons pushBack [missionNamespace getVariable (format ["SC_var_planeShop%1", _x]), "Vehicles", "\A3\ui_f\data\Map\Markers\NATO\c_plane.paa", 1];
        } forEach SC_var_planeSpawnIds;

        {
            _icons pushBack [_x select 1, "Vehicles", "\A3\ui_f\data\Map\Markers\NATO\c_ship.paa", 1];
        } forEach (missionNamespace getVariable ["SC_var_harbors", []]);

        // the harbours come a few seconds after the start (SC_fnc_createHarbors): cache once they are known
        if (missionNamespace getVariable ["SC_var_harborsReady", true]) then {
            SC_var_baseIconsCache set [_sideStr, _icons];
        };
    };

    _icons
};

// [flag object, letter icon] of a sector
SC_fnc_getSectorIcon = {
    params ["_sector"];

    private _icon = SC_var_sectorIconsCache get _sector;

    if (isNil "_icon") then {
        _icon = [
            missionNamespace getVariable ("SC_var_flag" + _sector + "3d"),
            format ["\A3\ui_f\data\IGUI\Cfg\simpleTasks\letters\%1_ca.paa", _sector]
        ];

        SC_var_sectorIconsCache set [_sector, _icon];
    };

    _icon
};

// background passes: sleeps once the pass used up its frame budget, returns the new slice start
SC_fnc_yieldIfOverBudget = {
    params ["_sliceStart", ["_canSleep", true]];

    if (_canSleep && {(diag_tickTime - _sliceStart) > SC_var_iconFrameBudget}) then {
        sleep 0.001;
        _sliceStart = diag_tickTime;
    };

    _sliceStart
};

// the icon size is factor / distance^0.25 * sqrt zoom and must be at least SC_var_iconMinSize:
// squared distance beyond which an icon is never drawn (to cull early)
SC_fnc_getIconMaxDistanceSqr = {
    params ["_factor", "_viewDis", "_sqrtZoom"];

    (_viewDis min ((_factor * _sqrtZoom / SC_var_iconMinSize) ^ 4)) ^ 2
};

// icon alpha that fades out small (far away) icons
SC_fnc_getIconAlpha = {
    params ["_size"];

    if (_size >= SC_var_iconMaxAlphaSize) then {1} else {1 - ((SC_var_iconMaxAlphaSize - _size) / 0.15)}
};

SC_fnc_updateMapIconsDrawArray = {
    params ["_sleep"];

    private _sliceStart = diag_tickTime;

    {
        private _timeText = [_x] call SC_fnc_getAirdropTimeText;

        if(!isNil "_timeText" &&
            {!MM_var_gpsOpened ||
            {[(uiNamespace getVariable "MM_var_currentDisplay"),
            (getPosWorldVisual _x)] call MM_fnc_isPosVisibleOnGPS}}) then {
            MM_var_preDrawArray pushBack [
                _x, true, 0, false, "iconParachute", MM_var_colorWhite, 16,
                (" " + _timeText), 2, 0.06, true
            ];
        };

        _sliceStart = [_sliceStart, _sleep] call SC_fnc_yieldIfOverBudget;
    } forEach (SC_var_airdropBoxes select {!isNull _x});

    private _playerSide = side (group player);
    private _alivePlayer = alive player;

    {
        private _owner = missionNamespace getVariable ("SC_var_owner" + _x);

        if (
            (_alivePlayer || {!visibleMap} || {_owner != _playerSide}) &&
            {!MM_var_gpsOpened || {[(uiNamespace getVariable "MM_var_currentDisplay"), (getMarkerPos ("SC_var_sector" + _x))] call MM_fnc_isPosVisibleOnGPS}}
        ) then {
            private _flag = ([_x] call SC_fnc_getSectorIcon) select 0;
            private _color = [
                missionNamespace getVariable ("SC_var_holder" + _x),
                1,
                (missionNamespace getVariable ("SC_var_flag" + _x)) / 100
            ] call SC_fnc_getSectorColor;

            MM_var_preDrawArray pushBack [_flag, true, 0, false, "iconLogic", _color, 20, "", 2, 0, true];
            MM_var_preDrawArray pushBack [_flag, true, 50, false, "iconLogic", MM_var_colorWhite, 0, _x, 2, 0.085, true];
        };

        _sliceStart = [_sliceStart, _sleep] call SC_fnc_yieldIfOverBudget;
    } forEach SC_var_sectors;
};

// line of sight from the camera to a 3D icon position; checkVisibility ignores two objects:
// _firstIgnored, then the camera unit's vehicle, then the unit itself (1st person), then _lastIgnored
SC_fnc_isIconVisible = {
    params ["_pos", "_unit", "_par", "_camPosAsl", ["_firstIgnored", []], ["_lastIgnored", []]];

    private _objsToIgnore = +_firstIgnored;

    if !(isNull _par) then {
        _objsToIgnore pushBack _par;
    };

    if (cameraView != "EXTERNAL") then {
        _objsToIgnore pushBack _unit;
    };

    _objsToIgnore append _lastIgnored;
    _objsToIgnore append [objNull, objNull];

    ([(_objsToIgnore select 0), "FIRE", (_objsToIgnore select 1)] checkVisibility [_camPosAsl, (AGLToASL _pos)]) != 0
};

SC_fnc_updateTdIconsDrawArray = {
    params ["_unit", "_par", "_drawUnit", "_group", "_groupUnits", "_side", "_uav", "_hasUav", "_isInUav", "_groupUnitsUavs", "_viewDis", "_camPos", "_camPosAsl", "_zoom", "_sqrtZoom", "_isInSpectator"];

    private _sliceStart = diag_tickTime;

    // base objects: icon above the object, fading out between 10 m and SC_var_baseIconMaxDistance
    {
        _x params ["_obj", "_text", "_icon", "_sizeFactorModification"];

        if ((_camPos distanceSqr _obj) < ((SC_var_baseIconMaxDistance + 1) ^ 2)) then {
            private _pos = _obj modelToWorld [0, 0.1, 0.45];
            private _dis = _camPos distance _pos;

            if (
                (_dis < SC_var_baseIconMaxDistance) &&
                {[_pos] call TDI_fnc_isOnScreen} &&
                {[_pos, _unit, _par, _camPosAsl, [], [_obj]] call SC_fnc_isIconVisible}
            ) then {
                TDI_var_preDrawArray pushBack [
                    _dis,
                    4, _obj,
                    [_icon, [1, 1, 1, (if (_dis <= 10) then {1} else {(-2 * ((_dis - 10) / 10)) + 1})]],
                    ((1.5 * _sizeFactorModification) / (sqrt (sqrt _dis))), false,
                    0, 0, _text, 2, (20 * _sizeFactorModification)
                ];
            };
        };

        _sliceStart = [_sliceStart] call SC_fnc_yieldIfOverBudget;
    } forEach ([_side] call SC_fnc_getBaseIcons);

    if SC_var_showSector3DIcons then {
        private _sectorMaxDistanceSqr = [1.4, _viewDis, _sqrtZoom] call SC_fnc_getIconMaxDistanceSqr;

        {
            ([_x] call SC_fnc_getSectorIcon) params ["_flag", "_letterIcon"];

            private _pos = _flag modelToWorldVisual [0, 0, 1.05];

            if ((_pos distanceSqr _camPos) <= _sectorMaxDistanceSqr) then {
                private _dis = _pos distance _camPos;
                private _sizeFactor = 1.4 / (sqrt (sqrt _dis));
                private _size = _sizeFactor * _sqrtZoom;

                if (
                    (_dis <= _viewDis) &&
                    {_size >= SC_var_iconMinSize} &&
                    {[_pos] call TDI_fnc_isOnScreen} &&
                    {[_pos, _unit, _par, _camPosAsl, [_flag]] call SC_fnc_isIconVisible}
                ) then {
                    private _color = [
                        missionNamespace getVariable ("SC_var_holder" + _x),
                        [_size] call SC_fnc_getIconAlpha,
                        (missionNamespace getVariable ("SC_var_flag" + _x)) / 100
                    ] call SC_fnc_getSectorColor;

                    TDI_var_preDrawArray pushBack [_dis, 3, _flag, [_letterIcon, _color], _sizeFactor, true, 0, 0, "", 2];
                };
            };

            _sliceStart = [_sliceStart] call SC_fnc_yieldIfOverBudget;
        } forEach SC_var_sectors;
    };

    if SC_var_showAirDrop3DIcons then {
        private _boxMaxDistanceSqr = [1.7, _viewDis, _sqrtZoom] call SC_fnc_getIconMaxDistanceSqr;

        {
            private _pos = _x modelToWorldVisual [0, 0, 0];

            // only once the box has landed: none while it hangs on its parachute
            if (((_camPos distanceSqr _pos) <= _boxMaxDistanceSqr) && {isNull (attachedTo _x)}) then {
                private _timeText = [_x] call SC_fnc_getAirdropTimeText;
                private _dis = _camPos distance _pos;
                private _sizeFactor = 1.7 / (sqrt (sqrt _dis));
                private _size = _sizeFactor * _sqrtZoom;

                if (
                    !isNil "_timeText" &&
                    {_dis <= _viewDis} &&
                    {_size >= SC_var_iconMinSize} &&
                    {[_pos] call TDI_fnc_isOnScreen} &&
                    {[_pos, _unit, _par, _camPosAsl, [_x]] call SC_fnc_isIconVisible}
                ) then {
                    TDI_var_preDrawArray pushBack [
                        _dis,
                        2, _x,
                        ["\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa", [1, 1, 1, ([_size] call SC_fnc_getIconAlpha)]],
                        _sizeFactor, true,
                        0, 0, _timeText, 2, 20
                    ];
                };
            };

            _sliceStart = [_sliceStart] call SC_fnc_yieldIfOverBudget;
        } forEach (SC_var_airdropBoxes select {!isNull _x});
    };
};
