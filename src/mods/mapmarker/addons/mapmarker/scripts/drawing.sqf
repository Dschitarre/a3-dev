// Map marker drawing (client): building the draw array from the unit lists, grouping overlapping labels and drawing it
// every frame. Included by fnc_client.sqf.

// ---- draw array ----

// spreads a background pass over frames: yields once it used up the per-frame budget, returns the new slice start
MM_fnc_yieldIfOverBudget = {
    params ["_sliceStart", "_scheduled"];

    if (_scheduled && {diag_tickTime - _sliceStart > MM_var_frameBudget}) then {
        sleep 0.001;
        _sliceStart = diag_tickTime;
    };

    _sliceStart
};

MM_fnc_unitIcon = {
    params ["_target"];

    if (_target getUnitTrait "Medic") exitWith {"iconManMedic"};

    if (MM_var_restrictUnitIcons) exitWith {"iconMan"};

    if (_target getUnitTrait "Engineer") exitWith {"iconManEngineer"};

    if (_target getUnitTrait "ExplosiveSpecialist") exitWith {"iconManExplosive"};

    private _weaponType = [primaryWeapon _target] call MM_fnc_weaponType;

    if (_weaponType == "MachineGun") exitWith {"iconManMG"};

    if (_weaponType == "SniperRifle") exitWith {"iconManRecon"};

    if (secondaryWeapon _target != "") exitWith {"iconManAT"};

    if (_target isEqualTo leader group _target) exitWith {"iconManLeader"};

    if (rankId _target >= 2) exitWith {"iconManOfficer"};

    "iconMan"
};

// group members: yellow for the focused unit, white for the others; everybody else in the side color
MM_fnc_unitColor = {
    params ["_target", "_unit", "_groupUnits"];

    if (_target in _groupUnits) exitWith {[MM_var_colorWhite, MM_var_colorYellow] select (_target isEqualTo _unit)};

    [_target] call MM_fnc_unitSideColor
};

// label relevance of overlapping labels (higher wins): the viewed unit 6, its vehicle 5, group members and vehicles
// with one 4, players and vehicles with one 3, other crewed vehicles 2 (the label stands for the crew), AI units and
// vehicles shown while empty 1, dead units and wrecks 0
MM_fnc_unitRelevance = {
    params ["_target", "_unit", "_groupUnits"];

    if (_target isEqualTo _unit) exitWith {6};

    if (!alive _target) exitWith {0};

    if (_target in _groupUnits) exitWith {4};

    [1, 3] select (isPlayer _target)
};

MM_fnc_vehicleRelevance = {
    params ["_crew", "_unit", "_groupUnits"];

    if (_unit in _crew) exitWith {5};

    private _aliveCrew = _crew select {alive _x};

    if (_aliveCrew isEqualTo []) exitWith {0};

    if ((_aliveCrew arrayIntersect _groupUnits) isNotEqualTo []) exitWith {4};

    if ((_aliveCrew findIf {isPlayer _x}) != -1) exitWith {3};

    2
};

// the units a label stands for in a group count: a living unit, or the living crew of a vehicle (not a UAV's AI)
MM_fnc_unitCount = {
    params ["_entity"];

    if (_entity isKindOf "CAManBase") exitWith {[0, 1] select (alive _entity)};

    {alive _x && {!([_x] call MM_fnc_isUavAi)}} count (crew _entity)
};

// the name label of an icon, grouped by its relevance (MM_fnc_groupLabels); without names (setting) an empty label
// that only shows the group count, on the GPS none. _alwaysShow: a fixed label (e.g. "Spawn Truck") that always shows,
// also on the GPS and without hover, and takes no part in the grouping
MM_fnc_addNameEntry = {
    params ["_entity", "_isNear", "_offsetToRight", "_icon", "_color", "_text", "_relevance", ["_alwaysShow", false]];

    if (_alwaysShow) exitWith {
        MM_var_preDrawArray pushBack [_entity, _isNear, _offsetToRight, false, _icon, _color, 0, _text, 2, 0.0495, true];
    };

    private _showNames = MM_var_showUnitNamesOverride && {MM_var_showUnitNames};

    if (_showNames || {MM_var_groupLabels && {!MM_var_gpsOpened}}) then {
        MM_var_preDrawArray pushBack [_entity, _isNear, _offsetToRight, false, _icon, _color, 0,
            ["", _text] select _showNames, 2, 0.0495, false, _relevance];
    };
};

MM_fnc_addUnitIcon = {
    params ["_target", "_context"];

    _context params ["_unit", "_groupUnits", "_isNear"];

    private _isUnconscious = [_target] call MM_fnc_isUnconscious;
    private _icon = "iconExplosiveGP";
    private _size = 30;
    private _color = if (_target isEqualTo _unit) then {MM_var_colorYellow} else {[_target] call MM_fnc_unitSideColor};

    if (alive _target) then {
        _color = [_target, _unit, _groupUnits] call MM_fnc_unitColor;

        if (_isUnconscious) then {
            _icon = "pictureHeal";
            _size = 16.3;
        } else {

            _icon = [_target] call MM_fnc_unitIcon;
            _size = 20;
        };
    };

    private _relevance = [_target, _unit, _groupUnits] call MM_fnc_unitRelevance;

    MM_var_preDrawArray pushBack [_target, _isNear, 0, !_isUnconscious, _icon, _color, _size, "", 1, 0, true];
    [_target, _isNear, 55, "iconMan", MM_var_colorWhite, [_target] call MM_fnc_unitName, _relevance] call MM_fnc_addNameEntry;
};

MM_fnc_addParachuteIcon = {
    params ["_target", "_context"];

    _context params ["_unit", "_groupUnits", "_isNear"];

    private _driver = driver _target;

    private _color = if (_driver in _groupUnits) then {
        [MM_var_colorWhite, MM_var_colorYellow] select (_driver isEqualTo _unit)
    } else {

        [_target] call MM_fnc_unitSideColor
    };

    private _relevance = [_driver, _unit, _groupUnits] call MM_fnc_unitRelevance;

    MM_var_preDrawArray pushBack [_target, _isNear, 0, false, "iconParachute", _color, MM_var_parachuteIconSize, "", 1, 0, true];
    [_target, _isNear, 3 * MM_var_parachuteIconSize, "iconParachute", MM_var_colorWhite,
        [_driver] call MM_fnc_unitName, _relevance] call MM_fnc_addNameEntry;
};

// "Hunter (destroyed) [J. Doe, A. Smith (dead), + 2 alive]"
MM_fnc_crewMemberLabel = {
    params ["_member", "_vehicle", "_crewInVehicle"];

    private _name = [_member] call MM_fnc_unitName;

    if (!alive _member) exitWith {_name + " (dead)"};

    if ((getConnectedUAV _member) isEqualTo _vehicle) exitWith {_name + ([" (remote)", " (crew + remote)"] select (_member in _crewInVehicle))};

    if ([_member] call MM_fnc_isUnconscious) exitWith {_name + " (unconscious)"};

    _name
};

MM_fnc_vehicleLabel = {
    params ["_vehicle", "_crew"];

    private _crewInVehicle = crew _vehicle;
    private _otherCrew = _crew select [2];
    private _crewTexts = ((_crew select [0, 2]) apply {[_x, _vehicle, _crewInVehicle] call MM_fnc_crewMemberLabel}) select {_x != ""};

    private _aliveCount = {alive _x} count _otherCrew;
    private _deadCount = count _otherCrew - _aliveCount;

    if (_aliveCount > 0) then {
        _crewTexts pushBack format ["+ %1 alive", _aliveCount];
    };

    if (_deadCount > 0) then {
        _crewTexts pushBack format ["+ %1 dead", _deadCount];
    };

    (_vehicle getVariable ["MM_var_name", ""])
    + (if (unitIsUAV _vehicle) then {" (AI)"} else {""})
    + (if (alive _vehicle) then {""} else {" (destroyed)"})
    + (if (_crew isEqualTo []) then {""} else {" [" + (_crewTexts joinString ", ") + "]"})
};

// size factor of a vehicle map icon that makes the colored areas of all vehicle icons about equal
// (MM_var_vehicleIconInfo, vehicleIcons.sqf; key: a CfgVehicleIcons class or a texture path, lower case, no leading
// backslash), 1 for icons the table does not know; cached per icon - a vehicle's icon variable arrives from the server
// a moment after the vehicle itself, so a cache per class could keep the default icon's factor
MM_var_vehicleIconScales = createHashMap;

MM_fnc_vehicleIconScale = {
    params ["_icon"];

    private _scale = MM_var_vehicleIconScales get _icon;

    if (isNil "_scale") then {
        private _key = toLowerANSI _icon;

        if ((_key select [0, 1]) == "\") then {
            _key = _key select [1];
        };

        // a texture path without extension (CfgVehicleIcons classes have no backslash)
        if (((_key find "\") != -1) && {(_key find ".") == -1}) then {
            _key = _key + ".paa";
        };

        _scale = MM_var_vehicleIconInfo getOrDefault [_key, 1];
        MM_var_vehicleIconScales set [_icon, _scale];
    };

    _scale
};

// _emptySide: a vehicle without living crew, drawn for this side (MM_var_showWhenEmpty), else sideUnknown
MM_fnc_addVehicleIcon = {
    params ["_vehicle", "_context", ["_emptySide", sideUnknown]];

    _context params ["_unit", "_groupUnits", "", "_objectViewDistance", "_camPos"];

    private _crew = [_vehicle] call MM_fnc_getCrew;
    private _groupUnitsInCrew = _crew arrayIntersect _groupUnits;
    private _isShownEmpty = _emptySide != sideUnknown;

    // group members inside: white (yellow with the focused unit), else the side color of the (first) crew - of an
    // empty vehicle the side it is shown for
    private _color = switch (true) do {
        case (_groupUnitsInCrew isNotEqualTo []): {[MM_var_colorWhite, MM_var_colorYellow] select (_unit in _groupUnitsInCrew)};
        case (_isShownEmpty): {[_emptySide] call MM_fnc_sideColor};
        default {[([_crew, crew _vehicle] select (_crew isEqualTo [])) select 0] call MM_fnc_unitSideColor};
    };

    // one base size for all vehicles, scaled only by the icon's opaque area (not by the mass); the label keeps its distance to the icon
    private _icon = _vehicle getVariable ["MM_var_icon", "iconCar"];
    private _size = MM_var_vehicleIconSize * ([_icon] call MM_fnc_vehicleIconScale);
    private _isNear = isServer || {_vehicle distance _camPos <= _objectViewDistance};
    private _relevance = if (_isShownEmpty) then {1} else {[_crew, _unit, _groupUnits] call MM_fnc_vehicleRelevance};

    // a vehicle with a fixed label (MM_var_emptyLabel, e.g. the spawn vehicles of a mission) always shows it, manned
    // or empty; others the label of their crew
    private _label = _vehicle getVariable ["MM_var_emptyLabel", ""];
    private _isFixedLabel = _label != "";

    if (!_isFixedLabel) then {
        _label = [_vehicle, _crew] call MM_fnc_vehicleLabel;
    };

    MM_var_preDrawArray pushBack [_vehicle, _isNear, 0, true, _icon, _color, _size, "", 1, 0, true];
    [_vehicle, _isNear, 3 * _size, _icon, MM_var_colorWhite, _label, _relevance, _isFixedLabel] call MM_fnc_addNameEntry;
};

// the vehicles without living crew that a game mode shows to one of the shown sides (MM_var_showWhenEmpty) and that
// are not drawn yet (through dead crew)
MM_fnc_isHiddenForMap = {
    isObjectHidden _this && {!(_this getVariable ["EC_var_culled", false])} && {!(_this getVariable ["CU_var_culled", false])}
};

MM_fnc_addEmptyVehicleIcons = {
    params ["_shownSides", "_drawnVehicles", "_unit", "_groupUnits", "_objectViewDistance", "_camPos", "_scheduled"];

    private _sliceStart = diag_tickTime;

    {
        private _vehicle = _x;
        private _side = _vehicle getVariable ["MM_var_showWhenEmpty", sideUnknown];

        if (
        alive _vehicle && {simulationEnabled _vehicle} && {_side in _shownSides} &&
            {!(_vehicle in _drawnVehicles)} && {((crew _vehicle) findIf {alive _x}) == -1} &&
            {!(_vehicle call MM_fnc_isHiddenForMap)} &&
            {!MM_var_gpsOpened ||
            {[uiNamespace getVariable "MM_var_currentDisplay",
            getPosWorldVisual _vehicle] call MM_fnc_isPosVisibleOnGps}}

        ) then {
            private _isNear = isServer || {_vehicle distance _camPos <= _objectViewDistance};

            [_vehicle, [_unit, _groupUnits, _isNear, _objectViewDistance, _camPos], _side] call MM_fnc_addVehicleIcon;
        };

        _sliceStart = [_sliceStart, _scheduled] call MM_fnc_yieldIfOverBudget;
    } forEach MM_var_emptyShownVehicles;
};

MM_fnc_updateDrawArray = {
    params ["_scheduled"];

    call MM_fnc_updateUnitBuckets;

    private _unit = call MM_fnc_viewUnit;
    private _groupUnits = [_unit] call MM_fnc_getGroupUnits;
    private _objectViewDistance = if (isServer) then {-1} else {getObjectViewDistance select 0};
    private _camPos = if (isServer) then {[]} else {positionCameraToWorld [0, 0, 0]};
    private _drawnVehicles = [];
    private _sliceStart = diag_tickTime;
    private _shownSides = [_unit] call MM_fnc_shownSides;

    // the EG spectator draws units and crewed vehicles on its map itself
    private _unitLists = if (MM_var_spectatorMapOpened) then {[]} else {
        _shownSides apply {"MM_var_units" + ([_x] call MM_fnc_getSideString)}
    };

    {
        {
            private _target = _x;

            if (

            !isNull _target && {simulationEnabled _target} &&
                {!(missionNamespace getVariable ["MM_var_showOwnUnitOnly", false]) ||
                {_target isEqualTo _unit}} &&
                {!MM_var_gpsOpened ||
                {[uiNamespace getVariable "MM_var_currentDisplay",
                getPosWorldVisual _target] call MM_fnc_isPosVisibleOnGps}} && {
                MM_var_showAliveGroupUnits || {_target isEqualTo _unit} || {!(_target in _groupUnits)} ||
                    {!alive _target} || {[_target] call MM_fnc_isUnconscious}
            }

            ) then {
                private _parTarget = objectParent _target;

                // Rendering culling is local to the camera; it must not remove legitimate map information.
                private _isHidden = _target call MM_fnc_isHiddenForMap;
                private _isNear = isServer || {_target distance _camPos <= _objectViewDistance};
                private _context = [_unit, _groupUnits, _isNear, _objectViewDistance, _camPos];

                switch (true) do {
                    case (isNull _parTarget): {
                        if (!_isHidden) then {
                            [_target, _context] call MM_fnc_addUnitIcon;
                        };
                    };
                    case (!_isHidden && {_parTarget isKindOf "Steerable_Parachute_F"}): {
                        [_target, _context] call MM_fnc_addParachuteIcon;
                    };

                    // a vehicle is drawn once per pass; a UAV always through its AI driver
                    case (
                    (!_isHidden && {!(_parTarget in _drawnVehicles)}) ||
                        {[_target] call MM_fnc_isUavAi && {_target isEqualTo driver _parTarget}}

                    ): {
                        _drawnVehicles pushBack _parTarget;
                        [_parTarget, _context] call MM_fnc_addVehicleIcon;
                    };
                };
            };

            _sliceStart = [_sliceStart, _scheduled] call MM_fnc_yieldIfOverBudget;
        } forEach (missionNamespace getVariable _x);
    } forEach _unitLists;

    [_shownSides, _drawnVehicles, _unit, _groupUnits, _objectViewDistance, _camPos, _scheduled] call MM_fnc_addEmptyVehicleIcons;

    // game mode entries not on the EG spectator map (only the empty vehicles are added there)
    if (!MM_var_spectatorMapOpened) then {
        {
            if (_scheduled) then {
                private _handle = [_scheduled] spawn (missionNamespace getVariable _x);
                waitUntil {scriptDone _handle};
            } else {

                [_scheduled] call (missionNamespace getVariable _x);
            };
        } forEach MM_var_gatherDrawArrFncs;
    };

    [_scheduled] call MM_fnc_buildDrawArray;
    MM_var_preDrawArray = [];
    MM_var_lastDrawArrUpdateFrameNo = diag_frameNo;
};

// public entry -> per-frame form: [entity, isNear, offsetToRight, calculateDir, textSize, alwaysShow,
// drawIcon arguments, label texts] - label texts of a grouping label: [text placed by the grouping, whole text when
// hovered] (MM_fnc_buildDrawArray), else []
MM_fnc_prepareDrawEntry = {
    params ["_entity", "_isNear", "_offsetToRight", "_calculateDir", "_icon", "_color", "_size", "_text", "_shadow", "_textSize", "_alwaysShow"];

    if (_color isEqualType {}) then {
        _color = call _color;
    };

    _size = _size * MM_var_iconSizeFactor;

    private _args = [_icon, _color, [0, 0, 0], _size, _size, 0, _text, _shadow];

    if (_textSize != 0) then {
        _args append [0, MM_var_font];
    };

    [_entity, _isNear, _offsetToRight, _calculateDir, _textSize, _alwaysShow, _args, []]
};

// ---- grouping labels ----
// The icons are always drawn; only their labels (names) group: a label that would overlap a label drawn before is
// hidden and its units count in that one ("J. Doe +3"), so every drawn label stands for its icon and the ones nearby.
// The grouping runs at the end of every draw-array pass (in the background, within the frame budget) and a pass starts
// at once after a zoom - the Draw handler only reads the results. Not on the GPS.
// Labels are rectangles [minX, minY, maxX, maxY, label index] in world metres at the zoom of the map drawn last,
// entered in every cell of a grid they cover.

// MM_var_preDrawArray -> MM_var_drawArray; the text-only entries with a label relevance are the labels that group
MM_fnc_buildDrawArray = {
    params ["_scheduled"];

    private _labels = []; // [relevance, entity, isNear, offsetToRight, textSize, alwaysShow, label texts]

    private _drawArray = MM_var_preDrawArray apply {
        _x params ["_entity", "_isNear", "_offsetToRight", "", "", "", "_size", "_text", "", "_textSize", "_alwaysShow", ["_relevance", -1]];

        private _entry = _x call MM_fnc_prepareDrawEntry;

        if (_relevance >= 0 && {_size == 0}) then {

            // ungrouped (switched off, GPS): the text where names show without hover
            private _labelTexts = [["", _text] select (_alwaysShow || {!MM_var_showUnitNamesOnlyOnHover}), _text];

            _entry set [7, _labelTexts];
            _labels pushBack [_relevance, _entity, _isNear, _offsetToRight, _textSize, _alwaysShow, _labelTexts];
        };

        _entry
    };

    // names only on hover: no grouping and no "+X", the cursor shows the one nearest name (MM_fnc_drawIcons)
    if (MM_var_groupLabels && {!MM_var_gpsOpened} && {!MM_var_showUnitNamesOnlyOnHover}) then {
        [_labels, _scheduled] call MM_fnc_groupLabels;
    };

    MM_var_drawArray = _drawArray;
};

// the grid cells [x, y] a rectangle covers
MM_fnc_rectCells = {
    params ["_rect", "_cellSize"];

    _rect params ["_minX", "_minY", "_maxX", "_maxY"];

    private _cells = [];

    for "_cellX" from (floor (_minX / _cellSize)) to (floor (_maxX / _cellSize)) do {
        for "_cellY" from (floor (_minY / _cellSize)) to (floor (_maxY / _cellSize)) do {
            _cells pushBack [_cellX, _cellY];
        };
    };

    _cells
};

// the first rectangle in the grid that overlaps _rect, else []
MM_fnc_findOverlap = {
    params ["_grid", "_rect", "_cellSize"];

    _rect params ["_minX", "_minY", "_maxX", "_maxY"];

    private _overlap = [];

    {
        private _cellRects = _grid getOrDefault [_x, []];

        private _index = _cellRects findIf {
            _x params ["_otherMinX", "_otherMinY", "_otherMaxX", "_otherMaxY"];

            _minX < _otherMaxX && {_otherMinX < _maxX} && {_minY < _otherMaxY} && {_otherMinY < _maxY}
        };

        if (_index != -1) exitWith {
            _overlap = _cellRects select _index;
        };
    } forEach ([_rect, _cellSize] call MM_fnc_rectCells);

    _overlap
};

MM_fnc_addRect = {
    params ["_grid", "_rect", "_cellSize"];

    {
        private _cellRects = _grid get _x;

        if (isNil "_cellRects") then {
            _grid set [_x, [_rect]];
        } else {

            _cellRects pushBack _rect;
        };
    } forEach ([_rect, _cellSize] call MM_fnc_rectCells);
};

// the rectangle of a text that drawIcon writes from _left on, vertically centred on its position
MM_fnc_textRect = {
    params ["_text", "_left", "_centreY", "_textSize", "_metresPerX", "_metresPerY"];

    private _halfHeight = 0.5 * _textSize * _metresPerY;

    [_left, _centreY - _halfHeight, _left + (_text getTextWidth [MM_var_font, _textSize]) * _metresPerX, _centreY + _halfHeight]
};

// In relevance order (ties: nearer to the viewed unit) a label is drawn unless it overlaps a label drawn before - then
// it joins that one: hidden, its units counted there. Each label keeps room for the count (MM_var_groupCountSpace);
// the label of the viewed unit or its vehicle always shows. Texts of never grouping entries (sector markers, ...) are
// no obstacles: they cannot take a label in, and no label may vanish without being counted in another one.
MM_fnc_groupLabels = {
    params ["_labels", "_scheduled"];

    disableSerialization;

    private _mapCtrl = uiNamespace getVariable ["MM_var_currentDisplay", controlNull];

    if (isNull _mapCtrl) exitWith {};

    MM_var_groupScale = ctrlMapScale _mapCtrl;
    MM_var_groupHoverChanged = false;

    // text sizes and widths are screen units; a map shows the same metres per pixel on both axes
    private _metresPerPixel =((_mapCtrl ctrlMapScreenToWorld [0.5,
        0.5]) distance2D (_mapCtrl ctrlMapScreenToWorld [0.5 + 100 * pixelW, 0.5])) / 100;
    private _metresPerX = _metresPerPixel / pixelW; // metres per screen unit
    private _metresPerY = _metresPerPixel / pixelH;
    private _cellSize = MM_var_groupCellSize * _metresPerY;

    if (_cellSize <= 0) exitWith {};

    private _offsetScale = MM_var_groupScale * MM_var_mapScaleFactor; // metres per offsetToRight unit
    private _namesShown = !MM_var_showUnitNamesOnlyOnHover;
    private _viewPos = getPosWorldVisual (call MM_fnc_viewUnit);
    private _order = [];
    private _sliceStart = diag_tickTime;

    {
        _x params ["_relevance", "_entity", "_isNear", "_offsetToRight", "_textSize", "_alwaysShow", "_labelTexts"];

        // a far entity: where its icon is shown (MM_fnc_farPosAndDir)
        private _move = if (_isNear) then {[]} else {_entity getVariable ["MM_var_serverMove", []]};
        private _pos = if(_move isEqualTo []) then {getPosWorldVisual _entity} else {([_move,
            diag_tickTime] call MM_fnc_farPosAndDir) select 0};
        private _name = _labelTexts select 1;
        private _text = if((_alwaysShow || _namesShown) &&
            {_name != ""}) then {_name + " " + MM_var_groupCountSpace} else {MM_var_groupCountSpace};

        // the on-screen text size is constant (zoom compensation in MM_fnc_drawIcons): the size at the reference scale
        private _rect =[_text,(_pos select 0) + _offsetToRight * _offsetScale, _pos select 1,
            _textSize * MM_var_textSizeFactor, _metresPerX, _metresPerY] call MM_fnc_textRect;

        _rect pushBack _forEachIndex;
        _x append [_rect, 0, true]; // rectangle, units taken in, drawn

        // the label of the entity nearest to the mouse (MM_fnc_drawIcons) first after the viewed unit's
        private _priority = if (_entity isEqualTo MM_var_groupHoverEntity) then {_relevance max 4.5} else {_relevance};

        _order pushBack [-_priority, _pos distance2D _viewPos, _forEachIndex];
        _sliceStart = [_sliceStart, _scheduled] call MM_fnc_yieldIfOverBudget;
    } forEach _labels;

    private _grid = createHashMap; // [cellX, cellY] -> rectangles of the drawn labels in the cell

    _order sort true;

    {
        private _label = _labels select (_x select 2);

        _label params ["_relevance", "_entity", "", "", "", "", "", "_rect"];

        // the viewed unit or its vehicle (MM_fnc_unitRelevance) always shows
        private _overlap = if (_relevance >= 5) then {[]} else {[_grid, _rect, _cellSize] call MM_fnc_findOverlap};

        if (_overlap isEqualTo []) then {
            [_grid, _rect, _cellSize] call MM_fnc_addRect;
        } else {

            private _group = _labels select (_overlap select 4);

            _group set [8, (_group select 8) + ([_entity] call MM_fnc_unitCount)];
            _label set [9, false];
        };

        _sliceStart = [_sliceStart, _scheduled] call MM_fnc_yieldIfOverBudget;
    } forEach _order;

    // drawn without hover: "J. Doe +3" where names show, else only "+3"; hovered: the whole text
    {
        _x params ["", "", "", "", "", "_alwaysShow", "_labelTexts", "", "_units", "_isDrawn"];

        private _name = _labelTexts select 1;
        private _countText = if (_units > 0) then {format ["+%1", _units]} else {""};

        private _wholeText = if (_countText == "") then {_name} else {
            if (_name == "") then {_countText} else {_name + " " + _countText}
        };

        private _placedText = switch (true) do {
            case (!_isDrawn): {""};
            case (_alwaysShow || _namesShown): {_wholeText};
            default {_countText};
        };

        _labelTexts set [0, _placedText];
        _labelTexts set [1, _wholeText];
    } forEach _labels;
};

// the map was zoomed since the last grouping: the labels have to group anew
MM_fnc_isGroupingOutdated = {
    MM_var_groupLabels && {!MM_var_gpsOpened} && {!MM_var_showUnitNamesOnlyOnHover} && {
        MM_var_groupHoverChanged ||
            {abs (ctrlMapScale (uiNamespace getVariable ["MM_var_currentDisplay",
            controlNull]) - MM_var_groupScale) > MM_var_groupRescale * MM_var_groupScale}
    }
};

MM_fnc_updateDrawArrayLoop = {
    waitUntil {

        // only while a map control is drawn
        waitUntil {diag_frameNo - MM_var_lastDrawFrameNo < 10};

        private _passStart = time;

        if (diag_tickTime > MM_var_colorRefreshTime) then {
            call MM_fnc_refreshColors;
        };

        MM_var_updateDrawArrayScript = [true] spawn MM_fnc_updateDrawArray;
        waitUntil {scriptDone MM_var_updateDrawArrayScript};

        // the next pass after the interval, or at once after a zoom
        waitUntil {time - _passStart >= MM_var_drawArrayInterval || {call MM_fnc_isGroupingOutdated}};
        false
    };
};

MM_fnc_updateDrawArrayImmediate = {
    if (!scriptDone MM_var_updateDrawArrayScript) then {
        terminate MM_var_updateDrawArrayScript;
    };

    MM_var_drawArray = [];
    MM_var_preDrawArray = [];
    MM_var_lastDrawArrUpdateFrameNo = diag_frameNo;
    [false] call MM_fnc_updateDrawArray;
};

// ---- drawing (map control "Draw", every frame) ----
// Per icon: the position (local, or moving towards the one the server sent last), optionally the direction and text
// size, written into the prepared drawIcon arguments. No config, string or entity queries happen here; a label only
// picks the text the grouping prepared.

MM_fnc_drawIcons = {
    if (!(missionNamespace getVariable ["MM_cba_showMarkers", true])) exitWith {};

    params ["_mapCtrl"];

    private _parentIdd = ctrlIDD ctrlParent _mapCtrl;
    private _isSpectatorMap = _parentIdd == MM_var_spectatorDisplay;

    uiNamespace setVariable ["MM_var_currentDisplay", _mapCtrl];
    MM_var_gpsOpened = !(_parentIdd in MM_var_fullMapIdds);
    MM_var_showAllSidesOverride = _parentIdd in MM_var_allSidesMapIdds;

    // switched between GPS (no names), map and EG spectator map, or the list is stale: rebuild now
    if (
    MM_var_showUnitNamesOverride == MM_var_gpsOpened || {MM_var_spectatorMapOpened != _isSpectatorMap} ||
        {scriptDone MM_var_updateDrawArrayScript && {diag_frameNo - MM_var_lastDrawArrUpdateFrameNo > 200}}

    ) then {
        MM_var_showUnitNamesOverride = !MM_var_gpsOpened;
        MM_var_spectatorMapOpened = _isSpectatorMap;
        call MM_fnc_updateDrawArrayImmediate;
    };

    private _mapScale = ctrlMapScale _mapCtrl;
    private _offsetScale = _mapScale * MM_var_mapScaleFactor;

    // constant on-screen text size at every zoom: undoes the engine's text growth below the reference scale
    private _textSizeFactor = MM_var_textSizeFactor *((((_mapScale max MM_var_textZoomMinScale) /
        MM_var_textZoomReference) ^ MM_var_textZoomExponent) min 1);
    private _showOptional = !MM_var_gpsOpened;

    // Share the held Windows-key reveal with 3D icons without changing the saved hover preference.
    private _forceNames = (missionNamespace getVariable ["TDI_var_showAllText", false]) && {isGameFocused};
    private _hoverOnly = MM_var_showUnitNamesOnlyOnHover && {!_forceNames};
    private _mousePos = getMousePosition;
    private _now = diag_tickTime;
    private _texts = []; // all texts are drawn after all icons, so no icon covers a text
    private _hovered = []; // names only on hover: [cursor distance, drawIcon arguments] of the nearest name, drawn last
    private _nearest = [MM_var_hoverRadius, objNull]; // grouped names: [cursor distance, entity] of the nearest label
    private _trackNearest = _showOptional && {!_hoverOnly} && {!_forceNames} && {MM_var_groupLabels};

    // a text to draw after the icons; of the hovered names only the one nearest to the cursor
    private _addText = {
        params ["_textArgs"];

        if (_isHovered) then {
            if ((_hovered isEqualTo []) || {_cursorDistance < (_hovered select 0)}) then {
                _hovered = [_cursorDistance, _textArgs];
            };
        } else {

            _texts pushBack _textArgs;
        };
    };

    {
        _x params ["_entity", "_isNear", "_offsetToRight", "_calculateDir", "_textSize", "_alwaysShow", "_args", "_labelTexts"];

        // a label: [text placed by the grouping, whole text]
        private _isLabel = _labelTexts isNotEqualTo [];

        if (_alwaysShow || _showOptional) then {

            // a far entity: the server state continued (MM_fnc_farPosAndDir)
            private _move = if (_isNear) then {[]} else {_entity getVariable ["MM_var_serverMove", []]};
            private _far = if (_move isEqualTo []) then {[]} else {[_move, _now] call MM_fnc_farPosAndDir};
            private _pos = if (_move isEqualTo []) then {getPosWorldVisual _entity} else {_far select 0};
            private _cursorDistance = if(_hoverOnly &&
                {!_alwaysShow}) then {(_mapCtrl ctrlMapWorldToScreen _pos) distance _mousePos} else {0};
            private _isVisible = _alwaysShow || {_showOptional && {!_hoverOnly || {_cursorDistance < MM_var_hoverRadius}}};
            private _isHovered = false;

            if (_isLabel && {_trackNearest}) then {
                private _distance = (_mapCtrl ctrlMapWorldToScreen _pos) distance _mousePos;

                if (_distance < (_nearest select 0)) then {
                    _nearest = [_distance, _entity];
                };
            };

            if (_isLabel) then {

                // a hovered name shows whole and on top (only the nearest one), the others as placed
                _isHovered = _isVisible && {_hoverOnly} && {!_alwaysShow};

                private _text = _labelTexts select ([0, 1] select (_isHovered || _forceNames));

                _args set [6, _text];
                _isVisible = _text != "";
            };

            if (_isVisible) then {
                if (_offsetToRight != 0) then {
                    _pos = _pos vectorAdd [_offsetToRight * _offsetScale, 0, 0];
                };

                _args set [2, _pos];

                if (_calculateDir) then {
                    _args set [5, if (_move isEqualTo []) then {getDirVisual _entity} else {_far select 1}];
                };

                if (_textSize != 0) then {
                    _args set [8, _textSizeFactor * _textSize];
                };

                switch true do {
                    case ((_args select 6) == ""): {
                        _mapCtrl drawIcon _args;
                    };

                    // an icon with its own text: the icon now, the text later with an invisible icon of the same size
                    // (drawIcon places the text by the icon size)
                    case (((_args select 3) > 0) && {(_args select 0) != ""}): {
                        private _iconArgs = +_args;
                        _iconArgs set [6, ""];
                        _mapCtrl drawIcon _iconArgs;

                        private _textArgs = +_args;
                        _textArgs set [0, MM_var_emptyIcon];
                        [_textArgs] call _addText;
                    };
                    default {
                        [_args] call _addText;
                    };
                };
            };
        };
    } forEach MM_var_drawArray;

    {
        _mapCtrl drawIcon _x;
    } forEach _texts;

    if (_hovered isNotEqualTo []) then {
        _mapCtrl drawIcon (_hovered select 1);
    };

    // another entity is nearest to the mouse now: its label gets priority in the next grouping, at once
    if (_trackNearest && {(_nearest select 1) isNotEqualTo MM_var_groupHoverEntity}) then {
        MM_var_groupHoverEntity = _nearest select 1;
        MM_var_groupHoverChanged = true;
    };

    MM_var_lastDrawFrameNo = diag_frameNo;
};
