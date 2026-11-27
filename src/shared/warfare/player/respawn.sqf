// Respawn: death, respawn positions and map, parachute jumps (client, respawn handling also server).

// Player: death, respawn, parachute jumps, spectating, stamina, vision modes, camera view,
// map and GPS panel (client, parachute jumps and respawn handling also server).

// ---- respawn ----

SC_fnc_onKilled = {
    // start of the respawn delay, for the spectator's "RESPAWN HERE" (SC_fnc_respawnWaitTime)
    SC_var_deathTime = time;

    if SC_var_viewSwitchable then {
        terminate SC_var_cameraViewLoop;
    };

    // the kill cam (killfeed) first, with sound; it opens the held respawn menu (map) at its end
    if (!isNil "KF_fnc_waitUntilKillCamDone") then {
        call KF_fnc_waitUntilKillCamDone;
    };

    3 fadeSound 0;
    waitUntil {visibleMap};
    saveProfileNamespace;
    [false] call KF_fnc_EnableMidFeed;
    [] spawn SC_fnc_respawnMapDisplay;
    MM_var_showAliveGroupUnits = false;
    call MM_fnc_updateDrawArrayImmediate;
    waitUntil {alive player};
    [SC_var_hudEnabled] call KF_fnc_EnableMidFeed;
};

SC_fnc_onRespawn = {
    if (SC_var_hudEnabled && !SC_var_hudShown) then {
        [SC_var_hudEnabled] call SC_fnc_setHud;
    };

    MM_var_showAliveGroupUnits = true;
    cutText ["", "BLACK IN", 1];

    if SC_var_viewSwitchable then {
        SC_var_cameraViewLoop = [SC_var_lastView] spawn SC_fnc_cameraViewLoop;
    };

    // always: a fade out still running (death, spectator) would otherwise end muted; to the volume of the earplugs
    // that are in (earplugs mod)
    1 fadeSound (call (missionNamespace getVariable ["E_fnc_effectiveVolume", {1}]));

    [SC_var_lastLoadout] call SC_fnc_setLoadout;

    // "RESPAWN HERE" of the spectator: at the spectated group member instead of the position chosen in the respawn
    // menu, like his respawn position there (a free seat in his vehicle, else next to him); after the menu moved the
    // player, during the fade in
    private _respawnTarget = missionNamespace getVariable ["SC_var_respawnTarget", objNull];
    SC_var_respawnTarget = objNull;

    if ([_respawnTarget] call SC_fnc_canRespawnAt) then {
        sleep 0.3;
        [_respawnTarget] call SC_fnc_moveToRespawnTarget;
    };

    // respawned at a spawn vehicle (SC\vehicles\spawnVehicles.sqf): from the driver's seat to a free cargo seat
    [] spawn SC_fnc_seatAtSpawnVehicle;

    if SC_var_nvGogglesEnabled then {
        player action ["nvGoggles", player];
    };

    if (((getPosATL player) select 2) > 1500) then {
        [player] spawn SC_fnc_zoneParachuteJump;
    } else {
        private _baseMarker = "SC_var_" + (toLower (str (side (group player)))) + "Respawn";
        private _baseMarkerPos = getMarkerPos _baseMarker;
        [player, false] call ADG_fnc_allowDamage;

        if ((player distance _baseMarkerPos) < 8) then {
            player setDir (markerDir _baseMarker);
            waitUntil {((player distance _baseMarkerPos) > 8) || {!(alive player)}};
            [player, true] call ADG_fnc_allowDamage;

            if (simulationEnabled player) then {
                ["spawnprotectiondisabled"] call SC_fnc_showNotificationIfHudIsEnabled;
            };
        } else {
            sleep 4;

            if (alive player) then {
                [player, true] call ADG_fnc_allowDamage;
            };
        };
    };
};

// The SPECTATE button (and its panel) appear in the middle of the fade in to the respawn map (user 2026-11-26): after
// the kill cam the killfeed fades in (KF_var_menuFadeInHalfAt); without it the vanilla respawn menu blacks out and in
// (a3\functions_f\Respawn: respawn delay > 5 s: black out after 3 s, black in at 4 s for 1 s; > 2 s: after 0.5 s,
// black in at 1.5 s), so the middle is 4.5 s / 2 s after the menu opened. The vanilla menu does that only while the
// dead player is simulated: not after the base "Teleport" (SC_fnc_teleportToPlayZone disables the old unit's
// simulation), which shows them at once, as does a menu opened again later (back from the spectator).
SC_fnc_showRespawnMapButtonsDelayed = {
    params ["_display"];

    private _controls = [1000, 1600] apply {_display displayCtrl _x};
    private _deathTime = missionNamespace getVariable ["SC_var_deathTime", -1];
    private _firstMenu = (missionNamespace getVariable ["SC_var_respawnMenuDeath", -2]) != _deathTime;
    private _killCamHalf = missionNamespace getVariable ["KF_var_menuFadeInHalfAt", -1];
    // the conditions of the vanilla black out (a3\functions_f\Respawn, the menu's "open")
    private _vanillaBlackOut = (isNil {uiNamespace getVariable "BIS_RscRespawnControls_skipBlackOut"}) && {simulationEnabled player};
    SC_var_respawnMenuDeath = _deathTime;

    private _showAt = switch (true) do {
        case (!_firstMenu): {time};
        case (_killCamHalf > _deathTime): {_killCamHalf};
        case (_vanillaBlackOut && {playerRespawnTime > 5}): {time + 4.5};
        case (_vanillaBlackOut && {playerRespawnTime > 2}): {time + 2};
        default {time};
    };

    if (time >= _showAt) exitWith {};

    {_x ctrlShow false} forEach _controls;
    waitUntil {time >= _showAt || {isNull _display}};
    {_x ctrlShow true} forEach _controls;
};

SC_fnc_respawnMapDisplay = {
    waitUntil {
        call {
            private _respawnMapDisplay = uiNamespace getVariable ["SC_var_respawnMapDisplay", displayNull];
            private _spectatorActive = !(isNull (uiNamespace getVariable ["SC_var_spectatorDisplay", displayNull]));
            private _respawnMapDisplayActive = !(isNull _respawnMapDisplay);
            private _escMenuActive = !(isNull (findDisplay 49));
            private _roundEnded = missionNamespace getVariable ["SC_var_roundEnded", false];
            private _shouldDrawRespawnMapDisplay = !(alive player) && {!_spectatorActive} && {!_escMenuActive} && {!_roundEnded};

            if (_respawnMapDisplayActive != _shouldDrawRespawnMapDisplay) then {
                if _shouldDrawRespawnMapDisplay then {
                    [(findDisplay 46) createDisplay "respawnMapDisplay"] spawn SC_fnc_showRespawnMapButtonsDelayed;
                } else {
                    _respawnMapDisplay closeDisplay 1;
                };
            };

            (alive player) || {_roundEnded}
        }
    };
};

SC_fnc_groupRespawnAllowed = {true};
SC_fnc_respawnPositionsLoop = {
    waitUntil {
        call {
            {
                _x params ["_unit"];

                if((alive _unit) && {!(_unit getVariable ["ais_unconscious", false])} &&
                    {simulationEnabled _unit} && {[_unit] call SC_fnc_groupRespawnAllowed} &&
                    {!(_unit in (SC_var_groupResArr apply {_x select 0}))}) then {
                    ([player, _unit, (_unit getVariable "SC_var_name")] call BIS_fnc_addRespawnPosition) params ["", "_resID"];
                    SC_var_groupResArr pushBack [_unit, _resId];
                };
            } forEach (([player] call SC_fnc_getGroupUnits) - [player]);
        };

        sleep 0.5;

        call {
            private _groupUnits = [player] call SC_fnc_getGroupUnits;

            {
                _x params ["_unit", "_resId"];

                if(!(alive _unit) || {_unit getVariable ["ais_unconscious", false]} ||
                    {!(simulationEnabled _unit)} || {!([_unit] call SC_fnc_groupRespawnAllowed)} ||
                    {!(_unit in _groupUnits)}) then {
                    [player, _resId] call BIS_fnc_removeRespawnPosition;
                };
            } forEach SC_var_groupResArr;

            SC_var_groupResArr = SC_var_groupResArr select {(alive (_x select 0)) &&
                {!((_x select 0) getVariable ["ais_unconscious", false])} &&
                {simulationEnabled (_x select 0)} && {[_x select 0] call SC_fnc_groupRespawnAllowed} &&
                {(_x select 0) in _groupUnits}};
        };

        sleep 0.5;
        false
    };
};

// base "Teleport" action: respawn and choose a new spawn position, the old body is hidden
SC_fnc_teleportToPlayZone = {
    private _oldUnit = player;
    0 fadeSound 0;
    forceRespawn _oldUnit;
    [_oldUnit, true] remoteExecCall ["hideObjectGlobal", 2];
    [_oldUnit, false] remoteExecCall ["enableSimulationGlobal", 2];
    _oldUnit setPos (((getMarkerPos "SC_var_playZone") select [0, 2]) + [100]);
    setPlayerRespawnTime 0.1;
    [] spawn SC_fnc_onKilled;
    waitUntil {alive player};
    setPlayerRespawnTime (getMissionConfigValue ["respawnDelay", 10]);
    [player, true] remoteExecCall ["enableSimulationGlobal", 2];
};

SC_fnc_entityRespawned = {
    params ["_newEntity", "_oldEntity"];

    [_oldEntity, _newEntity] call SC_fnc_updateGroupAfterRespawn;

    if (_newEntity isKindOf "CAManBase") then {
        if (isPlayer _newEntity) then {
            _newEntity setVariable ["SC_var_timeRemaining", SC_var_unitDespawnTime];
            [_newEntity] call SC_fnc_registerEntityServer;

            private _parEntity = objectParent _newEntity;

            if !(isNull _parEntity) then {
                private _playerGroupMatesInVehicle =(([_newEntity] call SC_fnc_getGroupUnits) -[_newEntity])
                    select {(alive _x) && {isPlayer _x} && {(objectParent _x) isEqualTo _parEntity}};

                if (_playerGroupMatesInVehicle isNotEqualTo []) then {
                    ["groupMateSpawned",
                        [(_newEntity getVariable "SC_var_name"),
                        ("in your " +([(typeOf _parEntity)] call SC_fnc_getDisplayName))],
                        _playerGroupMatesInVehicle] call SC_fnc_notifyPlayers;
                };
            } else {
                private _possibleGroupUnits = (([_newEntity] call SC_fnc_getGroupUnits) - [_newEntity]) select {alive _x};

                if (_possibleGroupUnits isNotEqualTo []) then {
                    private _possibleMarkers = (SC_var_sectors apply {"SC_var_sector" + _x}) + ["SC_var_" + (toLower (str (side (group _newEntity)))) + "Respawn"];
                    private _closestMarkerPos = [(_possibleMarkers apply {getMarkerPos _x}), _newEntity] call BIS_fnc_nearestPosition;
                    private _closestGroupUnit = [_possibleGroupUnits, _newEntity] call BIS_fnc_nearestPosition;

                    if((isPlayer _closestGroupUnit) &&
                        {(_newEntity distance _closestGroupUnit) <(_newEntity distance _closestMarkerPos)}) then
                        {
                        ["groupMateSpawned", [(_newEntity getVariable "SC_var_name"), "on your position"]] remoteExec ["BIS_fnc_showNotification", _closestGroupUnit];
                    };
                };
            };
        } else {
            // the slot of a player who disconnected while dead respawns as AI with the player's identity
            if (isNil {_newEntity getVariable "SC_var_unitId"}) then {
                [_newEntity, side (group _newEntity), SC_var_nextAiUnitId,
                    ([_newEntity] call SC_fnc_getRandomAiNameArr)] call SC_fnc_initPoolAi;
                SC_var_nextAiUnitId = SC_var_nextAiUnitId + 1;
            };

            [_newEntity] call SC_fnc_suspendUnit;
        };
    };
};

SC_fnc_zoneParachuteJump = {
    params ["_unit"];

    private _pos = [];
    private _side = side (group _unit);
    private _enemySides = SC_var_sides - [_side];
    private _enemySidesBaseMarkers = _enemySides apply {"SC_var_" + (str _x) + "Base"};
    private _enemySidesSectorMarkers = SC_var_sectors select {(missionNamespace getVariable ("SC_var_holder" + _x)) != _side};

    waitUntil {
        _pos = if SC_var_hugeMap then {
            "SC_var_playZone" call BIS_fnc_randomPosTrigger
        } else {
            [
                SC_var_playZoneMiddle,
                (
                    ((markerSize "SC_var_playZone") apply {0.3 * _x}) +
                    [
                        (markerDir "SC_var_playZone"),
                        ((markerShape "SC_var_playZone") isEqualTo "RECTANGLE")
                    ]
                )
            ] call BIS_fnc_randomPosTrigger
        };

        !(surfaceIsWater _pos) &&
        {(
            (_enemySidesBaseMarkers + ([[], _enemySidesSectorMarkers] select SC_var_hugeMap)) findIf
            {(_pos distance (getMarkerPos _x)) < (1.2 * (selectMax (getMarkerSize _x)))}
        ) == -1}
    };

    _unit setPos (_pos vectorAdd [0, 0, SC_var_parachuteJumpHeight]);
    [_unit] spawn SC_fnc_parachuteJump;
};

SC_fnc_heliParachuteJump = {
    params ["_unit"];

    private _heli = objectParent _unit;
    private _posAslHeli = getPosASL _heli;
    _posAslHeli set [2, (_posAslHeli select 2) - 3];
    _unit setPosASL _posAslHeli;
    [_unit, _heli] spawn SC_fnc_parachuteJump;
};

// the unit's backpack is swapped for a parachute and restored from its loadout data (keeps partially used magazines
// and weapons with attachments) once the parachute is open; a unit that dies on the way down keeps the parachute
SC_fnc_parachuteJump = {
    params ["_unit", ["_heli", objNull]];

    _unit switchMove "AfalPpneMstpSnonWnonDnon";
    _unit setDir (random 360);
    private _backpackLoadout = (getUnitLoadout _unit) select 5;
    removeBackpack _unit;
    _unit addBackpackGlobal "B_Parachute";

    if !(isNull _heli) then {
        _unit setVelocity (velocity _heli);
    };

    sleep 1;
    waitUntil {sleep 0.5; !(alive _unit) || {((getPos _unit) select 2) <= 100}};

    if !(alive _unit) exitWith {};

    _unit action ["OpenParachute", _unit];
    waitUntil {sleep 0.2; !(alive _unit) || {isNull (unitBackpack _unit)}};

    if (!(alive _unit) || {_backpackLoadout isEqualTo []}) exitWith {};

    private _loadout = getUnitLoadout _unit;
    _loadout set [5, _backpackLoadout];
    _unit setUnitLoadout _loadout;
};

// ---- recovery (alt-tab robustness) ----

/*
    Client, for the whole mission. Death, kill cam, unconscious view, spectator and respawn map black the screen out,
    mute the sound and hide HUD parts in a chain of fades and waits; when the game window lost the focus meanwhile
    (alt-tab), a step of that chain could be missed and the player was left with a black screen, no sound or a broken
    HUD after the respawn (user). So whenever the player has been plainly playing (alive, conscious, his own view, no kill
    cam, spectator or round end) or plainly at the respawn map for SC_var_recoveryDelay seconds in a row, everything
    that should be off is turned off once: the black layers, the spectator's night vision, a wrong volume, a lost HUD.
*/
SC_var_recoveryDelay = 3;
SC_var_recoveryBlackLayers = ["KF_killCamOutro", "KF_deathTransition", "KF_killCamFade"];   // named layers of the killfeed

// 0: in a transition (death, kill cam, unconscious view, spectator, round end, thermal blackout), 1: playing, 2: at the
// respawn map
SC_fnc_recoveryState = {
    switch true do {
        case (missionNamespace getVariable ["SC_var_roundEnded", false]): {0};
        case (missionNamespace getVariable ["KF_var_killCamActive", false]): {0};
        case (!isNull (uiNamespace getVariable ["SC_var_spectatorDisplay", displayNull])): {0};
        case (alive player): {
            [0, 1] select (
                !(player getVariable ["AIS_unconscious", false]) &&
                {focusOn isEqualTo player} &&
                {(currentVisionMode player) != 2}
            )
        };
        case (visibleMap || {!isNull (uiNamespace getVariable ["SC_var_respawnMapDisplay", displayNull])}): {2};
        default {0};
    }
};

SC_fnc_recover = {
    params ["_state"];

    // the black screens of SC (default layer), AIS (title layer) and the killfeed (named layers)
    cutText ["", "PLAIN", 0, false, false];
    titleCut ["", "PLAIN", 0];

    {
        (_x call BIS_fnc_rscLayer) cutText ["", "PLAIN", 0, true];
    } forEach SC_var_recoveryBlackLayers;

    if (_state != 1) exitWith {};

    [false] call SC_fnc_setSpectatorNightVision;

    private _volume = call (missionNamespace getVariable ["E_fnc_effectiveVolume", {1}]);

    if ((abs (soundVolume - _volume)) > 0.05) then {
        1 fadeSound _volume;
    };

    // a HUD display that got lost while its loops still run: closed state, so SC_fnc_setHud opens it again
    if (SC_var_hudDisplayIsOpen && {isNull (uiNamespace getVariable ["SC_var_sectorControlDisplay", displayNull])}) then {
        SC_var_hudDisplayIsOpen = false;

        {
            terminate (missionNamespace getVariable [_x, scriptNull]);
            missionNamespace setVariable [_x, scriptNull];
        } forEach ["SC_var_hudUpdateSectorOverviewLoopScript", "SC_var_hudUpdateGroupOverviewLoopScript", "SC_var_hudUpdatePlayerStatsLoopScript"];
    };

    // the HUD as the settings want it, also showHUD (the unconscious view turns parts of it off)
    [
        SC_var_hudEnabled ||
        {SC_var_alwaysShowHudOnMap && visibleMap} ||
        {SC_var_alwaysShowHudWhenUnconscious && (player getVariable ["AIS_unconscious", false])}
    ] call SC_fnc_setHud;
};

SC_fnc_recoveryLoop = {
    private _state = 0;
    private _since = time;
    private _recovered = false;

    waitUntil {
        private _newState = call SC_fnc_recoveryState;

        if (_newState != _state) then {
            _state = _newState;
            _since = time;
            _recovered = false;
        };

        if (_state != 0 && {!_recovered} && {(time - _since) >= SC_var_recoveryDelay}) then {
            _recovered = true;
            [_state] call SC_fnc_recover;
        };

        sleep 0.5;
        false
    };
};
