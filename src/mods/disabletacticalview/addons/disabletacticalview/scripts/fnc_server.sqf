DTV_var_remoteExecId = "";

DTV_fnc_startDisableTacticalViewServer = {
    call {
        if !isMultiplayer then {
            call DTV_fnc_startDisableTacticalViewClient;
        } else {
            if (DTV_var_remoteExecId == "") then {
                DTV_var_remoteExecId = [[], {if hasInterface then {waitUntil {!(isNil "DTV_var_clientInitDone")}; call DTV_fnc_startDisableTacticalViewClient;};}] remoteExecCall ["spawn", 0, true];
            };
        };
    };
};

DTV_fnc_stopDisableTacticalViewServer = {
    call {
        if !isMultiplayer then {
            call DTV_fnc_stopDisableTacticalViewClient;
        } else {
            if (DTV_var_remoteExecId != "") then {
                remoteExecCall ["", DTV_var_remoteExecId];
                DTV_var_remoteExecId = "";

                [[], {if hasInterface then {waitUntil {!(isNil "DTV_var_clientInitDone")}; call DTV_fnc_stopDisableTacticalViewClient;};}] remoteExecCall ["spawn", 0];
            };
        };
    };
};

DTV_var_serverInitDone = true;
publicVariable "DTV_var_serverInitDone";