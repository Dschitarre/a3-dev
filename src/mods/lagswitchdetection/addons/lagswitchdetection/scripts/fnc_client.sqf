[] spawn {
    waitUntil {!(isNull player)};
    waitUntil {!(isNull (findDisplay 46))};

    [player] remoteExec ["LD_fnc_playerInit", 2];

    waitUntil {
        [player, ["LD_var_serverTime", serverTime]] remoteExecCall ["setVariable", 2];
        sleep 1;
        false
    };
};