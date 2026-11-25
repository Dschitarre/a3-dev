// 3D icon drawing (client): unit, vehicle and group icons, the draw array and the Draw3D handler.
// Included by fnc_client.sqf.

// ---- vehicle icons ----
// Three stages by the icon size at the vehicle's centre (TDI_var_vehicleNearSize / TDI_var_vehicleFarSize): near, the
// crew members get their own unit icons; middle, one side icon at the vehicle's centre with the name of its driver
// (else commander, gunner, passenger); far, only a symbol in the side color, never lower than TDI_var_vehicleSymbolSize:
// the vehicle's own side view (its config picture, the white silhouette of the command bar), scaled per picture by
// TDI_var_vehiclePictureInfo (vehicleSymbols.sqf) so all symbols cover about the same area, else a generic side view of
// its kind (car, tank, helicopter, plane, boat, static weapon). A UAV has no near stage (its crew are AI units), nor
// has a vehicle shown while empty (TDI_var_showWhenEmpty).

TDI_var_vehicleCenters = createHashMap;
TDI_var_vehicleSymbols = createHashMap;
TDI_var_nameTargets = [];
TDI_var_textKeys = [];
TDI_var_showAllText = false;

// Hold either Windows key. Display hooks are installed outside Draw3D.
TDI_fnc_textKey = {
    params ["_key", "_down"];
    if !(_key in [219,220]) exitWith {false};
    if (_down) then {TDI_var_textKeys pushBackUnique _key} else {TDI_var_textKeys = TDI_var_textKeys - [_key]};
    TDI_var_showAllText = TDI_var_textKeys isNotEqualTo [];
    true
};

TDI_fnc_installTextKeys = {
    {
        private _display = _x;
        if (!isNull _display && {!(_display getVariable ["TDI_var_textKeysInstalled",false])}) then {
            _display setVariable ["TDI_var_textKeysInstalled",true];
            _display displayAddEventHandler ["KeyDown",{[_this select 1,true] call TDI_fnc_textKey}];
            _display displayAddEventHandler ["KeyUp",{[_this select 1,false] call TDI_fnc_textKey}];
            _display displayAddEventHandler ["Unload",{TDI_var_textKeys=[];TDI_var_showAllText=false}];
        };
    } forEach allDisplays;
};

// seats in the order a vehicle icon picks the named crew member
TDI_var_crewRoles = ["driver", "commander", "gunner", "turret", "cargo"];

// centre of a vehicle class's geometry in model coordinates, cached; the default bounding box also holds rotors,
// antennas and memory points and lies far above many vehicles
TDI_fnc_vehicleCenter = {
    params ["_vehicle"];

    private _type = typeOf _vehicle;
    private _center = TDI_var_vehicleCenters get _type;

    if (isNil "_center") then {
        (2 boundingBoxReal _vehicle) params ["_min", "_max"];

        _center = (_min vectorAdd _max) vectorMultiply 0.5;
        TDI_var_vehicleCenters set [_type, _center];
    };

    _center
};

// the far symbols of vehicles whose picture TDI_var_vehiclePictureInfo does not know (3D renders instead of silhouettes,
// encrypted DLCs, other mods): one generic side view per vehicle kind, the category icons of the vanilla garage (all
// 2:1); [kind, texture, scale], the first kind a vehicle is of wins (a wheeled APC is also a car), cars are the
// fallback. Scales measured like the pictures, against the same median (opaque: car 41 %, tank 33 %, boat 23 %,
// plane 19 %, helicopter 16 %, static weapon 4 % - the thin static weapon is capped at 1.6).
TDI_var_vehicleKindSymbols = [
    ["Tank", "tank_ca.paa", 1.01],
    ["Wheeled_APC_F", "tank_ca.paa", 1.01],
    ["Helicopter", "helicopter_ca.paa", 1.44],
    ["Plane", "plane_ca.paa", 1.33],
    ["Ship", "naval_ca.paa", 1.22],
    ["StaticWeapon", "static_ca.paa", 1.6],
    ["Car", "car_ca.paa", 0.91]
] apply {[_x select 0, "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\" + (_x select 1), _x select 2]};
TDI_var_vehicleSymbolWidth = 2;   // width / height of the garage icons

// key of TDI_var_vehiclePictureInfo for a config picture: lower case, no leading backslash, ".paa" when it has no
// extension (as genVehicleSymbols.py normalizes the texture paths)
TDI_fnc_vehiclePictureKey = {
    params ["_picture"];

    private _key = toLowerANSI _picture;

    if ((_key select [0, 1]) == "\") then {
        _key = _key select [1];
    };

    if ((_key find ".") == -1) then {
        _key = _key + ".paa";
    };

    _key
};

// [texture, width / height, scale] of a vehicle class's far symbol, cached: its own picture, else the generic symbol
TDI_fnc_vehicleSymbol = {
    params ["_vehicle"];

    private _type = typeOf _vehicle;
    private _symbol = TDI_var_vehicleSymbols get _type;

    if (isNil "_symbol") then {
        private _picture = getText (configOf _vehicle >> "picture");
        private _pictureInfo = TDI_var_vehiclePictureInfo get ([_picture] call TDI_fnc_vehiclePictureKey);

        _symbol = if (isNil "_pictureInfo") then {
            private _index = TDI_var_vehicleKindSymbols findIf {_vehicle isKindOf (_x select 0)};

            if (_index == -1) then {
                _index = (count TDI_var_vehicleKindSymbols) - 1;
            };

            (TDI_var_vehicleKindSymbols select _index) params ["", "_texture", "_scale"];
            [_texture, TDI_var_vehicleSymbolWidth, _scale]
        } else {
            [_picture] + _pictureInfo
        };

        TDI_var_vehicleSymbols set [_type, _symbol];
    };

    _symbol
};

// 0 near, 1 middle, 2 far. A size has to pass a threshold by the share TDI_var_vehicleStageHysteresis to change the
// stage, so a vehicle at a threshold does not flicker between two stages.
TDI_fnc_vehicleStage = {
    params ["_vehicle", "_size", "_distance"];

    // closer than TDI_var_vehicleCrewDistance the crew always has its own icons, whatever the zoom
    if (_distance < TDI_var_vehicleCrewDistance) exitWith {
        _vehicle setVariable ["TDI_var_vehicleStage", 0];
        0
    };

    private _stage = _vehicle getVariable ["TDI_var_vehicleStage", 1];
    private _newStage = 0;

    {
        // on the near side of a threshold it is lowered, on the far side raised
        private _margin = [TDI_var_vehicleStageHysteresis, -TDI_var_vehicleStageHysteresis] select (_stage <= _forEachIndex);

        if (_size < _x * (1 + _margin)) then {
            _newStage = _newStage + 1;
        };
    } forEach [TDI_var_vehicleNearSize, TDI_var_vehicleFarSize];

    _vehicle setVariable ["TDI_var_vehicleStage", _newStage];
    _newStage
};

// the crew member named by a vehicle icon: living ones first, then by TDI_var_crewRoles
TDI_fnc_vehicleLeader = {
    params ["_vehicle"];

    private _leader = objNull;
    private _bestRank = 1e9;

    {
        _x params ["_member", "_role"];

        private _rank = (TDI_var_crewRoles find toLowerANSI _role) + ([count TDI_var_crewRoles, 0] select alive _member);

        if (_rank < _bestRank) then {
            _bestRank = _rank;
            _leader = _member;
        };
    } forEach fullCrew _vehicle;

    _leader
};

// middle stage: the name below the side icon, sized like it (the same size factor and floor, text = icon / divisor) and
// only from the size from which unit names are drawn; the plain name as on units on foot (no state suffix), none
// when nobody on board lives - a vehicle shown while empty has its label (TDI_var_emptyLabel)
TDI_fnc_addVehicleName = {
    params ["_vehicle", "_distance", "_sizeFactor", "_isUav", "_isEmpty", ["_textEnabled",TDI_var_showUnitNames]];

    private _name = switch (true) do {
        case (_isUav): {[_vehicle] call TDI_fnc_uavName};
        case (_isEmpty): {_vehicle getVariable ["TDI_var_emptyLabel", ""]};
        default {
            private _member = [_vehicle] call TDI_fnc_vehicleLeader;

            if (isNull _member || {!alive _member}) then {""} else {[_member] call TDI_fnc_unitName}
        };
    };

    if (_name == "") exitWith {};
    TDI_var_nameTargets pushBackUnique _vehicle;

    TDI_var_preDrawArray pushBack [
        _distance - 0.001,
        5,
        _vehicle,
        ["", TDI_var_colorWhite],
        _sizeFactor,
        false,
        0,
        TDI_var_nameMinSize,
        _name,
        2,
        TDI_var_nameSizeDivisor,
        TDI_var_vehicleFarSize,
        1,
        _textEnabled
    ];
};

// the icon of a vehicle in the color of _side (its crew's); true when the crew gets its own unit icons. _isEmpty: a
// vehicle without living crew shown for _side (TDI_var_showWhenEmpty), which has no crew icons near.
TDI_fnc_addVehicleIcon = {
    params ["_vehicle", "_side", "_context", ["_isEmpty", false]];
    _context params ["_unit", "_par", "_drawUnit", "", "", "", "_uav", "", "_isInUav", "", "_viewDis", "_camPos", "_camPosAsl", "_zoom"];

    // the own vehicle only when seen from outside, the own UAV not while controlling it; vehicles hidden by the
    // culling mod (EC_var_culled) count as visible
    if (!_drawUnit && {_vehicle isEqualTo _par}) exitWith {false};
    if (_isInUav && {_vehicle isEqualTo _uav}) exitWith {false};
    if (isObjectHidden _vehicle && {!(_vehicle getVariable ["EC_var_culled", false])}) exitWith {false};

    private _pos = _vehicle modelToWorldVisual ([_vehicle] call TDI_fnc_vehicleCenter);
    private _distance = _camPos distance _pos;
    private _sizeFactor = [_distance] call TDI_fnc_iconSize;
    private _isUav = unitIsUAV _vehicle;
    private _stage = [_vehicle, _sizeFactor * _zoom, _distance] call TDI_fnc_vehicleStage;

    if (_stage == 0 && {_isEmpty}) then {
        _stage = 1;
    };

    if (_stage == 0 && {!_isUav}) exitWith {true};
    if (_distance > _viewDis || {_sizeFactor * _zoom < TDI_var_minVehicleIconSize} || {!([_pos] call TDI_fnc_isOnScreen)}) exitWith {false};
    if(TDI_var_hideInvisible &&
        {!([_vehicle, "TDI_var_losUnitIcon", _vehicle, _isUav, _pos, _unit, _par, _uav, _isInUav,
        _camPosAsl] call TDI_fnc_hasLineOfSight)}) exitWith {false};

    if (_stage == 2) exitWith {
        ([_vehicle] call TDI_fnc_vehicleSymbol) params ["_symbol", "_widthFactor", "_symbolScale"];

        private _color = +(TDI_var_sideColors getOrDefault [_side, TDI_var_otherSideColor]);

        if (!alive _vehicle) then {
            _color set [3, 0.5];
        };

        TDI_var_preDrawArray pushBack [
            _distance,
            5,
            _vehicle,
            [_symbol, _color],
            _symbolScale * _sizeFactor,
            false,
            0,
            0,
            "",
            2,
            0,
            _symbolScale * TDI_var_vehicleSymbolSize,
            _widthFactor
        ];

        [_vehicle, _distance, _symbolScale * _sizeFactor, _isUav, _isEmpty, false] call TDI_fnc_addVehicleName;
        false
    };

    TDI_var_preDrawArray pushBack [
        _distance,
        5,
        _vehicle,
        [[_vehicle, _side] call TDI_fnc_getIcon, TDI_var_colorWhite],
        _sizeFactor,
        false,
        0,
        0,
        "",
        2,
        0,
        TDI_var_vehicleFarSize
    ];

    [_vehicle, _distance, _sizeFactor, _isUav, _isEmpty] call TDI_fnc_addVehicleName;

    false
};

// a vehicle is handled once per pass, by its first crew member; true when its crew is shown like units on foot
TDI_fnc_isCrewShown = {
    params ["_vehicle", "_target", "_context", "_vehicles", "_crewShown"];

    private _index = _vehicles find _vehicle;

    if (_index == -1) then {
        _index = _vehicles pushBack _vehicle;
        _crewShown pushBack ([_vehicle, [_target] call TDI_fnc_unitSide, _context] call TDI_fnc_addVehicleIcon);
    };

    _crewShown select _index
};

// a vehicle without living crew that a game mode shows to one of the shown sides (TDI_var_showWhenEmpty), unless it
// was handled through its (dead) crew already
TDI_fnc_addEmptyVehicleIcon = {
    params ["_vehicle", "_context", "_shownSides", "_vehicles"];

    private _side = _vehicle getVariable ["TDI_var_showWhenEmpty", sideUnknown];

    if (
        !alive _vehicle ||
        {!simulationEnabled _vehicle} ||
        {!(_side in _shownSides)} ||
        {_vehicle in _vehicles} ||
        {((crew _vehicle) findIf {alive _x}) != -1}
    ) exitWith {};

    [_vehicle, _side, _context, true] call TDI_fnc_addVehicleIcon;
};

// ---- unit icons ----
// The diary icon of the unit's side and its name above every visible unit of the own side (or of all sides), plus a
// heal icon for unconscious units outside the own group. Crews go through their vehicle's icon (above).

TDI_fnc_addUnitIcon = {
    params ["_target", "_context", "_vehicles", "_crewShown"];
    _context params ["_unit", "_par", "_drawUnit", "", "_groupUnits", "", "_uav", "", "_isInUav", "", "_viewDis", "_camPos", "_camPosAsl", "_zoom", "", "_isInSpectator"];

    if (!simulationEnabled _target) exitWith {};

    private _isUavAi = [_target] call TDI_fnc_isUavAi;

    if (_isInSpectator && {!TDI_var_drawUnitsOnSpectator} && {!_isUavAi}) exitWith {};

    private _parTarget = objectParent _target;
    private _isCrew = !isNull _parTarget && {!(_parTarget isKindOf "ParachuteBase")};

    if (_isCrew && {!([_parTarget, _target, _context, _vehicles, _crewShown] call TDI_fnc_isCrewShown)}) exitWith {};

    // UAV AI units only through their UAV; units hidden by the culling mod (EC_var_culled) count as visible
    if (_isUavAi) exitWith {};
    if (isObjectHidden _target && {!(_target getVariable ["EC_var_culled", false])}) exitWith {};

    // the own unit only when seen from outside
    if (!_drawUnit && {_target isEqualTo _unit}) exitWith {};

    private _pos = _target modelToWorldVisual (_target selectionPosition "head");
    private _distance = _camPos distance _pos;

    if (_distance > _viewDis || {!([_pos] call TDI_fnc_isOnScreen)}) exitWith {};

    private _sizeFactor = [_distance] call TDI_fnc_iconSize;

    if (_sizeFactor * _zoom < TDI_var_minUnitIconSize) exitWith {};

    if(TDI_var_hideInvisible &&
        {!([_target, "TDI_var_losUnitIcon", _parTarget, false, _pos, _unit, _par, _uav, _isInUav,
        _camPosAsl] call TDI_fnc_hasLineOfSight)}) exitWith {};

    private _name = [_target] call TDI_fnc_unitName;
    TDI_var_nameTargets pushBackUnique _target;

    TDI_var_preDrawArray pushBack [
        _distance,
        0,
        _target,
        [[_target, [_target] call TDI_fnc_unitSide] call TDI_fnc_getIcon, TDI_var_colorWhite],
        _sizeFactor,
        false,
        0,
        TDI_var_nameMinSize,
        _name,
        2,
        TDI_var_nameSizeDivisor,
        TDI_var_minUnitIconSize,
        1,
        TDI_var_showUnitNames
    ];

    if (alive _target && {[_target] call TDI_fnc_isUnconscious} && {!(_target in _groupUnits)}) then {
        TDI_var_preDrawArray pushBack [
            _distance,
            1,
            _target,
            ["\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa", TDI_var_colorWhite],
            TDI_var_unconsciousIconScale * _sizeFactor,
            false,
            0,
            0,
            "",
            2,
            0,
            TDI_var_unconsciousIconScale * TDI_var_minUnitIconSize
        ];
    };
};

TDI_fnc_gatherUnitIcons = {
    params ["_unit", "_par", "_drawUnit", "_group", "_groupUnits", "_side", "_uav", "_hasUav", "_isInUav", "_groupUnitsUavs", "_viewDis", "_camPos", "_camPosAsl", "_zoom", "_sqrtZoom", "_isInSpectator"];

    private _showAllSides = !isNull findDisplay 314 || {TDI_var_showAllSides} || {_isInSpectator && {TDI_var_showAllSidesOnSpectator}};
    private _shownSides = if (_showAllSides) then {[west, east, independent, civilian]} else {[_side]};
    private _vehicles = [];
    private _crewShown = [];

    {
        {
            call TDI_fnc_yieldIfBudgetUsed;
            [_x, _this, _vehicles, _crewShown] call TDI_fnc_addUnitIcon;
        } forEach (missionNamespace getVariable ("TDI_var_units" + ([_x] call TDI_fnc_getSideString)));
    } forEach _shownSides;

    // vehicles shown while empty: by the same spectator rule as the units
    if (_isInSpectator && {!TDI_var_drawUnitsOnSpectator}) exitWith {};

    {
        call TDI_fnc_yieldIfBudgetUsed;
        [_x, _this, _shownSides, _vehicles] call TDI_fnc_addEmptyVehicleIcon;
    } forEach TDI_var_emptyShownVehicles;
};

// ---- group icons ----
// A marker on every member of the own group and on their UAVs (alive, unconscious or dead).

TDI_fnc_addGroupIcon = {
    params ["_target", "_context"];
    _context params ["_unit", "_par", "_drawUnit", "", "", "", "_uav", "", "_isInUav", "", "_viewDis", "_camPos", "_camPosAsl"];

    if (!simulationEnabled _target) exitWith {};

    private _isUav = unitIsUAV _target;

    if (_isInUav && {_isUav} && {_target isEqualTo _uav}) exitWith {};
    if (!_isInUav && {!_drawUnit} && {_target isEqualTo _unit}) exitWith {};

    private _pos = if (_isUav) then {
        _target modelToWorldVisual [0, 0, 0]
    } else {
        _target modelToWorldVisual (((_target selectionPosition "head") vectorAdd (_target selectionPosition "pelvis")) vectorMultiply 0.5)
    };

    private _distance = _camPos distance _pos;

    if (TDI_var_groupUnitsLimitedDistance && {_distance > _viewDis}) exitWith {};
    if (!([_pos] call TDI_fnc_isOnScreen)) exitWith {};

    private _first = if (_isUav) then {_target} else {objectParent _target};

    if(TDI_var_hideInvisibleGroupMembers &&
        {!([_target, "TDI_var_losGroupIcon", _first, false, _pos, _unit, _par, _uav, _isInUav,
        _camPosAsl] call TDI_fnc_hasLineOfSight)}) exitWith {};

    private _icon = if (alive _target) then {
        if ([_target] call TDI_fnc_isUnconscious) then {
            "\A3\ui_f\data\IGUI\Cfg\Revive\overlayIconsGroup\r100_ca.paa"
        } else {
            "\A3\ui_f\data\IGUI\Cfg\Cursors\select_ca.paa"
        }
    } else {
        "\A3\ui_f\data\IGUI\Cfg\Revive\overlayIconsGroup\d75_ca.paa"
    };

    // the own unit (or the own UAV seen from outside) is yellow
    private _isOwn = if (_isUav) then {!_isInUav && {_target isEqualTo _uav}} else {_target isEqualTo _unit};
    private _color = [TDI_var_colorWhite, TDI_var_colorYellow] select _isOwn;
    private _groupName = if (_target in TDI_var_nameTargets) then {""} else {
        if (_isUav) then {[_target] call TDI_fnc_uavName} else {[_target] call TDI_fnc_unitName}
    };

    // an unconscious member: his revive symbol scales with the distance and zoom like the unit icons (as the heal icon
    // of units outside the group), the other markers shrink much slower so they stay visible far away
    if (alive _target && {[_target] call TDI_fnc_isUnconscious}) exitWith {
        TDI_var_preDrawArray pushBack [
            _distance,
            1,
            _target,
            [_icon, _color],
            TDI_var_unconsciousIconScale * ([_distance] call TDI_fnc_iconSize),
            false,
            0,
            TDI_var_nameMinSize,
            _groupName,
            2,
            TDI_var_nameSizeDivisor,
            TDI_var_unconsciousIconScale * TDI_var_minUnitIconSize,
            1,
            false
        ];
    };

    private _baseSize = [2.025, 1.5] select alive _target;

    TDI_var_preDrawArray pushBack [
        _distance,
        1,
        _target,
        [_icon, _color],
        _baseSize / sqrt sqrt _distance,
        true,
        0,
        TDI_var_nameMinSize,
        _groupName,
        2,
        TDI_var_nameSizeDivisor,
        _baseSize / sqrt sqrt TDI_var_groupIconMinDistance,
        1,
        false
    ];
};

TDI_fnc_gatherGroupIcons = {
    params ["_unit", "_par", "_drawUnit", "_group", "_groupUnits", "_side", "_uav", "_hasUav", "_isInUav", "_groupUnitsUavs"];

    {
        call TDI_fnc_yieldIfBudgetUsed;
        [_x, _this] call TDI_fnc_addGroupIcon;
    } forEach (_groupUnits + _groupUnitsUavs);
};

// ---- draw array ----

// public entry -> per-frame form: [object, positionType, positionOffset, sizeFactor, useSqrtZoom, textSizeCutoff,
// text, textSizeDivisor, floor, widthFactor, drawIcon3D arguments]. Icons shrink with the distance down to their floor
// (minSize times TDI_var_minSizeFactor); a text is always its icon's size / textSizeDivisor (the same ratio at every
// distance) and is drawn only while the unfloored size is at least textSizeCutoff.
TDI_fnc_prepareDrawEntry = {
    params [
        "_distance",
        "_posType",
        "_obj",
        "_iconColor",
        "_sizeFactor",
        "_useSqrtZoom",
        "_angle",
        "_textSizeCutoff",
        "_text",
        "_shadow",
        ["_textSizeDivisor", 0],
        ["_minSize", 0],
        ["_widthFactor", 1],
        ["_textEnabled", true]
    ];

    // type 0: above the head, 1: middle of the body (offset unused), 2: origin, 3: flag top, 4: base object,
    // 5: centre of a vehicle
    private _posOffset = if (_posType == 5) then {
        [_obj] call TDI_fnc_vehicleCenter
    } else {
        [[0, 0, 1.6 - exp (_distance / 8000)], [], [0, 0, 0], [0, 0, 1.05], [0, 0.1, 0.45]] select _posType
    };
    private _args = _iconColor + [[0, 0, 0], 0, 0, _angle, "", _shadow];

    // only the text size, no font: drawIcon3D's default font as in the original version
    if (_textSizeDivisor != 0) then {
        _args pushBack 0;
    };

    [
        _obj,
        _posType,
        _posOffset,
        _sizeFactor,
        _useSqrtZoom,
        _textSizeCutoff,
        _text,
        _textSizeDivisor,
        _minSize * TDI_var_minSizeFactor,
        _widthFactor,
        _args,
        _textEnabled,
        _textSizeCutoff max TDI_var_nameMinSize
    ]
};

TDI_fnc_iconViewDistance = {
    private _objects = (getObjectViewDistance) select 0;
    viewDistance min ([viewDistance, _objects] select (_objects >= 0))
};

TDI_fnc_updateDrawArrayLoop = {
    waitUntil {
        waitUntil {isNull findDisplay 49};

        private _passStart = time;
        if (!isGameFocused) then {TDI_var_textKeys=[];TDI_var_showAllText=false};
        call TDI_fnc_installTextKeys;
        TDI_var_nameTargets = [];
        TDI_var_sliceStart = diag_tickTime;

        call TDI_fnc_updateUnitBuckets;

        private _unit = if (unitIsUAV focusOn) then {[objectParent focusOn, "DRIVER", "GUNNER"] call TDI_fnc_uavControl} else {focusOn};
        private _par = objectParent _unit;
        private _groupUnits = [_unit] call TDI_fnc_getGroupUnits;
        private _uav = getConnectedUAV _unit;
        private _hasUav = !isNull _uav;
        private _isInUav = _hasUav && {_unit in ([_uav, true] call TDI_fnc_uavControlUnits)};
        private _drawUnit = _isInUav || {cameraView == "EXTERNAL" && {!isNull _par} && {(typeOf _par) find "arachute" == -1}};
        private _groupUnitsUavs = [];

        {
            _groupUnitsUavs pushBackUnique getConnectedUAV _x;
        } forEach _groupUnits;

        _groupUnitsUavs = _groupUnitsUavs - [objNull];

        private _camPos = positionCameraToWorld [0, 0, 0];
        private _zoom = sqrt (call TDI_fnc_getZoom);
        private _context = [
            _unit,
            _par,
            _drawUnit,
            group _unit,
            _groupUnits,
            [_unit] call TDI_fnc_unitSide,
            _uav,
            _hasUav,
            _isInUav,
            _groupUnitsUavs,
            call TDI_fnc_iconViewDistance,
            _camPos,
            AGLToASL _camPos,
            _zoom,
            sqrt _zoom,
            call TDI_fnc_isSpectator
        ];

        _context call TDI_fnc_gatherUnitIcons;
        _context call TDI_fnc_gatherGroupIcons;

        {
            private _handle = _context spawn (missionNamespace getVariable _x);
            waitUntil {scriptDone _handle};
        } forEach TDI_var_gatherDrawArraysFncs;

        TDI_var_preDrawArray sort false; // far icons first, near icons on top
        TDI_var_drawArray = TDI_var_preDrawArray apply {_x call TDI_fnc_prepareDrawEntry};
        TDI_var_preDrawArray = [];

        sleep (0 max (TDI_var_drawArrayInterval - (time - _passStart)));
        false
    };
};

// ---- drawing (Draw3D, every frame) ----
// Per icon: position, an off-screen check, the size from the current zoom, and drawIcon3D with the prepared
// arguments. No config, string or visibility work happens here.

TDI_fnc_drawIcons = {
    if (!(missionNamespace getVariable ["TDI_cba_showIcons", true])) exitWith {};

    if (!isNull findDisplay 49) exitWith {TDI_var_textKeys=[];TDI_var_showAllText=false};

    private _zoom = sqrt (call TDI_fnc_getZoom);
    private _zooms = [_zoom, sqrt _zoom];
    private _maxDistanceSqr = (call TDI_fnc_iconViewDistance) ^ 2;
    private _cameraPosition = positionCameraToWorld [0,0,0];
    if (!isGameFocused) then {TDI_var_textKeys=[];TDI_var_showAllText=false};
    private _forceText = TDI_var_showAllText;

    {
        _x params ["_obj", "_posType", "_posOffset", "_sizeFactor", "_useSqrtZoom", "_textSizeCutoff", "_text", "_textSizeDivisor", "_floor", "_widthFactor", "_args", "_textEnabled", "_textIconFloor"];

        private _pos = if (_posType == 0) then {
            (_obj modelToWorldVisual (_obj selectionPosition "head")) vectorAdd _posOffset
        } else {
            if (_posType == 1) then {
                _obj modelToWorldVisual (((_obj selectionPosition "head") vectorAdd (_obj selectionPosition "pelvis")) vectorMultiply 0.5)
            } else {
                if (_posType == 4) then {_obj modelToWorld _posOffset} else {_obj modelToWorldVisual _posOffset}
            }
        };

        if ((_cameraPosition distanceSqr _pos) <= _maxDistanceSqr && {(worldToScreen _pos) isNotEqualTo []}) then {
            // the floors only enlarge: what is shown at which distance depends on the unfloored size
            private _naturalSize = _sizeFactor * (_zooms select _useSqrtZoom);
            private _size = _naturalSize max _floor;
            if (_forceText) then {_size = _size max _textIconFloor};

            _args set [2, _pos];
            _args set [3, _size * _widthFactor];
            _args set [4, _size];

            if (_text != "") then {
                _args set [6, if ((_textEnabled && {_naturalSize >= _textSizeCutoff}) || {_forceText}) then {_text} else {""}];
            };

            if (_textSizeDivisor != 0) then {
                _args set [8, _size / _textSizeDivisor];
            };

            drawIcon3D _args;
        };
    } forEach TDI_var_drawArray;
};
