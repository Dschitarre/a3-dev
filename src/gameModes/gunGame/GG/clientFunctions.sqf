GG_fnc_getPicture = {
    getText (configfile >>
        (
            if (((_this select 0) isKindOf "Car") || ((_this select 0) isKindOf "Helicopter") || ((_this select 0) isKindOf "Tank") || ((_this select 0) isKindOf "StaticWeapon")) then {
                "CfgVehicles"
            } else {
                if ((_this select 0) isKindOf [(_this select 0), (configFile >> "CfgMagazines")]) then {
                    "CfgMagazines"
                } else {
                    "CfgWeapons"
                }
            }
        )
    >> (_this select 0) >> "picture")
};

GG_fnc_refreshLeaderBoardClient = {
    _leaderBoard = GG_var_leaderBoard;
    _posText = (name player);
    _textPos = _leaderBoard find _posText;

    if (_textPos == -1) then {
        _num = player getVariable "GG_var_weaponNum";
        _leaderBoard = [_leaderBoard, (format ["<t size='0.6' align='center'><br/>%1. %2 %3 %4</t>", (player getVariable "rankOnServer"), (name player), (format ["<img size='0.75' color='#ffffff' image='%1'/>", ([(GG_var_weaponList select _num) select 0] call GG_fnc_getPicture)]), (format ["%1/%2", _num, ((count GG_var_weaponList) - 1)])])] joinString "";
    };

    _textPos = _leaderBoard find _posText;
    _leaderBoard = [(_leaderBoard select [0, _textPos]), (format ["<t color='#ffd400'>%1</t>", (name player)]), (_leaderBoard select [(_textPos + (count _posText)), ((count _leaderBoard) - ((_textPos + (count _posText))))])] joinString "";
    
    [_leaderBoard, [safeZoneX, safeZoneW], [((safeZoneH / 100) + safezoneY), safeZoneH], 9999, 0, 0, 1010] spawn BIS_fnc_dynamicText;
};

GG_fnc_refreshNextWeapon = {
    _num = player getVariable "GG_var_weaponNum";

    [
        (
            if ((_num + 1) < ((count GG_var_weaponList) - 1)) then {
                format [
                    "<t align='right' size='0.6'>Next Weapons:<br/>%1</t>",
                    (
                        (
                            (GG_var_weaponList select [(_num + 1),(if (_num < ((count GG_var_weaponList) - 3)) then {2} else {1})]) apply {
                                format ["<img size='1.25' color='#ffffff' image='%1'/>", ([_x select 0] call GG_fnc_getPicture)]
                            }
                        ) joinString "<br/>"
                    )
                ]
            } else {
                "<t align='right' size='0.6'>No weapons left</t>"
            }
        ),
        [safeZoneX, (0.995 * safeZoneW)], [((0.4 * safeZoneH) + safezoneY), safeZoneH], 9999, 0, 0, 1012
    ] spawn BIS_fnc_dynamicText;
};

GG_fnc_spawnPlayer = {
    ["", 0, 0, 0, 0, 0, 1011] spawn BIS_fnc_dynamicText;
    _startTime = time;
    _safePos = getMarkerPos "GG_var_playZone";
    _playZonePos = _safePos;

    waitUntil {
        _safePos = [_playZonePos, 0, GG_var_maxZoneSize, 3, 0, 0, 0, [], _playZonePos] call BIS_fnc_findSafePos;

        (
            if (
                !(surfaceIsWater _safePos) &&
                {_safePos inArea "GG_var_playZone"} &&
                {
                    _safePosAsl = _safePos;
                    _safePosAsl set [2, 0];
                    _safePosAsl = AGLToASL _safePosAsl;
                    _safePosAsl set [2, ((_safePosAsl select 2) + 0.5)];

                    (([objNull, "VIEW"] checkVisibility [_safePosAsl, (_safePosAsl vectorAdd [0, 0, 100])]) != 0)
                }
            ) then {
                if ((time - _startTime) < 5) then {
                    if !(_safePos isEqualTo _playZonePos) then {
                        if ((GG_var_lastSpawnPos distance _safePos) >= (GG_var_maxZoneSize * 0.38)) then {
                            if (
                                (
                                    {
                                        if ((_x distance _safePos) > (GG_var_maxZoneSize / 3)) then {
                                            ([objNull, "VIEW"] checkVisibility [(eyePos _x), (_safePos vectorAdd [0, 0, 1.5])] > 0)
                                        } else {
                                            true
                                        }
                                    } count (((entities [["CAManBase"], [], true, false]) inAreaArray "GG_var_playZone") select {alive _x})
                                ) == 0
                            ) then {
                                true
                            } else {
                                false
                            }
                        } else {
                            false
                        }
                    } else {
                        false
                    }
                } else {
                    true
                }
            } else {
                false
            }
        )
    };

    if !(_safePos inArea "GG_var_playZone") exitWith {
        GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
    };

    setplayerrespawntime 0;
    waitUntil {alive player};
    GG_var_playZoneLoopScript = [] spawn GG_fnc_playZoneLoop;
    player setPos _safePos;
    player setDir (((getDir player) + (player getRelDir (getMarkerPos "GG_var_playZone"))) mod 360);
    player setVelocity [0, 0, 0];

    [] spawn {
        _timeStart = time;

        waitUntil {
            if !(player inArea "GG_var_playZone") exitWith {
                terminate GG_var_spawnPlayerScript;

                if !(isNull GG_var_cameraViewLoopScript) then {
                    terminate GG_var_cameraViewLoopScript;
                };

                player enableSimulationGlobal false;
                cutText ["", "BLACK FADED", 9999];
                0 fadeSound 0;
                GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
                true
            };

            ((time - _timeStart) >= 1)
        };
    };

    player enableSimulationGlobal true;
    player switchCamera GG_var_lastview;
    cutText ["", "BLACK IN", 1];
    player addRating ((-3000) - (rating player));
    1 fadeSound 1;
    [player, false] call ADG_fnc_allowDamage;
    GG_var_cameraViewLoopScript = [] spawn GG_fnc_cameraViewLoop;
    [player] call GG_fnc_applyWeapon;
    waitUntil {!(isNull player)};

    if GG_var_nvGogglesEnabled then {
        player action ["nvGoggles", player];
    };

    sleep 3;

    if (alive player) then {
        [player, true] call ADG_fnc_allowDamage;
        ["spawnProtectionDisabled"] spawn BIS_fnc_showNotification;
    };
};

GG_fnc_isNight = {
    (dayTime < 4.5) || {dayTime > 19.5}
};

GG_fnc_respawnScreen = {
    if !(isNull GG_var_playZoneLoopScript) then {
        terminate GG_var_playZoneLoopScript;
    };

    ["<t align='center'>Press space to spawn</t>", [safeZoneX, safeZoneW], [((safeZoneH / 2) + safezoneY), safeZoneH], 9999, 0, 0, 1011] spawn BIS_fnc_dynamicText;
    
    GG_var_respawn = false;

    _id = (findDisplay 46) displayAddEventHandler ["KeyDown", {
        params ["", "_key"];
        if (_key == 57) then {
            GG_var_respawn = true;
        };
    }];

    waitUntil {GG_var_respawn};
    GG_var_respawn = nil;
    (findDisplay 46) displayRemoveEventHandler ["KeyDown", _id];
    GG_var_spawnPlayerScript = [] spawn GG_fnc_spawnPlayer;
};

GG_fnc_respawn = {
    params ["_unit", "_corpse"];

    [_unit, _corpse] remoteExec ["GG_fnc_respawnServer", 2];
};

GG_fnc_killed = {
    setplayerrespawntime 9999;

    if !(isNull GG_var_cameraViewLoopScript) then {
        terminate GG_var_cameraViewLoopScript;
    };

    GG_var_lastSpawnPos = getPosATL player;

    [] spawn {
        sleep 4;

        [] spawn GG_fnc_respawnScreen;
    };
};

GG_fnc_take = {
    params ["", "", "_item"];

    if (_item isKindOf [_item, configFile >> "CfgMagazines"]) then {
        player removeMagazine _item;
        player addMagazine _item;
    };
};

GG_fnc_firedMan = {
    params ["", "_weapon", "", "", "", "_muzzle"];

    if (_weapon == "Throw") then {
        player addMagazine _muzzle;
    };
};

GG_fnc_visionModeChanged = {
    params ["_unit", "_visionMode", "_TIindex", "_visionModePrev", "_TIindexPrev", "_vehicle", "_turret"];

    if !(GG_var_isInVehicleVision && (cameraView != "GUNNER")) then {
        GG_var_nvGogglesEnabled = _visionMode == 1;
    };

    GG_var_isInVehicleVision = cameraView == "GUNNER";

    if !GG_var_isInVehicleVision then {
        if GG_var_nvGogglesEnabled then {
            player action ["nvGoggles", player];
        } else {
            player action ["nvGogglesOff", player];
        };
    };
};

GG_fnc_map = {
    params ["_isOpened"];

    if _isOpened then {
        mapAnimAdd [0, (GG_var_mapScaleFactor * GG_var_maxZoneSize * 10 ^ -4), (getMarkerPos "GG_var_playZone")];
        mapAnimCommit;
    };
};