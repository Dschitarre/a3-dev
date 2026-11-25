// Map markers (client): unit, vehicle and parachute icons with names on the map, GPS, UAV terminal and camera
// map. A background pass rebuilds the draw array while a map is drawn; the Draw handlers only place the icons.

MM_var_clientRunning = false;
MM_var_attachDrawLoopScript = scriptNull;
MM_var_reportShownSidesLoopScript = scriptNull;
MM_var_updateDrawArrayLoopScript = scriptNull;
MM_var_updateDrawArrayScript = scriptNull;

MM_var_frameBudget = 0.002;          // seconds of draw-array work per frame
MM_var_drawArrayInterval = 0.2;      // minimum seconds between two draw-array passes
MM_var_hoverRadius = 0.02;           // screen distance for "names only on hover"
MM_var_font = "RobotoCondensed";     // GUI_FONT_NORMAL
MM_var_emptyIcon = "#(argb,8,8,3)color(0,0,0,0)";   // invisible icon for texts drawn after all icons

// Icons and texts have a constant size at every map zoom (user decision): the icons their fixed size in pixels, the
// texts MM_var_textSizeFactor times their base size (1: the full size of the former zoom-dependent texts). The engine
// enlarges drawIcon texts when zoomed in, so below the map scale MM_var_textZoomReference the text size is multiplied by
// ((scale max MM_var_textZoomMinScale) / MM_var_textZoomReference) ^ MM_var_textZoomExponent; the label grouping
// assumes the resulting constant on-screen size (the size at the reference scale). All these can be set by missions
// before the mod loads and changed at any time (debug console, local): texts follow at once, icons and the label
// grouping with the next draw-array pass.
if (isNil "MM_var_textSizeFactor") then {
    MM_var_textSizeFactor = 1.25;     // tuned in game
};
if (isNil "MM_var_iconSizeFactor") then {
    MM_var_iconSizeFactor = 1.15;     // tuned in game
};
if (isNil "MM_var_vehicleIconSize") then {
    MM_var_vehicleIconSize = 22;       // base size of every vehicle icon (before its area scale and MM_var_iconSizeFactor)
};
if (isNil "MM_var_parachuteIconSize") then {
    MM_var_parachuteIconSize = 13;     // parachutes (before MM_var_iconSizeFactor; was 16, user: a bit smaller)
};
if (isNil "MM_var_textZoomReference") then {
    MM_var_textZoomReference = 0.1;      // map scale from which on the engine leaves the text size as it is
};
if (isNil "MM_var_textZoomExponent") then {
    MM_var_textZoomExponent = 1;         // measured in game: the engine enlarges the text like the zoom between the scales
                                         // 0.1 and 0.05 (twice as large at 0.05) and keeps it constant outside
};
if (isNil "MM_var_textZoomMinScale") then {
    MM_var_textZoomMinScale = 0.05;      // smallest scale the compensation follows (the old curve stopped there)
};

// overlapping labels (names) group on the map, not on the GPS: only the most relevant one is drawn, with the number of
// units of the others (MM_fnc_groupLabels); the icons are always drawn
if (isNil "MM_var_groupLabels") then {
    MM_var_groupLabels = true;
};
MM_var_groupCellSize = 0.1;          // grid cell of the grouping in screen units (about two text lines)
MM_var_groupCountSpace = "+99";      // room each label keeps for its group count
MM_var_groupRescale = 0.1;           // relative map zoom change after which the labels group anew at once
MM_var_groupScale = 0;               // map scale of the last grouping
MM_var_groupHoverEntity = objNull;   // entity with a label nearest to the mouse (within MM_var_hoverRadius): grouped first
MM_var_groupHoverChanged = false;    // it changed since the last grouping: group anew at once

MM_var_bucketCheckInterval = 1;     // seconds between two checks for units that changed their side
MM_var_bucketCheckTime = 0;
MM_var_moveBlendTime = 0.5;          // seconds over which an icon glides from where it is shown onto a new server state
MM_var_moveSnapDistance = 100;       // metres: an icon further away from a new server position jumps there
MM_var_spectatorDisplay = 60492;     // RscDisplayEGSpectator

// the map control of each display; 12 (map), 160 (UAV terminal), 314 (camera) and the EG spectator are full maps, 311
// (GPS panel, an IGUI display) and map controls of game modes are minimaps. The camera and the EG spectator map show
// all sides; the EG spectator draws units and crewed vehicles on its map itself, so there only the vehicles shown
// while empty are added (MM_var_showWhenEmpty, below).
MM_var_mapControlIdcs = createHashMapFromArray [[12, 51], [160, 51], [314, 3141], [311, 101], [MM_var_spectatorDisplay, 62609]];
MM_var_fullMapIdds = [12, 160, 314, MM_var_spectatorDisplay];
MM_var_allSidesMapIdds = [314, MM_var_spectatorDisplay];

if (isNil "MM_var_posBroadcastInterval") then {
    MM_var_posBroadcastInterval = 0.3;   // set by the server
};

if (isNil "MM_var_predictionTime") then {
    MM_var_predictionTime = 3;           // set by the server
};

// ---- colors ----
// Side colors: a fixed palette (clearer on the map than the vanilla defaults); MM_fnc_refreshColors is kept as the
// single place that (re)builds MM_var_colors.

MM_var_colorRefreshInterval = 5;
MM_var_colorRefreshTime = 0;

// fixed side colors (the mod's own palette, deliberately not the player's map color settings)
MM_var_colorSources = createHashMapFromArray [
    ["west", [0, 0.5, 1, 1]],
    ["east", [1, 0, 0, 1]],
    ["guer", [0, 0.8, 0.27, 1]],
    ["civ", [0.75, 0.75, 0.75, 1]],
    ["unknown", [0.75, 0.75, 0.75, 1]]
];

MM_var_sideKeys = createHashMapFromArray [[west, "west"], [east, "east"], [independent, "guer"], [civilian, "civ"]];

MM_fnc_refreshColors = {
    MM_var_colors = +MM_var_colorSources;
    MM_var_colorDefault = MM_var_colors get "unknown";
    MM_var_colorRefreshTime = diag_tickTime + MM_var_colorRefreshInterval;
};

call MM_fnc_refreshColors;

// own unit (yellow) and group members (white), as before the UI rework
MM_var_colorYellow = [1, 0.83, 0, 1];
MM_var_colorWhite = [1, 1, 1, 1];

MM_fnc_sideColor = {
    params ["_side"];

    MM_var_colors get (MM_var_sideKeys getOrDefault [_side, "unknown"])
};

MM_fnc_unitSideColor = {
    params ["_unit"];

    [[_unit] call MM_fnc_unitSide] call MM_fnc_sideColor
};

uiNamespace setVariable ["MM_var_currentDisplay", controlNull];   // the map control drawn last

// game modes add functions (argument: [scheduled]) that push their own entries into MM_var_preDrawArray;
// entry format: [entity, isWithinObjectViewDistance, offsetToRight, calculateDir, icon, color, size, text,
// shadow, textSize, alwaysShow, labelRelevance] - labelRelevance optional, only for text-only entries (size 0):
// -1 (default) never groups, the text is always drawn (sector / base markers, ...); >= 0 the text is a label that
// groups with overlapping labels: the most relevant one is drawn as "text +X" with the units of the others
// (scale: MM_fnc_unitRelevance, units: MM_fnc_unitCount of the entity). Icons never group.
MM_var_gatherDrawArrFncs = [];
MM_var_preDrawArray = [];
MM_var_drawArray = [];
MM_var_lastDrawArrUpdateFrameNo = 0;
MM_var_lastDrawFrameNo = 0;
MM_var_gpsOpened = false;
MM_var_spectatorMapOpened = false;
MM_var_showUnitNamesOverride = true;
MM_var_showAllSidesOverride = false;

// Vehicles are drawn through their crew. A game mode can show a vehicle also without living crew: the public object
// variable MM_var_showWhenEmpty (a side) draws it, while alive, for the viewers of that side (by the normal rules: GPS
// area, hidden, all sides on the camera / spectator) in that side's color; MM_var_emptyLabel (optional, public) is
// its label while empty, else the vehicle name. With crew it is drawn as any vehicle.

// ---- helpers ----

MM_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in typeOf _unit
};

// unconscious (AIS or vanilla revive)
MM_fnc_isUnconscious = {
    params ["_unit"];

    (_unit getVariable ["AIS_unconscious", false]) || {lifeState _unit == "INCAPACITATED"}
};

// dead or in the (EG) spectator; a unit under Zeus remote control is no spectator
MM_fnc_isSpectator = {
    !alive player || {!isNull findDisplay MM_var_spectatorDisplay}
};

MM_fnc_uavControlUnits = {
    params ["_vehicle", ["_onlyControlling", false]];

    private _uavControl = UAVControl _vehicle;
    private _controls = [_uavControl select [0, 2]];

    if (count _uavControl == 4) then {
        _controls pushBack (_uavControl select [2, 2]);
    };

    if (_onlyControlling) then {
        (_controls select {(_x select 1) != ""}) apply {_x select 0}
    } else {
        (_controls select {!isNull (_x select 0)}) apply {_x select 0}
    }
};

// the unit controlling the UAV in _mode (e.g. "DRIVER"), else in _altMode
MM_fnc_uavControl = {
    params ["_vehicle", "_mode", ["_altMode", ""]];

    private _uavControl = UAVControl _vehicle;
    private _controls = [_uavControl select [0, 2]];

    if (count _uavControl == 4) then {
        _controls pushBack (_uavControl select [2, 2]);
    };

    private _seats = _controls apply {_x select 1};
    private _index = _seats find _mode;

    if (_index == -1 && {_altMode != ""}) then {
        _index = _seats find _altMode;
    };

    if (_index == -1) then {objNull} else {(_controls select _index) select 0}
};

// the unit the map is shown for: the focused unit, for a UAV view its operator
MM_fnc_viewUnit = {
    if (unitIsUAV focusOn) then {[objectParent focusOn, "DRIVER", "GUNNER"] call MM_fnc_uavControl} else {focusOn}
};

// the sides whose units are shown for _unit: its own, or all (setting, spectator, camera map)
MM_fnc_shownSides = {
    params ["_unit"];

    if (MM_var_showAllSidesOverride || {MM_var_showAllSides} || {MM_var_showAllSidesOnSpectator && {call MM_fnc_isSpectator}}) exitWith {
        [west, east, independent, civilian]
    };

    [[_unit] call MM_fnc_unitSide]
};

// crew of a vehicle; for a UAV its operators instead of the UAV AI
MM_fnc_getCrew = {
    params ["_vehicle"];

    if (!unitIsUAV _vehicle) exitWith {crew _vehicle};

    private _crew = (crew _vehicle) select {!([_x] call MM_fnc_isUavAi)};

    {
        _crew pushBackUnique _x;
    } forEach ([_vehicle] call MM_fnc_uavControlUnits);

    _crew
};

// game modes may replace this
MM_fnc_getGroupUnits = {
    params ["_unit"];

    units group _unit
};

MM_fnc_isPosVisibleOnGps = {
    params ["_ctrlGps", "_posWorld"];

    if (isNull _ctrlGps) exitWith {false};

    (ctrlMapPosition _ctrlGps) params ["_mapX", "_mapY", "_mapWidth", "_mapHeight"];
    (_ctrlGps ctrlMapWorldToScreen _posWorld) params ["_screenX", "_screenY"];

    private _gpsX = 0.012771 - ((_mapX - _screenX) / _mapWidth);
    private _gpsY = 1.128351 + ((_mapY - _screenY) / _mapHeight);

    _gpsX >= 0 && {_gpsX <= 1} && {_gpsY >= 0} && {_gpsY <= 1}
};

// weapon class -> BIS_fnc_itemType type ("MachineGun", "SniperRifle", ...), cached
MM_var_weaponTypes = createHashMap;

MM_fnc_weaponType = {
    params ["_weapon"];

    private _type = MM_var_weaponTypes get _weapon;

    if (isNil "_type") then {
        _type = ([_weapon] call BIS_fnc_itemType) select 1;
        MM_var_weaponTypes set [_weapon, _type];
    };

    _type
};

// ---- names ----
// Built here from the unit's name and whether a player controls it - both change when a player takes over an AI
// unit or hands it back. A game mode may set its own name (MM_var_name); a dead unit keeps the controller of its death.

// player name, or a short AI name: "John Doe" -> "J. Doe (AI)", "Jean-Luc Picard" -> "J.-L. Picard (AI)"
MM_fnc_formatName = {
    params ["_name", "_isPlayer"];

    if (_isPlayer) exitWith {_name};

    private _nameParts = _name splitString " ";

    if (count _nameParts > 1) then {
        private _firstNames = (_nameParts select 0) splitString "-";
        private _lastName = _nameParts select 1;

        _name = if (count _firstNames > 1) then {
            ((_firstNames select 0) select [0, 1]) + ".-" + ((_firstNames select 1) select [0, 1]) + ". " + _lastName
        } else {
            ((_nameParts select 0) select [0, 1]) + ". " + _lastName
        };
    };

    _name + " (AI)"
};

// the shown name of a unit, cached per name and controller
MM_fnc_unitName = {
    params ["_unit"];

    if (isNull _unit) exitWith {""};

    private _override = _unit getVariable "MM_var_name";

    if (!isNil "_override") exitWith {_override};

    private _isPlayer = if (alive _unit) then {isPlayer _unit} else {_unit getVariable ["MM_var_wasPlayer", isPlayer _unit]};
    private _source = [name _unit, _isPlayer];

    (_unit getVariable ["MM_var_nameCache", [[], ""]]) params ["_cachedSource", "_cachedName"];

    if (_source isEqualTo _cachedSource) exitWith {_cachedName};
    if ((_source select 0) == "") exitWith {""};

    private _name = _source call MM_fnc_formatName;

    _unit setVariable ["MM_var_nameCache", [_source, _name]];
    _name
};

// ---- unit lists ----
// One list per side (MM_var_units<side>), filled when the server announces a unit, emptied by "Deleted" and kept
// up to date when a unit changes its side (e.g. a player taking over a unit of another group).

MM_var_bucketSides = [west, east, independent, civilian, sideEmpty, sideLogic, sideAmbientLife, sideUnknown];

MM_fnc_getSideString = {
    params ["_side"];

    if (_side == sideAmbientLife) then {"AmbientLife"} else {str _side}
};

MM_fnc_resetUnitBuckets = {
    {
        missionNamespace setVariable ["MM_var_units" + ([_x] call MM_fnc_getSideString), []];
    } forEach MM_var_bucketSides;

    MM_var_emptyShownVehicles = [];   // vehicles with MM_var_showWhenEmpty
};

call MM_fnc_resetUnitBuckets;

// the side a unit is listed and colored for: its group's side while alive, else the side the server announced at
// its init or death
MM_fnc_unitSide = {
    params ["_unit"];

    if (alive _unit && {!isNull group _unit}) exitWith {side group _unit};

    _unit getVariable ["MM_var_side", sideUnknown]
};

MM_fnc_addToBucket = {
    params ["_unit", "_side"];

    private _bucket = "MM_var_units" + ([_side] call MM_fnc_getSideString);
    private _oldUnits = missionNamespace getVariable [_unit getVariable ["MM_var_unitsBucket", ""], []];
    private _oldIndex = _oldUnits find _unit;

    if (_oldIndex != -1) then {
        _oldUnits deleteAt _oldIndex;
    };

    _unit setVariable ["MM_var_unitsBucket", _bucket];
    (missionNamespace getVariable [_bucket, []]) pushBackUnique _unit;
};

// moves the units whose side changed into the list of their new side and drops deleted ones; collects the vehicles
// shown while empty
MM_fnc_updateUnitBuckets = {
    if (diag_tickTime < MM_var_bucketCheckTime) exitWith {};

    MM_var_bucketCheckTime = diag_tickTime + MM_var_bucketCheckInterval;
    MM_var_emptyShownVehicles = vehicles select {(_x getVariable ["MM_var_showWhenEmpty", sideUnknown]) isNotEqualTo sideUnknown};

    private _moved = [];

    {
        private _side = _x;
        private _bucket = "MM_var_units" + ([_side] call MM_fnc_getSideString);
        private _units = missionNamespace getVariable _bucket;
        private _kept = _units select {!isNull _x && {([_x] call MM_fnc_unitSide) == _side}};

        if (count _kept != count _units) then {
            _moved append (_units select {!isNull _x && {([_x] call MM_fnc_unitSide) != _side}});
            missionNamespace setVariable [_bucket, _kept];
        };
    } forEach MM_var_bucketSides;

    {
        [_x, [_x] call MM_fnc_unitSide] call MM_fnc_addToBucket;
    } forEach _moved;
};

MM_fnc_entityInitClient = {
    params ["_entity"];

    if (_entity isKindOf "CAManBase") then {
        private _deletedEhId = _entity getVariable ["MM_var_deletedEhId", -1];

        if (_deletedEhId != -1) then {
            _entity removeEventHandler ["Deleted", _deletedEhId];
        };

        _entity setVariable ["MM_var_deletedEhId", _entity addEventHandler ["Deleted", {
            params ["_entity"];

            private _units = missionNamespace getVariable [_entity getVariable ["MM_var_unitsBucket", ""], []];
            private _index = _units find _entity;

            if (_index != -1) then {
                _units deleteAt _index;
            };
        }]];

        [_entity, [_entity] call MM_fnc_unitSide] call MM_fnc_addToBucket;
    };

    [_entity, getPosWorldVisual _entity, getDirVisual _entity] call MM_fnc_updateServerPosAndDir;
};

// ---- positions ----
// Beyond the object view distance the icons use what the server sends: position, direction, velocity and turn rate.
// Between two updates an icon continues that movement (for at most MM_var_predictionTime seconds, the server sends again
// once the continuation deviates from the real movement), and a new update doesn't make it jump: the offset between
// where it was shown and the new state fades out over MM_var_moveBlendTime (MM_fnc_farPosAndDir).

// signed difference of two directions in degrees (-180..180); the server has the same (fnc_server.sqf)
MM_fnc_angleDiff = {
    params ["_a", "_b"];

    ((_a - _b + 540) % 360) - 180
};

MM_fnc_updateServerPosAndDir = {
    params ["_entity", "_pos", "_dir", ["_velocity", [0, 0]], ["_turnRate", 0]];

    if (isNull _entity) exitWith {};

    private _now = diag_tickTime;
    private _base = [_pos select 0, _pos select 1, 0];
    private _posOffset = [0, 0, 0];
    private _dirOffset = 0;
    private _move = _entity getVariable ["MM_var_serverMove", []];

    // the offset of where the icon is shown now, faded out over the blend time
    if (_move isNotEqualTo []) then {
        ([_move, _now] call MM_fnc_farPosAndDir) params ["_shownPos", "_shownDir"];

        if ((_shownPos distance2D _base) < MM_var_moveSnapDistance) then {
            _posOffset = _shownPos vectorDiff _base;
            _dirOffset = [_shownDir, _dir] call MM_fnc_angleDiff;
        };
    };

    _entity setVariable ["MM_var_serverMove", [_base, _dir, (_velocity select [0, 2]) + [0], _turnRate, _now, _posOffset, _dirOffset]];
};

// [position, direction] of a far entity's icon at _now: the server state continued, plus the fading offset
MM_fnc_farPosAndDir = {
    params ["_move", "_now"];
    _move params ["_base", "_dir", "_velocity", "_turnRate", "_time", "_posOffset", "_dirOffset"];

    private _elapsed = _now - _time;
    private _continued = _elapsed min MM_var_predictionTime;
    private _fade = 1 - ((_elapsed / MM_var_moveBlendTime) min 1);

    [
        _base vectorAdd (_velocity vectorMultiply _continued) vectorAdd (_posOffset vectorMultiply _fade),
        _dir + (_turnRate * _continued) + (_dirOffset * _fade)
    ]
};

MM_fnc_updateServerPosAndDirBatch = {
    params ["_updates"];

    {
        _x call MM_fnc_updateServerPosAndDir;
    } forEach _updates;
};

#include "vehicleIcons.sqf"
#include "drawing.sqf"

// ---- maps / start / stop ----

// the map controls of the open maps, GPS panels and UAV terminals
MM_fnc_getMapControls = {
    disableSerialization;

    private _mapCtrls = [];

    {
        private _idc = MM_var_mapControlIdcs getOrDefault [ctrlIDD _x, -1];

        if (_idc != -1 && {!isNull (_x displayCtrl _idc)}) then {
            _mapCtrls pushBack (_x displayCtrl _idc);
        };
    } forEach (allDisplays + (uiNamespace getVariable ["IGUI_Displays", []]));

    _mapCtrls
};

// adds the draw handler to every map control once, also to maps opened later (UAV terminal, camera) and to the GPS
// panel each time it is created again
MM_fnc_attachDrawLoop = {
    disableSerialization;

    waitUntil {
        {
            if ((_x getVariable ["MM_var_drawEhId", -1]) == -1) then {
                _x setVariable ["MM_var_drawEhId", _x ctrlAddEventHandler ["Draw", {_this call MM_fnc_drawIcons}]];
            };
        } forEach (call MM_fnc_getMapControls);

        sleep 0.1;
        false
    };
};

// tells the server which sides' positions this client needs - only while it draws a map, GPS or UAV terminal
MM_fnc_reportShownSidesLoop = {
    private _reportedSides = [];

    waitUntil {
        private _isDrawing = diag_frameNo - MM_var_lastDrawFrameNo < 10;
        private _sides = if (_isDrawing) then {[call MM_fnc_viewUnit] call MM_fnc_shownSides} else {[]};

        if (_sides isNotEqualTo _reportedSides) then {
            _reportedSides = _sides;
            [_sides] remoteExecCall ["MM_fnc_setClientShownSides", 2];
        };

        sleep 0.25;
        false
    };
};

MM_fnc_startMapMarkerClient = {
    if (MM_var_clientRunning) exitWith {};

    MM_var_clientRunning = true;

    [] spawn {
        // original workaround, kept: one local vehicle is created and deleted before the first draw
        deleteVehicle ("B_Quadbike_01_F" createVehicleLocal [0, 0, 100]);

        waitUntil {!isNil "MM_var_clientInitDone" && {!isNull player} && {!isNull findDisplay 46}};

        {
            [_x] call MM_fnc_entityInitClient;
        } forEach entities [["CAManBase"], [""], true, false];

        MM_var_attachDrawLoopScript = [] spawn MM_fnc_attachDrawLoop;
        MM_var_updateDrawArrayLoopScript = [] spawn MM_fnc_updateDrawArrayLoop;

        // the server itself knows every position
        if (!isServer) then {
            MM_var_reportShownSidesLoopScript = [] spawn MM_fnc_reportShownSidesLoop;
        };
    };
};

MM_fnc_stopMapMarkerClient = {
    if (!MM_var_clientRunning) exitWith {};

    disableSerialization;

    MM_var_clientRunning = false;

    {
        terminate _x;
    } forEach [MM_var_updateDrawArrayLoopScript, MM_var_updateDrawArrayScript, MM_var_attachDrawLoopScript,
        MM_var_reportShownSidesLoopScript];

    MM_var_updateDrawArrayLoopScript = scriptNull;
    MM_var_updateDrawArrayScript = scriptNull;
    MM_var_attachDrawLoopScript = scriptNull;
    MM_var_reportShownSidesLoopScript = scriptNull;

    if (!isServer) then {
        [[]] remoteExecCall ["MM_fnc_setClientShownSides", 2];
    };

    call MM_fnc_resetUnitBuckets;

    uiNamespace setVariable ["MM_var_currentDisplay", controlNull];
    MM_var_lastDrawFrameNo = 0;
    MM_var_lastDrawArrUpdateFrameNo = 0;
    MM_var_groupScale = 0;
    MM_var_gpsOpened = false;
    MM_var_spectatorMapOpened = false;
    MM_var_showUnitNamesOverride = true;
    MM_var_drawArray = [];
    MM_var_preDrawArray = [];

    {
        private _ehId = _x getVariable ["MM_var_drawEhId", -1];

        if (_ehId != -1) then {
            _x ctrlRemoveEventHandler ["Draw", _ehId];
            _x setVariable ["MM_var_drawEhId", nil];
        };
    } forEach (call MM_fnc_getMapControls);
};

MM_var_clientInitDone = true;
