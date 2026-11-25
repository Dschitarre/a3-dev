// HUD: sector overview with the capture info, group overview and player stats panels, dialog table styling and UI
// helpers (client).

// ---- hud ----

// sector bar color: the holder's side color (player's map colors), not captured sectors transparent black
SC_fnc_getHudColor = {
    params ["_side"];

    if !(_side in SC_var_sides) exitWith {[0, 0, 0, 0.35]};

    (([_side] call UI_fnc_sideColor) select [0, 3]) + [0.85]
};

// ---- table colors (controls tables of the dialogs) ----

// header: background in the accent color, labels in pure white; _controls: [background, columns ...]
SC_fnc_styleTableHeader = {
    params ["_controls"];

    (_controls select 0) ctrlSetBackgroundColor (["accent"] call UI_fnc_color);

    {
        _x ctrlSetTextColor [1, 1, 1, 1];
    } forEach (_controls select [1, count _controls]);
};

// row: a light tile on the dark dialog body like the data tiles of the vanilla debriefing (pictures of dark weapons
// stay visible; a further black layer made them disappear), black when locked, error color when unavailable; cells
// transparent
SC_fnc_styleTableRow = {
    params ["_controls", ["_state", "normal"]];

    private _background = switch _state do {
        case "locked": {[0, 0, 0, 0.3]};
        case "unavailable": {((["error"] call UI_fnc_color) select [0, 3]) + [0.5]};
        default {[1, 1, 1, 0.06]};
    };
    private _textColor = [[1, 1, 1, 1], [1, 1, 1, 0.5]] select (_state != "normal");

    (_controls select 0) ctrlSetBackgroundColor _background;

    {
        _x ctrlSetBackgroundColor [0, 0, 0, 0];
        _x ctrlSetTextColor _textColor;
    } forEach (_controls select [1, count _controls]);
};

// remoteExec'd to everyone (target 0): a dedicated server or headless client has no HUD setting and shows nothing
SC_fnc_showNotificationIfHudIsEnabled = {
    if (hasInterface && {missionNamespace getVariable ["SC_var_hudEnabled", true]}) then {
        _this call BIS_fnc_showNotification;
    };
};

// settings indices of the HUD elements that "whole HUD on the map / when unconscious" shows as by default; the other
// settings (3D icon and map behaviour, 11 - 16) always stay the player's own
SC_var_wholeHudSettings = [5, 6, 7, 8, 9, 10, 17, 18, 19, 20];

// _mapOpen: whether the map is open (the "Map" event passes the new state, visibleMap may still be the old one)
SC_fnc_setHud = {
    params ["_enable", ["_mapOpen", visibleMap]];

    SC_var_hudShown = _enable;

    private _settings = +SC_var_settings;

    switch true do {
        case !SC_var_hudShown: {
            _settings = SC_var_defaultSettings apply {!_x};
        };
        case ((SC_var_showWholeHudOnMap && _mapOpen) || {SC_var_showWholeHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}): {
            {
                _settings set [_x, SC_var_defaultSettings select _x];
            } forEach SC_var_wholeHudSettings;
        };
    };

    // Hiding the HUD must not reverse the player's map-name preference.
    _settings set [16, SC_var_settings select 16];

    (_settings select [5, 16]) params [
        "_sectorOverview",
        "_playerStats",
        "_groupOverview",
        "_killfeed",
        "_midfeed",
        "_deathfeed",
        "_unitNamesBelow3DUnitIcons",
        "_hideInvisible3DGroupIcons",
        "_limit3DGroupIconDrawDistance",
        "_sector3DIcons",
        "_airDrop3DIcons",
        "_showMapGroupIconsOnlyOnHover",
        "_infoPanels",
        "_vehicleRadar",
        "_vehicleCompass",
        "_gpsPanel"
    ];

    if (_midfeed && _mapOpen && !(alive player)) then {
        _midfeed = false;
    };

    disableSerialization;

    [_killfeed] call KF_fnc_EnableKillFeed;
    [_midfeed] call KF_fnc_EnableMidFeed;
    [_deathfeed] call KF_fnc_EnableDeathFeed;

    TDI_var_ShowUnitNames = _unitNamesBelow3DUnitIcons;
    TDI_var_HideInvisibleGroupMembers = _hideInvisible3DGroupIcons;
    TDI_var_groupUnitsLimitedDistance = _limit3DGroupIconDrawDistance;
    MM_var_showUnitNamesOnlyOnHover = _showMapGroupIconsOnlyOnHover;

    showHUD [
        true,
            // scripted HUD such as weapon crosshair, action menu and overlays created with cutRsc and titleRsc. Same as showHUD's first syntax
        _infoPanels, // vehicle, soldier and weapon info
        _vehicleRadar, // vehicle radar
        _vehicleCompass, // vehicle compass
        true, // tank direction indicator. Not present in vanilla Arma 3
        true, // commanding menu (HC related menus)
        false, // group info bar (Squad leader info bar)
        true, // Show HUD weapon cursors (connected with scripted HUD)
        _gpsPanel, // Custom Info (for example GPS and vehicle crew)
        true, // "x killed by y" systemChat messages
        true // icons drawn with drawIcon3D even when the HUD is hidden
    ];

    private _hudDisplay = _sectorOverview || _groupOverview || _playerStats;

    if (
        (!_sectorOverview && !(isNull SC_var_hudUpdateSectorOverviewLoopScript)) ||
        {!_groupOverview && !(isNull SC_var_hudUpdateGroupOverviewLoopScript)} ||
        {!_playerStats && !(isNull SC_var_hudUpdatePlayerStatsLoopScript)}
    ) then {
        terminate SC_var_hudUpdateSectorOverviewLoopScript;
        SC_var_hudUpdateSectorOverviewLoopScript = scriptNull;

        terminate SC_var_hudUpdateGroupOverviewLoopScript;
        SC_var_hudUpdateGroupOverviewLoopScript = scriptNull;

        terminate SC_var_hudUpdatePlayerStatsLoopScript;
        SC_var_hudUpdatePlayerStatsLoopScript = scriptNull;

        (uiNamespace getVariable "SC_var_sectorControlDisplay") closeDisplay 1;
        SC_var_hudDisplayIsOpen = false;
    };

    if (_hudDisplay && !SC_var_hudDisplayIsOpen) then {
        (["sectorControlHud"] call BIS_fnc_rscLayer) cutRsc ["sectorControlDisplay", "PLAIN", 0, true];
        SC_var_hudDisplayIsOpen = true;
    };

    if (_sectorOverview && (isNull SC_var_hudUpdateSectorOverviewLoopScript)) then {
        [0] call SC_fnc_hudUpdateSectorOverview;
        call SC_fnc_hudUpdateCaptureInfo;
        SC_var_hudUpdateSectorOverviewLoopScript = [] spawn SC_fnc_hudUpdateSectorOverviewLoop;
    };

    if (_groupOverview && (isNull SC_var_hudUpdateGroupOverviewLoopScript)) then {
        [0] call SC_fnc_hudUpdateGroupOverview;
        SC_var_hudUpdateGroupOverviewLoopScript = [] spawn SC_fnc_hudUpdateGroupOverviewLoop;
    };

    if (_playerStats && (isNull SC_var_hudUpdatePlayerStatsLoopScript)) then {
        [true, 0] call SC_fnc_hudUpdatePlayerStats;
        SC_var_hudUpdatePlayerStatsLoopScript = [] spawn SC_fnc_hudUpdatePlayerStatsLoop;
    };

    if (!_hudDisplay && SC_var_hudDisplayIsOpen) then {
        (uiNamespace getVariable "SC_var_sectorControlDisplay") closeDisplay 1;
        SC_var_hudDisplayIsOpen = false;
    };
};

// ---- sector overview (top centre) ----

// width of a sector bar of the sector overview (share of the safe zone width)
SC_var_hudSectorWidth = 0.0155;

// the sector bars animate over SC_var_hudSectorInterval seconds; the capture info is updated every
// SC_var_hudCaptureInfoInterval seconds, so it follows the flag faster
SC_var_hudSectorInterval = 1.2;
SC_var_hudCaptureInfoInterval = 0.4;

SC_fnc_hudUpdateSectorOverview = {
    params ["_commitDuration"];

    disableSerialization;
    private _display = uiNamespace getVariable "SC_var_sectorControlDisplay";

    private _aspectRatio = (getResolution select 0) / (getResolution select 1);
    private _sectorWidth = SC_var_hudSectorWidth;
    private _sectorHeight = 3 * _sectorWidth / _aspectRatio;
    private _sectorGapX = _sectorWidth / 8;
    private _sectorGapY = 3 * _sectorGapX / _aspectRatio;
    private _numSectors = count SC_var_sectors;
    private _totalSectorWidth = _numSectors * _sectorWidth + (_numSectors - 1) * _sectorGapX;

    for "_i" from 0 to (_numSectors-1) step 1 do {
        private _posX = 0.5 - 0.5 * _totalSectorWidth + _i * _sectorWidth + _i * _sectorGapX;
        private _points = missionNamespace getVariable ("SC_var_flag" + (SC_var_sectors select _i));

        (_display displayCtrl (8030 + _i)) ctrlSetBackgroundColor ([missionNamespace getVariable ("SC_var_holder"
            +(SC_var_sectors select _i))] call SC_fnc_getHudColor);
        (_display displayCtrl (8030 + _i)) ctrlSetPosition ([_posX,
            1 -(_sectorGapY + _sectorHeight *((100 - _points) / 100)), _sectorWidth,
            _sectorHeight *(_points / 100), "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl (1807 + _i)) ctrlSetPosition ([_posX,
            1 -(_sectorGapY + _sectorHeight *((100 - _points) / 100)), _sectorWidth, 0,
            "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl (1020 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth,
            _sectorHeight *((100 - _points) / 100), "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl (3040 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth,
            _sectorHeight, "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl (1910 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth,
            _sectorHeight, "CENTER"] call SC_fnc_transformAlignToSafezone);
    };

    for "_i" from _numSectors to (SC_var_numSectorsLimit - 1) step 1 do {
        {
            (_display displayCtrl (_x + _i)) ctrlSetPosition ([0, 0, 0, 0, "LEFT"] call SC_fnc_transformAlignToSafezone);
        } forEach [8030, 1807, 1020, 3040, 1910];
    };

    for "_i" from 0 to (SC_var_numSectorsLimit - 1) step 1 do {
        {
            (_display displayCtrl (_x + _i)) ctrlCommit _commitDuration;
        } forEach [8030, 1807, 1020, 3040, 1910];
    };
};

// ---- capture info (box below the sector overview while the player stands in a sector) ----

// controls SC_var_captureInfoIdc + offset: [offset, x, y, width, height] in GUI grid cells of the box. Upper row: the
// sector letter in the holder's color and the capture progress bar; lower row: state and the units in the sector,
// "<unit icon> 1 vs 0" (own vs enemy).
SC_var_captureInfoIdc = 9120;
SC_var_captureInfoWidth = 8.4;
SC_var_captureInfoRatioWidth = 3.2;
SC_var_captureInfoLayout = [
    [0, 0, 0, SC_var_captureInfoWidth, 1.9],                                                        // panel
    [1, 0.1, 0.1, 0.8, 0.8],                                                                        // sector letter
    [3, 1, 0.1, SC_var_captureInfoWidth - 1.1, 0.8],                                                // progress bar (width x progress)
    [4, 1, 0.1, SC_var_captureInfoWidth - 1.1, 0.8],                                                // progress text
    [5, 0.1, 1, SC_var_captureInfoWidth - SC_var_captureInfoRatioWidth - 0.2, 0.8],                 // state
    [6, SC_var_captureInfoWidth - SC_var_captureInfoRatioWidth - 0.1, 1, SC_var_captureInfoRatioWidth, 0.8],  // units
    [7, 0, 0, SC_var_captureInfoWidth, 1.9]                                                         // frame
];

SC_var_captureInfoUnitIcon = "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa";

// state of the sector the player stands in: [text, color key] for a side moving the flag (the same rule as on the
// server: more units in the sector than all other sides together), contested or nobody
SC_fnc_getSectorState = {
    params ["_unitsOnSector", "_side", "_holder", "_flag"];

    private _numUnits = 0;
    private _numSidesPresent = 0;
    private _movingSide = sideUnknown;

    {
        _numUnits = _numUnits + (count (_unitsOnSector getOrDefault [_x, []]));
    } forEach SC_var_sides;

    {
        private _count = count (_unitsOnSector getOrDefault [_x, []]);

        if (_count > 0) then {
            _numSidesPresent = _numSidesPresent + 1;

            if ((_count == _numUnits) || {(_count / (_numUnits - _count)) > 1}) then {
                _movingSide = _x;
            };
        };
    } forEach SC_var_sides;

    switch true do {
        case (_movingSide == sideUnknown): {[["Idle", "Contested"] select (_numSidesPresent > 1), ["hudText", "warning"] select (_numSidesPresent > 1)]};
        case ((_movingSide == _holder) && {_flag >= 100}): {[["Enemy holds", "Held"] select (_holder == _side), ["error", "hudText"] select (_holder == _side)]};
        case (_movingSide == _side): {["Capturing", "hudText"]};
        default {["Enemy capturing", "error"]};
    }
};

// outline of the sector bar the player stands in (-1: none) in the HUD text color
SC_fnc_hudHighlightSector = {
    params ["_display", "_sectorIndex"];

    private _lastIndex = _display getVariable ["SC_var_highlightedSector", -1];

    if (_lastIndex == _sectorIndex) exitWith {};

    if (_lastIndex != -1) then {
        (_display displayCtrl (1910 + _lastIndex)) ctrlSetTextColor [0, 0, 0, 0.6];
    };

    if (_sectorIndex != -1) then {
        (_display displayCtrl (1910 + _sectorIndex)) ctrlSetTextColor (["hudText"] call UI_fnc_color);
    };

    _display setVariable ["SC_var_highlightedSector", _sectorIndex];
};

// box centered below the sector bars of SC_fnc_hudUpdateSectorOverview, hidden while the player is in no sector
SC_fnc_hudCaptureInfoTop = {
    private _aspectRatio = (getResolution select 0) / (getResolution select 1);
    private _sectorHeight = 3 * SC_var_hudSectorWidth / _aspectRatio;
    safeZoneY + safeZoneH * (_sectorHeight + 2 * (_sectorHeight / 8))
};

SC_fnc_hudUpdateCaptureInfo = {
    disableSerialization;

    private _display = uiNamespace getVariable "SC_var_sectorControlDisplay";
    private _sectorIndex = if (alive player) then {SC_var_sectors findIf {player inArea ("SC_var_sector" + _x)}} else {-1};

    [_display, _sectorIndex] call SC_fnc_hudHighlightSector;

    {
        (_display displayCtrl (SC_var_captureInfoIdc + (_x select 0))) ctrlShow (_sectorIndex != -1);
    } forEach SC_var_captureInfoLayout;

    if (_sectorIndex == -1) exitWith {};

    private _sectorInd = SC_var_sectors select _sectorIndex;
    private _side = side (group player);
    private _holder = missionNamespace getVariable [("SC_var_holder" + _sectorInd), civilian];
    private _flag = missionNamespace getVariable [("SC_var_flag" + _sectorInd), 0];
    private _unitsOnSector = [("SC_var_sector" + _sectorInd)] call SC_fnc_getUnitsOnSector;
    private _numOwnUnits = count (_unitsOnSector getOrDefault [_side, []]);
    private _enemySidesPresent = (SC_var_sides - [_side]) select {(_unitsOnSector getOrDefault [_x, []]) isNotEqualTo []};
    private _numEnemyUnits = 0;

    {
        _numEnemyUnits = _numEnemyUnits + (count (_unitsOnSector get _x));
    } forEach _enemySidesPresent;

    ([_unitsOnSector, _side, _holder, _flag] call SC_fnc_getSectorState) params ["_state", "_stateColor"];

    (call SC_fnc_hudGrid) params ["_gridW", "_gridH"];
    private _aspectRatio = (getResolution select 0) / (getResolution select 1);
    private _sectorHeight = 3 * SC_var_hudSectorWidth / _aspectRatio;
    private _left = 0.5 - 0.5 * SC_var_captureInfoWidth * _gridW;
    private _top = call SC_fnc_hudCaptureInfoTop;
    private _progress = 0 max (_flag / 100) min 1;

    {
        _x params ["_offset", "_x0", "_y0", "_width", "_height"];

        if (_offset == 3) then {
            _width = _width * _progress;
        };

        private _ctrl = _display displayCtrl (SC_var_captureInfoIdc + _offset);
        _ctrl ctrlSetPosition ([[_left + _x0 * _gridW, _top + _y0 * _gridH, _width * _gridW, _height * _gridH]] call SC_fnc_snapRect);
        _ctrl ctrlCommit 0;
    } forEach SC_var_captureInfoLayout;

    private _holderColor = [_holder] call SC_fnc_getHudColor;
    (_display displayCtrl (SC_var_captureInfoIdc + 1)) ctrlSetBackgroundColor _holderColor;
    (_display displayCtrl (SC_var_captureInfoIdc + 3)) ctrlSetBackgroundColor _holderColor;

    [(_display displayCtrl (SC_var_captureInfoIdc + 1)), _sectorInd] call SC_fnc_hudSetText;
    [(_display displayCtrl (SC_var_captureInfoIdc + 4)), ((str (floor _flag)) + "%")] call SC_fnc_hudSetText;
    [(_display displayCtrl (SC_var_captureInfoIdc + 5)), _state, ([_stateColor] call UI_fnc_color)] call SC_fnc_hudSetText;

    // own units in the own side color, enemies in their side color if only one enemy side is present
    private _hudTextColor = ["hudText"] call UI_fnc_colorHtml;
    private _ratioText = format [
        "<t align='right' color='%1'><img color='%1' image='%2'/> <t color='%3'>%4</t> vs <t color='%5'>%6</t></t>",
        _hudTextColor,
        SC_var_captureInfoUnitIcon,
        ([_side] call UI_fnc_sideColorHtml),
        _numOwnUnits,
        (if ((count _enemySidesPresent) == 1) then {[_enemySidesPresent select 0] call UI_fnc_sideColorHtml} else {_hudTextColor}),
        _numEnemyUnits
    ];
    private _ratioCtrl = _display displayCtrl (SC_var_captureInfoIdc + 6);

    if ((_ratioCtrl getVariable ["SC_var_text", ""]) != _ratioText) then {
        _ratioCtrl setVariable ["SC_var_text", _ratioText];
        _ratioCtrl ctrlSetStructuredText parseText _ratioText;
    };
};

// ---- group overview (bottom left) ----

// One row of fixed width per group member (the first one at the bottom), in GUI grid cells: transparent dark
// background with a thin health bar at its bottom, role icon (state icon while unconscious / dead), rank, name (cut
// with "..." when too long), vehicle picture (centred in its slot, sized by its opaque area: UI_fnc_vehiclePictureFill),
// distance or bleed out / respawn time. With the default layout the rows sit between the chat input / channel line
// (bottom, about 0.8 cells high) and the chat messages (5.5 cells above the bottom edge; five rows reach 0.1 cells
// higher), left aligned with the chat. Groups larger than one column continue in a second column to its right, again
// filled from the bottom.
SC_var_groupColumnRows = 5;         // rows per column (the height between channel line and chat messages)
SC_var_groupMaxRows = 10;           // two columns; SC\hud\hudDisplay.hpp has the controls of this many rows
SC_var_groupRowIdc = 9200;          // controls of row n: SC_var_groupRowIdc + 10 * n + offset
SC_var_groupRowWidth = 7.5;
SC_var_groupRowHeight = 0.8;
SC_var_groupRowGap = 0.15;           // the standard row gap of row-based text blocks (UI_var_textBlockGap)
SC_var_groupNameWidth = 3;
SC_var_groupNameWidthWide = 4.25;   // name column of a unit on foot: also over the vehicle picture's slot
SC_var_groupLeftGap = 1;            // cells from the left safe zone edge (like the chat)
SC_var_hudBottomGap = 1;            // cells from the bottom safe zone edge: free for the chat input / channel line

// [offset, x, y, width, height] in cells of a row
SC_var_groupRowColumns = [
    [0, 0, 0, SC_var_groupRowWidth, SC_var_groupRowHeight],                // background
    [1, 0, SC_var_groupRowHeight - 0.08, SC_var_groupRowWidth, 0.08],      // health bar (width x health)
    [3, 0.15, 0.1, 0.6, 0.6],                                              // role / state icon
    [4, 0.8, 0, 1, SC_var_groupRowHeight],                                 // rank
    [5, 1.8, 0, SC_var_groupNameWidth, SC_var_groupRowHeight],             // name
    [6, 4.85, 0.1, 1, 0.6],                                                // vehicle picture (drawn up to 1.36 x, see below)
    [7, 6.05, 0, 1.3, SC_var_groupRowHeight]                               // distance / bleed out or respawn time
];

// the outer columns keep 0.15 cells to the row's edges: the standard margin between a text block and its text
// (UI_var_textBlockPadding, KF_var_blockPadding)
// a vehicle picture scaled up to SC_var_groupVehiclePictureScale (1.36) still keeps about 0.15 cells to the name (cut
// 0.3 cells before its column ends) and to the right aligned distance

// health below which the health bar has the error color
SC_var_groupLowHealth = 0.35;

// role icons (map unit icons) by the unit's gear, see SC_fnc_getRoleIcon
SC_var_hudRoleIcons = createHashMapFromArray ([
    ["rifle", "iconMan"],
    ["machinegun", "iconManMG"],
    ["launcher", "iconManAT"],
    ["marksman", "iconManRecon"],
    ["medic", "iconManMedic"]
] apply {[_x select 0, getText (configFile >> "CfgVehicleIcons" >> (_x select 1))]});

SC_var_hudHealIcon = "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa";
SC_var_hudDeadIcon = "\A3\ui_f\data\IGUI\Cfg\Revive\overlayIcons\d100_ca.paa";
SC_var_hudRespawnDelay = getMissionConfigValue ["respawnDelay", 10];

// state icons relative to the icon column: the dead icon (skull in a circle) has more empty border than the other
// icons, drawn this much larger it fills the whole row height; the heal icon fills its whole texture and is drawn
// smaller
SC_var_hudDeadIconScale = SC_var_groupRowHeight / 0.6;
SC_var_groupVehiclePictureScale = 1.28 / 0.94;     // vehicle pictures: a typical one (UI_fnc_vehiclePictureFill) fills the slot
SC_var_hudHealIconScale = 0.8;

// the distance of a group member is renewed at most every this many seconds and only after it changed by this share
SC_var_groupDistanceInterval = 1;
SC_var_groupDistanceChange = 0.05;

// role icon of a unit, cached on the unit until its weapons or medikit change: medic (Medikit), launcher, machine gun,
// marksman rifle, else rifleman
SC_fnc_getRoleIcon = {
    params ["_unit"];

    private _primaryWeapon = primaryWeapon _unit;
    private _key = [_primaryWeapon, (secondaryWeapon _unit), ("Medikit" in (items _unit))];
    (_unit getVariable ["SC_var_hudRole", [[], ""]]) params ["_cachedKey", "_icon"];

    if (_cachedKey isNotEqualTo _key) then {
        _key params ["", "_launcher", "_isMedic"];

        private _role = switch true do {
            case _isMedic: {"medic"};
            case (_launcher != ""): {"launcher"};
            case (_primaryWeapon == ""): {"rifle"};
            default {
                switch (([_primaryWeapon] call SC_fnc_getItemType) select 1) do {
                    case "MachineGun": {"machinegun"};
                    case "SniperRifle": {"marksman"};
                    default {"rifle"};
                }
            };
        };

        _icon = SC_var_hudRoleIcons get _role;
        _unit setVariable ["SC_var_hudRole", [_key, _icon]];
    };

    _icon
};

// "1:23", "0:07" (minutes not padded)
SC_fnc_hudShortTime = {
    params ["_seconds"];

    private _text = [_seconds] call SC_fnc_secondsToMinSec;

    if ((_text select [0, 1]) == "0") then {_text select [1]} else {_text}
};

// "850m", "1.2km", "12km"
SC_fnc_formatDistance = {
    params ["_distance"];

    if (_distance < 999.5) exitWith {format ["%1m", round _distance]};
    if (_distance < 9950) exitWith {format ["%1km", ((round (_distance / 100)) / 10) toFixed 1]};

    format ["%1km", round (_distance / 1000)]
};

// distance text of a group member, see SC_var_groupDistanceInterval / SC_var_groupDistanceChange (cached on the unit,
// locally)
SC_fnc_hudGroupDistance = {
    params ["_unit"];

    private _distance = player distance _unit;
    (_unit getVariable ["SC_var_hudDistance", [-1e9, -1, ""]]) params ["_time", "_shownDistance", "_text"];

    if(((time - _time) >= SC_var_groupDistanceInterval) &&
        {(abs (_distance - _shownDistance)) >=(SC_var_groupDistanceChange * _shownDistance)}) then {
        _text = [_distance] call SC_fnc_formatDistance;
        _unit setVariable ["SC_var_hudDistance", [time, _distance, _text]];
    };

    _text
};

// positions of the rows; the rows from _numRows on are hidden
SC_fnc_hudLayoutGroupOverview = {
    params ["_display", "_numRows"];

    (call SC_fnc_hudGrid) params ["_gridW", "_gridH"];

    private _left = safeZoneX + SC_var_groupLeftGap * _gridW;
    private _bottom = safeZoneY + safeZoneH - SC_var_hudBottomGap * _gridH;

    for "_row" from 0 to (SC_var_groupMaxRows - 1) do {
        private _idc = SC_var_groupRowIdc + 10 * _row;
        private _column = floor (_row / SC_var_groupColumnRows);
        private _columnRow = _row mod SC_var_groupColumnRows;
        private _rowX = _left + _column * (SC_var_groupRowWidth + SC_var_groupRowGap) * _gridW;
        private _rowY = _bottom - ((_columnRow + 1) * SC_var_groupRowHeight + _columnRow * SC_var_groupRowGap) * _gridH;

        {
            _x params ["_offset", "_x0", "_y0", "_width", "_height"];

            private _ctrl = _display displayCtrl (_idc + _offset);
            private _pos = [_rowX + _x0 * _gridW, _rowY + _y0 * _gridH, _width * _gridW, _height * _gridH];
            _ctrl ctrlSetPosition _pos;
            _ctrl ctrlCommit 0;
            _ctrl ctrlShow (_row < _numRows);

            // base position for the scaled state icons and vehicle pictures (SC_fnc_hudScaleCtrl) and the name width
            // (SC_fnc_hudUpdateGroupRow)
            _ctrl setVariable ["SC_var_basePos", _pos];
            _ctrl setVariable ["SC_var_ctrlScale", 1];
            _ctrl setVariable ["SC_var_nameCells", -1];
        } forEach SC_var_groupRowColumns;

        // the health bar is sized again by the next row update
        (_display displayCtrl (_idc + 1)) setVariable ["SC_var_health", -1];
    };
};

// sizes a control of a group row to _scale times its base position (SC_fnc_hudLayoutGroupOverview), centred on it
SC_fnc_hudScaleCtrl = {
    params ["_ctrl", "_scale"];

    if ((_ctrl getVariable ["SC_var_ctrlScale", 1]) == _scale) exitWith {};

    _ctrl setVariable ["SC_var_ctrlScale", _scale];
    (_ctrl getVariable ["SC_var_basePos", (ctrlPosition _ctrl)]) params ["_baseX", "_baseY", "_baseW", "_baseH"];
    _ctrl ctrlSetPosition [_baseX - 0.5 * (_scale - 1) * _baseW, _baseY - 0.5 * (_scale - 1) * _baseH, _scale * _baseW, _scale * _baseH];
    _ctrl ctrlCommit 0;
};

SC_fnc_hudUpdateGroupRow = {
    params ["_display", "_row", "_unit", "_gridW", "_textSize", "_commitDuration"];

    private _idc = SC_var_groupRowIdc + 10 * _row;

    // a suspended AI (alive, not simulated) waits to come back into the game like a dead unit
    private _state = switch true do {
        case (!(alive _unit) || {!(simulationEnabled _unit)}): {"dead"};
        case (_unit getVariable ["ais_unconscious", false]): {"unconscious"};
        default {"alive"};
    };

    // time (local) since the unit is in this state: the AIS times of other machines are not comparable
    (_unit getVariable ["SC_var_hudState", ["", 0]]) params ["_lastState", "_stateTime"];

    if (_lastState != _state) then {
        _stateTime = time;
        _unit setVariable ["SC_var_hudState", [_state, _stateTime]];
    };

    private _hudTextColor = ["hudText"] call UI_fnc_color;
    private _textColor = _hudTextColor;
    private _icon = SC_var_hudDeadIcon;
    private _iconColor = _hudTextColor;
    private _value = "";
    private _vehiclePicture = "";

    switch _state do {
        case "alive": {
            _icon = [_unit] call SC_fnc_getRoleIcon;
            private _vehicle = objectParent _unit;

            if !(isNull _vehicle) then {
                _vehiclePicture = [typeOf _vehicle] call SC_fnc_getPicture;
            };

            if (_unit isNotEqualTo player) then {
                _value = [_unit] call SC_fnc_hudGroupDistance;
            };
        };
        case "unconscious": {
            _icon = SC_var_hudHealIcon;

            if (_unit getVariable ["ais_stabilized", false]) then {
                _iconColor = ["warning"] call UI_fnc_color;
                _value = "Stable";
            } else {
                private _start = if (local _unit) then {_unit getVariable ["ais_unconscious_since", _stateTime]} else {_stateTime};
                _iconColor = ["error"] call UI_fnc_color;
                _value = [(missionNamespace getVariable ["AIS_BLEEDOUT_TIME", 120]) - (time - _start)] call SC_fnc_hudShortTime;
            };
        };
        default {
            _textColor = (_hudTextColor select [0, 3]) + [0.5 * (_hudTextColor select 3)];

            // the respawn countdown of a dead unit (a suspended AI has none)
            if !(alive _unit) then {
                private _respawnIn = SC_var_hudRespawnDelay - (time - _stateTime);

                if (_respawnIn > 0) then {
                    _value = [_respawnIn] call SC_fnc_hudShortTime;
                };
            };
        };
    };

    // a unit on foot has no vehicle picture: its name may use that slot too (up to the distance column); names are cut
    // 0.3 cells before their column ends
    private _nameCells = [SC_var_groupNameWidthWide, SC_var_groupNameWidth] select (_vehiclePicture != "");
    private _nameCtrl = _display displayCtrl (_idc + 5);

    if ((_nameCtrl getVariable ["SC_var_nameCells", -1]) != _nameCells) then {
        _nameCtrl setVariable ["SC_var_nameCells", _nameCells];
        (_nameCtrl getVariable ["SC_var_basePos", (ctrlPosition _nameCtrl)]) params ["_nameX", "_nameY", "", "_nameH"];
        _nameCtrl ctrlSetPosition [_nameX, _nameY, _nameCells * _gridW, _nameH];
        _nameCtrl ctrlCommit 0;
    };

    private _name = [(_unit getVariable ["SC_var_name", name _unit]), ((_nameCells - 0.3) * _gridW), _textSize] call SC_fnc_hudFitText;

    private _iconCtrl = _display displayCtrl (_idc + 3);
    private _iconScale = switch _state do {
        case "dead": {SC_var_hudDeadIconScale};
        case "unconscious": {SC_var_hudHealIconScale};
        default {1};
    };

    [_iconCtrl, _iconScale] call SC_fnc_hudScaleCtrl;

    // the vehicle picture sized by its opaque area (UI_fnc_vehiclePictureFill), so thin and bulky vehicles look alike;
    // here a typical vehicle fills its whole slot and bulky ones reach a little into the neighbouring columns (user:
    // too small at 0.73 of the slot)
    private _vehicleCtrl = _display displayCtrl (_idc + 6);

    if (_vehiclePicture != "") then {
        [_vehicleCtrl, (SC_var_groupVehiclePictureScale * ([_vehiclePicture] call UI_fnc_vehiclePictureFill))] call SC_fnc_hudScaleCtrl;
    };

    [_iconCtrl, _icon, _iconColor] call SC_fnc_hudSetText;
    [(_display displayCtrl (_idc + 4)), str (_unit getVariable ["SC_var_rank", 1]), _textColor] call SC_fnc_hudSetText;
    [_nameCtrl, _name, _textColor] call SC_fnc_hudSetText;
    [_vehicleCtrl, _vehiclePicture] call SC_fnc_hudSetText;
    [(_display displayCtrl (_idc + 7)), _value, ([_textColor, _iconColor] select (_state == "unconscious"))] call SC_fnc_hudSetText;

    // thin bar as wide as the row x health, in the error color at low health; animated, but set at once after a new
    // layout
    private _health = if (_state == "dead") then {0} else {1 - (damage _unit)};
    private _healthBar = _display displayCtrl (_idc + 1);
    private _lastHealth = _healthBar getVariable ["SC_var_health", -1];

    if (_lastHealth != _health) then {
        _healthBar setVariable ["SC_var_health", _health];
        _healthBar ctrlSetBackgroundColor ([_hudTextColor, (["error"] call UI_fnc_color)] select (_health < SC_var_groupLowHealth));

        private _pos = ctrlPosition _healthBar;
        _pos set [2, ((ctrlPosition (_display displayCtrl _idc)) select 2) * _health];
        _healthBar ctrlSetPosition _pos;
        _healthBar ctrlCommit ([_commitDuration, 0] select (_lastHealth < 0));
    };
};

SC_fnc_hudUpdateGroupOverview = {
    params ["_commitDuration"];

    disableSerialization;

    private _display = uiNamespace getVariable "SC_var_sectorControlDisplay";
    private _groupUnits = (([player] call SC_fnc_getGroupUnits) select {!(isNull _x)}) select [0, SC_var_groupMaxRows];
    private _layout = [(count _groupUnits), safeZoneW, safeZoneH];

    // the positions only change with the number of rows or the interface size
    if ((_display getVariable ["SC_var_groupLayout", []]) isNotEqualTo _layout) then {
        _display setVariable ["SC_var_groupLayout", _layout];
        [_display, (count _groupUnits)] call SC_fnc_hudLayoutGroupOverview;
    };

    (call SC_fnc_hudGrid) params ["_gridW", "", "_textSize"];

    {
        [_display, _forEachIndex, _x, _gridW, _textSize, _commitDuration] call SC_fnc_hudUpdateGroupRow;
    } forEach _groupUnits;
};

// ---- player stats (bottom right) ----

// width of a side column of the player stats panel (share of the safe zone width)
SC_var_hudSideWidth = 0.02;

// widest texts of the XP bar and the points per minute boxes (SC_fnc_formatCompactNumber, rates as "12" / "1.2"):
// their font is fitted once to the width, so it never grows or changes with the values
SC_var_hudXpTextSample = "8.88 M/8.88 M XP";
SC_var_hudRateTextSample = "+8.8";

// positions controls of the player stats panel; _rect: [x, top, width, height] as shares of the safe zone, x from the
// left, top from the bottom edge (SC_fnc_transformAlignToSafezone, right aligned)
SC_fnc_hudPlaceRight = {
    params ["_display", "_idcs", "_rect", "_commitDuration"];

    private _pos = (_rect + ["RIGHT"]) call SC_fnc_transformAlignToSafezone;

    {
        private _ctrl = _display displayCtrl _x;
        _ctrl ctrlSetPosition _pos;
        _ctrl ctrlCommit _commitDuration;
    } forEach _idcs;
};

SC_var_hudRowIconScale = 0.7;      // height of the person symbol left of the unit counts, relative to a bar
SC_var_hudPointsIconScale = 0.8;   // height of the points symbol and the arrow up of the points per minute, relative to a bar
SC_var_hudRateTextScale = 0.92;    // points per minute ("+0.4"): a little smaller than the font that would fill their box
SC_var_hudPointsTextScale = 1;     // points of the sides, relative to the HUD text size
// both are applied by the layout: after changing them in the debug console, [true, 0] call SC_fnc_hudUpdatePlayerStats
SC_var_hudBarFontHeight = 0.034;   // texts of the bars (rank, XP, stamina, HP, spawn vehicles)
SC_var_hudSideSymbolScale = 0.85;  // height of the side symbols' row relative to a bar (low: room below the GPS panel)
SC_var_hudSideSymbolPictureScale = 1.3;   // the symbol pictures relative to their row: they may reach over it a bit
SC_var_hudSideSymbolAlpha = 0.85;         // opacity of the side symbols (SC\hud\side_*_ca.paa are opaque themselves)
SC_var_hudLowHealth = 25;          // HP below which the HP bar is filled in the error color instead of green
SC_var_hudColumnGap = 0.25;        // gap between the two columns of the panel, relative to a side column's width

/*
    Two columns at the bottom right, both bottom aligned above the chat input / channel line (SC_var_hudBottomGap; user
    decision 2026-11-13). Left, from the top down: the side symbols, the points of every side, their points per minute
    ("+0.4"), the unit counts and the spawn vehicles (SC\hud\spawnVehicleStatus.sqf); left of it a symbol per row: the
    points symbol (points), an arrow up (points per minute), a person (counts), and the spawn vehicles' direction arrows.
    Right, at the right screen edge, from the top down: rank, XP, stamina, HP and two perk rows (perks 1 - 3 in the upper
    one); the earplugs icon above it (SC_fnc_earplugsIconPosition). Laid out again when the number of spawn vehicles
    changes (SC_fnc_hudUpdateSpawnVehicles).
*/
SC_fnc_hudLayoutPlayerStats = {
    params ["_display", "_commitDuration"];

    private _aspectRatio = (getResolution select 0) / (getResolution select 1);
    private _sideWidth = SC_var_hudSideWidth;
    private _sideHeight = 2.1 * _sideWidth / _aspectRatio;
    private _sideGapX = _sideWidth / 10;
    private _gapY = 3 * _sideGapX / _aspectRatio;
    private _screenGapX = 0.007;
    private _panelWidth = 3 * _sideWidth + 2 * _sideGapX;    // width of each column
    private _panelX = 1 - (_screenGapX + _panelWidth);       // the right column
    private _leftX = _panelX - SC_var_hudColumnGap * _sideWidth - _panelWidth;
    private _teamWidth = (_panelWidth - ((count SC_var_sides) - 1) * _sideGapX) / (count SC_var_sides);
    private _barHeight = 1.75 * _sideWidth / _aspectRatio;   // rank, XP, stamina, HP, points per minute, spawn vehicles
    private _perkHeight = 1.5 * _sideWidth / _aspectRatio;
    private _textSize = (call SC_fnc_hudGrid) select 2;
    private _rateFontHeight = SC_var_hudRateTextScale *([SC_var_hudRateTextSample,
        (0.9 *(([0, 0, _sideWidth, 0, "RIGHT"] call SC_fnc_transformAlignToSafezone) select 2)),
        _textSize] call SC_fnc_hudFitFontHeight);

    // unit counts: one row, 0.7 of the points box high, the number over the whole column width. The vehicle counts are
    // shown in the vehicle spawn dialog (your side's vehicles / limit, user decision), not here.
    private _countHeight = 0.7 * _sideHeight;

    // tops of the rows, measured from the bottom edge of the safe zone (share of its height); the bottom edge of both
    // columns
    private _bottomTop = (SC_var_hudBottomGap * ((call SC_fnc_hudGrid) select 1)) / safeZoneH;

    // ---- left column, from the bottom up: the spawn vehicles (as wide and high as the bars), then the side rows ----
    private _spawnRowCount = count (call SC_fnc_hudSpawnVehicleRows);
    private _spawnRowsTop =[_display, _panelWidth, _barHeight, _sideGapX, _gapY, _leftX, _bottomTop,
        _spawnRowCount] call SC_fnc_hudLayoutSpawnVehicles;
    private _countsTop = _spawnRowsTop + ([0, _gapY] select (_spawnRowCount > 0)) + _countHeight;
    private _ratesTop = _countsTop + _barHeight;
    private _ticketsTop = _ratesTop + _gapY + _sideHeight;
    // the sides are told apart by their NATO symbols above their columns (no colored backgrounds, user decision): a
    // row of SC_var_hudSideSymbolScale bars, the pictures in square boxes (width share = height share * 9 / 16) of
    // SC_var_hudSideSymbolPictureScale rows, centred on the columns and the row
    private _symbolRowHeight = SC_var_hudSideSymbolScale * _barHeight;
    private _symbolsRowTop = _ticketsTop + _gapY + _symbolRowHeight;
    private _symbolHeight = SC_var_hudSideSymbolPictureScale * _symbolRowHeight;
    private _symbolWidth = _symbolHeight * 9 / 16;
    private _symbolsTop = _symbolsRowTop + 0.5 * (_symbolHeight - _symbolRowHeight);
    private _countWidthAbs = (([0, 0, _sideWidth, 0, "RIGHT"] call SC_fnc_transformAlignToSafezone) select 2);
    private _countFontMax = 0.9 * _countHeight * safeZoneH;
    private _unitsFontHeight = ["88", (0.9 * _countWidthAbs), _countFontMax] call SC_fnc_hudFitFontHeight;

    // the row symbols (SC\hud\person_ca.paa, points_ca.paa, increase_ca.paa: drawn for this, no wide margins): square
    // boxes left of the column, centred on their rows and on one vertical axis with the spawn vehicles' round panels
    // (SC_fnc_hudLayoutSpawnVehicles: a bar high, _sideGapX left of the bars)
    private _iconAxisX = _leftX - _sideGapX - 0.5 * (_barHeight * 9 / 16);

    {
        _x params ["_idc", "_rowTop", "_rowHeight", "_scale"];

        private _iconHeight = _scale * _barHeight;
        private _iconWidth = _iconHeight * 9 / 16;

        [_display,[_idc],
            [_iconAxisX - 0.5 * _iconWidth, _rowTop - 0.5 *(_rowHeight - _iconHeight), _iconWidth,
            _iconHeight], _commitDuration] call SC_fnc_hudPlaceRight;
    } forEach [
        [2009, _countsTop, _countHeight, SC_var_hudRowIconScale],
        [9495, _ticketsTop, _sideHeight, SC_var_hudPointsIconScale],
        [9497, _ratesTop, _barHeight, SC_var_hudPointsIconScale]
    ];

    {
        (_display displayCtrl _x) ctrlShow false;
    } forEach [2006, 2007, 2008, 2010, 2011, 2012, 2013, 2014];

    {
        private _i = _forEachIndex;
        private _sideX = _leftX + _i * (_teamWidth + _sideGapX);

        {
            _x params ["_idcs", "_rect"];
            [_display, _idcs, _rect, _commitDuration] call SC_fnc_hudPlaceRight;
        } forEach [
            [[2000 + _i], [_sideX, _countsTop, _teamWidth, _countHeight]],
            [[2003 + _i], [_sideX, _countsTop, _teamWidth, _countHeight]],
            [[1002 + _i], [_sideX, _ticketsTop, _teamWidth, _sideHeight]],
            [[9110 + _i], [_sideX, _ratesTop, _teamWidth, _barHeight]],
            [[9130 + _i], [_sideX, _ratesTop, _teamWidth, _barHeight]],
            [[9490 + _i], [_sideX + 0.5 * (_teamWidth - _symbolWidth), _symbolsTop, _symbolWidth, _symbolHeight]]
        ];

        (_display displayCtrl (2003 + _i)) ctrlSetFontHeight _unitsFontHeight;
        (_display displayCtrl (9130 + _i)) ctrlSetFontHeight _rateFontHeight;
        (_display displayCtrl (1002 + _i)) ctrlSetFontHeight (SC_var_hudPointsTextScale * _textSize);
        (_display displayCtrl (9490 + _i)) ctrlSetTextColor ((([_x] call UI_fnc_sideColor) select [0, 3]) + [SC_var_hudSideSymbolAlpha]);
    } forEach SC_var_sides;

    for "_i" from (count SC_var_sides) to 2 do {
        {(_display displayCtrl (_x + _i)) ctrlShow false} forEach [2000,2003,1002,9110,9130,9490];
    };

    // ---- right column, from the bottom up: the perk rows (the lower one first), HP, stamina, XP, rank ----
    private _perksTop = _bottomTop + _perkHeight;
    private _hpTop = _perksTop + _gapY + _perkHeight + _gapY + _barHeight;
    private _staminaTop = _hpTop + _gapY + _barHeight;
    private _xpTop = _staminaTop + _gapY + _barHeight;
    private _rankTop = _xpTop + _gapY + _barHeight;

    [_display, [1803, 1001], [_panelX, _hpTop, _panelWidth, _barHeight], _commitDuration] call SC_fnc_hudPlaceRight;
    [_display, [5006, 5735], [_panelX, _staminaTop, _panelWidth, _barHeight], _commitDuration] call SC_fnc_hudPlaceRight;
    [_display, [1000, 1804], [_panelX, _xpTop, _panelWidth, _barHeight], _commitDuration] call SC_fnc_hudPlaceRight;
    [_display, [1005], [_panelX, _rankTop, _panelWidth, _barHeight], _commitDuration] call SC_fnc_hudPlaceRight;

    for "_row" from 0 to 1 do {
        for "_column" from 0 to 2 do {
            private _perkId = (2 - _column) + 3 * (1 - _row);

            [
                _display,
                [6001 + _perkId],
                [1 -(_screenGapX + _sideWidth + _column *(1.1 * _sideWidth)),
                    _perksTop + _row *(_gapY + _perkHeight), _sideWidth, _perkHeight],
                _commitDuration
            ] call SC_fnc_hudPlaceRight;
        };
    };

    {
        (_display displayCtrl _x) ctrlSetFontHeight SC_var_hudBarFontHeight;
    } forEach [1001, 1005, 5006];

    (_display displayCtrl 1000) ctrlSetFontHeight ([SC_var_hudXpTextSample,
        (0.9 *((ctrlPosition (_display displayCtrl 1000)) select 2)),
        SC_var_hudBarFontHeight] call SC_fnc_hudFitFontHeight);
    (_display displayCtrl 2000) ctrlSetText "";

    // the HP and XP bars are sized by the next text update
    (_display displayCtrl 1000) ctrlSetText "";
    (_display displayCtrl 1001) ctrlSetText "";
};

SC_fnc_hudUpdatePlayerStats = {
    params ["_setPositions", "_commitDuration"];

    disableSerialization;

    private _display = uiNamespace getVariable "SC_var_sectorControlDisplay";
    private _hp = ceil ((1 - (damage player)) * 100);
    private _hpStr = (str _hp) + " HP";
    private _rankStr = format ["Rank %1", (player getVariable ["SC_var_rank", 1])];
    private _xp = (call SC_fnc_getPlayerData) select 0;
    private _xpStr = format ["%1/%2 XP", ([_xp] call SC_fnc_formatCompactNumber), ([SC_var_neededXp] call SC_fnc_formatCompactNumber)];

    if _setPositions then {
        [_display, _commitDuration] call SC_fnc_hudLayoutPlayerStats;
    };

    for "_row" from 0 to 1 do {
        for "_column" from 0 to 2 do {
            private _perkId = _column + 3 * (1 - _row);
            private _text = SC_var_perks param [_perkId, ""];

            if (_text == "") then {
                _text = "----";
            };

            [(_display displayCtrl (6001 + _perkId)), _text] call SC_fnc_hudSetText;
        };
    };

    private _posStaminaBar = ctrlPosition (_display displayCtrl 5006);
    _posStaminaBar set [2, (_posStaminaBar select 2) * SC_var_stamina];

    (_display displayCtrl 5005) ctrlSetPosition _posStaminaBar;
    (_display displayCtrl 5005) ctrlCommit _commitDuration;

    // grey like every fill level bar (SC_HudBarFill), turning into the error color below 20 % stamina
    private _barFill = ["barFill"] call UI_fnc_color;
    private _health = ["health"] call UI_fnc_color;
    private _errorRgb = (["error"] call UI_fnc_color) select [0, 3];
    private _staminaCriticalFactor = 5 * (0 max (0.2 - SC_var_stamina));
    private _colorStamina =((_barFill select [0,
        3]) vectorMultiply (1 - _staminaCriticalFactor)) vectorAdd (_errorRgb vectorMultiply
        _staminaCriticalFactor);
    (_display displayCtrl 5005) ctrlSetBackgroundColor (_colorStamina + [_barFill select 3]);

    if ((ctrlText (_display displayCtrl 1001)) != _hpStr) then {
        (_display displayCtrl 1001) ctrlSetText _hpStr;

        // the whole bar (hpPanel 1803) is the full health
        private _posHpBar = ctrlPosition (_display displayCtrl 1803);
        _posHpBar set [2, (_posHpBar select 2) * (_hp / 100)];

        (_display displayCtrl 999) ctrlSetPosition _posHpBar;
        (_display displayCtrl 999) ctrlCommit _commitDuration;
        // green (SC_HudHpFill), the error color at low health
        (_display displayCtrl 999) ctrlSetBackgroundColor ([_health, (_errorRgb + [_health select 3])] select (_hp < SC_var_hudLowHealth));
    };

    [(_display displayCtrl 1005), _rankStr] call SC_fnc_hudSetText;

    if ((ctrlText (_display displayCtrl 1000)) != _xpStr) then {
        (_display displayCtrl 1000) ctrlSetText _xpStr;

        private _posXpBar = ctrlPosition (_display displayCtrl 1000);
        _posXpBar set [2, ((_posXpBar select 2) * (if (SC_var_neededXp != 0) then {1 min (_xp / SC_var_neededXp)} else {1}))];

        (_display displayCtrl 998) ctrlSetPosition _posXpBar;
        (_display displayCtrl 998) ctrlCommit _commitDuration;
    };

    // per side texts (west, east, independent)
    {
        private _sideStr = str _x;
        private _rate = SC_var_ticketRates param [_forEachIndex, 0];

        {
            _x call SC_fnc_hudSetText;
        } forEach [
            [(_display displayCtrl (1002 + _forEachIndex)), str (floor (SC_var_tickets select _forEachIndex))],
            [(_display displayCtrl (2003 + _forEachIndex)), str (missionNamespace getVariable ("SC_var_numUnits" + _sideStr))],
            [(_display displayCtrl (9130 + _forEachIndex)),
                ((["",
                "+"] select (_rate > 0)) +(if(_rate >= 10) then {str (round _rate)} else {str _rate}))
                ]
        ];
    } forEach SC_var_sides;

    [_display] call SC_fnc_hudUpdateSpawnVehicles;
};

// ---- update loops ----

SC_fnc_hudUpdateSectorOverviewLoop = {
    private _sectorUpdateEvery = round (SC_var_hudSectorInterval / SC_var_hudCaptureInfoInterval);
    private _tick = 0;

    waitUntil {
        sleep SC_var_hudCaptureInfoInterval;
        _tick = _tick + 1;

        if ((_tick % _sectorUpdateEvery) == 0) then {
            [SC_var_hudSectorInterval] call SC_fnc_hudUpdateSectorOverview;
        };

        call SC_fnc_hudUpdateCaptureInfo;
        false
    };
};

SC_fnc_hudUpdateGroupOverviewLoop = {
    waitUntil {
        sleep 0.5;
        [0.5] call SC_fnc_hudUpdateGroupOverview;
        false
    };
};

SC_fnc_hudUpdatePlayerStatsLoop = {
    waitUntil {
        sleep 0.5;
        [false, 0.5] call SC_fnc_hudUpdatePlayerStats;
        false
    };
};

// ---- ui helpers ----

SC_fnc_transformAlignToSafezone = {
    params ["_x","_y","_w","_h","_align"];

    private _aspectRatio = (getResolution select 0) / (getResolution select 1);
    private _safezoneWCorrected = safeZoneW * ((16 / 9) / _aspectRatio);
    private _safeZoneXCorrected = switch _align do {
        case "LEFT": {safeZoneX};
        case "RIGHT": {safeZoneX + safeZoneW - _safezoneWCorrected};
        case "CENTER": {safeZoneX + (safeZoneW - _safezoneWCorrected) / 2};
    };

    // both edges on whole screen pixels: a frame and the block below it (separate controls) would otherwise round
    // their fractional edges differently and be off by a pixel
    [[
        _safeZoneXCorrected + _safezoneWCorrected * _x,
        safeZoneY + safeZoneH * (1 - _y),
        _safezoneWCorrected * _w,
        safeZoneH * _h
    ]] call SC_fnc_snapRect
};

// a screen coordinate on the nearest pixel edge (_pixel: pixelW or pixelH)
SC_fnc_snapToPixel = {
    params ["_value", "_pixel"];

    (round (_value / _pixel)) * _pixel
};

// [x, y, w, h] with all four edges on whole pixels
SC_fnc_snapRect = {
    params ["_rect"];
    _rect params ["_x0", "_y0", "_width", "_height"];

    private _left = [_x0, pixelW] call SC_fnc_snapToPixel;
    private _top = [_y0, pixelH] call SC_fnc_snapToPixel;

    [_left, _top, ([_x0 + _width, pixelW] call SC_fnc_snapToPixel) - _left, ([_y0 + _height, pixelH] call SC_fnc_snapToPixel) - _top]
};

// [cell width, cell height, UI_TEXT_SMALL] in screen units: GUI_GRID_W / GUI_GRID_H / GUI_TEXT_SIZE_SMALL of
// \a3\ui_f\hpp\defineCommon.inc, i.e. the grid of ui\ui.hpp (it scales with the interface size like the HUD texts)
SC_fnc_hudGrid = {
    private _gridWidthAbs = (safeZoneW / safeZoneH) min 1.2;
    private _gridH = (_gridWidthAbs / 1.2) / 25;

    [_gridWidthAbs / 40, _gridH, 0.8 * _gridH]
};

// sets the text (or picture) and the text color of a HUD control, each only when it changed
SC_fnc_hudSetText = {
    params ["_ctrl", "_text", ["_color", []]];

    if ((ctrlText _ctrl) != _text) then {
        _ctrl ctrlSetText _text;
    };

    if ((_color isNotEqualTo []) && {(_ctrl getVariable ["SC_var_textColor", []]) isNotEqualTo _color}) then {
        _ctrl setVariable ["SC_var_textColor", _color];
        _ctrl ctrlSetTextColor _color;
    };
};

SC_var_hudFont = "RobotoCondensed";

// [text, max width, font size] -> text cut by SC_fnc_hudFitText
SC_var_fittedTextCache = createHashMap;

// _text cut to the longest beginning that fits into _maxWidth (screen units) at font size _size together with "...";
// cached, so every name is measured (getTextWidth) only once
SC_fnc_hudFitText = {
    params ["_text", "_maxWidth", "_size"];

    private _key = [_text, _maxWidth, _size];
    private _fitted = SC_var_fittedTextCache get _key;

    if (isNil "_fitted") then {
        _fitted = _text;

        if ((_text getTextWidth [SC_var_hudFont, _size]) > _maxWidth) then {
            // binary search over the characters (toArray: also for non-ASCII names)
            private _chars = toArray _text;
            private _fits = 0;
            private _tooLong = count _chars;

            while {(_tooLong - _fits) > 1} do {
                private _length = floor ((_fits + _tooLong) / 2);

                if ((((toString (_chars select [0, _length])) + "...") getTextWidth [SC_var_hudFont, _size]) <= _maxWidth) then {
                    _fits = _length;
                } else {
                    _tooLong = _length;
                };
            };

            _fitted = (toString (_chars select [0, _fits])) + "...";
        };

        if ((count SC_var_fittedTextCache) >= 500) then {
            SC_var_fittedTextCache = createHashMap;
        };

        SC_var_fittedTextCache set [_key, _fitted];
    };

    _fitted
};

// font height (at most _maxHeight) at which _text fits into _maxWidth (screen units)
SC_fnc_hudFitFontHeight = {
    params ["_text", "_maxWidth", "_maxHeight"];

    private _width = _text getTextWidth [SC_var_hudFont, _maxHeight];

    if (_width <= _maxWidth) then {_maxHeight} else {_maxHeight * _maxWidth / _width}
};
