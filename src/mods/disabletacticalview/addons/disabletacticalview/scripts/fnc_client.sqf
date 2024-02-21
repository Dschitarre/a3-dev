DTV_var_ehId = -1;

DTV_fnc_keyDown = {
    params ["", "_key"];

    if (_key in (actionKeys "tacticalView")) then {
        true
    }
};

DTV_fnc_startDisableTacticalViewClient = {
    if (DTV_var_ehId == -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            DTV_var_ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call DTV_fnc_keyDown;}];

            if !isMultiplayer then {
                DTV_var_loadedEhId = addMissionEventHandler ["Loaded", {
                    call DTV_fnc_stopDisableTacticalViewClient;

                    [] spawn {
                        waitUntil {DTV_var_ehId == -1};
                        call DTV_fnc_startDisableTacticalViewClient;
                    };
                }];
            };
        };
    };
};

DTV_fnc_stopDisableTacticalViewClient = {
    if (DTV_var_ehId != -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", DTV_var_ehId];

            if !isMultiplayer then {
                removeMissionEventHandler ["Loaded", DTV_var_loadedEhId];
                DTV_var_loadedEhId = nil;
            };
            
            DTV_var_ehId = -1;
        };
    };
};

DTV_var_clientInitDone = true;