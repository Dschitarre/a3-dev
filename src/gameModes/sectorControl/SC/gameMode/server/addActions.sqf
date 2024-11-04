SC_var_airFieldPositions = [];

if (SC_var_hugeMap && {!((allAirports select 0) isEqualTo [])}) then {
    SC_var_airFieldPositions pushbackunique (getArray (configfile >> "CfgWorlds" >> worldname >> "ilsPosition"));
    0 setAirportSide sideUnknown;
    _secondaryAirfieldsConfig = (configfile >> "CfgWorlds" >> worldname >> "SecondaryAirports");

    for "_i" from 1 to (count _secondaryAirfieldsConfig) do {
        _airportPos = getarray ((_secondaryAirfieldsConfig select (_i - 1)) >> "ilsPosition");
        SC_var_airFieldPositions pushbackunique _airportPos;

        (([(SC_var_sides apply {
            [_x, ((getMarkerPos ("SC_var_" + (str _x) + "Base")) distance2D _airportPos)]
        }), [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy) select 0) params ["_nearestBasesSide", "_distanceToAirport"];

        if (_distanceToAirport <= 500) then {
            _i setAirportSide _nearestBasesSide;
        };
    };
};

if SC_var_spawnVehiclesOnSectors then {
    {
        _sectorInd = _x;
        _flag3d = missionNameSpace getVariable ("SC_var_flag" + _sectorInd + "3d");

        {
            _x params ["_vehicle", "_rank"];

            if !((_vehicle isKindOf "Plane_Base_F") || {_vehicle isKindOf "Plane"}) then {
                [
                    _flag3d, [
                        (format ["<img size='1' color='#ffffff' shadow='2' image=%1/> Rank %2: %3", (str ([_vehicle] call SC_fnc_getPicture)), _rank, ([_vehicle] call SC_fnc_getDisplayName)]),
                        {[player, ((_this select 3) select 0), ((_this select 3) select 1)] remoteExec ["SC_fnc_spawnVehicle", 2];},
                        [_sectorInd, _vehicle], 1.5, true, false, "",
                        (format ['((side (group player)) == SC_var_owner%1) && ((player getVariable "SC_var_rank") >= %2)', _sectorInd, _rank]),
                        3
                    ]
                ] remoteExecCall ["addAction", 0, true];
            };
        } forEach SC_var_availableVehicles;
    } forEach SC_var_sectors;
};

SC_var_planeSpawnIds = [];
if SC_var_hugeMap then {
    _i = 1;

    while {!(isNil ("SC_var_planeShop" + (str _i)))} do {
        _shop = missionNamespace getVariable ("SC_var_planeShop" + (str _i));

        if ((getPosWorld _shop) inArea "SC_var_playZone") then {
            {
                _x params ["_vehicle", "_rank"];

                [
                    _shop, [
                        (format ["<img size='1' color='#ffffff' shadow='2' image=%1/> Rank %2: %3", (str ([_vehicle] call SC_fnc_getPicture)), _rank, ([_vehicle] call SC_fnc_getDisplayName)]),
                        {[player, ((_this select 3) select 0), ((_this select 3) select 1), ((_this select 3) select 2)] remoteExec ["SC_fnc_spawnVehicle", 2];},
                        [((text (nearestLocation [(getPosWorld player), "nameCity"])) + " Airfield"), _vehicle, _i], 1.5, true, false, "",
                        (format ['(player getVariable "SC_var_rank") >= %1', _rank]),
                        3
                    ]
                ] remoteExecCall ["addAction", 0, true];
            } forEach SC_var_availableVehicles;

            missionNamespace setVariable [("SC_var_vehicleSpawnSemaphore" + (str _i)), false, true];
            missionNamespace setVariable [("SC_var_planeSpawnSemaphore" + (str _i)), false, true];

            _markerName = "SC_var_planeSpawnMarker" + (str _i);
            createMarker [_markerName, (getPosWorld _shop)];
            _markerName setMarkerType "c_plane";

            SC_var_planeSpawnIds pushBack _i;
        };

        _i = _i + 1;
    };
};
publicVariable "SC_var_planeSpawnIds";

{
    _side = _x;
    _inf = missionNamespace getVariable ("SC_var_" + (str _side) + "Inf");
    _CS = missionNamespace getVariable ("SC_var_" + (str _side) + "CS");
    _vehicle = missionNamespace getVariable ("SC_var_" + (str _side) + "Veh");
    _tp = missionNamespace getVariable ("SC_var_" + (str _side) + "Tp");
    _equip = missionNamespace getVariable ("SC_var_" + (str _side) + "Equip");

    [_side, (getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn")), "Base"] call BIS_fnc_addRespawnPosition;

    [
        _equip, [
            "<img size='1.1' color='#ffffff' shadow='2' image='\A3\Ui_f\data\GUI\Cfg\RespawnRoles\assault_ca.paa'/> Change Loadout",
            {["Open", [nil, SC_var_equip, player]] call BIS_fnc_arsenal;},
            nil, 1.5, true, false, "", "true", 3
        ]
    ] remoteExecCall ["addAction", 0, true];

    [
        _equip, [
            "<img size='1.5' color='#ffffff' shadow='2' image='\A3\Ui_f\data\IGUI\Cfg\Cursors\getIn_ca.paa'/> Store/Load Loadouts",
            {createDialog "loadoutDialog";}, nil, 1.5, true, false, "", "true", 3
        ]
    ] remoteExecCall ["addAction", 0, true];

    [
        _equip, [
            "<img size='1.1' color='#ffffff' shadow='2' image='\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa'/> Load last saved Loadout",
            {
                [SC_var_lastLoadout] call SC_fnc_setLoadout;
                ["loadoutLoaded"] call BIS_fnc_showNotification;
            },
            nil, 1.5, true, false, "", "true", 3
        ]
    ] remoteExecCall ["addAction", 0, true];

    [
        _equip, [
            "<img size='1.1' color='#ffffff' shadow='2' image='\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\rearm_ca.paa'/> Fill magazines",
            {
                if ((count ((weapons player) + (magazines player))) > 0) then {
                    {
                        player setAmmo[_x, 1000000];
                    } forEach (weapons player);

                    {
                        player removeMagazine _x;
                        player addMagazine _x;
                    } forEach (magazines player);

                    ["magsFilled"] call BIS_fnc_showNotification;
                } else {
                    ["noMags"] call BIS_fnc_showNotification;
                };
            },
            nil, 1.5, true, false, "", "true", 3
        ]
    ] remoteExecCall ["addAction", 0, true];

    {
        _text0 = _x select 0;
        _text1 = _x select 1;
        
        [
            _inf, [
                ("<img color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\MapControl\powersolar_CA.paa'/> " + _text0),
                {
                    createDialog "infoDialog";
                    ((uiNamespace getVariable "SC_var_infoDialog") displayCtrl 1101) ctrlSetText ((_this select 3) select 0);

                    {
                        lbAdd [1500, _x];
                    } forEach (getArray (missionConfigFile >> ((_this select 3) select 1)));

                    if (((_this select 3) select 0) == "Vehicle System") then {
                        lbAdd [1500, ""];
                        lbAdd [1500, "Vehicles:"];

                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach SC_var_availableVehicles;
                    };

                    if (((_this select 3) select 0) == "Equipment") then {
                        lbAdd [1500, "General Equipment:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([((getarray (missionConfigFile >> "general")) + (getarray (missionConfigFile >> ((str (side (group player))) + "General")))) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);
                        
                        lbAdd [1500, ""];
                        lbAdd [1500, "Marksman [MRKS] Perk:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([((getarray (missionConfigFile >> "marksman")) + (getarray (missionConfigFile >> ((str (side (group player))) + "Marksman")))) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);

                        lbAdd [1500, ""];
                        lbAdd [1500, "Machinegunner [MGNR] Perk:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([(getarray (missionConfigFile >> "machinegunner")) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);

                        lbAdd [1500, ""];
                        lbAdd [1500, "Grenadier [GRND] Perk:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([(getarray (missionConfigFile >> "grenadier")) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);

                        lbAdd [1500, ""];
                        lbAdd [1500, "Launcher [LNCR] Perk:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([(getarray (missionConfigFile >> "launcher")) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);

                        lbAdd [1500, ""];
                        lbAdd [1500, "Armor [ARMR] Perk:"];
                        {
                            _x params ["_type", "_rank"];
                            lbAdd [1500, ("Rank " + str _rank + ": " + ([_type] call SC_fnc_getDisplayName))];
                        } forEach ([(getarray (missionConfigFile >> ((str (side (group player))) + "Armor"))) call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy);
                    };
                },
                [_text0, _text1], 1.5, true, false, "", "", 3
            ]
        ] remoteExecCall ["addAction", 0, true];
    } forEach ([
        ["Hotkeys", "hotkeys"],
        ["Gamemode", "gameMode"],
        ["Rank System", "ranksystem"],
        ["Vehicle System", "vehiclesystem"],
        ["Equipment", "equipment"],
        ["Airdrops", "airdrops"],
        ["Perks", "perks"]
    ]);

    [
        _CS,
        [
            "<img size='1.1' color='#ffffff' shadow='2' image='\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa'/>Change Perks",
            {createDialog "perkDialog";}, [], 1.5, true, false, "", "", 3
        ]
    ] remoteExecCall ["addAction", 0, true];

    {
        _x params ["_vehicleStr", "_rank"];

        if (SC_var_wholeMap || {!((_vehicleStr isKindOf "Plane_Base_F") || {_vehicleStr isKindOf "Plane"})}) then {
            [
                _vehicle, [
                    (format ["<img size='1' color='#ffffff' shadow='2' image=%1/> Rank %2: %3", (str ([_vehicleStr] call SC_fnc_getPicture)), _rank, ([_vehicleStr] call SC_fnc_getDisplayName)]),
                    {[player, "the Base", (_this select 3)] remoteExec ["SC_fnc_spawnVehicle", 2];},
                    _vehicleStr, 1.5, true, false, "",
                    (format ['( player getVariable "SC_var_rank") >= %1', (str _rank)]),
                    3
                ]
            ] remoteExecCall ["addAction", 0, true];
        };
    } forEach SC_var_availableVehicles;

    {
        _sectorInd = _x;
        [
            _tp,
            [
                (format ["<img size='1.3' color='#ffffff' shadow='2' image='\A3\Ui_f\data\Map\Markers\Military\flag_CA.paa'/> <t size='1.5'>%1</t>", _sectorInd]),
                {
                    _randomPosArgs = [[[(getMarkerPos ("SC_var_sector" + (_this select 3))), 3]]];

                    _safePos = [0, 0];
                    _rad = 1;

                    waitUntil {
                        _pos = _randomPosArgs call BIS_fnc_randomPos;
                        _pos set [2, 0];

                        waitUntil {_pos findEmptyPositionReady [0, _rad]};
                        _safePos = _pos findEmptyPosition [0, _rad, "B_soldier_F"];
                        _rad = _rad + 1;

                        ((count _safePos) == 3) &&
                        {
                            _safePosAsl = _safePos;
                            _safePosAsl set [2, 0];
                            _safePosAsl = AGLToASL _safePosAsl;
                            _safePosAsl set [2, ((_safePosAsl select 2) + 0.5)];

                            (([objNull, "VIEW"] checkVisibility [_safePosAsl, (_safePosAsl vectorAdd [0, 0, 100])]) != 0)
                        }
                    };

                    player setPos _safePos;
                },
                _sectorInd, 1.5, true, false, "", ("(side (group player)) == SC_var_owner" + _sectorInd), 3
            ]
        ] remoteExecCall ["addAction", 0, true];
    } forEach SC_var_sectors;

    [
        _tp,
        [
            "<img size='1.2' shadow='2' image='\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa'/> Parachute",
            {[player] spawn SC_fnc_zoneParachuteJump},
            nil, 1.5, true, false, "", "", 3
        ]
    ] remoteExecCall ["addAction", 0, true];
} forEach SC_var_sides;