E_var_ehId = -1;
E_var_earplugsOn = false;

E_fnc_keyDown = {
    params ["", "_key"];

    if (_key == 59 || _key == 0x3B) then {
        0.5 fadesound ([E_var_volumeMuted, 1] select E_var_earplugsOn);
        E_var_earplugsOn = !E_var_earplugsOn;
        true
    };
};

E_fnc_startEarplugsClient = {
    if (E_var_ehId == -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            E_var_ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call E_fnc_keyDown;}];

            if !isMultiplayer then {
                E_var_loadedEhId = addMissionEventHandler ["Loaded", {
                    call E_fnc_stopEarplugsClient;
                    
                    [] spawn {
                        waitUntil {E_var_ehId == -1};
                        call E_fnc_startEarplugsClient;
                    };
                }];
            };
        };
    };
};

E_fnc_stopEarplugsClient = {
    if (E_var_ehId != -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", E_var_ehId];
            0.5 fadesound 1;
            E_var_earplugsOn = false;

            if !isMultiplayer then {
                removeMissionEventHandler ["Loaded", E_var_loadedEhId];
                E_var_loadedEhId = nil;
            };
            
            E_var_ehId = -1;
        };
    };
};

E_var_clientInitDone = true;