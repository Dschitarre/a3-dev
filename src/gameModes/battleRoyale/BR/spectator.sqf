// Battle Royale death and spectator (client): dead is dead. A dead player watches his living team mates first (vanilla
// spectator, no free camera); once the whole team is out, everyone and the free camera.

BR_var_spectatorDelay = 3;              // seconds between death and the spectator
BR_var_spectatorFocusInterval = 0.5;

// "Killed" event handler
BR_fnc_killed = {
    if (BR_var_state!="warmup" && {!isNil "KF_fnc_markRoundEliminated"}) then {call KF_fnc_markRoundEliminated};
    setPlayerRespawnTime BR_var_noRespawnTime;
    call CMN_fnc_stopCameraViewLoop;

    [] spawn {
        sleep BR_var_spectatorDelay;

        // the kill cam (killfeed mod, its own start delay and length; Space skips it) runs first
        if (!isNil "KF_fnc_waitUntilKillCamDone") then {call KF_fnc_waitUntilKillCamDone};

        call BR_fnc_startSpectator;
    };
};

// "Respawn" event handler: only the warmup respawns (normally nobody dies there); later the new unit stays parked
BR_fnc_respawn = {
    params ["_unit"];

    if (BR_var_state == "warmup") exitWith {
        call BR_fnc_warmupSpawn;
    };

    [_unit] call BR_fnc_parkUnit;
    call BR_fnc_startSpectator;
};

BR_fnc_startSpectator = {
    call CMN_fnc_hideCenterText;
    cutText ["", "PLAIN", 0, true];
    1 fadeSound 1;

    private _teamAlive = ((call BR_fnc_myTeammates) findIf {alive _x && {_x != player}}) != -1;

    [!_teamAlive] call BR_fnc_openSpectator;

    if (_teamAlive) then {
        [] spawn BR_fnc_spectatorTeamLoop;
    };
};

BR_fnc_openSpectator = {
    params ["_freeCamera"];

    ["Terminate"] call BIS_fnc_EGSpectator;
    ["Initialize", [
        player,
        [independent],
        true,
        _freeCamera,
        _freeCamera,
        true,
        true,
        true,
        true,
        true
    ]] call BIS_fnc_EGSpectator;
};

// scheduled: keeps the spectator on the team while a team mate lives, then opens it up
BR_fnc_spectatorTeamLoop = {
    waitUntil {
        sleep BR_var_spectatorFocusInterval;

        private _mates = (call BR_fnc_myTeammates) select {alive _x && {_x != player}};

        if (_mates isEqualTo [] || {BR_var_state == "ended"}) exitWith {true};

        // the spectator display's own focus functions (RscDisplayEGSpectator)
        private _displayFunction = uiNamespace getVariable ["RscDisplayEGSpectator_script", {objNull}];
        private _focus = ["GetFocus"] call _displayFunction;

        if (!(_focus in _mates)) then {
            ["SetFocus", [_mates select 0]] call _displayFunction;
        };

        false
    };

    [true] call BR_fnc_openSpectator;
};
