// Client init: player variables, event handlers, loops, dialogs and keys (client).

// ---- client init ----

// seconds the client tries to move a joining player to his base before the player respawns there instead
SC_var_baseTeleportTimeout = 15;
SC_var_loadingTextLayer = 1011;     // cut layer of the "Loading" text (ui\ui.sqf screen text)

// client init: moves the joining player to his base. A JIP player can take over an active AI that sits in a vehicle
// (setPos does not move crew) or is unconscious. True once the player is at the base, false after the timeout.
SC_fnc_moveJoiningPlayerToBase = {
    params ["_respawnPos"];

    private _timeout = time + SC_var_baseTeleportTimeout;

    waitUntil {
        private _wasUnconscious = player getVariable ["ais_unconscious", false];
        [player] call SC_fnc_resetUnitState;

        // AIS hid the HUD and muted the radios of the unconscious unit
        if _wasUnconscious then {
            [SC_var_hudEnabled] call SC_fnc_setHud;

            if AIS_TOGGLE_RADIO then {
                [true] call AIS_Effects_fnc_toggleRadio;
            };
        };

        player setPos _respawnPos;
        sleep 1;

        ((player distance _respawnPos) < 2) || {time > _timeout}
    };

    ((player distance _respawnPos) < 2)
};

// client init (scheduled): called from initPlayerLocal.sqf after all functions are compiled; starts the client loops
SC_fnc_initClient = {
    // enableSimulationGlobal only works on the server
    [player, false] remoteExecCall ["enableSimulationGlobal", 2];
    0 fadeSound 0;
    [false] call SC_fnc_setEarplugsHooks;

    // the mods use SC's group system (their scripts are loaded before SC_fnc_initClient)
    MM_fnc_getGroupUnits = SC_fnc_getGroupUnits;
    TDI_fnc_getGroupUnits = SC_fnc_getGroupUnits;
    KF_fnc_getGroupUnits = SC_fnc_getGroupUnits;

    // virtual arsenal whitelist override with the rank decorations of the item lists (SC\rankSystem\arsenal.sqf);
    // before SC adds its own arsenalOpened handler (it used to be a postInit function)
    VA_var_listDecorator = SC_fnc_decorateArsenalList;
    VA_var_tabDecorator = SC_fnc_decorateArsenalTab;
    VA_var_lockReason = SC_fnc_getArsenalLockReason;
    call VA_fnc_init;

    waitUntil {!(isNull (findDisplay 46))};

    cutText ["", "BLACK FADED", 99999999];

    // in the middle of the black screen, on a block like every screen text
    [
        SC_var_loadingTextLayer,
        "<t align='center'>Loading, please wait...</t>",
        [safeZoneX + safeZoneW / 2, safeZoneY + safeZoneH / 2, 0.5, 0.5]
    ] call UI_fnc_showTextBlocks;

    // a client that was connected when the mission started can get here before the server init is done;
    // the client variables below use variables published by the server
    waitUntil {!(isNil "SC_var_serverInitDone")};

    call SC_fnc_initClientVars;

    if SC_var_wholeMap then {
        [] spawn SC_fnc_removeCoverMapLocal;
    };

    [SC_var_hudEnabled] call SC_fnc_setHud;

    [player] join grpNull;
    [player, false] call ADG_fnc_allowDamage;

    if SC_var_wgOneTimeLaunchers then {
        {
            if (!(isPlayer _x) && {!(unitIsUAV _x)}) then {
                [_x] call SC_fnc_addFiredMan;
            };
        } forEach (entities [["CAManBase"], [], true, false]);
    };

    [] spawn {
        private _baseMarker = "SC_var_" + (toLower (str (side (group player)))) + "Respawn";
        private _dir = markerDir _baseMarker;
        private _respawnPos = getMarkerPos _baseMarker;
        [player, true] remoteExecCall ["enableSimulationGlobal", 2];
        // the slot unit was a hidden pool unit (SC_fnc_initAIUnitsServer, SC_fnc_suspendUnit)
        [player, false] remoteExecCall ["hideObjectGlobal", 2];

        // still not at the base (e.g. stuck in a vehicle): a clean respawn (old body hidden), then the new unit is moved
        if !([_respawnPos] call SC_fnc_moveJoiningPlayerToBase) then {
            diag_log format ["SC: %1 could not be moved to the base and respawns", (name player)];

            private _oldUnit = player;
            forceRespawn _oldUnit;
            setPlayerRespawnTime 0.1;

            waitUntil {(player isNotEqualTo _oldUnit) && {alive player}};

            setPlayerRespawnTime (getMissionConfigValue ["respawnDelay", 10]);
            [_oldUnit, true] remoteExecCall ["hideObjectGlobal", 2];
            [_oldUnit, false] remoteExecCall ["enableSimulationGlobal", 2];
            [player, true] remoteExecCall ["enableSimulationGlobal", 2];
            [_respawnPos] call SC_fnc_moveJoiningPlayerToBase;
        };

        player setDir _dir;
        player switchMove "amovpercmstpsnonwnondnon";

        [player] remoteExecCall ["SC_fnc_playerServer", 2];

        call {
            [SC_var_lastLoadout] call SC_fnc_setLoadout;
            call SC_fnc_adjustLoadoutAndInfo;

            [SC_var_loadingTextLayer] call UI_fnc_hideTextBlocks;
            player setUnitTrait ["Medic", ("MEDC" in SC_var_perks)];
            player setUnitTrait ["Engineer", true];
            player setUnitTrait ["UAVHacker", true];

            {
                [_x] call SC_fnc_addHandleHeal;
            } forEach (entities [["CAManBase"], [], true, false]);

            player addEventHandler ["killed", {_this spawn SC_fnc_onKilled;}];
            player addEventHandler ["Respawn", {_this spawn SC_fnc_onRespawn;}];
            player addEventHandler ["Put", {_this call SC_fnc_put;}];
            player addEventHandler ["InventoryOpened", {_this call SC_fnc_onInventoryOpened}];
            player addEventHandler ["VisionModeChanged", {_this call SC_fnc_visionModeChanged;}];
            addMissionEventHandler ["Map", {_this call SC_fnc_map;}];
            [missionNamespace, "arsenalOpened", {_this call SC_fnc_arsenalOpened;}] call BIS_fnc_addScriptedEventHandler;
            inGameUISetEventHandler ["Action", "_this call SC_fnc_onUiAction"];

            if SC_var_wgOneTimeLaunchers then {
                [player] call SC_fnc_addFiredMan;
            };

            disableSerialization;
            (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call SC_fnc_keyHud}];
            (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call SC_fnc_keySettingsDialog}];
            (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call SC_fnc_keyPanel}];
            // vehicle lock on J (SC\vehicles\handling.sqf), no scroll actions
            (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call SC_fnc_keyVehicleLock}];
            // SC group menu (SC\groupMenu.sqf) on the key of the vanilla Dynamic Groups menu (TeamSwitch, U)
            (findDisplay 46) displayAddEventHandler ["KeyDown", {_this call SC_fnc_groupMenuMainKeyDown}];
            (findDisplay 46) displayAddEventHandler ["KeyUp", {_this call SC_fnc_groupMenuMainKeyUp}];

            // param values: 0 = Disabled, 1 = Enabled
            if ((("thirdPerson" call BIS_fnc_getParamValue) == 0) && ((difficultyOption "thirdPersonView") == 1)) then {
                SC_var_forceFPPLoopScript = [] spawn SC_fnc_forceFPPLoop;
                (findDisplay 46) displayAddEventHandler ["KeyDown", {params ["", "_key"]; if (_key in (actionKeys "personView")) then {true};}];
                SC_var_viewSwitchable = false;
            } else {
                SC_var_viewSwitchable = (difficultyOption "thirdPersonView") == 1;
                SC_var_lastView = if SC_var_viewSwitchable then {profileNamespace getVariable ["SC_var_lastView", "EXTERNAL"]} else {"INTERNAL"};
            };

            if (("thermalVision" call BIS_fnc_getParamValue) == 0) then {
                SC_var_disableThermalLoopScript = [] spawn SC_fnc_disableThermalLoop;
            };

            SC_var_ranksystemLoopScript = [] spawn SC_fnc_rankSystemLoop;
            SC_var_inventoryDisabledCooldownLoopScript = [] spawn SC_fnc_inventoryDisabledCooldownLoop;
            SC_var_respawnPositionsLoopScript = [] spawn SC_fnc_respawnPositionsLoop;
            SC_var_spectatorMapDrawEHLoopScript = [] spawn SC_fnc_spectatorMapDrawEHLoop;
            SC_var_cameraMapDrawEHLoopScript = [] spawn SC_fnc_cameraMapDrawEHLoop;
            SC_var_uavTerminalLoopScript = [] spawn SC_fnc_uavTerminalLoop;
            SC_var_spectatorNightVisionLoopScript = [] spawn SC_fnc_spectatorNightVisionLoop;
            SC_var_cameraNightVisionLoopScript = [] spawn SC_fnc_cameraNightVisionLoop;
            SC_var_staminaSystemLoopScript = [] spawn SC_fnc_staminaSystemLoop;
            SC_var_disableLeftGpsLoopScript = [] spawn SC_fnc_disableLeftGpsLoop;
            SC_var_broadcastCameraViewLoopScript = [] spawn SC_fnc_broadcastCameraViewLoop;
            // black screens, sound and HUD after death / kill cam / spectator, robust against alt-tab (SC\player\respawn.sqf)
            SC_var_recoveryLoopScript = [] spawn SC_fnc_recoveryLoop;
            // the player's custom waypoint to the server: an AI driver of his group drives him there (SC_fnc_groupMenu*)
            if (isNil "SC_var_customWaypointScript") then {
                SC_var_customWaypointScript = [] spawn SC_fnc_customWaypointLoop;
            };

            [] spawn {
                waitUntil {!(isNil "TDI_var_clientInitDone")};
                TDI_var_gatherDrawArraysFncs pushBack "SC_fnc_updateTdIconsDrawArray";
            };

            [] spawn {
                waitUntil {!(isNil "MM_var_clientInitDone")};
                MM_var_gatherDrawArrFncs pushBack "SC_fnc_updateMapIconsDrawArray";
            };

            player setVariable ["SC_var_clientInitDone", true];
            [true] call SC_fnc_setEarplugsHooks;
            [] spawn SC_fnc_onRespawn;
        };
    };
};

// client: player variables, settings and the loadout / perks stored in the profile
SC_fnc_initClientVars = {
    SC_var_overridePerkChange = false;

    private _hudConfig = [
        ["HUD (press F2 to toggle)", true],
        ["Always show HUD when on map", true],
        ["Always show HUD when unconscious", true],
        ["Show all HUD components when on map", true],
        ["Show all HUD components when unconscious", true],
        ["Sector overview", true],
        ["Player stats", true],
        ["Group overview", true],
        ["Killfeed", true],
        ["Midfeed", true],
        ["Deathfeed", true],
        ["Unit names below 3D unit icons", true],
        ["Hide invisible 3D group icons", false],
        ["Limit 3D group icon draw distance", false],
        ["Sector 3D icons", true],
        ["Airdrop 3D icons", true],
        ["Show unit names on map only when hovered over", true],
        ["Vehicle-, soldier- and weapon info panels", true],
        ["Vehicle radar", true],
        ["Vehicle compass", true],
        ["GPS-/vehicle panel", true],
        ["Show locked items in the arsenal", true]
    ];
    SC_var_defaultSettings = _hudConfig apply {_x select 1};

    SC_var_neededXp = 0;
    SC_var_inventoryDisabledCooldown = 0;
    SC_var_groupResArr = [];
    SC_var_hudEnabled = true;
    SC_var_hudShown = false;
    SC_var_isInVehicleVision = false;
    SC_var_nvGogglesEnabled = call SC_fnc_isNight;
    SC_var_hudSwitchCooldown = 0;
    SC_var_mapPosition = [];
    SC_var_mapScale = -1;
    SC_var_uavTerminalOpened = false;
    SC_var_stamina = 1;
    SC_var_hudDisplayIsOpen = false;

    SC_var_vehicleCooldownEnd = 0;

    SC_var_cameraViewLoop = scriptNull;
    SC_var_forceFPPLoopScript = scriptNull;
    SC_var_ranksystemLoopScript = scriptNull;
    SC_var_inventoryDisabledCooldownLoopScript = scriptNull;
    SC_var_respawnPositionsLoopScript = scriptNull;
    SC_var_uavTerminalLoopScript = scriptNull;
    SC_var_disableThermalLoopScript = scriptNull;
    SC_var_spectatorNightVisionLoopScript = scriptNull;
    SC_var_cameraNightVisionLoopScript = scriptNull;
    SC_var_staminaSystemLoopScript = scriptNull;
    SC_var_hudUpdateSectorOverviewLoopScript = scriptNull;
    SC_var_hudUpdateGroupOverviewLoopScript = scriptNull;
    SC_var_hudUpdatePlayerStatsLoopScript = scriptNull;
    SC_var_disableLeftGpsLoopScript = scriptNull;
    SC_var_broadcastCameraViewLoopScript = scriptNull;

    [] call UI_fnc_applyViewDistance;
    call UI_fnc_initViewDistance;

    if (isNil {profileNamespace getVariable "SC_var_killHistory"}) then {
        profileNamespace setVariable ["SC_var_killHistory", []];
    };

    if (isNil {profileNamespace getVariable "SC_var_deathHistory"}) then {
        profileNamespace setVariable ["SC_var_deathHistory", []];
    };

    SC_var_baseLoadout = +((getArray (SC_var_worldGroupConfig >> "baseLoadouts")) select (SC_var_sides find (side (group player))));

    SC_var_baseLoadoutInfo = [playerSide, 1, 1, 1, 1, 1];

    if DW_var_skipNight then {
        private _tmp = SC_var_baseLoadout select 9;
        _tmp set [5, ""];
        SC_var_baseLoadout set [9, _tmp];
    };

    TDI_var_DrawUnitsOnSpectator = false;
    KF_var_DeathTransition = false;

    SC_var_mapPosition = getMarkerPos "SC_var_playZone";
    SC_var_mapScale = SC_var_mapZoomFactor * SC_var_maxZoneSize * 10 ^ -4;

    if (isNil "SC_var_maximumVehicleAmount") then {
        SC_var_maximumVehicleAmount = 0;
    };

    // settings of an older version can have fewer (or other) entries: missing or invalid entries get the default
    private _storedSettings = profileNamespace getVariable ["SC_var_lastSettings", []];
    SC_var_settings = +SC_var_defaultSettings;

    if (_storedSettings isEqualType []) then {
        {
            if (_x isEqualType true) then {
                SC_var_settings set [_forEachIndex, _x];
            };
        } forEach (_storedSettings select [0, count SC_var_defaultSettings]);
    };

    // Apply the new default once to existing profiles; later explicit changes remain shared by SC and OF.
    if ((profileNamespace getVariable ["SC_var_hoverNamesDefaultVersion", 0]) < 1) then {
        SC_var_settings set [16, true];
        profileNamespace setVariable ["SC_var_hoverNamesDefaultVersion", 1];
    };
    if ((profileNamespace getVariable ["SC_var_visibleGroupIconsDefaultVersion", 0]) < 1) then {
        SC_var_settings set [12, false];
        profileNamespace setVariable ["SC_var_visibleGroupIconsDefaultVersion", 1];
    };
    call SC_fnc_writeSettingsArrToVariables;
    profileNamespace setVariable ["SC_var_lastSettings", +SC_var_settings];

    call SC_fnc_loadProgress;

    (call SC_fnc_getPlayerData) params ["_xp", "_rank"];
    player setVariable ["SC_var_rank", _rank, true];

    // per-world-group profile lists; if one of them is corrupt, it is reset and the defaults are used
    private _profileValid = true;

    {
        private _data = [_x] call SC_fnc_getProgressList;

        if (
            !(_data isEqualType []) ||
            {(_data findIf {
                !(_x isEqualType []) ||
                {(count _x) != 2} ||
                {!((_x select 0) isEqualType "")} ||
                {!((_x select 1) isEqualType [])}
            }) != -1}
        ) then {
            [_x, []] call SC_fnc_setProgressList;
            _profileValid = false;
        };
    } forEach ["SC_var_lastLoadout", "SC_var_lastLoadoutInfo", "SC_var_perks"];

    if _profileValid then {
        SC_var_lastLoadout = ["SC_var_lastLoadout", +SC_var_baseLoadout] call SC_fnc_getWorldGroupProfileEntry;
        SC_var_lastLoadoutInfo = ["SC_var_lastLoadoutInfo", +SC_var_baseLoadoutInfo] call SC_fnc_getWorldGroupProfileEntry;
        SC_var_perks = ["SC_var_perks", ["EXPR"]] call SC_fnc_getWorldGroupProfileEntry;
    } else {
        SC_var_lastLoadout = +SC_var_baseLoadout;
        SC_var_lastLoadoutInfo = +SC_var_baseLoadoutInfo;
        SC_var_perks = ["EXPR"];
    };

    call SC_fnc_loadArsenalSeenItems;
    call SC_fnc_saveLoadoutToProfile;

    player setVariable ["SC_var_hasExprPerk", ("EXPR" in SC_var_perks), true];
    player setVariable ["ais_side", side (group player), true];
};
