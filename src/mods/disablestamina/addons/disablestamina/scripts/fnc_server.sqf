// Disable stamina (server): weapon sway settings; starts / stops disabling stamina on every machine (server,
// clients, headless clients), including JIP.

DS_var_remoteExecId = "";

DS_var_weaponSwayEnabled = 1;
DS_var_weaponSwayDisabled = 0.3;

publicVariable "DS_var_weaponSwayEnabled";
publicVariable "DS_var_weaponSwayDisabled";

DS_fnc_startDisableStaminaServer = {
    if (missionNamespace getVariable ["DS_cba_override", false]) then {
        call DS_fnc_applyCbaSettings;
    };

    if (!isMultiplayer) exitWith {
        call DS_fnc_startDisableStaminaClientServer;
    };

    if (DS_var_remoteExecId != "") exitWith {};

    DS_var_remoteExecId = [[], {
        waitUntil {!isNil "DS_var_clientServerInitDone"};
        call DS_fnc_startDisableStaminaClientServer;
    }] remoteExecCall ["spawn", 0, true];
};

DS_fnc_stopDisableStaminaServer = {
    if (!isMultiplayer) exitWith {
        call DS_fnc_stopDisableStaminaClientServer;
    };

    if (DS_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", DS_var_remoteExecId];
    DS_var_remoteExecId = "";

    [[], {
        waitUntil {!isNil "DS_var_clientServerInitDone"};
        call DS_fnc_stopDisableStaminaClientServer;
    }] remoteExecCall ["spawn", 0];
};

DS_var_serverInitDone = true;
publicVariable "DS_var_serverInitDone";
