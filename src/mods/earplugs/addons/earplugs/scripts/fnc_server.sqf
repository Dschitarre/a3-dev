// Earplugs (server): the default settings of the players; starts / stops the earplugs on every client, including JIP.

E_var_remoteExecId = "";

// defaults for players without settings of their own (the clients keep theirs in profileNamespace E_var_settings):
// [volume with the earplugs in (F1), automatic earplugs in [ground vehicles, aircraft, boats] on, their volumes].
// Missions may set it before the mod loads; the Eden module sets it from its attributes.
if (isNil "E_var_defaultSettings") then {
    E_var_defaultSettings = [0.3, [true, true, true], [0.5, 0.3, 0.5]];
};

publicVariable "E_var_defaultSettings";

E_fnc_startEarplugsServer = {
    if (!isMultiplayer) exitWith {
        call E_fnc_startEarplugsClient;
    };

    if (E_var_remoteExecId != "") exitWith {};

    E_var_remoteExecId = [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "E_var_clientInitDone"};
        call E_fnc_startEarplugsClient;
    }] remoteExecCall ["spawn", 0, true];
};

E_fnc_stopEarplugsServer = {
    if (!isMultiplayer) exitWith {
        call E_fnc_stopEarplugsClient;
    };

    if (E_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", E_var_remoteExecId];
    E_var_remoteExecId = "";

    [[], {
        if (!hasInterface) exitWith {};
        waitUntil {!isNil "E_var_clientInitDone"};
        call E_fnc_stopEarplugsClient;
    }] remoteExecCall ["spawn", 0];
};

E_var_serverInitDone = true;
publicVariable "E_var_serverInitDone";
