SC_fnc_getSectorColor = {
    params ["_side", "_alpha", "_colorIntensity"];

    (
        [1, 1, 1] vectorDiff (
            (
                [1, 1, 1] vectorDiff (
                    switch _side do {
                        case civilian: {[1, 1, 1]};
                        case west: {[0, 0.4, 0.7]};
                        case east: {[0.9, 0, 0]};
                        case independent: {[0, 0.6, 0.2]};
                    }
                )
            ) vectorMultiply _colorIntensity
        )
    ) + [_alpha]
};

SC_fnc_put = {
    params ["", "_container"];
    
    if ((typeOf _container) isEqualTo "GroundWeaponHolder") then {
        [_container] remoteExecCall ["SC_fnc_addGroundWeaponHolder", 2];
    };
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

        if (SC_var_alwaysShowHudOnMap && !SC_var_hudEnabled && !SC_var_hudShown) then {
            [true] call SC_fnc_setHud;
        };
    } else {
        if !SC_var_uavTerminalOpened then {
            SC_var_mapScale = ctrlMapScale ((findDisplay 12) displayCtrl 51);
            SC_var_mapPosition = ((findDisplay 12) displayCtrl 51) ctrlMapScreenToWorld [0.5, 0.53];
        };

        if (SC_var_alwaysShowHudOnMap && !SC_var_hudEnabled && SC_var_hudShown) then {
            [false] call SC_fnc_setHud;
        };
    };
};

SC_fnc_actionStr = '
    if (unitIsUAV (_this select 0)) then {
        {
            _x linkItem "itemMap";
            _x linkItem "itemGPS";
            _x linkItem "H_PilotHelmetFighter_B";
        } forEach (crew (_this select 0));
    };
    
    false
';

SC_fnc_isNight = {
    _offset = [4, 5.666] select (worldName == "Tanoa");

    (dayTime < _offset) || {dayTime > (24 - _offset)}
};

SC_fnc_onInventoryOpened = {
    if ((getPosATL player) inArea ("SC_var_" + (str (side (group player))) + "Base")) then {
        if (SC_var_hudEnabled && {SC_var_inventoryDisabledCooldown == 0}) then {
            ["inventoryDisabled"] call BIS_fnc_showNotification;
        };

        true
    } else {
        nil
    }
};

SC_fnc_onKilled = {
    if SC_var_viewSwitchable then {
        terminate SC_var_cameraViewLoop;
    };

    3 fadesound 0;
    waitUntil {visibleMap};
    [false] call KF_fnc_EnableMidFeed;
    MM_var_showAliveGroupUnits = false;
    call MM_fnc_updateDrawArrayImmediate;
    (uiNamespace getVariable "SC_var_sectorControlDisplay" displayctrl 1999) ctrlSetTextColor [1, 1, 1, 0];
    sleep 4;
    waitUntil {alive player};
    [SC_var_hudEnabled] call KF_fnc_EnableMidFeed;
};

SC_fnc_setArsenalVisionMode = {
    missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", ([0, 1] select SC_var_nvGogglesEnabled)];
    false setCamUseTi 0;
    camUseNVG SC_var_nvGogglesEnabled;
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

    if (soundVolume == 0) then {
        1 fadesound ([1, 0.3] select SC_var_earplugsOn);
    };
    
    [SC_var_lastLoadout] call SC_fnc_setLoadout;

    if SC_var_nvGogglesEnabled then {
        player action ["nvGoggles", player];
    };

    if (((getPosATL player) select 2) > 1500) then {
        [player] spawn SC_fnc_zoneParachuteJump;
    } else {
        _baseMarker = "SC_var_" + (toLower (str (side (group player)))) + "Respawn";
        _baseMarkerPos = getMarkerPos _baseMarker;
        [player, false] call ADG_fnc_allowDamage;

        if ((player distance _baseMarkerPos) < 8) then {
            player setDir (markerDir _baseMarker);
            waitUntil {((player distance _baseMarkerPos) > 8) || {!(alive player)}};
            [player, true] call ADG_fnc_allowDamage;
            ["spawnprotectiondisabled"] call SC_fnc_showNotificationIfHudIsEnabled;
        } else {
            sleep 4;

            if (alive player) then {
                [player, true] call ADG_fnc_allowDamage;
            };
        };
    };
};

SC_fnc_showNotificationIfHudIsEnabled = {
    if SC_var_hudEnabled then {
        _this call BIS_fnc_showNotification;
    };
};

SC_fnc_can_lockVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) <= 1) &&
    {(_vehicle getVariable "SC_var_lockerUid") == -1}
};

SC_fnc_lockVehicle = {
    params ["_vehicle"];

    [_vehicle, 3] remoteExecCall ["lock", (owner _vehicle)];
    _vehicle setVariable ["SC_var_lockerUid", (call (compile (getPlayerUID player))), true];

    {
        _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

        if ((alive _assignedUnit) && {!(_assignedUnit isEqualTo _crewUnit)}) then {
            (group _assignedUnit) leaveVehicle _vehicle;
        };
    } forEach (fullCrew _vehicle);
};

SC_fnc_canUnlockVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) > 1) &&
    {SC_var_playerUid isEqualTo (_vehicle getVariable "SC_var_lockerUid")}
};

SC_fnc_unlockVehicle = {
    params ["_vehicle"];

    [_vehicle, 1] remoteExecCall ["lock", (owner _vehicle)];
    _vehicle setVariable ["SC_var_lockerUid", -1, true];
};

SC_fnc_canMoveAIOutofVehicle = {
    params ["_vehicle"];

    ((locked _vehicle) > 1) &&
    {SC_var_playerUid isEqualTo (_vehicle getVariable "SC_var_lockerUid")} &&
    {
        (
            (crew _vehicle) findIf {
                (alive _x) &&
                {!(isPlayer _x)} &&
                {_x isKindOf "CAManBase"}
            }
        ) != -1
    }
};

SC_fnc_moveAiOutOfVehicle = {
    params ["_vehicle"];

    _unitsToSetOut = (crew _vehicle) select {(alive _x) && {!(isPlayer _x)} && {_x isKindOf "CAManBase"}};
    doGetOut _unitsToSetOut;

    {
        (group _x) leaveVehicle _vehicle;
    } forEach _unitsToSetOut;
    
    {
        _x params ["_crewUnit", "", "", "", "", "_assignedUnit"];

        if ((alive _assignedUnit) && {!(_assignedUnit isEqualTo _crewUnit)}) then {
            (group _assignedUnit) leaveVehicle _vehicle;
        };
    } forEach (fullCrew _vehicle);
};