// Shared TDM/GunGame client view (CMN_): loading screen, safe names in structured text, camera / view switching,
// night vision.

// ---- client screen ----

CMN_var_centerTextLayer = 1011;     // cut layer of the centered texts (loading, "press space")
CMN_var_fontNormal = "RobotoCondensed";         // GUI_FONT_NORMAL / GUI_FONT_BOLD of ui\ui.hpp, for structured text
CMN_var_fontBold = "RobotoCondensedBold";

// a screen text (ui\ui.sqf) in the middle of the screen, stays until CMN_fnc_hideCenterText. On a block (user rule: also
// the texts on a black screen, like the loading text); _boxed false only for a text that must stand alone
CMN_fnc_showCenterText = {
    params ["_text", ["_boxed", true]];

    [
        CMN_var_centerTextLayer,
        format ["<t align='center'>%1</t>", _text],
        [safeZoneX + safeZoneW / 2, safeZoneY + safeZoneH / 2, 0.5, 0.5],
        -1,
        -1,
        _boxed
    ] call UI_fnc_showTextBlocks;
};

CMN_fnc_hideCenterText = {
    [CMN_var_centerTextLayer] call UI_fnc_hideTextBlocks;
};

// a name (or any text) for structured text: & < > as entities, so it cannot break or inject markup
CMN_fnc_escapeText = {
    params ["_text"];

    ((toArray _text) apply {
        switch (_x) do {
            case 38: {"&amp;"};
            case 60: {"&lt;"};
            case 62: {"&gt;"};
            default {toString [_x]};
        }
    }) joinString ""
};

// scheduled: black screen with "Loading" as soon as the main display exists
CMN_fnc_showLoadingScreen = {
    waitUntil {!isNull (findDisplay 46)};
    cutText ["", "BLACK FADED", 999999, true];
    ["Loading, please wait..."] call CMN_fnc_showCenterText;
};

// CMN_var_isLoading (public unit variable) is true while the player's client preloads the scene
CMN_fnc_trackPreload = {
    onPreloadStarted {player setVariable ["CMN_var_isLoading", true, true];};
    onPreloadFinished {player setVariable ["CMN_var_isLoading", false, true];};
};

// true when all variables are defined on the namespace or object
CMN_fnc_varsDefined = {
    params ["_holder", "_varNames"];

    ((_varNames apply {_holder getVariable _x}) findIf {isNil "_x"}) == -1
};

/*
    Scheduled: shows _text and waits until space is pressed or _abortCondition is true.
    Returns true if space was pressed.
*/
CMN_fnc_waitForSpaceKey = {
    params ["_text", ["_abortCondition", {false}]];

    [_text] call CMN_fnc_showCenterText;
    CMN_var_spacePressed = false;

    private _ehId = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];

        if (_key == 57) then {
            CMN_var_spacePressed = true;
        };
    }];

    waitUntil {CMN_var_spacePressed || {call _abortCondition}};
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", _ehId];
    call CMN_fnc_hideCenterText;

    CMN_var_spacePressed
};

CMN_fnc_enableGps = {
    player enableInfoPanelComponent ["right", "MinimapDisplay", true];
    player enableInfoPanelComponent ["left", "MinimapDisplay", false];
    openGPS true;
    player enableInfoPanelComponent ["left", "MinimapDisplay", true];
};

// ---- camera ----
// CMN_var_lastView remembers the last first/third person view while alive; restore it with "player switchCamera CMN_var_lastView".

// once in the client setup; _thirdPersonAllowed comes from the mode's 3rd person param
CMN_fnc_initCameraView = {
    params ["_thirdPersonAllowed"];

    CMN_var_cameraViewLoopScript = scriptNull;

    if (!_thirdPersonAllowed && {difficultyOption "thirdPersonView" == 1}) exitWith {
        CMN_var_lastView = "INTERNAL";
        [] spawn CMN_fnc_forceFirstPersonLoop;
        (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call CMN_fnc_keyDownThirdPerson}];
    };

    CMN_var_lastView = ["EXTERNAL", "INTERNAL"] select (difficultyOption "thirdPersonView" == 0);
};

CMN_fnc_keyDownThirdPerson = {
    params ["", "_key"];

    if (_key in actionKeys "personView") then {
        true
    }
};

CMN_fnc_forceFirstPersonLoop = {
    waitUntil {
        if (alive player) then {
            if (cameraView == "EXTERNAL") then {
                player switchCamera "INTERNAL";
            };
        } else {
            waitUntil {alive player};
        };

        false
    };
};

CMN_fnc_cameraViewLoop = {
    waitUntil {
        if (CMN_var_lastView isNotEqualTo cameraView && {cameraView in ["EXTERNAL", "INTERNAL"]}) then {
            CMN_var_lastView = cameraView;
        };

        false
    };
};

// (re)starts the view tracking; only one instance runs at a time
CMN_fnc_startCameraViewLoop = {
    call CMN_fnc_stopCameraViewLoop;
    CMN_var_cameraViewLoopScript = [] spawn CMN_fnc_cameraViewLoop;
};

CMN_fnc_stopCameraViewLoop = {
    if (!isNil "CMN_var_cameraViewLoopScript" && {!isNull CMN_var_cameraViewLoopScript}) then {
        terminate CMN_var_cameraViewLoopScript;
    };
};

// ---- night vision ----
// CMN_var_nvGogglesEnabled is the player's wanted NV state; it survives respawns, loadout changes and spectating.

CMN_var_spectatorNvInterval = 0.2;  // how often the NV state is re-applied to the spectated unit

CMN_fnc_isNight = {
    dayTime < 4.5 || {dayTime > 19.5}
};

// once in the client setup
CMN_fnc_initNightVision = {
    CMN_var_nvGogglesEnabled = call CMN_fnc_isNight;
    CMN_var_isInVehicleVision = false;

    player addEventHandler ["VisionModeChanged", {_this call CMN_fnc_visionModeChanged}];
};

CMN_fnc_visionModeChanged = {
    params ["", "_visionMode"];

    if !(CMN_var_isInVehicleVision && {cameraView != "GUNNER"}) then {
        CMN_var_nvGogglesEnabled = _visionMode == 1;
    };

    CMN_var_isInVehicleVision = cameraView == "GUNNER";

    if (!CMN_var_isInVehicleVision) then {
        player action [["nvGogglesOff", "nvGoggles"] select CMN_var_nvGogglesEnabled, player];
    };
};

// turns the goggles back on after spawn, loadout or weapon changes
CMN_fnc_restoreNightVision = {
    if (CMN_var_nvGogglesEnabled) then {
        player action ["nvGoggles", player];
    };
};

// keeps NV toggling working inside the EG spectator (display 60492)
CMN_fnc_spectatorNightVisionLoop = {
    waitUntil {
        waitUntil {!isNull (findDisplay 60492)};

        (findDisplay 60492) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];

            if (_key in actionKeys "nightVision" || {_key in actionKeys "TransportNightVision"}) then {
                CMN_var_nvGogglesEnabled = !CMN_var_nvGogglesEnabled;
                true
            };
        }];

        private _focus = objNull;
        private _nvState = !CMN_var_nvGogglesEnabled;
        private _nextApply = 0;

        waitUntil {
            camUseNVG CMN_var_nvGogglesEnabled;

            // the unit action is not free: on a focus or state change at once, otherwise a few times per second
            if (focusOn isNotEqualTo _focus || {CMN_var_nvGogglesEnabled isNotEqualTo _nvState} || {time >= _nextApply}) then {
                _focus = focusOn;
                _nvState = CMN_var_nvGogglesEnabled;
                _nextApply = time + CMN_var_spectatorNvInterval;
                _focus action [["nvGogglesOff", "nvGoggles"] select _nvState, _focus];
            };

            isNull (findDisplay 60492)
        };

        player action [["nvGogglesOff", "nvGoggles"] select CMN_var_nvGogglesEnabled, player];

        false
    };
};
