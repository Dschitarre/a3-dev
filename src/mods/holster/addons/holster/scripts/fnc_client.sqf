H_var_ehId = -1;
H_var_lastWeapon = "";

H_fnc_keyDown = {
    params ["", "_key"];

    if ((_key == 35) || (_key == 0x23)) then {
        _curWep = currentWeapon player;
        
        if (_curWep != "") then {
            if (
                if (_curWep == (secondaryWeapon player)) then {
                    (speed player) == 0
                } else {
                    true
                }
            ) then {
                H_var_lastWeapon = _curWep;
                player action ["SwitchWeapon", player, player, 100];
            };
        } else {
            player selectWeapon H_var_lastWeapon;
            H_var_lastWeapon = "";
        };
    };
};

H_fnc_startHolsterClient = {
    if (H_var_ehId == -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            H_var_ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call H_fnc_keyDown;}];

            if !isMultiplayer then {
                H_var_loadedEhId = addMissionEventHandler ["Loaded", {
                    call H_fnc_stopHolsterClient;
                    
                    [] spawn {
                        waitUntil {H_var_ehId == -1};
                        call H_fnc_startHolsterClient;
                    };
                }];
            };
        };
    };
};

H_fnc_stopHolsterClient = {
    if (H_var_ehId != -1) then {
        [] spawn {
            waitUntil {!(isNull player) && !(isNull (findDisplay 46))};

            disableSerialization;
            (findDisplay 46) displayRemoveEventHandler ["KeyDown", H_var_ehId];

            if !isMultiplayer then {
                removeMissionEventHandler ["Loaded", H_var_loadedEhId];
                H_var_loadedEhId = nil;
            };
            
            H_var_ehId = -1;
        };
    };
};

H_var_clientInitDone = true;