// Base, sector and airfield actions (arsenal, vehicle spawn, teleports, ...) on the flag poles (server).

// ---- base actions ----

// server: actions of the base objects, sector flags and airfield vehicle shops (JIP)
SC_fnc_addActionsServer = {
    SC_var_airFieldPositions = [];

    if (SC_var_hugeMap && {((allAirports select 0) isNotEqualTo [])}) then {
        SC_var_airFieldPositions pushBackUnique (getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition"));
        0 setAirportSide sideUnknown;
        private _secondaryAirfieldsConfig = (configFile >> "CfgWorlds" >> worldName >> "SecondaryAirports");

        for "_i" from 1 to (count _secondaryAirfieldsConfig) do {
            private _airportPos = getArray ((_secondaryAirfieldsConfig select (_i - 1)) >> "ilsPosition");
            SC_var_airFieldPositions pushBackUnique _airportPos;

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
            private _sectorInd = _x;
            private _flag3d = missionNamespace getVariable ("SC_var_flag" + _sectorInd + "3d");

            [
                _flag3d, [
                    "<img size='1' color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\Markers\NATO\c_car.paa'/> Vehicles",
                    {params ["", "", "", "_arguments"]; [false, (_arguments select 0), -1] call SC_fnc_setupVehicleSpawnDialog;},
                    [_sectorInd], 1.5, true, false, "", ("(side (group player)) == SC_var_owner" + _sectorInd), 3
                ]
            ] remoteExecCall ["addAction", 0, true];
        } forEach SC_var_sectors;
    };

    SC_var_planeSpawnIds = [];
    if SC_var_hugeMap then {
        _i = 1;

        while {!(isNil ("SC_var_planeShop" + (str _i)))} do {
            private _shop = missionNamespace getVariable ("SC_var_planeShop" + (str _i));

            if ((getPosWorld _shop) inArea "SC_var_playZone") then {
                [
                    _shop, [
                        "<img size='1' color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\Markers\NATO\c_car.paa'/> Vehicles",
                        {params ["", "", "", "_arguments"]; ([true] + _arguments) call SC_fnc_setupVehicleSpawnDialog;},
                        [((text (nearestLocation [(getPosWorld _shop), "nameCity"])) + " Airfield"), _i], 1.5, true, false, "", "", 3
                    ]
                ] remoteExecCall ["addAction", 0, true];

                missionNamespace setVariable [("SC_var_vehicleSpawnSemaphore" + (str _i)), false, true];
                missionNamespace setVariable [("SC_var_planeSpawnSemaphore" + (str _i)), false, true];

                private _markerName = "SC_var_planeSpawnMarker" + (str _i);
                createMarker [_markerName, (getPosWorld _shop)];
                _markerName setMarkerType "c_plane";

                SC_var_planeSpawnIds pushBack _i;
            };

            _i = _i + 1;
        };
    };
    publicVariable "SC_var_planeSpawnIds";

    {
        private _side = _x;
        private _inf = missionNamespace getVariable ("SC_var_" + (str _side) + "Inf");
        private _CS = missionNamespace getVariable ("SC_var_" + (str _side) + "CS");
        private _vehicle = missionNamespace getVariable ("SC_var_" + (str _side) + "Veh");
        private _tp = missionNamespace getVariable ("SC_var_" + (str _side) + "Tp");
        private _equip = missionNamespace getVariable ("SC_var_" + (str _side) + "Equip");

        private _respawn = [_side, (getMarkerPos ("SC_var_" + (toLower (str _side)) + "Respawn")), "Base"] call BIS_fnc_addRespawnPosition;
        missionNamespace setVariable ["SC_var_baseRespawn" + str _side, _respawn];

        [
            _equip, [
                "<img size='1.1' color='#ffffff' shadow='2' image='\A3\Ui_f\data\GUI\Cfg\RespawnRoles\assault_ca.paa'/> Change Loadout",
                {["Open", [false, SC_var_equip, player]] call BIS_fnc_arsenal;},
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

        // information board: the info dialog (all topics of SC\infoBoards.sqf, it opens on the topic viewed last), the
        // equipment list and the statistics
        {
            _x params ["_title", "_code"];

            [
                _inf, [
                    ("<img color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\MapControl\powersolar_CA.paa'/> " + _title),
                    _code, nil, 1.5, true, false, "", "", 3
                ]
            ] remoteExecCall ["addAction", 0, true];
        } forEach [
            ["Show Information", {[] call SC_fnc_openInfoDialog;}],
            ["Equipment List", {createDialog "equipmentDialog";}],
            ["Statistics", {createDialog "statisticsDialog";}]
        ];

        [
            _CS,
            [
                "<img size='1.1' color='#ffffff' shadow='2' image='\A3\ui_f\data\IGUI\Cfg\Actions\reammo_ca.paa'/>Perks",
                {createDialog "perkDialog";}, [], 1.5, true, false, "", "", 3
            ]
        ] remoteExecCall ["addAction", 0, true];

        [
            _vehicle, [
                "<img size='1' color='#ffffff' shadow='2' image='\A3\ui_f\data\Map\Markers\NATO\c_car.paa'/> Vehicles",
                {[true, "the Base", -1] call SC_fnc_setupVehicleSpawnDialog;},
                [], 1.5, true, false, "", "true", 3
            ]
        ] remoteExecCall ["addAction", 0, true];

        [
            _tp,
            [
                "<img size='1.2' shadow='2' image='\A3\ui_f\data\IGUI\Cfg\Actions\unloadVehicle_ca.paa'/> Teleport",
                {call SC_fnc_teleportToPlayZone;},
                nil, 1.5, true, false, "", "", 3
            ]
        ] remoteExecCall ["addAction", 0, true];
    } forEach SC_var_sides;
};
