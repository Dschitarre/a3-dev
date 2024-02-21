E_var_remoteExecId = "";

E_var_volumeMuted = 0.3;
publicVariable "E_var_volumeMuted";

E_fnc_startEarplugsServer = {
    call {
        if !isMultiplayer then {
            call E_fnc_startEarplugsClient;
        } else {
            if (E_var_remoteExecId == "") then {
                E_var_remoteExecId = [[], {if hasInterface then {waitUntil {!(isNil "E_var_clientInitDone")}; call E_fnc_startEarplugsClient;};}] remoteExecCall ["spawn", 0, true];
            };
        };
    };
};

E_fnc_stopEarplugsServer = {
    call {
        if !isMultiplayer then {
            call E_fnc_stopEarplugsClient;
        } else {
            if (E_var_remoteExecId != "") then {
                remoteExecCall ["", E_var_remoteExecId];
                E_var_remoteExecId = "";

                [[], {if hasInterface then {waitUntil {!(isNil "E_var_clientInitDone")}; call E_fnc_stopEarplugsClient;};}] remoteExecCall ["spawn", 0];
            };
        };
    };
};

E_var_serverInitDone = true;
publicVariable "E_var_serverInitDone";