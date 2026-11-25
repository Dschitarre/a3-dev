// Shared TDM/GunGame world (CMN_): environment settings (time, weather, view distance) and play zone helpers.

// ---- world and environment ----

CMN_fnc_disableEngineFeatures = {
    enableRadio false;
    enableSentences false;
    showSubtitles false;
    enableTeamSwitch false;
    enableDynamicSimulationSystem false;

    if (isNil "CMN_var_aiRadioScript") then {
        CMN_var_aiRadioScript = [] spawn CMN_fnc_disableAiRadioLoop;
    };
};

// The AI reports ("2, enemy man, 200 m") and orders still show in the chat with the settings above: the radio protocol
// of an AI unit is off only where disableAI ran on the machine the unit is local to, and the AI of a group a player
// leads becomes local to that player's machine. So every machine turns it off for its own local AI, again after every
// respawn or change of locality.
CMN_fnc_disableAiRadioLoop = {
    while {true} do {
        {
            if ((local _x) && {!(isPlayer _x)} && {_x checkAIFeature "RADIOPROTOCOL"}) then {
                _x disableAI "RADIOPROTOCOL";
            };
        } forEach allUnits;

        sleep 2;
    };
};

CMN_fnc_setupClientEnvironment = {
    call CMN_fnc_disableEngineFeatures;

    0 enableChannel [true, false];
    1 enableChannel [true, false];
    2 enableChannel [false, false];
};

// zoom factor for the map screen, see CMN_fnc_mapZoom
CMN_fnc_mapScaleFactor = {
    switch (worldName) do {
        case "Malden": {1.3};
        case "Altis": {0.5};
        case "Stratis": {2};
        default {1.1};
    };
};

/*
    Server, before DW_fnc_startDynamicWeather: hands the shared params (common\config.hpp: weather, startTime,
    timeMultiplierDay/Night) to the dynamicweather mod. _date: [year, month, day]; _skipNight: the mode's own param.
*/
CMN_fnc_applyWorldParams = {
    params ["_date", "_skipNight"];

    // values[] 0..6 of timeMultiplierDay/Night
    private _timeMultipliers = [0.1, 1, 10, 20, 40, 80, 120];
    private _timeMultiplierDay = _timeMultipliers select ("timeMultiplierDay" call BIS_fnc_getParamValue);
    private _timeMultiplierNight = _timeMultipliers select ("timeMultiplierNight" call BIS_fnc_getParamValue);

    DW_var_changeTimeMultiplierDay = _timeMultiplierDay;
    DW_var_staticTimeMultiplierDay = _timeMultiplierDay;
    DW_var_changeTimeMultiplierNight = _timeMultiplierNight;
    DW_var_staticTimeMultiplierNight = _timeMultiplierNight;
    // startTime: 0 Morning, 1 Noon, 2 Evening, 3 Night; a mission that starts at night never skips nights
    private _startTime = "startTime" call BIS_fnc_getParamValue;
    DW_var_skipNight = _skipNight && {_startTime != 3};
    DW_var_date = _date + ([[6, 0], [12, 0], [18, 0], [1, 0]] select _startTime);

    // weather: 0 Dynamic, 1 Dynamic Foggy, 2 Sun, 3 Clouds, 4 Storm, 5 Rain -> presets of the dynamicweather mod
    DW_var_weatherPreset = ["dynamic", "dynamicFoggy", "sunny", "cloudy", "stormy", "rainy"] select ("weather" call BIS_fnc_getParamValue);
};

// ---- play zone ----

/*
    Server. Moves the cover map module and the play zone marker to one row of the mode's map table, whose rows start with
    [coverMapPos, coverMapDir, coverMapSize, playZonePos, playZoneSize, playZoneDir, playZoneShape, ...].
    Returns [maxZoneSize, zoneArea]; marker sizes are half extents, so a rectangle covers 4*a*b.
*/
CMN_fnc_applyPlayZone = {
    params ["_coverMap", "_marker", "_mapRow"];

    _mapRow params ["_coverMapPos", "_coverMapDir", "_coverMapSize", "_playZonePos", "_playZoneSize", "_playZoneDir", "_playZoneShape"];

    _marker setMarkerPos _playZonePos;
    _marker setMarkerSize _playZoneSize;
    _marker setMarkerDir _playZoneDir;
    _marker setMarkerShape _playZoneShape;

    private _zoneInfo = [
        selectMax _playZoneSize,
        (_playZoneSize select 0) * (_playZoneSize select 1) * ([4, pi] select (_playZoneShape == "ELLIPSE"))
    ];

    // last: BIS_fnc_moduleCoverMap assigns locals without private (e.g. _marker), which overwrites the caller's
    // variables of the same name (SQF's dynamic scope); the play zone used to stay at its mission.sqm position
    if (!isNull _coverMap) then {
        _coverMap setPos _coverMapPos;
        _coverMap setVariable ["objectArea", [_coverMapSize, _coverMapSize, _coverMapDir, true, 0]];
        [_coverMap, [], true] call BIS_fnc_moduleCoverMap;
    };

    _zoneInfo
};

/*
    Server. Indices of the mapData[] rows to choose from by the mapSize param (CMN_PARAM_MAP_SIZE): a fixed size, or
    with Auto one by the number of players (up to _playerLimits select 0: small, up to select 1: medium, more: large).
    _sizeIndex: position of the size category (0 small, 1 medium, 2 large) in a row. Without a row of that size the
    nearest size is taken (the smaller one first).
*/
CMN_fnc_mapsOfWantedSize = {
    params ["_sizeIndex", "_playerLimits"];

    private _wantedSize = ("mapSize" call BIS_fnc_getParamValue) - 1;

    if (_wantedSize < 0) then {
        private _playerCount = count (allPlayers - (allMissionObjects "HeadlessClient_F"));
        _wantedSize = {_playerCount > _x} count _playerLimits;
    };

    private _sizes = (getArray (missionConfigFile >> "mapData")) apply {_x param [_sizeIndex, 1]};
    private _maps = [];

    {
        private _size = _x;

        {
            if (_x == _size) then {
                _maps pushBack _forEachIndex;
            };
        } forEach _sizes;

        if (_maps isNotEqualTo []) exitWith {};
    } forEach [_wantedSize, _wantedSize - 1, _wantedSize + 1, _wantedSize - 2, _wantedSize + 2];

    _maps
};

// client, "Map" mission event handler: centers the map on the play zone when it opens
CMN_fnc_mapZoom = {
    params ["_isOpened", "_marker", "_scaleFactor", "_maxZoneSize"];

    if (_isOpened) then {
        mapAnimAdd [0, _scaleFactor * _maxZoneSize * 10 ^ -4, getMarkerPos _marker];
        mapAnimCommit;
    };
};

/*
    Client, scheduled, runs for the whole mission: the map of the EG spectator (display 60492, map control 62609) is
    centred on the play zone like CMN_fnc_mapZoom whenever it opens; the spectator would centre it on its camera, which
    sits at [0, 0] while no unit is viewed. _zone: code returning [marker, scale factor, max zone size] (read at every
    opening, the zone changes between rounds). Zoomed out by CMN_var_spectatorMapZoomOut compared to the normal map (with
    the same scale the spectator's map showed too little around the zone, user).
*/
CMN_var_spectatorMapZoomOut = 1.75;

CMN_fnc_spectatorMapZoneLoop = {
    params ["_zone"];

    disableSerialization;

    waitUntil {
        waitUntil {sleep 0.1; !isNull (findDisplay 60492)};

        private _map = (findDisplay 60492) displayCtrl 62609;

        // every opening of the map while the spectator is open
        waitUntil {
            waitUntil {sleep 0.05; isNull _map || {ctrlShown _map}};

            if (!isNull _map) then {
                (call _zone) params ["_marker", "_scaleFactor", "_maxZoneSize"];

                _map ctrlMapAnimAdd [0, CMN_var_spectatorMapZoomOut * _scaleFactor * _maxZoneSize * 10 ^ -4, getMarkerPos _marker];
                ctrlMapAnimCommit _map;

                waitUntil {sleep 0.1; isNull _map || {!ctrlShown _map}};
            };

            isNull _map
        };

        false
    };
};
