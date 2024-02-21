SC_fnc_hudUpdateSectorOverviewLoop = {
    waitUntil {
        sleep 1.2;
        [1.2] call SC_fnc_hudUpdateSectorOverview;
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

SC_fnc_disableLeftGpsLoop = {
    waitUntil {
        call {
            if ((((infoPanel "right") select 0) == "EmptyDisplay") != !SC_var_gpsPanelEnabled) then {
                opengps SC_var_gpsPanelEnabled;
                setInfoPanel ["right", (["EmptyDisplay", "MinimapDisplay"] select SC_var_gpsPanelEnabled)];
            };
            
            if (((infoPanel "left") select 0) != "EmptyDisplay") then {
                setInfoPanel ["left", "EmptyDisplay"];
            };
        };

        false
    };
};

SC_fnc_spectatorMapDrawEHLoop = {
    waitUntil {
        waitUntil {!(isNull (findDisplay 60492))};
        SC_var_isInSpectator = true;

        waitUntil {
            waitUntil {(isNull (findDisplay 60492)) || {ctrlshown ((findDisplay 60492) displayCtrl 62609)}};
            if (isNull (findDisplay 60492)) exitWith {true};
            ((findDisplay 60492) displayCtrl 62609) ctrlMapAnimAdd [0, 1.95 * SC_var_mapScale, SC_var_mapPosition];
            ctrlMapAnimCommit ((findDisplay 60492) displayCtrl 62609);

            waitUntil {
                if (ctrlShown ((findDisplay 60492) displayCtrl 62609)) then {
                    SC_var_mapScale = (ctrlMapScale ((findDisplay 60492) displayCtrl 62609)) / 1.95;
                    SC_var_mapPosition = ((findDisplay 60492) displayCtrl 62609) ctrlMapScreenToWorld [0.5, 0.5];
                    false
                } else {
                    true
                }
            };

            (isNull (findDisplay 60492))
        };

        SC_var_isInSpectator = false;
        false
    };
};

SC_fnc_cameraMapDrawEHLoop = {
    waitUntil {
        waitUntil {!(isNull (findDisplay 314))};
        _pos = ((findDisplay 314) displayCtrl 3141) ctrlMapScreenToWorld [0.5, 0.5];
        waitUntil {!((((findDisplay 314) displayCtrl 3141) ctrlMapScreenToWorld [0.5, 0.5]) isEqualTo _pos)};

        waitUntil {
            waitUntil {(isNull (findDisplay 314)) || {ctrlEnabled ((findDisplay 314) displayCtrl 3141)}};
            if (isNull (findDisplay 314)) exitWith {true};
            ((findDisplay 314) displayCtrl 3141) ctrlMapAnimAdd [0, 1.2 * SC_var_mapScale, SC_var_mapPosition];
            ctrlMapAnimCommit ((findDisplay 314) displayCtrl 3141);

            waitUntil {
                if (ctrlEnabled ((findDisplay 314) displayCtrl 3141)) then {
                    SC_var_mapScale = (ctrlMapScale ((findDisplay 314) displayCtrl 3141)) / 1.2;
                    SC_var_mapPosition = ((findDisplay 314) displayCtrl 3141) ctrlMapScreenToWorld [0.5, 0.5];
                    false
                } else {
                    true
                }
            };

            (isNull (findDisplay 314))
        };

        false
    };
};