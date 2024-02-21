J_var_remoteExecId = "";

J_var_JumpSpeed = 1;
publicVariable "J_var_JumpSpeed";

J_fnc_startJumpServer = {
    call {
        if !isMultiplayer then {
            call J_fnc_startJumpClient;
        } else {
            if (J_var_remoteExecId == "") then {
                J_var_remoteExecId = [[], {if hasInterface then {waitUntil {!(isNil "J_var_clientInitDone")}; call J_fnc_startJumpClient;};}] remoteExecCall ["spawn", 0, true];
            };
        };
    };
};

J_fnc_stopJumpServer = {
    call {
        if !isMultiplayer then {
            call J_fnc_stopJumpClient;
        } else {
            if (J_var_remoteExecId != "") then {
                remoteExecCall ["", J_var_remoteExecId];
                J_var_remoteExecId = "";

                [[], {if hasInterface then {waitUntil {!(isNil "J_var_clientInitDone")}; call J_fnc_stopJumpClient;};}] remoteExecCall ["spawn", 0];
            };
        };
    };
};

J_var_serverInitDone = true;
publicVariable "J_var_serverInitDone";