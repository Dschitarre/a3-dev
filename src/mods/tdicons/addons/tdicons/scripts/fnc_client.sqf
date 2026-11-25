// 3D icons (client): icons and names above the units and vehicles of the own side and markers on the own group
// members. A background pass rebuilds the draw array at most every TDI_var_drawArrayInterval seconds; the Draw3D
// handler only positions and sizes the prepared icons.

TDI_var_clientRunning = false;
TDI_var_draw3dEhId = -1;
TDI_var_updateDrawArrayLoopScript = scriptNull;

TDI_var_frameBudget = 0.002;          // seconds of draw-array work per frame
TDI_var_drawArrayInterval = 0.1;      // minimum seconds between two draw-array passes
TDI_var_losCacheTime = 0.2;           // seconds a line-of-sight result is reused per unit
TDI_var_iconSizeFactor = 2;           // unit and vehicle icons: size = this / distance ^ TDI_var_iconDistanceExponent * zoom
TDI_var_minUnitIconSize = 0.08;       // smaller unit icons (far away) are not drawn

// how fast the icons shrink with the distance (0.5 = 1 / sqrt (distance), the original; smaller = slower; sizes
// tuned in game 2026-11-13); missions may set it before the mod loads, the debug console at any time
if (isNil "TDI_var_iconDistanceExponent") then {TDI_var_iconDistanceExponent = 0.5;};

// the natural icon size at _distance (before zoom and floors)
TDI_fnc_iconSize = {
    params ["_distance"];

    TDI_var_iconSizeFactor / ((_distance max 0.1) ^ TDI_var_iconDistanceExponent)
};
TDI_var_unconsciousIconScale = 1.11;  // heal / revive symbol of unconscious units relative to the unit icons
TDI_var_nameMinSize = 0.45;           // icon size from which unit and vehicle names are drawn
TDI_var_nameSizeDivisor = 20;         // text size = icon size / this (drawIcon3D's default font)
TDI_var_groupIconMinDistance = 3000;  // group markers shrink up to this distance (before TDI_var_minSizeFactor)
TDI_var_sliceStart = 0;
TDI_var_bucketCheckInterval = 1;      // seconds between two checks for units that changed their side
TDI_var_bucketCheckTime = 0;
TDI_var_spectatorDisplay = 60492;     // RscDisplayEGSpectator

// ---- size settings ----
// Icons and texts shrink with the distance down to a floor (per entry minSize, for texts the size of their
// textSizeCutoff); this factor scales every floor alike, so text and icon floors keep their ratio. Tuned in game: 1.7
// at 1080 pixels screen height, less on higher resolutions (1.275 at 1440, 0.85 at 2160).
if (isNil "TDI_var_minSizeFactor") then {TDI_var_minSizeFactor = 1.7 / ((getResolution select 1) / 1080);};

// ---- vehicle stage settings ----
// Chosen by the icon size at the vehicle's centre (distance and zoom, see TDI_var_iconSizeFactor): near vehicles show
// each crew member's own icon, middle ones one side icon with the driver's name, far ones only a side-view symbol of
// the vehicle (drawing.sqf). Missions may set these before the mod loads.

if (isNil "TDI_var_vehicleNearSize") then {TDI_var_vehicleNearSize = 0.4;};                // above: crew icons (~15 m)
if (isNil "TDI_var_vehicleCrewDistance") then {TDI_var_vehicleCrewDistance = 30;};         // meters: closer always crew icons
if (isNil "TDI_var_vehicleFarSize") then {TDI_var_vehicleFarSize = 0.12;};                 // below: far symbol (~170 m)
if (isNil "TDI_var_vehicleStageHysteresis") then {TDI_var_vehicleStageHysteresis = 0.1;};  // share a size must pass a threshold by
// height of the far symbol (x its scale, x TDI_var_minSizeFactor): only a hint where a unit icon would be too small to
// notice, at scale 1 (a typical picture) as high as the side icon of the middle stage at its smallest
if (isNil "TDI_var_vehicleSymbolSize") then {TDI_var_vehicleSymbolSize = 0.23;};
if (isNil "TDI_var_minVehicleIconSize") then {TDI_var_minVehicleIconSize = 0.04;};         // smaller vehicle icons are not drawn (~1.5 km)

// ---- colors and icons ----
// Units and the middle vehicle stage use the vanilla diary icons, which carry their side's color and are drawn white;
// names are white, the own unit's group marker yellow. Far vehicle symbols get a fixed side palette.

TDI_var_colorYellow = [1, 0.83, 0, 1];   // the own-player yellow of mapmarker / killfeed ("#FFD400")
TDI_var_colorWhite = [1, 1, 1, 1];

TDI_var_sideIconNames = createHashMapFromArray [[west, "West"], [east, "East"], [independent, "Guer"], [civilian, "Civ"]];

TDI_var_sideColors = createHashMapFromArray [
    [west, [0, 0.5, 1, 1]],
    [east, [1, 0, 0, 1]],
    [independent, [0, 0.8, 0.27, 1]]
];
TDI_var_otherSideColor = [0.75, 0.75, 0.75, 1];

// game modes add functions that push their own entries into TDI_var_preDrawArray (same arguments as
// TDI_fnc_gatherUnitIcons); entry format: [distance, positionType, object, [texture, color], sizeFactor,
// useSqrtZoom, angle, textSizeCutoff, text, shadow, textSizeDivisor, minSize, widthFactor, textEnabled]
// The last four are optional. Keep text cached even when disabled, so holding Windows can reveal it immediately.
TDI_var_gatherDrawArraysFncs = [];
TDI_var_preDrawArray = [];
TDI_var_drawArray = [];

// Vehicles are drawn through their crew. A game mode can show a vehicle also without living crew: the public object
// variable TDI_var_showWhenEmpty (a side) draws its icon, while alive, for the viewers of that side (by the normal
// rules: shown sides, distance, line of sight) in that side's color - near as well, as there are no crew icons;
// TDI_var_emptyLabel (optional, public) is its name while empty. With crew it is drawn as any vehicle.

// ---- helpers ----

TDI_fnc_isUavAi = {
    params ["_unit"];

    "UAV_AI" in typeOf _unit
};

// unconscious (AIS or vanilla revive)
TDI_fnc_isUnconscious = {
    params ["_unit"];

    (_unit getVariable ["AIS_unconscious", false]) || {lifeState _unit == "INCAPACITATED"}
};

// dead or in the (EG) spectator; a unit under Zeus remote control is no spectator
TDI_fnc_isSpectator = {
    !alive player || {!isNull findDisplay TDI_var_spectatorDisplay}
};

TDI_fnc_getZoom = {
    ([0.5, 0.5] distance2D worldToScreen positionCameraToWorld [0, 3, 4]) * (getResolution select 5) * 1.5
};

TDI_fnc_isOnScreen = {
    params ["_pos"];

    private _screenPos = worldToScreen _pos;

    if (_screenPos isEqualTo []) exitWith {false};

    _screenPos params ["_screenX", "_screenY"];

    _screenX > safeZoneX && {_screenX < safeZoneX + safeZoneW} && {_screenY > safeZoneY} && {_screenY < safeZoneY + safeZoneH}
};

// the diary icon of a unit's (or a vehicle's) side; dead ones get the "Brief" variant
TDI_fnc_getIcon = {
    params ["_unit", "_side"];

    format [
        "\A3\ui_f\data\Map\Diary\Icons\player%1%2_ca.paa",
        ["Brief", ""] select alive _unit,
        TDI_var_sideIconNames getOrDefault [_side, "Unknown"]
    ]
};

TDI_fnc_uavControlUnits = {
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
TDI_fnc_uavControl = {
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

// game modes may replace this
TDI_fnc_getGroupUnits = {
    params ["_unit"];

    units group _unit
};

// "Darter (AI) [J. Doe (remote)]"
TDI_fnc_uavName = {
    params ["_uav"];

    private _controllers = [_uav] call TDI_fnc_uavControlUnits;
    private _controllersText = if (_controllers isEqualTo []) then {""} else {
        " [" + ((_controllers apply {([_x] call TDI_fnc_unitName) + " (remote)"}) joinString ", ") + "]"
    };

    (_uav getVariable ["TDI_var_name", ""]) + (if (unitIsUAV _uav) then {" (AI)"} else {""}) + _controllersText
};

// ---- names ----
// Built here from the unit's name and whether a player controls it - both change when a player takes over an AI
// unit or hands it back. A game mode may set its own name (TDI_var_name); a dead unit keeps the controller of its death.

// player name, or a short AI name: "John Doe" -> "J. Doe (AI)", "Jean-Luc Picard" -> "J.-L. Picard (AI)"
TDI_fnc_formatName = {
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
TDI_fnc_unitName = {
    params ["_unit"];

    if (isNull _unit) exitWith {""};

    private _override = _unit getVariable "TDI_var_name";

    if (!isNil "_override") exitWith {_override};

    private _isPlayer = if (alive _unit) then {isPlayer _unit} else {_unit getVariable ["TDI_var_wasPlayer", isPlayer _unit]};
    private _source = [name _unit, _isPlayer];

    (_unit getVariable ["TDI_var_nameCache", [[], ""]]) params ["_cachedSource", "_cachedName"];

    if (_source isEqualTo _cachedSource) exitWith {_cachedName};
    if ((_source select 0) == "") exitWith {""};

    private _name = _source call TDI_fnc_formatName;

    _unit setVariable ["TDI_var_nameCache", [_source, _name]];
    _name
};

// yields to the next frame once the draw-array pass used up its per-frame budget
TDI_fnc_yieldIfBudgetUsed = {
    if (diag_tickTime - TDI_var_sliceStart > TDI_var_frameBudget) then {
        sleep 0.001;
        TDI_var_sliceStart = diag_tickTime;
    };
};

// ---- visibility ----

// Hidden by the entity culling mod (EC_var_culled, on the unit or its vehicle): EC hides only what terrain and
// buildings block from the camera (with margins), so the own check would find it blocked as well - it is skipped.
// Everything EC shows or does not cover gets the own check (vegetation, units and vehicles can still block it).
TDI_fnc_isCulled = {
    params ["_target"];

    private _root = vehicle _target;

    isObjectHidden _root && {_root getVariable ["EC_var_culled", false]}
};

// Line of sight from the camera to _targetPos (AGL), cached per target and purpose for TDI_var_losCacheTime.
// checkVisibility ignores _first (the target's vehicle, or the UAV itself), in first person also the camera
// unit's vehicle / UAV and the unit itself, then the target.
TDI_fnc_hasLineOfSight = {
    params ["_target", "_cacheName", "_first", "_forceViewLod", "_targetPos", "_unit", "_par", "_uav", "_isInUav", "_camPosAsl"];

    if ([_target] call TDI_fnc_isCulled) exitWith {false};

    private _cache = _target getVariable [_cacheName, [-1, false]];

    if (time - (_cache select 0) < TDI_var_losCacheTime) exitWith {_cache select 1};

    private _firstPerson = cameraView != "EXTERNAL";
    private _ignore = [];

    if (!isNull _first) then {
        _ignore pushBack _first;
    };

    if (_firstPerson) then {
        if (_isInUav) then {
            _ignore pushBack _uav;
        } else {
            if (!isNull _par) then {
                _ignore pushBack _par;
            };
        };

        _ignore pushBack _unit;
    };

    _ignore pushBackUnique _target;
    _ignore append [objNull, objNull];

    private _lod = ["FIRE", "VIEW"] select (_forceViewLod || {(!isNull _par || _isInUav) && _firstPerson});
    private _visible = ([_ignore select 0, _lod, _ignore select 1] checkVisibility [_camPosAsl, AGLToASL _targetPos]) != 0;

    _target setVariable [_cacheName, [time, _visible]];
    _visible
};

// ---- unit lists ----
// One list per side (TDI_var_units<side>), filled when the server announces a unit, emptied by "Deleted" and kept
// up to date when a unit changes its side (e.g. a player taking over a unit of another group).

TDI_var_bucketSides = [west, east, independent, civilian, sideEmpty, sideLogic, sideAmbientLife, sideUnknown];

TDI_fnc_getSideString = {
    params ["_side"];

    if (_side == sideAmbientLife) then {"AmbientLife"} else {str _side}
};

TDI_fnc_resetUnitBuckets = {
    {
        missionNamespace setVariable ["TDI_var_units" + ([_x] call TDI_fnc_getSideString), []];
    } forEach TDI_var_bucketSides;

    TDI_var_emptyShownVehicles = [];   // vehicles with TDI_var_showWhenEmpty
};

call TDI_fnc_resetUnitBuckets;

// the side a unit is listed and colored for: its group's side while alive, else the side the server announced at
// its init or death
TDI_fnc_unitSide = {
    params ["_unit"];

    if (alive _unit && {!isNull group _unit}) exitWith {side group _unit};

    _unit getVariable ["TDI_var_side", sideUnknown]
};

TDI_fnc_addToBucket = {
    params ["_unit", "_side"];

    private _bucket = "TDI_var_units" + ([_side] call TDI_fnc_getSideString);
    private _oldUnits = missionNamespace getVariable [_unit getVariable ["TDI_var_unitsBucket", ""], []];
    private _oldIndex = _oldUnits find _unit;

    if (_oldIndex != -1) then {
        _oldUnits deleteAt _oldIndex;
    };

    _unit setVariable ["TDI_var_unitsBucket", _bucket];
    (missionNamespace getVariable [_bucket, []]) pushBackUnique _unit;
};

// moves the units whose side changed into the list of their new side and drops deleted ones; collects the vehicles
// shown while empty
TDI_fnc_updateUnitBuckets = {
    if (diag_tickTime < TDI_var_bucketCheckTime) exitWith {};

    TDI_var_bucketCheckTime = diag_tickTime + TDI_var_bucketCheckInterval;
    TDI_var_emptyShownVehicles = vehicles select {(_x getVariable ["TDI_var_showWhenEmpty", sideUnknown]) isNotEqualTo sideUnknown};

    private _moved = [];

    {
        private _side = _x;
        private _bucket = "TDI_var_units" + ([_side] call TDI_fnc_getSideString);
        private _units = missionNamespace getVariable _bucket;
        private _kept = _units select {!isNull _x && {([_x] call TDI_fnc_unitSide) == _side}};

        if (count _kept != count _units) then {
            _moved append (_units select {!isNull _x && {([_x] call TDI_fnc_unitSide) != _side}});
            missionNamespace setVariable [_bucket, _kept];
        };
    } forEach TDI_var_bucketSides;

    {
        [_x, [_x] call TDI_fnc_unitSide] call TDI_fnc_addToBucket;
    } forEach _moved;
};

TDI_fnc_entityInitClient = {
    params ["_entity"];

    private _deletedEhId = _entity getVariable ["TDI_var_deletedEhId", -1];

    if (_deletedEhId != -1) then {
        _entity removeEventHandler ["Deleted", _deletedEhId];
    };

    _entity setVariable ["TDI_var_deletedEhId", _entity addEventHandler ["Deleted", {
        params ["_entity"];

        private _units = missionNamespace getVariable [_entity getVariable ["TDI_var_unitsBucket", ""], []];
        private _index = _units find _entity;

        if (_index != -1) then {
            _units deleteAt _index;
        };
    }]];

    [_entity, [_entity] call TDI_fnc_unitSide] call TDI_fnc_addToBucket;
};

#include "vehicleSymbols.sqf"
#include "drawing.sqf"

// ---- start / stop ----

TDI_fnc_startTdIconsClient = {
    if (TDI_var_clientRunning) exitWith {};

    TDI_var_clientRunning = true;

    {
        [_x] call TDI_fnc_entityInitClient;
    } forEach entities [["CAManBase"], [""], true, false];

    TDI_var_draw3dEhId = addMissionEventHandler ["Draw3D", {call TDI_fnc_drawIcons}];
    TDI_var_updateDrawArrayLoopScript = [] spawn TDI_fnc_updateDrawArrayLoop;
};

TDI_fnc_stopTdIconsClient = {
    if (!TDI_var_clientRunning) exitWith {};

    TDI_var_clientRunning = false;

    call TDI_fnc_resetUnitBuckets;
    removeMissionEventHandler ["Draw3D", TDI_var_draw3dEhId];
    terminate TDI_var_updateDrawArrayLoopScript;
    TDI_var_updateDrawArrayLoopScript = scriptNull;
    TDI_var_draw3dEhId = -1;
};

TDI_var_clientInitDone = true;
