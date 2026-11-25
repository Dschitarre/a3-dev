// Disable tactical view (server): starts / stops blocking the tactical view key on every client, including JIP.

DTV_var_remoteExecId = "";

DTV_fnc_startDisableTacticalViewServer = {
    if (!isMultiplayer) exitWith {
        call DTV_fnc_startDisableTacticalViewClient;
    };

    if (DTV_var_remoteExecId != "") exitWith {};

    DTV_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "DTV_var_clientInitDone"};
        call DTV_fnc_startDisableTacticalViewClient;
    }] remoteExecCall ["spawn", 0, true];
};

DTV_fnc_stopDisableTacticalViewServer = {
    if (!isMultiplayer) exitWith {
        call DTV_fnc_stopDisableTacticalViewClient;
    };

    if (DTV_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", DTV_var_remoteExecId];
    DTV_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "DTV_var_clientInitDone"};
        call DTV_fnc_stopDisableTacticalViewClient;
    }] remoteExecCall ["spawn", 0];
};

DTV_var_serverInitDone = true;
publicVariable "DTV_var_serverInitDone";
