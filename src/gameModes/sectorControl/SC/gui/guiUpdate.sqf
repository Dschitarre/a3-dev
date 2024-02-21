SC_fnc_setHud = {
    params ["_enable"];

    SC_var_hudShown = _enable;

    ((switch true do {
        case !SC_var_hudShown:
            {SC_var_defaultSettings apply {!_x}};
        case ((SC_var_showWholeHudOnMap && visibleMap) || {SC_var_showWholeHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}):
            {SC_var_defaultSettings};
        default
            {SC_var_settings};
    }) select [5, 16]) params [
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

    if (_midfeed && visibleMap && !(alive player)) then {
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
        true, // scripted HUD such as weapon crosshair, action menu and overlays created with cutRsc and titleRsc. Same as showHUD's first syntax
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

    _hudDisplay = _sectorOverview || _groupOverview || _playerStats;
    
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

SC_fnc_hudUpdateSectorOverview = {
    params ["_commitDuration"];

    disableSerialization;
    _display = uiNamespace getVariable "SC_var_sectorControlDisplay";

    _aspectRatio = (getResolution select 0) / (getResolution select 1);
    _sectorWidth = 0.0155;
    _sectorHeight = 3 * _sectorWidth / _aspectRatio;
    _sectorGapX = _sectorWidth / 8;
    _sectorGapY = 3 * _sectorGapX / _aspectRatio;
    _numSectors = count SC_var_sectors;
    _totalSectorWidth = _numSectors * _sectorWidth + (_numSectors - 1) * _sectorGapX;

    for "_i" from 0 to (_numSectors-1) step 1 do {
        _posX = 0.5 - 0.5 * _totalSectorWidth + _i * _sectorWidth + _i * _sectorGapX;
        _points = missionNameSpace getVariable ("SC_var_flag" + (SC_var_sectors select _i));

        (_display displayctrl (8030 + _i)) ctrlSetBackgroundColor ([missionNameSpace getVariable ("SC_var_holder" + (SC_var_sectors select _i))] call SC_fnc_getHudColor);
        (_display displayctrl (8030 + _i)) ctrlSetPosition ([_posX, 1 - (_sectorGapY + _sectorHeight * ((100 - _points) / 100)), _sectorWidth, _sectorHeight * (_points / 100), "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayctrl (1807 + _i)) ctrlSetPosition ([_posX, 1 - (_sectorGapY + _sectorHeight * ((100 - _points) / 100)), _sectorWidth, 0, "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayctrl (1020 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth, _sectorHeight * ((100 - _points) / 100), "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayctrl (3040 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth, _sectorHeight, "CENTER"] call SC_fnc_transformAlignToSafezone);
        (_display displayctrl (1910 + _i)) ctrlSetPosition ([_posX, 1 - _sectorGapY, _sectorWidth, _sectorHeight, "CENTER"] call SC_fnc_transformAlignToSafezone);
    };

    for "_i" from _numSectors to (SC_var_numSectorsLimit - 1) step 1 do {
        {
            (_display displayctrl (_x + _i)) ctrlSetPosition ([0, 0, 0, 0, "LEFT"] call SC_fnc_transformAlignToSafezone);
        } forEach [8030, 1807, 1020, 3040, 1910];
    };

    for "_i" from 0 to (SC_var_numSectorsLimit - 1) step 1 do {
        {
            (_display displayctrl (_x + _i)) ctrlCommit _commitDuration;
        } forEach [8030, 1807, 1020, 3040, 1910];
    };
};

SC_fnc_hudUpdateGroupOverview = {
    params ["_commitDuration"];
    
    disableSerialization;

    _display = uiNamespace getVariable "SC_var_sectorControlDisplay";
    _aspectRatio = (getResolution select 0) / (getResolution select 1);
    _groupUnits = [player] call SC_fnc_getGroupUnits;

    _groupTextHeight = 0.035 / _aspectRatio;
    _groupTextOffsetX = 0.008;
    _groupTextOffsetY = (2 * _groupTextOffsetX) / _aspectRatio;

    for "_i" from 0 to (((count _groupUnits) - 1) min 4) do {
        _groupUnit = _groupUnits select _i;
        _nameGroupUnit = (_groupUnits select _i) getVariable ["TDI_var_name", ""];
        _groupTextWidth = 0.475 * (_nameGroupUnit getTextWidth ["RobotoCondensed", 0.03]);
        _groupIconBackgroundWidth = 0;
        _groupIconBackgroundHeight = 0;
        _groupIconWidth = 0;
        _groupIconHeight = 0;
        _icon = "";
        _isUnconscious = _groupUnit getVariable ["AIS_unconscious", false];

        if ((alive _groupUnit) && {!_isUnconscious} && {simulationEnabled _groupUnit}) then {
            _parGroupUnit = objectParent _groupUnit;

            if !(isNull _parGroupUnit) then {
                _icon = [typeOf _parGroupUnit] call SC_fnc_getPicture;
                _groupIconBackgroundWidth = 0.0167;
                _groupIconBackgroundHeight = _groupTextHeight;
                _groupIconWidth = 0.85 * _groupIconBackgroundWidth;
                _groupIconHeight = 0.7 * _groupIconBackgroundHeight;
            };
        } else {
            _groupIconBackgroundHeight = _groupTextHeight;
            _groupIconBackgroundWidth = 0.0125;

            if (_isUnconscious && {alive _groupUnit}) then {
                _icon = "\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa";
                _groupIconWidth = 0.0075;
            } else {
                _icon = "\A3\Ui_f\data\Map\Respawn\icon_dead_ca.paa";
                _groupIconBackgroundHeight = _groupTextHeight;
                _groupIconWidth = 0.65 *_groupTextHeight;
            };

            _groupIconHeight = 3.2 * _groupIconWidth / _aspectRatio;
        };

        _groupFrameWidth = _groupTextWidth + _groupIconBackgroundWidth;

        _framePos = [_groupTextOffsetX, _groupTextOffsetY + ((_i + 1) * _groupTextHeight), _groupFrameWidth, _groupTextHeight, "LEFT"] call SC_fnc_transformAlignToSafezone;
        _textPos = [_groupTextOffsetX, _groupTextOffsetY + ((_i + 1) * _groupTextHeight), _groupTextWidth, _groupTextHeight, "LEFT"] call SC_fnc_transformAlignToSafezone;
        _posHpBar = [_groupTextOffsetX, _groupTextOffsetY + ((_i + 1) * _groupTextHeight), ((1 - (if (simulationEnabled _groupUnit) then {damage _groupUnit} else {1})) * _groupFrameWidth), _groupTextHeight, "LEFT"] call SC_fnc_transformAlignToSafezone;

        _iconPos = [
            _groupTextOffsetX + _groupTextWidth + (0.5 * (_groupIconBackgroundWidth - _groupIconWidth)),
            (_groupTextOffsetY + ((_i + 1) * _groupTextHeight)) - (0.5 * (_groupIconBackgroundHeight - _groupIconHeight)),
            _groupIconWidth, _groupIconHeight,
            "LEFT"
        ] call SC_fnc_transformAlignToSafezone;

        _ctrlFrame = _display displayCtrl (1930 + _i);
        _ctrlText = _display displayCtrl (4058 + _i);
        _ctrlHpBar = _display displayCtrl (4350 + _i);
        _ctrlIcon = _display displayCtrl (2150 + _i);

        _ctrlFrame ctrlSetPosition _framePos;
        _ctrlText ctrlSetPosition _textPos;
        _ctrlHpBar ctrlSetPosition _posHpBar;
        _ctrlIcon ctrlSetPosition _iconPos;

        _ctrlFrame ctrlCommit _commitDuration;
        _ctrlText ctrlCommit _commitDuration;
        _ctrlHpBar ctrlCommit _commitDuration;
        _ctrlIcon ctrlCommit _commitDuration;

        _ctrlText ctrlSetText _nameGroupUnit;
        _ctrlText ctrlSetFontHeight 0.03;

        _ctrlIcon ctrlsetText _icon;
    };

    for "_i" from ((count _groupUnits) min 5) to 7 do {
        _ctrlFrame = _display displayCtrl (1930 + _i);
        _ctrlText = _display displayCtrl (4058 + _i);
        _ctrlHpBar = _display displayCtrl (4350 + _i);
        _ctrlIcon = _display displayCtrl (2150 + _i);

        _ctrlFrame ctrlSetPosition [-1, -1, 0, 0];
        _ctrlText ctrlSetPosition [-1, -1, 0, 0];
        _ctrlHpBar ctrlSetPosition [-1, -1, 0, 0];
        _ctrlIcon ctrlSetPosition [-1, -1, 0, 0];

        _ctrlFrame ctrlCommit _commitDuration;
        _ctrlText ctrlCommit _commitDuration;
        _ctrlHpBar ctrlCommit _commitDuration;
        _ctrlIcon ctrlCommit _commitDuration;
    };
};

SC_fnc_hudUpdatePlayerStats = {
    params ["_setPositions", "_commitDuration"];

    disableSerialization;

    _display = uiNamespace getVariable "SC_var_sectorControlDisplay";
    _hp = ceil ((1 - (damage player)) * 100);
    _hpStr = (str _hp) + " HP";
    _rankStr = "Rank: " + (str (player getVariable ["SC_var_rank", 1]));
    _xp = player getVariable ["SC_var_xp", 0];
    _xpStr = format ["%1/%2 XP", (str _xp), (str SC_var_neededXp)];
    _aspectRatio = (getResolution select 0) / (getResolution select 1);

    if _setPositions then {
        (_display displayCtrl 1000) ctrlSetFontHeight 0.034;
        (_display displayCtrl 1001) ctrlSetFontHeight 0.034;
        (_display displayCtrl 1005) ctrlSetFontHeight 0.034;
        (_display displayCtrl 5006) ctrlSetFontHeight 0.034;

        _sideWidth = 0.02;
        _sideHeight = 2.1 * _sideWidth / _aspectRatio;
        _screenGapX = 0.007;
        _screenGapY = 2 * _screenGapX / _aspectRatio;
        _sideGapX = _sideWidth / 10;
        _gapY = 3 * _sideGapX / _aspectRatio;
        _totalSidesWidth = 3 * _sideWidth + 2 * _sideGapX;

        _numEntitiesBackgroundWidth = _sideWidth;
        _numEntitiesBackgroundHeight = _sideHeight;
        _numUnitsOrVehiclesHeight = _numEntitiesBackgroundHeight / 2;
        _numUnitsOrVehiclesHeight = _numEntitiesBackgroundHeight;

        _hpWidth = _totalSidesWidth;
        _hpHeight = 1.43 * _sideWidth / _aspectRatio;

        _staminaWidth = _hpWidth;
        _staminaHeight = _hpHeight;

        _xpWidth = _totalSidesWidth;
        _xpHeight = _hpHeight;

        _rankWidth = 1.7 * _sideWidth;
        _rankHeight = _hpHeight;

        _perkWidth = _sideWidth;
        _perkHeight = 1.5 * _perkWidth / _aspectRatio;

        _perkGapX = _perkWidth / 10;

        {
            (_display displayCtrl _x) ctrlSetPosition ([1 - (_screenGapX + _hpWidth), _screenGapY + _numEntitiesBackgroundHeight + 1 *_gapY + _sideHeight + _hpHeight, _hpWidth, _hpHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
            (_display displayCtrl _x) ctrlCommit _commitDuration;
        } forEach [1803, 1001];

        (_display displayCtrl 999) ctrlSetPosition ([1 - (_screenGapX + _hpWidth), _screenGapY + _numEntitiesBackgroundHeight + 1 *_gapY + _sideHeight + _hpHeight, _hpWidth * (_hp / 100), _hpHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 999) ctrlCommit _commitDuration;

        {
            (_display displayCtrl _x) ctrlSetPosition ([1 - (_screenGapX + _staminaWidth), _screenGapY + _numEntitiesBackgroundHeight + 2 *_gapY + _sideHeight + _hpHeight + _staminaHeight, _staminaWidth, _staminaHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
            (_display displayCtrl _x) ctrlCommit _commitDuration;
        } forEach [5006, 5735];

        (_display displayCtrl 5005) ctrlSetPosition ([1 - (_screenGapX + _staminaWidth), _screenGapY + _numEntitiesBackgroundHeight + 3 *_gapY + _sideHeight + _hpHeight + _staminaHeight, SC_var_stamina * _staminaWidth, _staminaHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 5005) ctrlCommit _commitDuration;

        {
            (_display displayCtrl _x) ctrlSetPosition ([1 - (_screenGapX + _xpWidth), _screenGapY + _numEntitiesBackgroundHeight + 5 *_gapY + _sideHeight + _hpHeight + _staminaHeight + 2 *_perkHeight + _xpHeight, _xpWidth, _xpHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
            (_display displayCtrl _x) ctrlCommit _commitDuration;
        } forEach [1000, 1804];

        {
            (_display displayCtrl _x) ctrlSetPosition ([1 - (_screenGapX + _rankWidth), _screenGapY + _numEntitiesBackgroundHeight + 6 *_gapY + _sideHeight + _hpHeight + _staminaHeight + _xpHeight + _rankHeight + 2 * _perkHeight, _rankWidth, _rankHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
            (_display displayCtrl _x) ctrlCommit _commitDuration;
        } forEach [1005, 1805];

        _perkWHO = [_perkWidth, _perkHeight, "RIGHT"];

        for "_row" from 0 to 1 do {
            for "_column" from 0 to 2 do {
                _transform = ([
                    1 - (_screenGapX + _perkWidth + _column * (_perkGapX + _perkWidth)),
                    _screenGapY + _numEntitiesBackgroundHeight + 3 * _gapY + _sideHeight + _hpHeight + _staminaHeight + _perkHeight + (_row * _gapY) + (_row * _perkHeight)
                ] + _perkWHO) call SC_fnc_transformAlignToSafezone;

                _perkId = (2 - _column) + 3 * (1 - _row);

                {
                    (_display displayCtrl _x) ctrlSetPosition _transform;
                    (_display displayCtrl _x) ctrlCommit _commitDuration;
                } forEach [6001 + _perkId, 7001 + _perkId];
            };
        };

        _sideYWHO = [_screenGapY + _numEntitiesBackgroundHeight + _sideHeight, _sideWidth, _sideHeight, "RIGHT"];

        _ticketsWestTransform = (([1 - (_screenGapX + _totalSidesWidth)] + _sideYWHO) call SC_fnc_transformAlignToSafezone);
        _ticketsEastTransform = (([1 - (_screenGapX + 2 * _sideWidth + _sideGapX)] + _sideYWHO) call SC_fnc_transformAlignToSafezone);
        _ticketsGuerTransform = (([1 - (_screenGapX + _sideWidth)] + _sideYWHO) call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 1002) ctrlSetPosition _ticketsWestTransform;
        (_display displayCtrl 1800) ctrlSetPosition _ticketsWestTransform;

        (_display displayCtrl 1003) ctrlSetPosition _ticketsEastTransform;
        (_display displayCtrl 1801) ctrlSetPosition _ticketsEastTransform;

        (_display displayCtrl 1004) ctrlSetPosition _ticketsGuerTransform;
        (_display displayCtrl 1802) ctrlSetPosition _ticketsGuerTransform;

        (_display displayCtrl 1002) ctrlCommit _commitDuration;
        (_display displayCtrl 1800) ctrlCommit _commitDuration;

        (_display displayCtrl 1003) ctrlCommit _commitDuration;
        (_display displayCtrl 1801) ctrlCommit _commitDuration;

        (_display displayCtrl 1004) ctrlCommit _commitDuration;
        (_display displayCtrl 1802) ctrlCommit _commitDuration;

        _numEntitiesBackgroundYWH = [_screenGapY + _numEntitiesBackgroundHeight, _numEntitiesBackgroundWidth, _numEntitiesBackgroundHeight];

        _numEntitiesWestTransform = (([1 - (_screenGapX + _totalSidesWidth)] + _numEntitiesBackgroundYWH + [ "RIGHT"]) call SC_fnc_transformAlignToSafezone);
        _numEntitiesEastTransform = (([1 - (_screenGapX + 2 * _sideWidth + _sideGapX)] + _numEntitiesBackgroundYWH + [ "RIGHT"]) call SC_fnc_transformAlignToSafezone);
        _numEntitiesGuerTransform = (([1 - (_screenGapX + _sideWidth)] + _numEntitiesBackgroundYWH + [ "RIGHT"]) call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 2000) ctrlSetPosition _numEntitiesWestTransform;
        (_display displayCtrl 2001) ctrlSetPosition _numEntitiesEastTransform;
        (_display displayCtrl 2002) ctrlSetPosition _numEntitiesGuerTransform;

        (_display displayCtrl 2000) ctrlSetText "";

        (_display displayCtrl 2000) ctrlCommit _commitDuration;
        (_display displayCtrl 2001) ctrlCommit _commitDuration;
        (_display displayCtrl 2002) ctrlCommit _commitDuration;

        (_display displayCtrl 2009) ctrlSetPosition ([1 - (_screenGapX + _totalSidesWidth) + (0.03 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.4 * _numEntitiesBackgroundWidth, _numEntitiesBackgroundHeight / 2, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2010) ctrlSetPosition ([1 - (_screenGapX + 2 * _sideWidth + _sideGapX) + (0.03 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.4 * _numEntitiesBackgroundWidth, _numEntitiesBackgroundHeight / 2, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2011) ctrlSetPosition ([1 - (_screenGapX + _sideWidth) + (0.03 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.4 * _numEntitiesBackgroundWidth, _numEntitiesBackgroundHeight / 2, "RIGHT"] call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 2009) ctrlCommit _commitDuration;
        (_display displayCtrl 2010) ctrlCommit _commitDuration;
        (_display displayCtrl 2011) ctrlCommit _commitDuration;

        (_display displayCtrl 2012) ctrlSetPosition ([1 - (_screenGapX + _totalSidesWidth), _screenGapY + 0.45 * _numEntitiesBackgroundHeight, 0.5 * _numEntitiesBackgroundWidth, 0.4 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2013) ctrlSetPosition ([1 - (_screenGapX + 2 * _sideWidth + _sideGapX), _screenGapY + 0.45 * _numEntitiesBackgroundHeight, 0.5 * _numEntitiesBackgroundWidth, 0.4 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2014) ctrlSetPosition ([1 - (_screenGapX + _sideWidth), _screenGapY + 0.45 * _numEntitiesBackgroundHeight, 0.5 * _numEntitiesBackgroundWidth, 0.4 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 2012) ctrlCommit _commitDuration;
        (_display displayCtrl 2013) ctrlCommit _commitDuration;
        (_display displayCtrl 2014) ctrlCommit _commitDuration;

        (_display displayCtrl 2003) ctrlSetPosition ([1 - (_screenGapX + _totalSidesWidth) + (0.525 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.475 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2004) ctrlSetPosition ([1 - (_screenGapX + 2 * _sideWidth + _sideGapX) + (0.525 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.475 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2005) ctrlSetPosition ([1 - (_screenGapX + _sideWidth) + (0.525 * _numEntitiesBackgroundWidth), _screenGapY + _numEntitiesBackgroundHeight, 0.475 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 2003) ctrlSetFontHeight 0.03;
        (_display displayCtrl 2004) ctrlSetFontHeight 0.03;
        (_display displayCtrl 2005) ctrlSetFontHeight 0.03;

        (_display displayCtrl 2003) ctrlCommit _commitDuration;
        (_display displayCtrl 2004) ctrlCommit _commitDuration;
        (_display displayCtrl 2005) ctrlCommit _commitDuration;

        (_display displayCtrl 2006) ctrlSetPosition ([1 - (_screenGapX + _totalSidesWidth) + (0.45 * _numEntitiesBackgroundWidth), _screenGapY + 0.5 * _numEntitiesBackgroundHeight, 0.55 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2007) ctrlSetPosition ([1 - (_screenGapX + 2 * _sideWidth + _sideGapX) + (0.45 * _numEntitiesBackgroundWidth), _screenGapY + 0.5 * _numEntitiesBackgroundHeight, 0.55 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);
        (_display displayCtrl 2008) ctrlSetPosition ([1 - (_screenGapX + _sideWidth) + (0.45 * _numEntitiesBackgroundWidth), _screenGapY + 0.5 * _numEntitiesBackgroundHeight, 0.55 * _numEntitiesBackgroundWidth, 0.5 * _numEntitiesBackgroundHeight, "RIGHT"] call SC_fnc_transformAlignToSafezone);

        (_display displayCtrl 2006) ctrlSetFontHeight 0.03;
        (_display displayCtrl 2007) ctrlSetFontHeight 0.03;
        (_display displayCtrl 2008) ctrlSetFontHeight 0.03;

        (_display displayCtrl 2006) ctrlCommit _commitDuration;
        (_display displayCtrl 2007) ctrlCommit _commitDuration;
        (_display displayCtrl 2008) ctrlCommit _commitDuration;
    };

    for "_row" from 0 to 1 do {
        for "_column" from 0 to 2 do {
            _perkId = _column + 3 * (1 - _row);
            _text = if (count SC_var_perks > _perkId) then {SC_var_perks select _perkId} else {"----"};

            if ((ctrlText (_display displayCtrl (6001 + _perkId))) != _text) then {
                (_display displayCtrl (6001 + _perkId)) ctrlSetText _text;
            };
        };
    };

    _posStaminaBar = ctrlPosition (_display displayCtrl 5006);
    _posStaminaBar set [2, (_posStaminaBar select 2) * SC_var_stamina];

    (_display displayCtrl 5005) ctrlSetPosition _posStaminaBar;
    (_display displayCtrl 5005) ctrlCommit _commitDuration;

    _staminaCriticalFactor = 5 * (0 max (0.2 - SC_var_stamina));
    _colorStamina = ([1, 0.9, 0] vectorMultiply (1 - _staminaCriticalFactor)) vectorAdd ([1, 0, 0] vectorMultiply _staminaCriticalFactor);
    (_display displayCtrl 5005) ctrlSetBackgroundColor (_colorStamina + [0.7]);

    if ((ctrlText (_display displayCtrl 1001)) != _hpStr) then {
        (_display displayCtrl 1001) ctrlSetText _hpStr;

        _posHpFrame = ctrlPosition (_display displayCtrl 1803);
        _posHpBar = _posHpFrame;
        _posHpBar set [2, (_posHpFrame select 2) * (_hp / 100)];

        (_display displayCtrl 999) ctrlSetPosition _posHpBar;
        (_display displayCtrl 999) ctrlCommit _commitDuration;
    };

    if ((ctrlText (_display displayCtrl 1005)) != _rankStr) then {
        (_display displayCtrl 1005) ctrlSetText _rankStr;
    };

    if ((ctrlText (_display displayCtrl 1000)) != _xpStr) then {
        (_display displayCtrl 1000) ctrlSetText _xpStr;

        _posXpBar = ctrlPosition (_display displayCtrl 1000);
        _posXpBar set [2, ((_posXpBar select 2) * (if (SC_var_neededXp != 0) then {1 min (_xp / SC_var_neededXp)} else {1}))];

        (_display displayCtrl 998) ctrlSetPosition _posXpBar;
        (_display displayCtrl 998) ctrlCommit _commitDuration;
    };

    _ticketsWestStr = str (floor SC_var_westTickets);
    if ((ctrlText (_display displayCtrl 1002)) != _ticketsWestStr) then {
        (_display displayCtrl 1002) ctrlSetText _ticketsWestStr;
    };
    
    _ticketsEastStr = str (floor SC_var_eastTickets);
    if ((ctrlText (_display displayCtrl 1003)) != _ticketsEastStr) then {
        (_display displayCtrl 1003) ctrlSetText _ticketsEastStr;
    };

    _ticketsGuerStr = str (floor SC_var_guerTickets);
    if ((ctrlText (_display displayCtrl 1004)) != _ticketsGuerStr) then {
        (_display displayCtrl 1004) ctrlSetText _ticketsGuerStr;
    };

    _numUnitsWestStr = str SC_var_numUnitsWest;
    if ((ctrlText (_display displayCtrl 2003)) != _numUnitsWestStr) then {
        (_display displayCtrl 2003) ctrlSetText _numUnitsWestStr;
    };

    _numUnitsEastStr = str SC_var_numUnitsEast;
    if ((ctrlText (_display displayCtrl 2004)) != _numUnitsEastStr) then {
        (_display displayCtrl 2004) ctrlSetText _numUnitsEastStr;
    };
    
    _numUnitsGuerStr = str SC_var_numUnitsGuer;
    if ((ctrlText (_display displayCtrl 2005)) != _numUnitsGuerStr) then {
        (_display displayCtrl 2005) ctrlSetText _numUnitsGuerStr;
    };

    _strmaxVehAmount = str SC_var_maximumVehicleAmount;

    _numVehiclesWestStr = if SC_var_hugeMap then {
        str (SC_var_numVehiclesSides select 0)
    } else {
        [(str (SC_var_numVehiclesSides select 0)), _strmaxVehAmount] joinString "/"
    };
    if ((ctrlText (_display displayCtrl 2006)) != _numVehiclesWestStr) then {
        (_display displayCtrl 2006) ctrlSetText _numVehiclesWestStr;
    };

    _numVehiclesEastStr = if SC_var_hugeMap then {
        str (SC_var_numVehiclesSides select 1)
    } else {
        [(str (SC_var_numVehiclesSides select 1)), _strmaxVehAmount] joinString "/"
    };
    if ((ctrlText (_display displayCtrl 2007)) != _numVehiclesEastStr) then {
        (_display displayCtrl 2007) ctrlSetText _numVehiclesEastStr;
    };

    _numVehiclesGuerStr = if SC_var_hugeMap then {
        str (SC_var_numVehiclesSides select 2)
    } else {
        [(str (SC_var_numVehiclesSides select 2)), _strmaxVehAmount] joinString "/"
    };
    if ((ctrlText (_display displayCtrl 2008)) != _numVehiclesGuerStr) then {
        (_display displayCtrl 2008) ctrlSetText _numVehiclesGuerStr;
    };
};