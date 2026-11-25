// Auto heal (server): heal settings; starts / stops healing on every machine, including JIP.

AH_var_serverRunning = false;
AH_var_remoteExecId = "";

AH_var_healSpeed = 1;
AH_var_healCooldownMedic = 8;
AH_var_healCooldown = 12;

publicVariable "AH_var_healSpeed";
publicVariable "AH_var_healCooldownMedic";
publicVariable "AH_var_healCooldown";

AH_fnc_startAutoHealServer = {
    if (missionNamespace getVariable ["AH_cba_override", false]) then {
        call AH_fnc_applyCbaSettings;
    };

    if (!isMultiplayer) exitWith {
        call AH_fnc_startAutoHealClientServer;
    };

    if (AH_var_serverRunning) exitWith {};

    AH_var_serverRunning = true;
    AH_var_remoteExecId = [[], {
        waitUntil {!isNil "AH_var_clientServerInitDone"};
        call AH_fnc_startAutoHealClientServer;
    }] remoteExecCall ["spawn", 0, true];
};

AH_fnc_stopAutoHealServer = {
    if (!isMultiplayer) exitWith {
        call AH_fnc_stopAutoHealClientServer;
    };

    if (!AH_var_serverRunning) exitWith {};

    AH_var_serverRunning = false;
    remoteExec ["", AH_var_remoteExecId];
    AH_var_remoteExecId = "";

    [[], {
        if (!isNil "AH_var_clientServerInitDone") then {
            call AH_fnc_stopAutoHealClientServer;
        };
    }] remoteExecCall ["call", 0];
};

AH_var_serverInitDone = true;
publicVariable "AH_var_serverInitDone";
