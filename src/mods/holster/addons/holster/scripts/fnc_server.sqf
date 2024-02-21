H_var_remoteExecId = "";

H_fnc_startHolsterServer = {
    call {
        if !isMultiplayer then {
            call H_fnc_startHolsterClient;
        } else {
            if (H_var_remoteExecId == "") then {
                H_var_remoteExecId = [[], {if hasInterface then {waitUntil {!(isNil "H_var_clientInitDone")}; call H_fnc_startHolsterClient;};}] remoteExecCall ["spawn", 0, true];
            };
        };
    };
};

H_fnc_stopHolsterServer = {
    call {
        if !isMultiplayer then {
            call H_fnc_stopHolsterClient;
        } else {
            if (H_var_remoteExecId != "") then {
                remoteExecCall ["", H_var_remoteExecId];
                H_var_remoteExecId = "";

                [[], {if hasInterface then {waitUntil {!(isNil "H_var_clientInitDone")}; call H_fnc_stopHolsterClient;};}] remoteExecCall ["spawn", 0];
            };
        };
    };
};

H_var_serverInitDone = true;
publicVariable "H_var_serverInitDone";