// Spectator: spectating teammates while dead, camera / night vision / map sync (client).

// ---- spectator ----

// a group member the player can respawn at (the same rule as his respawn position in the respawn menu,
// SC_fnc_respawnPositionsLoop)
SC_fnc_canRespawnAt = {
    params ["_unit"];

    (alive _unit) &&
    {_unit isNotEqualTo player} &&
    {simulationEnabled _unit} &&
    {!(_unit getVariable ["ais_unconscious", false])} &&
    {_unit in ([player] call SC_fnc_getGroupUnits)} &&
    {[_unit] call SC_fnc_hasRespawnRoom} &&
    {[_unit] call SC_fnc_isSafeSpawnTarget}
};

// a unit on foot or in a vehicle with a free seat; in a full vehicle only on the ground (the player appears next to it)
SC_fnc_hasRespawnRoom = {
    params ["_unit"];

    private _vehicle = objectParent _unit;

    (isNull _vehicle) ||
    {((fullCrew [_vehicle, "", true]) findIf {isNull (_x select 0)}) != -1} ||
    {(isTouchingGround _vehicle) && {(speed _vehicle) < 5}}
};

// after a respawn at a group member ("RESPAWN HERE", the respawn menu moved the player already): into his vehicle,
// else next to him; nothing when the player is already there (a second move threw him out of the vehicle)
SC_fnc_moveToRespawnTarget = {
    params ["_target"];

    private _vehicle = objectParent _target;

    if (!(isNull _vehicle) && {(objectParent player) isEqualTo _vehicle}) exitWith {};
    if ((isNull _vehicle) && {(player distance _target) < 15}) exitWith {};

    if (!(isNull _vehicle) && {player moveInAny _vehicle}) exitWith {};

    player setVehiclePosition [(getPosATL _target), [], 3, "NONE"];
};

// seconds until the respawn delay since the death is over
SC_fnc_respawnWaitTime = {
    0 max ((getMissionConfigValue ["respawnDelay", 10]) - (time - (missionNamespace getVariable ["SC_var_deathTime", -1e6])))
};

// spectator button: respawn at the spectated group member at once. The vanilla respawn menu (MenuPosition template)
// holds the player until its own respawn button is pressed (it keeps raising playerRespawnTime), so this closes the
// spectator, selects the member's entry in the menu's position list and does what that button does; SC_fnc_onRespawn
// then puts the player into the member's vehicle or next to him
SC_fnc_respawnHere = {
    private _target = focusOn;

    if (!([_target] call SC_fnc_canRespawnAt) || {(call SC_fnc_respawnWaitTime) > 0}) exitWith {};

    SC_var_respawnTarget = _target;
    (uiNamespace getVariable ["SC_var_spectatorDisplay", displayNull]) closeDisplay 1;

    [_target] spawn {
        params ["_target"];

        private _timeout = time + 3;
        private _button = controlNull;

        // the menu's controls are shown again on the map once the spectator has closed
        waitUntil {
            _button = uiNamespace getVariable ["BIS_RscRespawnControlsMap_ctrlHeaderRespawnButton", controlNull];

            (alive player) ||
            {time > _timeout} ||
            {(missionNamespace getVariable ["BIS_RscRespawnControlsMap_shown", false]) && {!isNull _button} && {ctrlEnabled _button}}
        };

        if ((alive player) || {isNull _button} || {!ctrlEnabled _button}) exitWith {};

        private _list = uiNamespace getVariable ["BIS_RscRespawnControlsMap_ctrlLocList", controlNull];

        for "_i" from 0 to ((lbSize _list) - 1) do {
            private _metadata = ["get", _i] call BIS_fnc_showRespawnMenuPositionMetadata;

            if (((_metadata param [0, []]) param [0, objNull]) isEqualTo _target) exitWith {
                _list lbSetCurSel _i;
            };
        };

        // the button's "ButtonDown" handler (a3\ui_f\scripts\GUI\RscRespawnControls.sqf); ctrlActivate would only fire
        // "ButtonClick", which the menu doesn't use
        uiNamespace setVariable ["BIS_RscRespawnControls_selected", [
            lbCurSel _list,
            lbCurSel (uiNamespace getVariable ["BIS_RscRespawnControlsMap_ctrlRoleList", controlNull]),
            lbCurSel (uiNamespace getVariable ["BIS_RscRespawnControlsMap_ctrlComboLoadout", controlNull])
        ]];

        if ((lbCurSel _list) >= 0) then {
            setPlayerRespawnTime 0;
        };
    };
};

// "RESPAWN HERE (7)" while the respawn delay runs, disabled while the spectated unit is no respawn position: "IN COMBAT"
// when that is because it is under fire or enemies are near (SC_fnc_isSafeSpawnTarget)
SC_fnc_updateRespawnHereButton = {
    params ["_display"];

    private _button = _display displayCtrl 1601;
    private _waitTime = ceil (call SC_fnc_respawnWaitTime);
    private _enabled = (_waitTime <= 0) && {[focusOn] call SC_fnc_canRespawnAt};
    private _inCombat = !_enabled && {alive focusOn} && {focusOn in ([player] call SC_fnc_getGroupUnits)} &&
        {!([focusOn] call SC_fnc_isSafeSpawnTarget)};
    private _text = switch (true) do {
        case _inCombat: {"IN COMBAT"};
        case (_waitTime > 0): {format ["RESPAWN HERE (%1)", _waitTime]};
        default {"RESPAWN HERE"};
    };

    if ((ctrlText _button) != _text) then {
        _button ctrlSetText _text;
    };

    if ((ctrlEnabled _button) != _enabled) then {
        _button ctrlEnable _enabled;
    };
};

// The vanilla damage feedback (a3\functions_f\Feedback\fn_feedbackMain.fsm) blurs and greys the screen when the player
// dies or goes unconscious (BIS_DeathBlur, ... - the death blur stays until the respawn); seen after tabbing back in
// while spectating. The spectator view stays clear: only effects that are on are switched off (the handle of a
// destroyed effect can belong to a newer effect by now), never the spectator's own night vision.
SC_var_vanillaFeedbackEffects = [
    "BIS_DeathBlur", "BIS_DeathRadialBlur", "BIS_DeathCC", "BIS_UncBlur", "BIS_UncRadialBlur", "BIS_UncCC",
    "BIS_TotDesatCC", "BIS_fnc_feedback_damageBlur", "BIS_fnc_feedback_damageCC", "BIS_SuffBlur", "BIS_SuffCC",
    "BIS_BleedCC", "BIS_HitCC", "BIS_BurnCC", "BIS_fnc_feedback_fatigueBlur", "BIS_fnc_feedback_fatigueCC"
];

SC_fnc_clearVanillaFeedbackEffects = {
    private _own = missionNamespace getVariable ["SC_var_spectatorNvEffects", []];

    {
        private _handle = missionNamespace getVariable [_x, -1];

        if ((_handle isEqualType 0) && {_handle >= 0} && {!(_handle in _own)} && {ppEffectEnabled _handle}) then {
            _handle ppEffectEnable false;
        };
    } forEach SC_var_vanillaFeedbackEffects;
};

SC_fnc_spectate = {
    private _respawnMapDisplay = uiNamespace getVariable ["SC_var_respawnMapDisplay", displayNull];

    if !(isNull _respawnMapDisplay) then {
        _respawnMapDisplay closeDisplay 1;
    };

    (findDisplay 46) createDisplay "spectatorDisplay";
    waitUntil {!(isNull (uiNamespace getVariable ["SC_var_spectatorDisplay", displayNull]))};
    private _spectatorDisplay = uiNamespace getVariable ["SC_var_spectatorDisplay", displayNull];
    _spectatorDisplay displayAddEventHandler ["KeyDown", {_this call SC_fnc_spectatorKeyDown}];
    [SC_var_nvGogglesEnabled] call SC_fnc_setSpectatorNightVision;
    openMap false;
    private _oldDeathFeedState = KF_var_clientDeathFeedVisible;
    [false] call KF_fnc_EnableDeathFeed;
    private _combo = _spectatorDisplay displayCtrl 2100;
    private _oldAvailableUnits = [];
    TDI_var_drawUnitsOnSpectator = true;
    cutText ["", "BLACK FADED", 99999999];
    0 fadeSound 0;
    private _fadedBlack = true;
    private _nextFeedbackClear = 0;

    waitUntil {
        if (time >= _nextFeedbackClear) then {
            _nextFeedbackClear = time + 0.5;
            call SC_fnc_clearVanillaFeedbackEffects;
        };

        private _availableUnits = ((player getVariable ["SC_var_groupUnits", []]) - [player]) select {
            (alive _x) && {simulationEnabled _x} && {!(_x getVariable ["ais_unconscious", false])}
        };

        if (_availableUnits isNotEqualTo _oldAvailableUnits) then {
            lbClear _combo;

            {
                _combo lbAdd (_x getVariable ["SC_var_name", (name _x)]);
            } forEach _availableUnits;

            private _newSelectedIndex = _availableUnits findIf {_x isEqualTo focusOn};

            if (_newSelectedIndex == -1) then {
                _newSelectedIndex = 0;
            };

            _combo lbSetCurSel _newSelectedIndex;
            _oldAvailableUnits = +_availableUnits;
        };

        private _selectedIndex = lbCurSel _combo;
        private _viewedIndex = _availableUnits findIf {_x isEqualTo focusOn};

        if (_selectedIndex != _viewedIndex) then {
            private _newSelectedUnit = _availableUnits select _selectedIndex;
            _newSelectedUnit switchCamera (focusOn getVariable ["SC_var_cameraView", "EXTERNAL"]);
            call MM_fnc_updateDrawArrayImmediate;
        };

        if (cameraView != (focusOn getVariable ["SC_var_cameraView", "EXTERNAL"])) then {
            focusOn switchCamera (focusOn getVariable ["SC_var_cameraView", "EXTERNAL"]);
            call MM_fnc_updateDrawArrayImmediate;
        };

        if (!(alive focusOn) != _fadedBlack) then {
            // with the earplugs that are in (earplugs mod)
            if _fadedBlack then {
                cutText ["", "PLAIN", 0, false, false];
                1 fadeSound (call (missionNamespace getVariable ["E_fnc_effectiveVolume", {1}]));
            } else {
                cutText ["", "BLACK FADED", 9999999, false, false];
                0 fadeSound 0;
            };

            _fadedBlack = !_fadedBlack;
        };

        if !(isNull _spectatorDisplay) then {
            [_spectatorDisplay] call SC_fnc_updateRespawnHereButton;
        };

        (isNull _spectatorDisplay)
    };

    [false] call SC_fnc_setSpectatorNightVision;
    player switchCamera SC_var_lastView;
    TDI_var_drawUnitsOnSpectator = false;
    [_oldDeathFeedState] call KF_fnc_EnableDeathFeed;

    // back to the respawn menu (map, muted); not if the player respawned meanwhile ("RESPAWN HERE"), that muted him
    if !(alive player) then {
        openMap true;
        cutText ["", "PLAIN", 0, false, false];
        0 fadeSound 0;
    };
};

// the camera view is read by spectators of this unit, it is only broadcast when it changes. Only first or third
// person: the optics view ("GUNNER") would show spectators the magnified view without the optics overlay, so it keeps
// the view from before aiming; the commander view ("GROUP") counts as third person.
SC_fnc_broadcastCameraViewLoop = {
    private _lastUnit = objNull;
    private _lastView = "";

    waitUntil {
        private _view = switch (cameraView) do {
            case "INTERNAL": {"INTERNAL"};
            case "GUNNER": {["INTERNAL", _lastView] select (_lastView != "")};
            default {"EXTERNAL"};
        };

        if ((alive player) && {!((player isEqualTo _lastUnit) && {_view == _lastView})}) then {
            _lastUnit = player;
            _lastView = _view;
            player setVariable ["SC_var_cameraView", _lastView, true];
        };

        sleep 0.3;

        false
    };
};

// night vision inside the spectator (60492) or splendid camera (314) display, toggled with the night vision keys.
// The NV action on the viewed unit is only issued when the NV state or the viewed unit changes.
SC_fnc_displayNightVisionLoop = {
    params ["_idd", ["_disableTi", false]];

    waitUntil {
        waitUntil {!(isNull (findDisplay _idd))};

        (findDisplay _idd) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];

            if ((_key in (actionKeys "nightVision")) || {_key in (actionKeys "TransportNightVision")}) then {
                SC_var_nvGogglesEnabled = !SC_var_nvGogglesEnabled;
                true
            };
        }];

        private _lastState = [];

        waitUntil {
            camUseNVG SC_var_nvGogglesEnabled;

            if _disableTi then {
                {
                    false setCamUseTI _x;
                } forEach [0, 1, 2, 3, 4, 5, 6, 7];
            };

            private _state = [SC_var_nvGogglesEnabled, focusOn];

            if (_state isNotEqualTo _lastState) then {
                focusOn action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), focusOn];
                _lastState = _state;
            };

            isNull (findDisplay _idd)
        };

        player action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), player];

        false
    };
};

// night vision in the SC spectator (SC_fnc_spectate), toggled with the night vision keys like SC_var_nvGogglesEnabled.
// The view through another unit (switchCamera) has no night vision of its own and switching the spectated unit's
// goggles would change them for that unit, so it is imitated locally: a green, brighter image with film grain. The
// settings can be tuned in the debug console while it is on.
SC_var_spectatorNvAperture = 2;     // camera aperture (smaller = brighter)
SC_var_spectatorNvColor = [1, 1.2, 0, [0, 0, 0, 0], [0.2, 1, 0.2, 0], [0.299, 0.587, 0.114, 0]];   // ColorCorrections
SC_var_spectatorNvGrain = [0.1, 1, 1.5, 0.75, 1, true];                                           // FilmGrain

SC_fnc_setSpectatorNightVision = {
    params ["_enabled"];

    if (isNil "SC_var_spectatorNvEffects") then {
        SC_var_spectatorNvEffects = [ppEffectCreate ["ColorCorrections", 1577], ppEffectCreate ["FilmGrain", 2577]];
    };

    SC_var_spectatorNvEffects params ["_color", "_grain"];

    if (_enabled) then {
        _color ppEffectAdjust SC_var_spectatorNvColor;
        _grain ppEffectAdjust SC_var_spectatorNvGrain;
        setAperture SC_var_spectatorNvAperture;
    } else {
        setAperture -1;
    };

    {
        _x ppEffectCommit 0;
        _x ppEffectEnable _enabled;
    } forEach [_color, _grain];
};

SC_fnc_spectatorKeyDown = {
    params ["", "_key"];

    if ((_key in (actionKeys "nightVision")) || {_key in (actionKeys "TransportNightVision")}) exitWith {
        SC_var_nvGogglesEnabled = !SC_var_nvGogglesEnabled;
        [SC_var_nvGogglesEnabled] call SC_fnc_setSpectatorNightVision;
        true
    };

    false
};

SC_fnc_spectatorNightVisionLoop = {
    [60492] call SC_fnc_displayNightVisionLoop;
};

SC_fnc_cameraNightVisionLoop = {
    [314, true] call SC_fnc_displayNightVisionLoop;
};

// keeps SC_var_mapScale / SC_var_mapPosition in sync with a map control of a display while it is open. The EG spectator
// map (60492) and the camera map (314) show all sides: the mapmarker mod draws there the spawn vehicles of every side in
// its color, also empty ones (SC\vehicles\spawnVehicles.sqf).
SC_fnc_syncDisplayMap = {
    params ["_idd", "_idc", "_scaleFactor", "_isMapActive"];

    waitUntil {
        waitUntil {(isNull (findDisplay _idd)) || {((findDisplay _idd) displayCtrl _idc) call _isMapActive}};
        if (isNull (findDisplay _idd)) exitWith {true};

        private _ctrlMap = (findDisplay _idd) displayCtrl _idc;
        _ctrlMap ctrlMapAnimAdd [0, _scaleFactor * SC_var_mapScale, SC_var_mapPosition];
        ctrlMapAnimCommit _ctrlMap;

        waitUntil {
            if (_ctrlMap call _isMapActive) then {
                SC_var_mapScale = (ctrlMapScale _ctrlMap) / _scaleFactor;
                SC_var_mapPosition = _ctrlMap ctrlMapScreenToWorld [0.5, 0.5];
                false
            } else {
                true
            }
        };

        (isNull (findDisplay _idd))
    };
};

SC_fnc_spectatorMapDrawEHLoop = {
    waitUntil {
        waitUntil {!(isNull (findDisplay 60492))};

        [60492, 62609, 1.95, {ctrlShown _this}] call SC_fnc_syncDisplayMap;

        false
    };
};

SC_fnc_cameraMapDrawEHLoop = {
    waitUntil {
        waitUntil {!(isNull (findDisplay 314))};
        private _pos = ((findDisplay 314) displayCtrl 3141) ctrlMapScreenToWorld [0.5, 0.5];
        waitUntil {(isNull (findDisplay 314)) ||
            {((((findDisplay 314) displayCtrl 3141) ctrlMapScreenToWorld [0.5,
            0.5]) isNotEqualTo _pos)}};

        [314, 3141, 1.2, {ctrlEnabled _this}] call SC_fnc_syncDisplayMap;

        false
    };
};
