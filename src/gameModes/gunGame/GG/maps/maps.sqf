// GunGame map and play zone (server and client): map setup from mapData[] (GG\maps\mapData<map>.hpp), also between
// rounds, and keeping the player inside the zone.

GG_var_mapSizeIndex = 7;            // position of the size category in a mapData[] row
GG_var_mapSizePlayerLimits = [6, 15];   // mapSize Auto: up to 6 players small zones, up to 15 medium, more large

// server: zones of the size the mapSize param asks for
GG_fnc_mapsOfWantedSize = {
    [GG_var_mapSizeIndex, GG_var_mapSizePlayerLimits] call CMN_fnc_mapsOfWantedSize
};

// server, Map param: 0 Random (of the wanted size), v > 0 -> row v - 1 of mapData[]
GG_fnc_initialMapIndex = {
    private _mapSetting = "Map" call BIS_fnc_getParamValue;

    if (_mapSetting > 0) exitWith {_mapSetting - 1};

    selectRandom (call GG_fnc_mapsOfWantedSize)
};

// server: play zone and cover map of row _mapIndex of mapData[]; the AI amount follows the zone size
GG_fnc_applyMap = {
    params ["_mapIndex"];

    private _mapRow = (getArray (missionConfigFile >> "mapData")) select _mapIndex;

    ([missionNamespace getVariable ["GG_var_coverMap", objNull], "GG_var_playZone", _mapRow] call CMN_fnc_applyPlayZone) params ["_maxZoneSize", "_zoneArea"];

    GG_var_mapIndex = _mapIndex;
    GG_var_maxZoneSize = _maxZoneSize;
    GG_var_mapArea = _zoneArea;
    publicVariable "GG_var_maxZoneSize";

    call GG_fnc_updateWantedUnitAmount;
};

// client: a player who stepped out of the zone is put back to his last position inside, however far he got
GG_fnc_playZoneLoop = {
    waitUntil {
        if (alive player) then {
            if (player inArea "GG_var_playZone") then {
                player setVariable ["GG_var_lastPos", getPosATL player];
            } else {
                private _lastPos = player getVariable ["GG_var_lastPos", []];

                if (_lastPos isNotEqualTo [] && {_lastPos inArea "GG_var_playZone"}) then {
                    player setPosATL _lastPos;
                    player setVelocity [0, 0, 0];
                };
            };
        };

        sleep 0.01;
        false
    };
};
