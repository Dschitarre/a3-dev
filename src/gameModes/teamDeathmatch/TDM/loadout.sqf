// Loadouts (server and client): equipment unlocks per round (TDM\itemConfig.hpp), the client arsenal box and the
// equip phase. Unlocks use the relative round number 0..30, which scales any match length to the same range.

DM_var_unlockRounds = getArray (missionConfigFile >> "unlockRounds");
DM_var_maxRelRoundNumber = 30;      // everything unlocked (warmup, unrestricted loadouts)
DM_var_medikitRelRoundNumber = 19;  // from here on a Medikit instead of FirstAidKits

// ---- unlocks ----

DM_fnc_relativeRoundNumber = {
    params ["_roundNumber"];

    if (DM_var_minPointsToWin <= 1) exitWith {DM_var_maxRelRoundNumber};

    round (30 * (_roundNumber / (2 * (DM_var_minPointsToWin - 1))))
};

// [weapons, items, magazines, backpacks] unlocked at _relRoundNumber
DM_fnc_calculateItems = {
    params ["_relRoundNumber"];

    private _weapons = [];
    private _items = [];
    private _magazines = [];
    private _backpacks = [];

    {
        private _round = str _x;
        _weapons append getArray (missionConfigFile >> ("weaponsRound" + _round));
        _items append getArray (missionConfigFile >> ("itemsRound" + _round));
        _magazines append getArray (missionConfigFile >> ("magazinesRound" + _round));
        _backpacks append getArray (missionConfigFile >> ("backpacksRound" + _round));
    } forEach (DM_var_unlockRounds select {_x <= _relRoundNumber});

    if (!DM_var_autoHealEnabled) then {
        _items pushBack ([_relRoundNumber] call DM_fnc_medicalItem);
    };

    [_weapons, _items, _magazines, _backpacks]
};

DM_fnc_medicalItem = {
    params ["_relRoundNumber"];

    ["FirstAidKit", "Medikit"] select (_relRoundNumber >= DM_var_medikitRelRoundNumber)
};

// the medical items of the round (none with automatic healing)
DM_fnc_addMedicalItems = {
    params ["_unit", "_relRoundNumber"];

    if (DM_var_autoHealEnabled) exitWith {};

    if (([_relRoundNumber] call DM_fnc_medicalItem) == "Medikit") exitWith {
        _unit addItem "Medikit";
    };

    for "_i" from 1 to 4 do {
        _unit addItem "FirstAidKit";
    };
};

// ---- equip phase ----
// DM_var_arsenalItems ([relRoundNumber, items]) is the current arsenal content (public, read by players who join later).

DM_fnc_setArsenalItemsServer = {
    params ["_relRoundNumber"];

    DM_var_arsenalItems = [_relRoundNumber, [_relRoundNumber] call DM_fnc_calculateItems];
    publicVariable "DM_var_arsenalItems";
};

// server: start of a round, every client goes back to its HQ and gets the arsenal of the round
DM_fnc_startEquipPhaseGlobal = {
    params ["_relRoundNumber"];

    private _args = [false, 25, [[], [], [], []]];

    if (DM_var_loadoutsRestricted) then {
        [_relRoundNumber] call DM_fnc_setArsenalItemsServer;
        _args = [DM_var_roundNumber == 1, _relRoundNumber, DM_var_arsenalItems select 1];
    };

    _args remoteExec ["DM_fnc_startEquipPhase", [0, -2] select isDedicated];
};

// client: back to the HQ (or respawn), reset the loadout in round 1, new arsenal content, open the arsenal
DM_fnc_startEquipPhase = {
    params ["_resetLoadout", "_relRoundNumber", "_items"];

    if (!hasInterface) exitWith {};

    private _script = [] spawn DM_fnc_closeArs;
    waitUntil {scriptDone _script};

    if (alive player) then {
        _script = [true] spawn DM_fnc_setToSpawn;
        waitUntil {scriptDone _script};
    } else {
        setPlayerRespawnTime 0;
        waitUntil {alive player};
    };

    if (_resetLoadout) then {
        _script = [_relRoundNumber] spawn DM_fnc_resetLoadout;
        waitUntil {scriptDone _script};
    };

    _script = scriptNull;

    if (DM_var_loadoutsRestricted) then {
        _script = [_relRoundNumber, _items] spawn DM_fnc_applyItemsOnArsenal;
    };

    waitUntil {!isNull player && {!(player getVariable "CMN_var_isLoading")} && {scriptDone _script}};

    // benched while loading (DM_fnc_benchLoadingPlayers): spectates this round
    if (!simulationEnabled player) exitWith {};

    call DM_fnc_openArs;
};

// back to the slot's start loadout plus the medical items of the round
DM_fnc_resetLoadout = {
    params ["_relRoundNumber"];

    waitUntil {alive player && {getUnitLoadout player isEqualTo (player getVariable "DM_var_lastLoadout")}};

    private _startLoadout = player getVariable "DM_var_startLoadout";
    private _nvGogglesEnabled = CMN_var_nvGogglesEnabled;

    waitUntil {
        player setUnitLoadout _startLoadout;
        getUnitLoadout player isEqualTo _startLoadout
    };

    CMN_var_nvGogglesEnabled = _nvGogglesEnabled;
    [player, _relRoundNumber] call DM_fnc_addMedicalItems;
    player setVariable ["DM_var_lastLoadout", _startLoadout];
};

// ---- arsenal (client) ----
// The arsenal box DM_var_equip is a local, invisible helipad.

DM_fnc_openArs = {
    ["Open", [nil, DM_var_equip, player]] call BIS_fnc_arsenal;
};

DM_fnc_closeArs = {
    disableSerialization;
    private _display = uiNamespace getVariable "RSCDisplayArsenal";

    if (!isNil "_display") then {
        waitUntil {
            if (isNull _display) exitWith {true};

            _display closeDisplay 2;
            false
        };
    };

    player setVariable ["DM_var_arsenalOpened", false, true];
};

// unrestricted loadouts: full arsenal
DM_fnc_createFullArsenal = {
    DM_var_equip = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
    waitUntil {!isNull DM_var_equip};
    ["AmmoboxInit", [DM_var_equip, true]] spawn BIS_fnc_arsenal;
};

// new arsenal box with the items of the round plus the side specific items (itemsRound<N>west / east)
DM_fnc_applyItemsOnArsenal = {
    params ["_relRoundNumber", "_items"];

    _items = +_items;

    if (!isNil "DM_var_equip" && {!isNull DM_var_equip}) then {
        deleteVehicle DM_var_equip;
    };

    DM_var_equip = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
    waitUntil {!isNull DM_var_equip};

    private _initScript = ["AmmoboxInit", [DM_var_equip, false]] spawn BIS_fnc_arsenal;
    private _sideName = toLowerANSI str (side group player);

    {
        (_items select 1) append getArray (missionConfigFile >> ("itemsRound" + str _x + _sideName));
    } forEach (DM_var_unlockRounds select {_x <= _relRoundNumber});

    waitUntil {scriptDone _initScript};

    {
        [DM_var_equip, _items select _forEachIndex, false, false] call (missionNamespace getVariable ("BIS_fnc_addVirtual" + _x + "Cargo"));
    } forEach ["Weapon", "Item", "Magazine", "Backpack"];
};

// scripted "arsenalOpened" event handler
DM_fnc_arsenalOpened = {
    params ["_display"];

    player setVariable ["DM_var_arsenalOpened", true, true];

    call DM_fnc_setArsenalVisionMode;

    [_display] spawn {
        params ["_display"];

        private _visionScript = [] spawn DM_fnc_arsenalThermalLoop;
        waitUntil {isNull _display};
        call CMN_fnc_restoreNightVision;
        terminate _visionScript;
    };
};

DM_fnc_setArsenalVisionMode = {
    missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", [0, 1] select CMN_var_nvGogglesEnabled];
    false setCamUseTI 0;
    camUseNVG CMN_var_nvGogglesEnabled;
};

// scripted "arsenalClosed" event handler: loads the matching magazines into the weapons and keeps the loadout
DM_fnc_arsenalClosed = {
    private _magazines = magazines player;

    {
        private _weapon = _x;

        {
            {
                if (_x in _magazines) then {
                    player addWeaponItem [_weapon, _x, true];
                };
            } forEach getArray (configFile >> "CfgWeapons" >> _weapon >> _x >> "magazines");
        } forEach getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
    } forEach weapons player;

    player setVariable ["DM_var_lastLoadout", getUnitLoadout player];
    player setVariable ["DM_var_arsenalOpened", false, true];
    ["Terminate"] call BIS_fnc_EGSpectator;
};

// no thermal vision in the arsenal; NV toggled in the arsenal becomes the player's NV state
DM_fnc_arsenalThermalLoop = {
    waitUntil {
        private _visionMode = missionNamespace getVariable ["BIS_fnc_arsenal_visionMode", -1];

        if (_visionMode == 2) then {
            _visionMode = 0;
            false setCamUseTI 0;
            camUseNVG false;
            missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", 0];
        };

        CMN_var_nvGogglesEnabled = _visionMode == 1;

        false
    };
};
