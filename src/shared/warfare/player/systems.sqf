// Player systems: stamina, night / thermal vision rules, camera view, map, UAV terminal and GPS panel (client).

// ---- player systems ----

// The mission's own stamina (HUD bar, STAM perk) replaces the engine's: engine stamina stays off for the player
// (AI: SC_fnc_spawnAi), so the Disable Stamina addon is not part of this mode.
SC_fnc_staminaSystemLoop = {
    waitUntil {
        waitUntil {
            if (isStaminaEnabled player) then {
                player enableStamina false;
                player enableFatigue false;
            };

            private _speed = vectorMagnitude (velocity player);
            private _holdsSprintButton = (inputAction "turbo") == 1;
            private _increase = 0;

            if (isNull (objectParent player)) then {
                if (
                    (_holdsSprintButton && {_speed > 4.3}) ||
                    {(SC_var_stamina <= 0.2) && {_speed > 3.3}} ||
                    {(SC_var_stamina <= 0.05) && {_speed > 1}}
                ) then {
                    _increase = -1;
                } else {
                    if (_speed <= 1) then {
                        _increase = 2;
                    } else {
                        if (_speed < 3.3) then {
                            _increase = 1;
                        } else {
                            if (_speed < 4.3) then {
                                _increase = 0.5;
                            };
                        };
                    };

                    _increase = _increase * (switch (stance player) do {
                        case "CROUCH": {1.2};
                        case "PRONE": {1.5};
                        default {1};
                    });
                };
            } else {
                _increase = 3;
            };

            if ("STAM" in SC_var_perks) then {
                if (_increase < 0) then {
                    _increase = 0.5 * _increase;
                } else {
                    _increase = 0.75 * _increase;
                };
            };

            SC_var_stamina = ((SC_var_stamina + (0.01 * _increase * (40 * (load player)) ^ 0.2)) max 0) min 1;
            player allowSprint (SC_var_stamina > 0.2);
            player forceWalk (SC_var_stamina <= 0.05);
            player setCustomAimCoef (if (SC_var_stamina > 0.2) then {0.3} else {0.3 + (0.7 * (1 - (SC_var_stamina / 0.2)))});

            sleep 0.5;

            !(alive player)
        };

        SC_var_stamina = 1;
        waitUntil {alive player};

        false
    };
};

SC_fnc_isNight = {
    private _offset = [4, 5.666] select (worldName == "Tanoa");

    (dayTime < _offset) || {dayTime > (24 - _offset)}
};

SC_fnc_visionModeChanged = {
    params ["", "_visionMode", "_TIindex", "_visionModePrev", "_TIindexPrev", "_vehicle", "_turret"];

    if !(SC_var_isInVehicleVision && (cameraView != "GUNNER")) then {
        SC_var_nvGogglesEnabled = _visionMode == 1;
    };

    SC_var_isInVehicleVision = cameraView == "GUNNER";

    if !SC_var_isInVehicleVision then {
        if SC_var_nvGogglesEnabled then {
            player action ["nvGoggles", player];
        } else {
            player action ["nvGogglesOff", player];
        };
    };
};

SC_fnc_disableThermalLoop = {
    private _blackedOut = false;

    waitUntil {
        if (_blackedOut != ((currentVisionMode player) == 2)) then {
            _blackedOut = !_blackedOut;

            // black screen, the message on a block like every screen text (ui\ui.sqf)
            if _blackedOut then {
                cutText ["", "BLACK FADED", 0, false, false];
                [
                    "SC_thermalBlackout",
                    "<t align='center'>Thermal vision is disabled, press 'N' to switch to another vision mode.</t>",
                    [safeZoneX + safeZoneW / 2, safeZoneY + safeZoneH / 2, 0.5, 0.5]
                ] call UI_fnc_showTextBlocks;
            } else {
                cutText ["", "PLAIN", 0, false, false];
                ["SC_thermalBlackout"] call UI_fnc_hideTextBlocks;
            };
        };

        false
    };
};

SC_fnc_cameraViewLoop = {
    params ["_initialView"];

    waitUntil {
        player switchCamera _initialView;
        cameraView isEqualTo _initialView
    };

    SC_var_lastView = _initialView;

    waitUntil {
        if ((SC_var_lastView isNotEqualTo cameraView) && {cameraView in ["EXTERNAL", "INTERNAL"]}) then {
            SC_var_lastView = cameraView;
            profileNamespace setVariable ["SC_var_lastView", SC_var_lastView];
        };
        false
    };
};

SC_fnc_forceFPPLoop = {
    waitUntil {
        if ((alive player) && {cameraView == "EXTERNAL"}) then {
            player switchCamera "INTERNAL";
        } else {
            waitUntil {alive player};
        };

        false
    };
};

SC_fnc_map = {
    params ["_isOpened"];

    if _isOpened then {
        if (!SC_var_uavTerminalOpened && {!(isNull (findDisplay 160))}) then {
            ((findDisplay 160) displayCtrl 51) ctrlMapAnimAdd [0, SC_var_mapScale, SC_var_mapPosition];
            ctrlMapAnimCommit ((findDisplay 160) displayCtrl 51);
            SC_var_uavTerminalOpened = true;
        } else {
            ((findDisplay 12) displayCtrl 51) ctrlMapAnimAdd [0, SC_var_mapScale, SC_var_mapPosition];
            ctrlMapAnimCommit ((findDisplay 12) displayCtrl 51);
        };

        // the HUD for the open map: shown with "always on the map", the whole HUD with "whole HUD on the map"
        if ((SC_var_alwaysShowHudOnMap && !SC_var_hudEnabled && !SC_var_hudShown) || {SC_var_hudShown && SC_var_showWholeHudOnMap}) then {
            [true, true] call SC_fnc_setHud;
        };
    } else {
        if !SC_var_uavTerminalOpened then {
            SC_var_mapScale = ctrlMapScale ((findDisplay 12) displayCtrl 51);
            SC_var_mapPosition = ((findDisplay 12) displayCtrl 51) ctrlMapScreenToWorld [0.5, 0.53];
        };

        // back to the HUD without the map: the player's own settings again (also those changed while the map was open)
        switch (true) do {
            case (SC_var_alwaysShowHudOnMap && !SC_var_hudEnabled && SC_var_hudShown): {
                [false, false] call SC_fnc_setHud;
            };
            case (SC_var_hudShown): {
                [true, false] call SC_fnc_setHud;
            };
        };
    };
};

SC_fnc_uavTerminalLoop = {
    waitUntil {
        waitUntil {!(isNull (findDisplay 160))};

        waitUntil {
            if (isNull (findDisplay 160)) then {
                SC_var_uavTerminalOpened = false;
                true
            } else {
                SC_var_mapScale = ctrlMapScale ((findDisplay 160) displayCtrl 51);
                SC_var_mapPosition = ((findDisplay 160) displayCtrl 51) ctrlMapScreenToWorld [0.5, 0.53];
                false
            }
        };

        false
    };
};

SC_fnc_disableLeftGpsLoop = {
    waitUntil {
        call {
            if ((((infoPanel "right") select 0) == "EmptyDisplay") != !SC_var_gpsPanelEnabled) then {
                openGPS SC_var_gpsPanelEnabled;
                setInfoPanel ["right", (["EmptyDisplay", "MinimapDisplay"] select SC_var_gpsPanelEnabled)];
            };

            if (((infoPanel "left") select 0) != "EmptyDisplay") then {
                setInfoPanel ["left", "EmptyDisplay"];
            };
        };

        false
    };
};
