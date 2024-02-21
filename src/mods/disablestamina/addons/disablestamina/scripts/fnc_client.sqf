DS_var_clientRunning = nil;
DS_var_respawnEhId = -1;

DS_fnc_startDisableStaminaClient = {
    call {
        if (isNil "DS_var_clientRunning") then {
            DS_var_clientRunning = true;
            DS_var_respawnEhId = player addEventHandler ["Respawn", {_this call DS_fnc_disableStamina;}];
            [player] call DS_fnc_disableStamina;

            if !isMultiplayer then {
                DS_var_loadedEhId = addMissionEventHandler ["Loaded", {
                    call DS_fnc_enableStaminaForAiUnits;
                    call DS_fnc_stopDisableStaminaClient;

                    [] spawn {
                        waitUntil {isNil "DS_var_clientRunning"};
                        call DS_fnc_startDisableStaminaClient;
                        call DS_fnc_disableStaminaForAiUnits;
                    };
                }];
            };
        };
    };
};

DS_fnc_stopDisableStaminaClient = {
    call {
        if !(isNil "DS_var_clientRunning") then {
            DS_var_clientRunning = nil;
            player removeEventHandler ["Respawn", DS_var_respawnEhId];
            [player] call DS_fnc_enableStamina;

            if !isMultiplayer then {
                removeMissionEventHandler ["Loaded", DS_var_loadedEhId];
                DS_var_loadedEhId = nil;
            };
        };
    };
};

DS_var_clientInitDone = true;