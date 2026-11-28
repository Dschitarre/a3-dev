// the map controls of the open displays (main map, spectator, GPS, ...)
BR_fnc_getMapControls = {
    private _displays = [findDisplay 12, findDisplay 60492, findDisplay 314, findDisplay 46];
    _displays append (uiNamespace getVariable ["IGUI_displays", []]);
    private _maps = [];
    {
        {
            if (ctrlType _x in [100, 101]) then {
                _maps pushBackUnique _x;
            };
        } forEach allControls _x;
    } forEach (_displays select {!isNull _x});
    _maps
};

// Battle Royale map and 3D drawing (client): the zones, flight route, team mates and supply drops on every map (main
// map, GPS panel, spectator and splendid camera maps), the zone edges in 3D and the team mates' names over their heads.
// Split from BR\hud.sqf (the on-screen HUD); colors from BR_fnc_initMapColors there.

BR_var_teamIconDistance = 1500; // team mates farther away get no icon over their heads
BR_var_showTeam3DIcons = true;
BR_var_showTeam3DNames = true;
BR_var_mapNamesOnlyOnHover = false; // names next to the map icons by default, never on the GPS
BR_var_showDropMapIcons = true;
BR_var_showZone3D = true;
BR_var_mapMinZoomRadius = 400; // the map opens at least this wide around the next zone
BR_var_mapLineWidth = 4; // px: zone circles and the flight route on the maps ...
BR_var_mapSegmentPixels = 12; // ... a circle drawn as pieces about this many pixels long ...
BR_var_mapSegmentRange = [24, 160]; // ... at least / at most this many
BR_var_mapSegmentOverlap = 1.02; // pieces a bit longer than their share: no gaps at the joints
BR_var_mapDrawCheckInterval = 1; // s: maps that showed up get the zone drawing
BR_var_gpsPanelInterval = 0.25; // s: the GPS is kept in (during the flight: open in) the right info panel this often
BR_var_zoneEdgeDrawDistance = 600; // the zone edges are drawn this far around the camera ...
BR_var_zoneEdgeStep = 15; // ... in pieces this long ...
BR_var_zoneEdgeHeights = [0.5, 10, 20, 30, 40, 50]; // ... as lines at these heights above the ground: a wall
                                                     // that rises over the trees
BR_var_iconMan = "\A3\ui_f\data\map\vehicleicons\iconMan_ca.paa";
BR_var_iconAircraft = "\A3\ui_f\data\map\vehicleicons\iconPlane_ca.paa";
BR_var_iconJumpEnd = "\A3\ui_f\data\map\markers\military\end_CA.paa";
BR_var_iconCrate = "\A3\ui_f\data\map\markers\military\box_CA.paa";

// ---- GPS panel ----
// The GPS shows in the right info panel: open and not closable during the flight, afterwards the GPS key switches it
// off and on there. The left panel's minimap component is switched off (the GPS key then opens the right one); a
// minimap that still shows up on the left (a vehicle's own panels) moves to the right.

// whether the info panel ("left" / "right") shows the minimap (infoPanel: [component class, component type])
BR_fnc_isGpsPanel = {
    params ["_panel"];

    ((str (infoPanel _panel)) find "Minimap") >= 0
};

// opens the GPS in the right panel (by the component's class, else by its type); where that panel has no minimap
// (some vehicle seats) it opens wherever the engine puts it
BR_fnc_showGpsRight = {
    if (["right"] call BR_fnc_isGpsPanel) exitWith {};

    setInfoPanel ["right", "MinimapDisplay"];

    if !(["right"] call BR_fnc_isGpsPanel) then {
        setInfoPanel ["right", "MinimapDisplayComponent"];
    };

    if (!visibleGPS) then {
        openGPS true;
    };
};

// scheduled, the whole session
BR_fnc_gpsPanelLoop = {
    while {true} do {

        // each unit the player controls once (a takeover brings a new one)
        if !(player getVariable ["BR_var_gpsLeftOff", false]) then {
            player setVariable ["BR_var_gpsLeftOff", true];
            player enableInfoPanelComponent ["left", "MinimapDisplay", false];
        };

        // not while the map is open: nothing may close it
        if (!visibleMap) then {
            if (["left"] call BR_fnc_isGpsPanel) then {
                call BR_fnc_showGpsRight;

                if (["right"] call BR_fnc_isGpsPanel) then {
                    setInfoPanel ["left", "EmptyDisplay"];
                };
            };

            if (player getVariable ["BR_var_aboard", false] && {!(["right"] call BR_fnc_isGpsPanel)}) then {
                call BR_fnc_showGpsRight;
            };
        };

        sleep BR_var_gpsPanelInterval;
    };
};

// ---- map ----

// "Map" mission event handler: opens on the next safe zone
BR_fnc_mapZoom = {
    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    // before the first shrink on the current zone (the next one is not shown yet)
    if !(call BR_fnc_nextZoneShown) then {
        ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];
        _nextCenter = _center;
        _nextRadius = _radius;
    };

    mapAnimAdd [0, (call CMN_fnc_mapScaleFactor) * 2 * (_nextRadius max BR_var_mapMinZoomRadius) * 1e-4, _nextCenter];
    mapAnimCommit;
};

/*
    Scheduled: the zones, flight route, team and crates on every map that shows up - the main map, the GPS panel, the
    spectator's map (RscDisplayEGSpectator) and the splendid camera's map (RscDisplayCamera); each map once.
*/
BR_fnc_mapDrawLoop = {
    disableSerialization;

    while {true} do {
        {
            if (!isNull _x && {!(_x getVariable ["BR_var_drawAdded", false])}) then {
                _x setVariable ["BR_var_drawAdded", true];
                _x ctrlAddEventHandler ["Draw", {_this call BR_fnc_drawMap}];
            };
        } forEach (call BR_fnc_getMapControls);

        sleep BR_var_mapDrawCheckInterval;
    };
};

// map "Draw" event handler: current circle (danger color), next safe zone (white), flight route, aircraft and crates
// (accent), then the player and its team mates on top (as in SC, BR_fnc_drawTeamMap)
BR_fnc_drawMap = {
    params ["_map"];

    BR_var_zone params ["_phase", "", "", "", "_nextCenter", "_nextRadius"];

    ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];

    private _metresPerPixel = [_map] call BR_fnc_mapMetresPerPixel;

    // both circles from the first shrink on: before it, the zone is the whole map
    if (call BR_fnc_nextZoneShown) then {
        [_map, _center, _radius, BR_var_colorDanger, _metresPerPixel] call BR_fnc_drawThickCircle;
    };

    if (call BR_fnc_nextZoneShown) then {
        [_map, _nextCenter, _nextRadius, [1, 1, 1, 1], _metresPerPixel] call BR_fnc_drawThickCircle;
    };

    if (BR_var_state == "flight" && {!isNil "BR_var_flightRoute"}) then {
        [_map] call BR_fnc_drawFlight;
    };

    {
        if (!isNull _x) then {
            _map drawIcon [BR_var_iconCrate, BR_var_colorAccent, getPosASL _x, 22, 22, 0, "Supply drop", 1, 0.04, "RobotoCondensed", "right"];
        };
    } forEach ([[], BR_var_airdropCrates] select BR_var_showDropMapIcons);

    [_map] call BR_fnc_drawTeamMap;
};

// ---- team on the maps ----
/*
    The player and its team mates exactly as SC shows its own unit and group mates. SC gets this from the mapmarker
    mod (MM_fnc_addUnitIcon / MM_fnc_addParachuteIcon / MM_fnc_addVehicleIcon / MM_fnc_drawIcons in
    mods\mapmarker\...\drawing.sqf): the man icon turned where the unit looks, the player in the own yellow and the
    mates in white, a heal icon while downed, a parachute or vehicle icon while in one (the vehicle in the color of the
    most own unit inside), the names in white right of the icons on the full maps (not on the GPS), drawn after all
    icons so no icon covers a name. BR can't load that mod: it lists and shows units by side, and in BR all combatants
    share one side (everyone fights everyone) - so only its drawing is duplicated here, for BR's team
    (BR_var_myTeammates). Not taken over: mapmarker's label grouping (a BR team is a few units) and its vehicle icon
    size table (vehicles keep one base size). Values below are mapmarker's.
*/

BR_var_mapIconSizeFactor = 1.15;          // MM_var_iconSizeFactor, times each base size below
BR_var_mapManIconSize = 20;               // on foot ...
BR_var_mapDownedIconSize = 16.3;          // ... downed (AIS) ...
BR_var_mapDeadIconSize = 30;              // ... dead ...
BR_var_mapParachuteIconSize = 13;         // ... under a parachute (MM_var_parachuteIconSize) ...
BR_var_mapVehicleIconSize = 22;           // ... in a vehicle (MM_var_vehicleIconSize)
BR_var_mapManNameOffset = 55;             // name right of a man icon (map units, see BR_var_mapOffsetFactor); of
                                          // parachutes and vehicles three times their base icon size
BR_var_mapNameSize = 0.0495;              // name text size ...
BR_var_mapTextSizeFactor = 1.25;          // ... times this (MM_var_textSizeFactor) ...
BR_var_mapTextZoomReference = 0.1;        // ... with the engine's text growth below this map scale undone ...
BR_var_mapTextZoomMinScale = 0.05;        // ... down to this scale: names keep one size at every zoom
BR_var_mapHoverRadius = 0.02;             // names only on hover: the one nearest to the cursor within this
BR_var_mapEmptyIcon = "#(argb,8,8,3)color(0,0,0,0)";
BR_var_mapFullIdds = [12, 160, 314];      // map, UAV terminal, splendid camera; other map controls are the GPS
BR_var_mapSpectatorIdd = 60492;           // RscDisplayEGSpectator: draws the units on its map itself
BR_var_mapMateColor = [1, 1, 1, 1];
BR_var_mapVehicleIcons = createHashMap;   // vehicle class -> map icon

// metres per name offset unit and map scale (MM_var_mapScaleFactor): the offsets follow the terrain size
BR_var_mapOffsetFactor = call {
    private _mapSizeConfig = configFile >> "CfgWorlds" >> worldName >> "mapSize";

    if (isNull _mapSizeConfig) then {
        private _centerPos = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
        0.0000001 * (_centerPos select 0) * (_centerPos select 1)
    } else {
        0.00035 * getNumber _mapSizeConfig
    }
};

// generic icons of vehicles without a usable own one: [kind, CfgVehicleIcons entry], the first kind wins
BR_var_mapGenericVehicleIcons = [
    ["Car_F", "iconCar"],
    ["Helicopter_Base_F", "iconHelicopter"],
    ["Tank_F", "iconTank"],
    ["Plane_Base_F", "iconPlane"],
    ["Plane", "iconPlane"],
    ["Ship_F", "iconShip"]
];

// the vehicle's own top-down map icon (config "icon"), else a generic one of its kind; cached per class
BR_fnc_mapVehicleIcon = {
    params ["_vehicle"];

    private _type = typeOf _vehicle;
    private _icon = BR_var_mapVehicleIcons get _type;

    if (isNil "_icon") then {
        _icon = getText (configOf _vehicle >> "icon");

        // a texture path is taken as it is; a name has to be a CfgVehicleIcons entry
        if (_icon == "" || {(_icon find "\") == -1 && {!isText (configFile >> "CfgVehicleIcons" >> _icon)}}) then {
            private _index = BR_var_mapGenericVehicleIcons findIf {_vehicle isKindOf (_x select 0)};

            _icon = if (_index == -1) then {"iconStaticAA"} else {(BR_var_mapGenericVehicleIcons select _index) select 1};
        };

        BR_var_mapVehicleIcons set [_type, _icon];
    };

    _icon
};

BR_fnc_mapUnitName = {
    params ["_unit"];

    _unit getVariable ["BR_var_name", name _unit]
};

// "Hunter (destroyed) [J. Doe, A. Smith (dead), + 2 alive]": the first two crew members by name (MM_fnc_vehicleLabel)
BR_fnc_mapVehicleLabel = {
    params ["_vehicle"];

    private _crew = crew _vehicle;
    private _others = _crew select [2];
    private _texts = (_crew select [0, 2]) apply {
        private _name = [_x] call BR_fnc_mapUnitName;

        switch (true) do {
            case (!alive _x): {_name + " (dead)"};
            case ([_x] call BR_fnc_isDownedOnMap): {_name + " (unconscious)"};
            default {_name};
        }
    };
    private _aliveCount = {alive _x} count _others;
    private _deadCount = count _others - _aliveCount;

    if (_aliveCount > 0) then {
        _texts pushBack format ["+ %1 alive", _aliveCount];
    };

    if (_deadCount > 0) then {
        _texts pushBack format ["+ %1 dead", _deadCount];
    };

    getText (configOf _vehicle >> "displayName")
    + (["", " (destroyed)"] select !alive _vehicle)
    + (if (_crew isEqualTo []) then {""} else {" [" + (_texts joinString ", ") + "]"})
};

// downed (AIS) or vanilla incapacitated (MM_fnc_isUnconscious)
BR_fnc_isDownedOnMap = {
    params ["_unit"];

    (_unit getVariable ["AIS_unconscious", false]) || {lifeState _unit == "INCAPACITATED"}
};

// hidden by a script, not by the local render culling (that must not remove map information; MM_fnc_isHiddenForMap)
BR_fnc_isHiddenOnMap = {
    params ["_unit"];

    isObjectHidden _unit && {!(_unit getVariable ["EC_var_culled", false])} && {!(_unit getVariable ["CU_var_culled", false])}
};

// the player and its team mates on one map control (called by BR_fnc_drawMap, every frame)
BR_fnc_drawTeamMap = {
    params ["_map"];

    private _idd = ctrlIDD ctrlParent _map;

    // the EG spectator shows every combatant on its map itself (in SC mapmarker leaves the units to it too)
    if (_idd == BR_var_mapSpectatorIdd) exitWith {};

    private _isGps = !(_idd in BR_var_mapFullIdds);
    private _mapScale = ctrlMapScale _map;
    private _offsetScale = _mapScale * BR_var_mapOffsetFactor;

    // one on-screen name size at every zoom: the engine enlarges drawIcon texts below the reference scale
    private _textSize = BR_var_mapNameSize * BR_var_mapTextSizeFactor *
        ((((_mapScale max BR_var_mapTextZoomMinScale) / BR_var_mapTextZoomReference)) min 1);
    private _forceNames = UI_var_heldWinKeys isNotEqualTo [] && {isGameFocused};
    private _hoverOnly = BR_var_mapNamesOnlyOnHover && {!_forceNames};
    private _mousePos = getMousePosition;
    private _yellow = ["you"] call UI_fnc_color;
    private _units = +BR_var_myTeammates;
    private _drawnVehicles = [];
    private _names = [];     // drawIcon arguments of the names, drawn after all icons
    private _hovered = [];   // names only on hover: [cursor distance, drawIcon arguments] of the nearest name

    _units pushBackUnique player;

    // an icon now, its name (if any is shown) after all icons
    private _drawEntity = {
        params ["_entity", "_icon", "_color", "_size", "_turn", "_name", "_nameOffset"];

        private _pos = getPosWorldVisual _entity;
        private _iconSize = _size * BR_var_mapIconSizeFactor;

        _map drawIcon [_icon, _color, _pos, _iconSize, _iconSize, [0, getDirVisual _entity] select _turn, "", 1];

        if (_isGps || {_name == ""}) exitWith {};

        private _namePos = _pos vectorAdd [_nameOffset * _offsetScale, 0, 0];
        private _args = [BR_var_mapEmptyIcon, BR_var_mapMateColor, _namePos, 0, 0, 0, _name, 2, _textSize, "RobotoCondensed", "right"];

        // hovering the icon shows its name
        if (_hoverOnly) then {
            private _distance = (_map ctrlMapWorldToScreen _pos) distance _mousePos;

            if (_distance < BR_var_mapHoverRadius && {(_hovered isEqualTo []) || {_distance < (_hovered select 0)}}) then {
                _hovered = [_distance, _args];
            };
        } else {
            _names pushBack _args;
        };
    };

    {
        private _unit = _x;
        private _vehicle = objectParent _unit;

        // aboard the transport aircraft the aircraft's own icon (BR_fnc_drawFlight) stands for the unit
        if (
            !isNull _unit && {simulationEnabled _unit} && {!([_unit] call BR_fnc_isHiddenOnMap)} &&
            {!(_unit getVariable ["BR_var_aboard", false])} && {isNull _vehicle || {_vehicle isNotEqualTo (missionNamespace getVariable ["BR_var_aircraft", objNull])}}
        ) then {
            private _color = [BR_var_mapMateColor, _yellow] select (_unit isEqualTo player);

            switch (true) do {
                case (isNull _vehicle): {
                    switch (true) do {
                        // a dead mate in the side color as in SC (white and yellow mark the living)
                        case (!alive _unit): {
                            [_unit, "iconExplosiveGP", [BR_var_colorTeam, _yellow] select (_unit isEqualTo player), BR_var_mapDeadIconSize, true, [_unit] call BR_fnc_mapUnitName, BR_var_mapManNameOffset] call _drawEntity;
                        };
                        case ([_unit] call BR_fnc_isDownedOnMap): {
                            [_unit, "pictureHeal", _color, BR_var_mapDownedIconSize, false, [_unit] call BR_fnc_mapUnitName, BR_var_mapManNameOffset] call _drawEntity;
                        };
                        default {
                            [_unit, "iconMan", _color, BR_var_mapManIconSize, true, [_unit] call BR_fnc_mapUnitName, BR_var_mapManNameOffset] call _drawEntity;
                        };
                    };
                };
                case (_vehicle isKindOf "ParachuteBase"): {
                    [_vehicle, "iconParachute", _color, BR_var_mapParachuteIconSize, false, [_unit] call BR_fnc_mapUnitName, 3 * BR_var_mapParachuteIconSize] call _drawEntity;
                };

                // a vehicle once, yellow with the player inside, else white
                case (!(_vehicle in _drawnVehicles)): {
                    _drawnVehicles pushBack _vehicle;

                    private _vehicleColor = [BR_var_mapMateColor, _yellow] select (player in crew _vehicle);

                    [_vehicle, [_vehicle] call BR_fnc_mapVehicleIcon, _vehicleColor, BR_var_mapVehicleIconSize, true, [_vehicle] call BR_fnc_mapVehicleLabel, 3 * BR_var_mapVehicleIconSize] call _drawEntity;
                };
            };
        };
    } forEach _units;

    {
        _map drawIcon _x;
    } forEach _names;

    if (_hovered isNotEqualTo []) then {
        _map drawIcon (_hovered select 1);
    };
};

// metres of the map per screen pixel (the thick lines keep their width in pixels at every zoom)
BR_fnc_mapMetresPerPixel = {
    params ["_map"];

    (_map ctrlMapScreenToWorld [0.5, 0.5]) distance2D (_map ctrlMapScreenToWorld [0.5 + pixelW, 0.5])
};

// the fill of a solid color (opaque: overlapping pieces show no seams)
BR_fnc_mapFill = {
    params ["_color"];

    format ["#(rgb,8,8,3)color(%1,%2,%3,1)", _color select 0, _color select 1, _color select 2]
};

// a straight piece of a thick line: a filled rectangle from _from to _to, _width metres wide, a bit longer (no gaps)
BR_fnc_drawThickSegment = {
    params ["_map", "_from", "_to", "_color", "_fill", "_width"];

    private _length = _from distance2D _to;

    if (_length <= 0) exitWith {};

    _map drawRectangle [
    (_from vectorAdd _to) vectorMultiply 0.5,
    _width / 2,
    _length / 2 * BR_var_mapSegmentOverlap + _width / 2,
    _from getDir _to,
    _color,
    _fill
    ];
};

/*
    A circle BR_var_mapLineWidth pixels wide: filled rectangles along it (offset ellipses and lines aliased into a
    dashed pattern), as many as its length on the screen needs (BR_var_mapSegmentPixels each).
*/
BR_fnc_drawThickCircle = {
    params ["_map", "_center", "_radius", "_color", "_metresPerPixel"];

    if (_radius <= 0) exitWith {};

    private _opaque = (_color select [0, 3]) + [1];
    private _fill = [_opaque] call BR_fnc_mapFill;
    private _width = BR_var_mapLineWidth * _metresPerPixel;
    BR_var_mapSegmentRange params ["_minCount", "_maxCount"];

    // (max / min bind tighter than select: "range select 0 max x" was "range select (0 max x)", out of range - no circle)
    private _count = (_minCount max (round (2 * pi * _radius / (_metresPerPixel max 0.001) / BR_var_mapSegmentPixels))) min _maxCount;
    private _step = 360 / _count;
    private _previous = _center getPos [_radius, 0];

    for "_i" from 1 to _count do {
        private _next = _center getPos [_radius, _i * _step];

        [_map, _previous, _next, _opaque, _fill, _width] call BR_fnc_drawThickSegment;
        _previous = _next;
    };
};

// a line BR_var_mapLineWidth pixels wide: one filled rectangle
BR_fnc_drawThickLine = {
    params ["_map", "_from", "_to", "_color", "_metresPerPixel"];

    private _opaque = (_color select [0, 3]) + [1];

    [_map, _from, _to, _opaque, [_opaque] call BR_fnc_mapFill, BR_var_mapLineWidth * _metresPerPixel] call BR_fnc_drawThickSegment;
};

// the flight: route (accent), the aircraft with the time left until everyone has to jump and the last jump point
BR_fnc_drawFlight = {
    params ["_map"];

    private _metresPerPixel = [_map] call BR_fnc_mapMetresPerPixel;

    for "_i" from 1 to count BR_var_flightRoute - 1 do {
        [_map, BR_var_flightRoute select (_i - 1), BR_var_flightRoute select _i, BR_var_colorAccent,
            _metresPerPixel] call BR_fnc_drawThickLine;
    };

    if (!isNil "BR_var_flightJumpEndPos") then {
        _map drawIcon [BR_var_iconJumpEnd, BR_var_colorDanger, BR_var_flightJumpEndPos, 18, 18, 0, "Last jump", 1, 0.04, "RobotoCondensed", "right"];
    };

    if (!isNull BR_var_aircraft) then {
        private _left = 0 max ((missionNamespace getVariable ["BR_var_flightEndTime", serverTime]) - serverTime);
        private _seconds = floor (_left % 60);

        _map drawIcon [
        BR_var_iconAircraft,
        BR_var_colorAccent,
        getPosASLVisual BR_var_aircraft,
        26,
        26,
        getDirVisual BR_var_aircraft,
        format ["%1:%2%3", floor (_left / 60), ["", "0"] select (_seconds < 10), _seconds],
        1,
        0.045,
        "RobotoCondensedBold",
        "right"
        ];
    };
};

// ---- zone in 3D ----

// "Draw3D" mission event handler, only while the spectator is open (playing, the map and the GPS show the zone): the edges of the current circle (danger color) and the next safe zone (white) near the camera, as a wall
// of lines over the ground (BR_var_zoneEdgeHeights)
BR_fnc_drawZone3D = {
    if (!BR_var_showZone3D) exitWith {};

    if !(BR_var_state in ["flight", "fight"]) exitWith {};
    if (isNull (findDisplay 60492)) exitWith {};

    private _camera = positionCameraToWorld [0, 0, 0];

    BR_var_zone params ["_phase", "", "", "", "_nextCenter", "_nextRadius"];

    if (call BR_fnc_nextZoneShown) then {
        ([] call BR_fnc_zoneCurrent) params ["_center", "_radius"];

        [_center, _radius, _camera, BR_var_colorDanger] call BR_fnc_drawCircleEdge3D;
    };

    if (call BR_fnc_nextZoneShown) then {
        [_nextCenter, _nextRadius, _camera, BR_var_colorZoneNext] call BR_fnc_drawCircleEdge3D;
    };
};

// the part of a circle's edge within BR_var_zoneEdgeDrawDistance of the camera
BR_fnc_drawCircleEdge3D = {
    params ["_center", "_radius", "_camera", "_color"];

    if (_radius < 1 || {abs ((_camera distance2D _center) - _radius) > BR_var_zoneEdgeDrawDistance}) exitWith {};

    private _baseAngle = _center getDir _camera;
    private _halfArc = deg ((BR_var_zoneEdgeDrawDistance / _radius) min pi);
    private _step = deg (BR_var_zoneEdgeStep / _radius);
    private _previous = [];

    for "_angle" from (_baseAngle - _halfArc) to (_baseAngle + _halfArc) step _step do {
        private _point = [_center getPos [_radius, _angle]] call BR_fnc_groundPos;

        if (_previous isNotEqualTo []) then {
            {
                drawLine3D [_previous vectorAdd [0, 0, _x], _point vectorAdd [0, 0, _x], _color];
            } forEach BR_var_zoneEdgeHeights;
        };

        _previous = _point;
    };
};

// ---- team icons ----

// "Draw3D" mission event handler: names over the living team mates
BR_fnc_drawTeamIcons = {
    if (!alive player || {!BR_var_showTeam3DIcons}) exitWith {};

    {
        if(alive _x && {_x != player} && {simulationEnabled _x} &&
            {player distance _x <(BR_var_teamIconDistance min (getObjectViewDistance select 0))}) then {
            drawIcon3D [
            BR_var_iconMan,
            BR_var_colorTeam,
            _x modelToWorldVisual [0, 0, 2.2],
            0.6,
            0.6,
            0,
            ["", _x getVariable ["BR_var_name", name _x]] select (BR_var_showTeam3DNames || {UI_var_heldWinKeys isNotEqualTo [] && {isGameFocused}}),
            1,
            0.03,
            "RobotoCondensed",
            "center"
            ];
        };
    } forEach BR_var_myTeammates;
};
