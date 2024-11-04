SC_fnc_setGrassViewDistance = {
    params ["_factor"];

    setTerrainGrid (6.25 / (1 + (([3, 9] select (SC_var_currentWorldGroup == "2035")) * _factor)));
    profileNameSpace setVariable ["SC_var_currentGrassViewDistanceFactor", _factor];
    saveProfileNamespace;
};

SC_fnc_setViewDistance = {
    params ["_factor"];

    _viewDistance = 500 + (3500 * _factor);
    setObjectViewDistance (0.9 * _viewDistance);
    setViewDistance _viewDistance;
    profileNameSpace setVariable ["SC_var_currentViewDistanceFactor", _factor];
    saveProfileNamespace;
};

SC_fnc_keySettingsDialog = {
    params ["", "_key"];

    if (_key == 62) then {
        if (isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
            createDialog "settingsDialog";
        } else {
            closeDialog 2;
        };
        
        true
    }
};

SC_fnc_keyPanel = {
    params ["", "_key"];

    if (_key == 61) then {
        [20] call SC_fnc_toggleSetting;

        if !(isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
            ((uiNamespace getVariable "SC_var_settingsDialog") displayCtrl 2820) cbSetChecked SC_var_gpsPanelEnabled;
        };
        
        true
    }
};

SC_fnc_keyEarplugs = {
    params ["", "_key"];

    if (_key == 59) then {
        if (alive player) then {
            SC_var_earplugsOn = !SC_var_earplugsOn;
            0.5 fadesound ([1, 0.3] select SC_var_earplugsOn);
            
            if (SC_var_hudEnabled && {SC_var_earplugsCooldown == 0}) then {
                SC_var_earplugsCooldown = 3;

                ["earplugs", [["", "off"], ["_crossed", "on"]] select SC_var_earplugsOn] call BIS_fnc_showNotification;
                
                [] spawn {
                    for "_i" from 1 to SC_var_earplugsCooldown do {
                        sleep 1;
                        SC_var_earplugsCooldown = SC_var_earplugsCooldown - 1;
                    };
                };
            };
        };
        
        true
    };
};

SC_fnc_keyHud = {
    params ["", "_key"];

    if (_key == 60) then {
        if (SC_var_hudSwitchCooldown == 0) then {
            call SC_fnc_toggleHud;
            SC_var_hudSwitchCooldown = 1;

            if !(isNull (uiNamespace getVariable ["SC_var_settingsDialog", displayNull])) then {
                ((uiNamespace getVariable "SC_var_settingsDialog") displayCtrl 2800) cbSetChecked SC_var_hudEnabled;
            };

            [] spawn {
                sleep 0.1;
                SC_var_hudSwitchCooldown = 0;
            };
        };

        true
    };
};