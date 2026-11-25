// Holster (server): starts / stops the holster key on every client, including JIP.

H_var_remoteExecId = "";

H_fnc_startHolsterServer = {
    if (!isMultiplayer) exitWith {
        call H_fnc_startHolsterClient;
    };

    if (H_var_remoteExecId != "") exitWith {};

    H_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "H_var_clientInitDone"};
        call H_fnc_startHolsterClient;
    }] remoteExecCall ["spawn", 0, true];
};

H_fnc_stopHolsterServer = {
    if (!isMultiplayer) exitWith {
        call H_fnc_stopHolsterClient;
    };

    if (H_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", H_var_remoteExecId];
    H_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "H_var_clientInitDone"};
        call H_fnc_stopHolsterClient;
    }] remoteExecCall ["spawn", 0];
};

H_var_serverInitDone = true;
publicVariable "H_var_serverInitDone";
