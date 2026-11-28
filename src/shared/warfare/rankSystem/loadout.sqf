// Loadout: setting / validating / saving the loadout, inventory lock and single-use launchers (client).

// Loadout: arsenal, saving / restoring, side conversion, single-use launchers
// and the stored loadouts dialog (client).

// ---- loadout ----

// restores a stored loadout; the uniform + vest + backpack contents are limited to VA_maxItemCounts (picked up
// extras are not restored)
SC_fnc_setLoadout = {
    params ["_loadout"];

    private _wasInNightVision = SC_var_nvGogglesEnabled;
    player setUnitLoadout ([_loadout] call VA_fnc_clampLoadoutToMax);

    if _wasInNightVision then {
        [] spawn {
            waitUntil {!SC_var_nvGogglesEnabled};
            SC_var_nvGogglesEnabled = true;
            player action ["nvGoggles", player];
        };
    };
};

SC_fnc_getPlayersWeaponsItems = {
    ((primaryWeaponItems player) + (secondaryWeaponItems player) + (handgunItems player)) select {_x != ""}
};

SC_fnc_isLoadoutValid = {
    private _allowedItems = [];
    {{_allowedItems pushBack (toLower _x);} forEach _x;
        } forEach ([(side (group player)), SC_var_perks,
        (player getVariable "SC_var_rank")] call SC_fnc_getItems);

    (
        (
            (weapons player) +
            (primaryWeaponItems player) +
            (secondaryWeaponItems player) +
            (handgunItems player) +
            (magazines player) +
            (items player) + [
                (uniform player),
                (vest player),
                (backpack player),
                (headgear player),
                (goggles player),
                (hmd player),
                (binocular player)
            ]
        ) findIf {(_x != "") && {!((toLower _x) in _allowedItems)}}
    ) == -1
};

SC_fnc_saveLoadoutToProfile = {
    ["SC_var_lastLoadout", +SC_var_lastLoadout] call SC_fnc_setWorldGroupProfileEntry;
    ["SC_var_lastLoadoutInfo", +SC_var_lastLoadoutInfo] call SC_fnc_setWorldGroupProfileEntry;
    ["SC_var_perks", +SC_var_perks] call SC_fnc_setWorldGroupProfileEntry;

    saveProfileNamespace;
};

// ---- inventory ----

// No inventory in the own base. Returning true blocks it only while this handler is the last InventoryOpened handler of
// the unit: other handlers added later (Magazine Repack re-adds its own after every respawn) decide instead, so an
// inventory that opens anyway is closed at once.
SC_fnc_onInventoryOpened = {
    if ((getPosATL player) inArea ("SC_var_" + (str (side (group player))) + "Base")) then {
        if (SC_var_hudEnabled && {SC_var_inventoryDisabledCooldown == 0}) then {
            ["inventoryDisabled"] call BIS_fnc_showNotification;
        };

        [] spawn SC_fnc_closeInventoryIfOpened;
        true
    } else {
        nil
    }
};

// closes the inventory display (602) should it open within the next second
SC_fnc_closeInventoryIfOpened = {
    private _end = diag_tickTime + 1;

    waitUntil {!(isNull (findDisplay 602)) || {diag_tickTime > _end}};

    if !(isNull (findDisplay 602)) then {
        (findDisplay 602) closeDisplay 2;
    };
};

SC_fnc_inventoryDisabledCooldownLoop = {
    waitUntil {
        if (SC_var_inventoryDisabledCooldown > 0) then {
            SC_var_inventoryDisabledCooldown = SC_var_inventoryDisabledCooldown - 1;
        };

        sleep 1;
        false
    };
};

// ---- single-use launchers ----

SC_fnc_addFiredMan = {
    params ["_unit"];

    private _id = _unit getVariable ["SC_var_firedManId", -1];
    if (_id != -1) then {_unit removeEventHandler ["FiredMan", _id];};
    _id = _unit addEventHandler ["FiredMan", {params ["_unit"]; if (local _unit) then {_this call SC_fnc_reloadOneTimeLauncher};}];
    _unit setVariable ["SC_var_firedManId", _id];
};

SC_fnc_reloadOneTimeLauncher = {
    params ["_unit", "_weapon"];

    if (((currentWeapon _unit) != (secondaryWeapon _unit)) ||
        {!("loaded" in (toLower _weapon))})
    exitWith {};

    [_unit, _weapon] spawn {
        params ["_unit", "_launcher"];
        private _lastWeapon = currentWeapon _unit;

        waitUntil {
            if ((secondaryWeapon _unit) != _launcher) then {
                private _allMags = magazines _unit;
                private _mags = (getArray (configFile >> "CfgWeapons" >> _launcher >> "magazines")) apply {
                    _mag = _x; [_mag, {_x == _mag} count _allMags]};
                {_unit removeMagazines (_x select 0);} forEach _mags;
                _unit addWeapon _launcher;
                {_unit addMagazines _x;} forEach _mags;

                if (_lastWeapon == _launcher) then {
                    _unit selectWeapon _launcher;
                };

                {
                    if ((_x isKindOf "WeaponHolderSimulated") || {_x isKindOf "GroundWeaponHolder"}) then {
                        private _weapons = (getWeaponCargo _x) param [0, []];

                        if (_weapons findIf {"used" in (toLower _x)} > -1) then {
                            deleteVehicle _x;
                        };
                    };
                } forEach (nearestObjects [_unit, ["WeaponHolderSimulated", "GroundWeaponHolder"], 5]);

                true
            } else {
                _lastWeapon = currentWeapon _unit;
                false
            }
        };
    };
};
