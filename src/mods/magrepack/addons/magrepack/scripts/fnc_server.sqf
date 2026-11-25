// Magazine repack (server): publishes the settings and starts / stops the mod on every machine, including JIP: the AI
// repack everywhere (each machine repacks its local AI units), the inventory button on every machine with an interface.

MR_var_remoteExecId = "";

// the settings of fnc_clientServer.sqf, published at every start: missions and the module set them on the server
MR_var_settings = ["MR_var_enabled", "MR_var_secondsPerRound", "MR_var_aiRepack", "MR_var_aiInterval"];

// sent to every machine; it may arrive before the machine loaded the mod's files (missions load them in parallel)
MR_fnc_startOnMachine = {
    waitUntil {!isNil "MR_var_clientServerInitDone" && {!hasInterface || {!isNil "MR_var_clientInitDone"}}};

    call MR_fnc_startAiRepack;

    if (hasInterface) then {
        call MR_fnc_startMagRepackClient;
    };
};

MR_fnc_stopOnMachine = {
    waitUntil {!isNil "MR_var_clientServerInitDone" && {!hasInterface || {!isNil "MR_var_clientInitDone"}}};

    call MR_fnc_stopAiRepack;

    if (hasInterface) then {
        call MR_fnc_stopMagRepackClient;
    };
};

// start of the mod (missions call it on the server after setting MR_var_*); calling it again publishes changed settings
MR_fnc_startMagRepackServer = {
    {
        publicVariable _x;
    } forEach MR_var_settings;

    if (!isMultiplayer) exitWith {
        [] spawn MR_fnc_startOnMachine;
    };

    if (MR_var_remoteExecId != "") exitWith {};

    MR_var_remoteExecId = [[], MR_fnc_startOnMachine] remoteExecCall ["spawn", 0, true];
};

// a running repack stops; what it already moved stays
MR_fnc_stopMagRepackServer = {
    if (!isMultiplayer) exitWith {
        [] spawn MR_fnc_stopOnMachine;
    };

    if (MR_var_remoteExecId == "") exitWith {};

    remoteExecCall ["", MR_var_remoteExecId];
    MR_var_remoteExecId = "";

    [[], MR_fnc_stopOnMachine] remoteExecCall ["spawn", 0];
};

MR_var_serverInitDone = true;
publicVariable "MR_var_serverInitDone";
