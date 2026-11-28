// GunGame HUD (client), leaderboard (server and client) and announcements (client).

// ---- leaderboard ----
/*
    The server ranks the active units and publishes one compact variable per change, GG_var_leaderBoard:
    [round ended, top 3 [[unit id, name, team, stage], ...], unit ids of all ranked units in rank order, team stages].
    Each client formats it (names escaped, colors of its own settings) and finds its own rank by its unit id.
    Shown in the top left corner as screen text blocks (ui\ui.sqf), one row each, every block as wide as its own row.
*/

GG_var_leaderBoardNameWidth = 4.5;      // grid cells for a name in a row, longer names are cut with "..."
GG_var_leaderBoardPictureSize = 1.5;    // weapon pictures, relative to the text height
GG_var_leaderBoardMargin = 0.5;         // grid cells from the screen edges, as the vanilla HUD

// active units by stage, highest first; a tie goes to who reached the stage first (teams: more kills)
GG_fnc_rankedUnits = {
    private _units = call GG_fnc_activeUnits;
    private _sortKeys = [];

    {
        private _tieBreak = if (GG_var_teamMode) then {
            -(_x getVariable ["GG_var_kills", 0])
        } else {
            _x getVariable ["GG_var_stageTime", 0]
        };

        _sortKeys pushBack [-(_x getVariable ["GG_var_weaponNum", 0]), _tieBreak, _forEachIndex];
    } forEach _units;

    _sortKeys sort true;
    _sortKeys apply {_units select (_x select 2)}
};

GG_fnc_refreshLeaderBoardServer = {
    private _rankedUnits = call GG_fnc_rankedUnits;

    GG_var_leaderBoard = [
        GG_var_ended,
        (_rankedUnits select [0, 3]) apply {
            [_x getVariable ["GG_var_unitId", -1], name _x, [_x] call GG_fnc_teamOf, _x getVariable ["GG_var_weaponNum", 0]]
        },
        _rankedUnits apply {_x getVariable ["GG_var_unitId", -1]},
        GG_var_teamWeaponNums
    ];

    publicVariable "GG_var_leaderBoard";

    // the public variable event handler does not fire on the broadcasting machine (hosted server)
    if (hasInterface && {!isNull player}) then {
        call GG_fnc_refreshLeaderBoardClient;
    };
};

GG_fnc_refreshLeaderBoardClient = {
    GG_var_leaderBoard params ["_ended", "_topEntries", "_rankedIds", "_teamWeaponNums"];

    private _ownId = player getVariable ["GG_var_unitId", -1];
    private _rows = [];

    if (_ended) then {
        _rows pushBack "Round over, winners:";
    };

    if (GG_var_teamMode) then {
        private _teamTexts = [];

        {
            _teamTexts pushBack format [
                "<t color='%1'>%2</t> %3/%4",
                [_x] call UI_fnc_sideColorHtml,
                GG_var_teamNames select _forEachIndex,
                _teamWeaponNums select _forEachIndex,
                count GG_var_weaponList - 1
            ];
        } forEach GG_var_teamSides;

        _rows pushBack (_teamTexts joinString "   ");
    };

    {
        _x params ["_unitId", "_name", "_team", "_weaponNum"];
        _rows pushBack ([_forEachIndex + 1, _name, _team, _weaponNum, _unitId == _ownId] call GG_fnc_leaderBoardLine);
    } forEach _topEntries;

    private _ownRank = (_rankedIds find _ownId) + 1;

    if (_ownRank > count _topEntries) then {
        _rows pushBack ([
            _ownRank,
            name player,
            side group player,
            player getVariable ["GG_var_weaponNum", 0],
            true
        ] call GG_fnc_leaderBoardLine);
    };

    (call UI_fnc_gridCell) params ["_cellW", "_cellH"];

    // every row on a block as wide as its own text
    private _bottom = [
        GG_var_leaderBoardLayer,
        _rows,
        [safeZoneX + GG_var_leaderBoardMargin * _cellW, safeZoneY + GG_var_leaderBoardMargin * _cellH],
        -1,
        -1
    ] call UI_fnc_showTextBlocks;

    // the killfeed's death feed (also top left) below the leaderboard
    KF_var_deathFeedTop = _bottom + GG_var_leaderBoardMargin * _cellH;
};

// "3. Name <weapon picture> 12/48"; the own name in the "you" yellow, team members in their side color; long names cut
GG_fnc_leaderBoardLine = {
    params ["_rank", "_name", "_team", "_weaponNum", "_isOwn"];

    (call UI_fnc_gridCell) params ["_cellW"];

    private _nameText = [[_name, GG_var_leaderBoardNameWidth * _cellW] call UI_fnc_fitText] call CMN_fnc_escapeText;

    if (_isOwn || {GG_var_teamMode}) then {
        private _color = if (_isOwn) then {["you"] call UI_fnc_colorHtml} else {[_team] call UI_fnc_sideColorHtml};
        _nameText = format ["<t color='%1'>%2</t>", _color, _nameText];
    };

    format [
        "%1. %2 <img size='%6' color='#ffffff' image='%3'/> %4/%5",
        _rank,
        _nameText,
        [(GG_var_weaponList select _weaponNum) select 0] call GG_fnc_getPicture,
        _weaponNum,
        count GG_var_weaponList - 1,
        GG_var_leaderBoardPictureSize
    ]
};

// ---- announcements (client) ----

// remoteExec'd by GG_fnc_announceGlobal: last stages ("grenade", "stagesLeft") and kill streaks ("streak")
GG_fnc_announce = {
    params ["_type", "_name", "_value"];

    if (!hasInterface) exitWith {};

    private _nameText = [_name] call CMN_fnc_escapeText;
    private _text = switch (_type) do {
        case "grenade": {format ["%1 is on the grenade", _nameText]};
        case "stagesLeft": {format ["%1 has %2 weapons left", _nameText, _value]};
        default {format ["%1: %2 kills in a row", _nameText, _value]};
    };

    ["gunGameAnnouncement", [_text]] call BIS_fnc_showNotification;
};

// ---- HUD (client) ----

/*
    RscTitles GG_rscHud (GG\ui.hpp), updated 10x per second; a text is only set when its value changes.
    Rows: stage with progress bar, kills and deaths, K/D and unit count, health bar.
*/
GG_fnc_guiLoop = {
    disableSerialization;
    private _hud = uiNamespace getVariable "GG_rscHud";
    private _hpBar = _hud displayCtrl 1200;
    private _hpText = _hud displayCtrl 1201;
    private _stageBar = _hud displayCtrl 1300;
    private _stageText = _hud displayCtrl 1301;
    private _killsText = _hud displayCtrl 1002;
    private _ratioText = _hud displayCtrl 1003;
    private _hpBarFull = ctrlPosition _hpBar;          // layout of GG\ui.hpp = 100 HP
    private _stageBarFull = ctrlPosition _stageBar;    // = end of the ladder

    private _shownHp = -1;
    private _shownStage = [];
    private _shownKills = -1;
    private _shownDeaths = -1;
    private _shownUnitCount = -1;
    private _kdRatio = 0;

    waitUntil {
        private _weaponNum = player getVariable ["GG_var_weaponNum", 0];
        private _lastWeaponNum = count GG_var_weaponList - 1;
        private _kills = player getVariable ["GG_var_kills", 0];
        private _deaths = player getVariable ["GG_var_deaths", 0];
        private _hpUnit = if (alive player) then {player} else {positionCameraToWorld [0, 0, 0] nearestObject "Man"};
        private _hp = ceil ((1 - damage _hpUnit) * 100);
        private _unitCount = {
            if (isPlayer _x) then {!(_x getVariable ["CMN_var_isLoading", true])} else {simulationEnabled _x}
        } count (entities [["CAManBase"], [], true, false]);

        if (_hp != _shownHp) then {
            _shownHp = _hp;
            _hpText ctrlSetText format ["%1 HP", _hp];
            _hpBarFull params ["_barX", "_barY", "_barW", "_barH"];
            _hpBar ctrlSetPosition [_barX, _barY, (_hp / 100) * _barW, _barH];
            _hpBar ctrlCommit 0;
        };

        if ([_weaponNum, _lastWeaponNum] isNotEqualTo _shownStage) then {
            _shownStage = [_weaponNum, _lastWeaponNum];
            _stageText ctrlSetText format ["Weapon %1/%2", _weaponNum, _lastWeaponNum];
            _stageBarFull params ["_barX", "_barY", "_barW", "_barH"];
            _stageBar ctrlSetPosition [_barX, _barY, (_weaponNum / (_lastWeaponNum max 1)) * _barW, _barH];
            _stageBar ctrlCommit 0;
        };

        private _scoreChanged = _kills != _shownKills || {_deaths != _shownDeaths};

        if (_scoreChanged) then {
            _shownKills = _kills;
            _shownDeaths = _deaths;
            _kdRatio = if (_deaths == 0) then {_kills} else {[_kills / _deaths, 1] call BIS_fnc_cutDecimals};
            _killsText ctrlSetText format ["Kills: %1 Deaths: %2", _kills, _deaths];
        };

        if (_scoreChanged || {_unitCount != _shownUnitCount}) then {
            _shownUnitCount = _unitCount;
            _ratioText ctrlSetText format ["K/D: %1 Units: %2", _kdRatio, _unitCount];
        };

        sleep GG_var_hudInterval;
        false
    };
};

/*
    Shows the next one or two weapons of the ladder (whenever the player's weapon changes): a screen text block
    (ui\ui.sqf) as wide as its content, right-aligned with the HUD right above it (GG\ui.hpp, stagePanel idc 5), so it
    stays clear of the GPS panel. Needs the HUD; GG_fnc_setupPlayer calls it once the HUD exists.
*/
GG_var_nextWeaponsPictureSize = 2;  // weapon pictures, relative to the text height

GG_fnc_refreshNextWeapon = {
    private _stagePanel = (uiNamespace getVariable ["GG_rscHud", displayNull]) displayCtrl 5;

    if (isNull _stagePanel) exitWith {};

    private _weaponNum = player getVariable ["GG_var_weaponNum", 0];
    private _lastWeaponNum = count GG_var_weaponList - 1;
    private _content = "No weapons left";

    if (_weaponNum + 1 < _lastWeaponNum) then {
        private _nextWeapons = GG_var_weaponList select [_weaponNum + 1, [1, 2] select (_weaponNum < _lastWeaponNum - 2)];
        private _pictures = _nextWeapons apply {
            format ["<img size='%1' color='#ffffff' image='%2'/>", GG_var_nextWeaponsPictureSize, [_x select 0] call GG_fnc_getPicture]
        };

        _content = "Next Weapons:<br/>" + (_pictures joinString "<br/>");
    };

    (call UI_fnc_gridCell) params ["", "_cellH"];
    (ctrlPosition _stagePanel) params ["_hudX", "_hudY", "_hudW"];

    [
        GG_var_nextWeaponsLayer,
        format ["<t align='right'>%1</t>", _content],
        [_hudX + _hudW, _hudY - UI_var_textBlockGap * _cellH, 1, 1]
    ] call UI_fnc_showTextBlocks;
};
