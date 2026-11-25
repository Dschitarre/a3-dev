// Entity culling (server): starts / stops the culling on every client, including JIP. All visibility work runs on
// the clients for their own camera (fnc_client.sqf); the settings are in fnc_clientServer.sqf.

EC_var_remoteExecId = "";

EC_fnc_startEntityCullingServer = {
    if (missionNamespace getVariable ["EC_cba_override", false]) then {
        call EC_fnc_applyCbaSettings;
    };

    if (!isMultiplayer) exitWith {
        call EC_fnc_startEntityCullingClient;
    };

    if (EC_var_remoteExecId != "") exitWith {};

    EC_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "EC_var_clientInitDone" && {!isNil "EC_var_clientServerInitDone"}};
        call EC_fnc_startEntityCullingClient;
    }] remoteExecCall ["spawn", 0, true];
};

// every client reveals what it hid
EC_fnc_stopEntityCullingServer = {
    if (!isMultiplayer) exitWith {
        call EC_fnc_stopEntityCullingClient;
    };

    if (EC_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", EC_var_remoteExecId];
    EC_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "EC_var_clientInitDone"};
        call EC_fnc_stopEntityCullingClient;
    }] remoteExecCall ["spawn", 0];
};

EC_var_serverInitDone = true;
publicVariable "EC_var_serverInitDone";
