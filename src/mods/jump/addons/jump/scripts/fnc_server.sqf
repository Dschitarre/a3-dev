// Jump (server): jump speed setting; starts / stops the jump key on every client, including JIP.

J_var_remoteExecId = "";

J_var_jumpSpeed = 1;
publicVariable "J_var_jumpSpeed";

J_fnc_startJumpServer = {
    if (missionNamespace getVariable ["J_cba_override", false]) then {
        call J_fnc_applyCbaSettings;
    };

    if (!isMultiplayer) exitWith {
        call J_fnc_startJumpClient;
    };

    if (J_var_remoteExecId != "") exitWith {};

    J_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "J_var_clientInitDone"};
        call J_fnc_startJumpClient;
    }] remoteExecCall ["spawn", 0, true];
};

J_fnc_stopJumpServer = {
    if (!isMultiplayer) exitWith {
        call J_fnc_stopJumpClient;
    };

    if (J_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", J_var_remoteExecId];
    J_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "J_var_clientInitDone"};
        call J_fnc_stopJumpClient;
    }] remoteExecCall ["spawn", 0];
};

J_var_serverInitDone = true;
publicVariable "J_var_serverInitDone";
