SC_var_mapName = (getArray (missionConfigFile >> "params" >> "MapName" >> "texts")) select ("MapName" call BIS_fnc_getParamValue);
_mapNames = getArray (missionConfigFile >> "params" >> "MapName" >> "texts");

if (SC_var_mapName == "Random") then {
	SC_var_mapName = selectRandom (_mapNames - ["Random"]);
};

SC_var_wholeMap = SC_var_mapName in ["Altis (Huge)", "Malden (Huge)"];
publicVariable "SC_var_wholeMap";

((getArray (missionConfigFile >> "MapData")) select ((_mapNames find SC_var_mapName) - 1)) params ["_generalData", "_sideData", "_sectorData"];

"SC_var_playZone" setMarkerPos (_generalData select 3);
"SC_var_playZone" setMarkerSize (_generalData select 4);
"SC_var_playZone" setMarkerDir (_generalData select 5);
"SC_var_playZone" setMarkerShape (_generalData select 6);

SC_var_coverMap setPos (_generalData select 0);

if (((getPosWorld SC_var_coverMap) distance2D (getMarkerPos "SC_var_playZone")) > 100) then {
	SC_var_coverMap setPos (getMarkerPos "SC_var_playZone");
	_size = 1.3 * (selectMax (getMarkerSize "SC_var_playZone"));
	SC_var_coverMap setVariable ["objectArea", [_size, _size, (_generalData select 1), true, 0]];
} else {
	SC_var_coverMap setVariable ["objectArea", [(_generalData select 2), (_generalData select 2), (_generalData select 1), true, 0]];
};

[SC_var_coverMap, [], true] call BIS_fnc_moduleCoverMap;
_sideData = _sideData call BIS_fnc_arrayShuffle;

{
	_varStart = "SC_var_" + toLower (str ([west, east, independent] select _forEachIndex));
	
	(_varStart + "Respawn") setMarkerPos (_x select 0);
	(_varStart + "Respawn") setMarkerDir (_x select 1);
	(_varStart + "HQ") setMarkerPos (_x select 2);
	(_varStart + "Base") setMarkerPos (_x select 3);
	(_varStart + "Base") setMarkerShape (_x select 4);
	(_varStart + "Base") setMarkerSize (_x select 5);
	(_varStart + "Base") setMarkerDir (_x select 6);

	{
		_obj = missionNamespace getVariable (_varStart + (["VehSpawn", "Cs", "Equip", "Inf", "Tp", "Veh", "PlaneSpawn"] select _forEachIndex));

		_pos = _x select 0;
		_pos set [2, 0];

		_obj setPos _pos;
		_obj setVectorDir ((_x select 1) select 0);
		_obj setVectorUp (surfaceNormal _pos);
	} foreach (_x select 7);
} forEach _sideData;

SC_var_sectors = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"];
SC_var_numSectorsLimit = count _sectorData;
publicVariable "SC_var_numSectorsLimit";

{
	deleteMarker ("SC_var_sector" + _x);
	deleteVehicle (missionNamespace getVariable ("SC_var_flag" + _x + "3d"));
} forEach (SC_var_sectors select [SC_var_numSectorsLimit, ((count SC_var_sectors) - SC_var_numSectorsLimit)]);

SC_var_sectors = SC_var_sectors select [0, SC_var_numSectorsLimit];
publicVariable "SC_var_sectors";

{
	_sectorInd = SC_var_sectors select _forEachIndex;
	_flag = missionNamespace getVariable ("SC_var_flag" + _sectorInd + "3d");
	_sectorMarker = "SC_var_sector" + _sectorInd;

	_pos = _x select 0;
	_safePos = [];
	_rad = 3;

	while {_safePos isEqualTo []} do {
		_safePos = _pos findEmptyPosition [0, _rad, "FlagSmall_F"];
		_rad = _rad + 1;
	};

	_flag setPos _safePos;
	_flag setVectorUp (surfaceNormal _safePos);

	_sectorMarker setMarkerPos (_x select 2);
	_sectorMarker setMarkerShape (_x select 3);
	_sectorMarker setMarkerSize (_x select 4);
	_sectorMarker setMarkerDir (_x select 5);
} forEach _sectorData;

"SC_var_playZone" setMarkerAlpha ([0.35, 0] select SC_var_wholeMap);
"SC_var_spawnArea" setMarkerAlpha 0;

if SC_var_wholeMap then {
    [SC_var_coverMap, [], false] call BIS_fnc_moduleCoverMap;
};