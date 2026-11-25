// Init on every machine: AIS and mods, world group (map family) constants (both).

// Game: shared helpers and constants, world group settings, server and client init (both).

// ---- common ----

// every machine (initServer.sqf and initPlayerLocal.sqf, both on a hosted server): AIS and local-effect settings
SC_fnc_initCommon = {
    // AIS (revive system) - topic files (source: src/shared/ais, copied to AIS\ by the build), setup.sqf first.
    // Compiled and initialized once per machine.
    isNil {
        if (isNil "AIS_var_initDone") then {
            AIS_var_initDone = true;

            {
                call (compile preprocessFileLineNumbers _x);
            } forEach [
                "AIS\setup.sqf",
                "AIS\core.sqf",
                "AIS\events.sqf",
                "AIS\interaction.sqf",
                "AIS\system.sqf",
                "AIS\unconscious.sqf",
                "AIS\revive.sqf",
                "AIS\transport.sqf",
                "AIS\effects.sqf",
                "AIS\bleeding.sqf",
                "AIS\damage.sqf"
            ];

            [] call AIS_Core_fnc_preInit;
            [] call AIS_Effects_fnc_preInit;
            [] spawn AIS_Core_fnc_postInit;
            [] spawn AIS_System_fnc_postInit;
        };
    };

    // local-effect settings, needed on every machine
    showSubtitles false;
    enableRadio false;
    enableSentences false;
    enableTeamSwitch false;
    enableDynamicSimulationSystem false;

    0 enableChannel [true, false];
    1 enableChannel [true, false];
    2 enableChannel [true, false];
    3 enableChannel [true, true];
    4 enableChannel [true, true];
    5 enableChannel [true, true];

    // once per machine (both calls on a hosted server)
    if (isNil "SC_var_localUnitsScript") then {
        SC_var_localUnitsScript = [] spawn SC_fnc_localUnitsLoop;
    };
};

// Every machine handles its own local units, again after every respawn or change of locality:
// - the AI reports ("2, enemy man, 200 m") and orders showed in the chat although the settings above are off: the
//   radio protocol of an AI unit is off only where disableAI ran on the machine the unit is local to;
// - the "under fire" marks (SC_fnc_markUnderFire): Hit and Suppressed fire where the unit is local.
SC_fnc_localUnitsLoop = {
    while {true} do {
        {
            if (local _x) then {
                if (!(isPlayer _x) && {_x checkAIFeature "RADIOPROTOCOL"}) then {
                    _x disableAI "RADIOPROTOCOL";
                };

                // a local flag: a machine the unit becomes local to adds its own handlers
                if !(_x getVariable ["SC_var_underFireHandlers", false]) then {
                    _x setVariable ["SC_var_underFireHandlers", true];
                    _x addEventHandler ["Hit", {[_this select 0] call SC_fnc_markUnderFire}];
                    _x addEventHandler ["Suppressed", {[_this select 0] call SC_fnc_markUnderFire}];
                };
            };
        } forEach allUnits;

        sleep 2;
    };
};

// ---- under fire (respawning at a group mate, players and AI) ----

SC_var_underFireTime = 10;        // s after a hit or a bullet passing close by: the unit counts as under fire
SC_var_spawnSafeRadius = 10;      // m: no conscious enemy this close to a group mate one respawns at (user decision)

// on the unit's machine: hit or suppressed (bullets passing close by); public, at most every 2 s
SC_fnc_markUnderFire = {
    params ["_unit"];

    if ((serverTime - (_unit getVariable ["SC_var_underFireAt", -1e6])) > 2) then {
        _unit setVariable ["SC_var_underFireAt", serverTime, true];
    };
};

SC_fnc_isUnderFire = {
    params ["_unit"];

    (serverTime - (_unit getVariable ["SC_var_underFireAt", -1e6])) < SC_var_underFireTime
};

// whether one may respawn at the unit (user decision): it isn't under fire and no conscious enemy is within
// SC_var_spawnSafeRadius, on foot or in a vehicle
SC_fnc_isSafeSpawnTarget = {
    params ["_unit"];

    private _side = side (group _unit);

    !([_unit] call SC_fnc_isUnderFire) &&
    {
        ((_unit nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], SC_var_spawnSafeRadius]) findIf {
            private _men = if (_x isKindOf "CAManBase") then {[_x]} else {crew _x};

            (_men findIf {
                (alive _x) &&
                {!(_x getVariable ["ais_unconscious", false])} &&
                {((side (group _x)) getFriend _side) < 0.6}
            }) != -1
        }) == -1
    }
};

SC_var_sides = [west, east, independent];

// loaded DLCs (used to filter the item / vehicle configs)
SC_var_rfActive = isClass (configFile >> "CfgWeapons" >> "SMG_01_black_RF");

SC_var_lxwsActive = isClass (configFile >> "CfgWeapons" >> "arifle_Velko_lxWS");

SC_var_efActive = isClass (configFile >> "CfgWeapons" >> "ef_hgun_P07_coy");

// world group (vanilla 2035 maps / CUP Chernarus), see SC\worldGroupConfig*.hpp
SC_var_worldGroupConfig = missionConfigFile >> "SC_worldGroupConfig";

SC_var_currentWorldGroup = getText (SC_var_worldGroupConfig >> "name");

SC_var_wgFilterDlcItems = (getNumber (SC_var_worldGroupConfig >> "filterDlcItems")) == 1;

SC_var_wgOneTimeLaunchers = (getNumber (SC_var_worldGroupConfig >> "oneTimeLaunchers")) == 1;

SC_var_wgUsesCupClasses = (getNumber (SC_var_worldGroupConfig >> "usesCupClasses")) == 1;

SC_var_wgClassPrefixLength = getNumber (SC_var_worldGroupConfig >> "classPrefixLength");

SC_var_wgUavTerminals = getArray (SC_var_worldGroupConfig >> "uavTerminals");

SC_var_wgDefaultNvgs = getArray (SC_var_worldGroupConfig >> "defaultNvgs");
