SC_fnc_worldNamesFromWorldGroup = {
    params ["_worldGroup"];

    (SC_var_worldGroups select (SC_var_worldGroups findIf {(_x select 0) == _worldGroup})) select 1
};

SC_fnc_setLoadout = {
    params ["_loadout"];

    _wasInNightVision = SC_var_nvGogglesEnabled;
    player setUnitLoadout _loadout;

    if _wasInNightVision then {
        [] spawn {
            waitUntil {!SC_var_nvGogglesEnabled};
            SC_var_nvGogglesEnabled = true;
            player action ["nvGoggles", player];
        };
    };
};

SC_fnc_setBaseLoadout = {
    [SC_var_baseLoadout] call SC_fnc_setLoadout;
    player addWeaponGlobal (["Binocular", "Rangefinder"] select ("MRKS" in SC_var_perks));

    if ("MEDC" in SC_var_perks) then {
        player addItem "Medikit";
    } else {
        for "_i" from 1 to 4 do {
            player addItem "FirstAidKit";
        };
    };

    SC_var_lastLoadout = getUnitLoadout player;
};

SC_fnc_addXP = {
    params ["_xp"];

    player setVariable ["SC_var_xp", (player getVariable "SC_var_xp") + _xp];
    profileNamespace setVariable ["SC_var_xp", player getVariable "SC_var_xp"];
    saveProfileNamespace;
};

SC_fnc_getPlayersWeaponsItems = {
    ((primaryWeaponItems player) + (secondaryWeaponItems player) + (handgunItems player)) select {_x != ""}
};

SC_fnc_getItems = {
    params ["_side", "_perks", "_rank"];

    _strings = ([_side, _perks, _rank, false] call SC_fnc_getItemsForUnit) apply {_x select 0};
    _lockedMags = [side (group player), SC_var_perks, (player getVariable "SC_var_rank"), false] call SC_fnc_getLockedMags;
    
    _weps = _strings select {!((["Rifle", "Pistol", "Launcher"] arrayIntersect ([(configFile >> "CfgWeapons" >> _x), true] call BIS_fnc_returnParents)) isEqualTo [])};
    _bags = _strings select {"Bag_Base" in ([(configFile >> "CfgVehicles" >> _x), true] call BIS_fnc_returnParents)};
    _items = _strings select {("ItemCore" in ([(configFile >> "CfgWeapons" >> _x), true] call BIS_fnc_returnParents)) || {_x in ["Rangefinder", "Binocular", "Medikit", "FirstAidKit"]} || {(_x find "binoc") != -1} || {(_x find "NVGoggles") != -1}};
    _mags = _strings select {"CA_Magazine" in ([(configFile >> "CfgMagazines" >> _x), true] call BIS_fnc_returnParents)};

    {
        _weapon = _x;
        {
            _muzzle = _x;

            if (_muzzle == "this") then {
                _mags append (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines"));
            } else {
                _mags append (getArray (configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "magazines"));
            };
        } forEach (getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles"));
    } forEach _weps;

    _mags = _mags - _lockedMags;

    [_weps, _bags, _items, _mags]
};

SC_fnc_changePerks = {
    params ["_object", "_side", "_rank", "_newPerks", ["_removedEquipment", false]];

    [_object, (_object call BIS_fnc_getVirtualWeaponCargo)] call BIS_fnc_removeVirtualWeaponCargo;
    [_object, (_object call BIS_fnc_getVirtualBackpackCargo)] call BIS_fnc_removeVirtualBackpackCargo;
    [_object, (_object call BIS_fnc_getVirtualItemCargo)] call BIS_fnc_removeVirtualItemCargo;
    [_object, (_object call BIS_fnc_getVirtualMagazineCargo)] call BIS_fnc_removeVirtualMagazineCargo;

    ([_side, _newPerks, _rank] call SC_fnc_getItems) params ["_weps", "_bags", "_items", "_mags"];

    [_object, _weps, false, false] call BIS_fnc_addVirtualWeaponCargo;
    [_object, _bags, false, false] call BIS_fnc_addVirtualBackpackCargo;
    [_object, _items, false, false] call BIS_fnc_addVirtualItemCargo;
    [_object, _mags, false, true] call BIS_fnc_addVirtualMagazineCargo;

    _itemsPlayer = items player;

    if _removedEquipment then {
        {player removeWeapon _x;} forEach ((weapons player) select {!(_x in _weps)});
        {player removePrimaryWeaponItem _x;} forEach ((primaryWeaponItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeSecondaryWeaponItem _x;} forEach ((secondaryWeaponItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeHandgunItem _x;} forEach ((handgunItems player) select {(_x != "") && {!(_x in _items)}});
        {player removeItems _x;} forEach ((_itemsPlayer arrayIntersect _itemsPlayer) select {!(_x in _items)});
        _magsPlayer = magazines player;
        {player removeMagazines _x;} forEach ((_magsPlayer arrayIntersect _magsPlayer) select {!(_x in _mags)});
        if !((uniform player) in _items) then {removeUniform player};
        if !((vest player) in _items) then {removeVest player};
        if !((backpack player) in _bags) then {removeBackpackGlobal player};
        if !((headgear player) in _items) then {removeHeadgear player};
        if !((goggles player) in _items) then {removeGoggles player};
        if !((hmd player) in _items) then {player unlinkItem (hmd player)};
    };
    
    player setUnitTrait ["Medic", ("MEDC" in _newPerks)];
    player setVariable ["SC_var_hasExprPerk", ("EXPR" in _newPerks), true];
    _itemsPlayer = items player;

    if ("MEDC" in SC_var_perks) then {
        if ("FirstAidKit" in _itemsPlayer) then {
            player removeItems "FirstAidKit";
        };

        if !("Medikit" in _itemsPlayer) then {
            player addItem "Medikit";
        };
    } else {
        if !("FirstAidKit" in _itemsPlayer) then {
            for "_i" from 1 to 4 do {
                player addItem "FirstAidKit";
            };
        };
    };
    
    _currentBinocular = binocular player;
    _wantedBinocular = ["Binocular", "Rangefinder"] select ("MRKS" in SC_var_perks);

    if (_currentBinocular != _wantedBinocular) then {
        player removeWeaponGlobal _currentBinocular;
        player addWeaponGlobal _wantedBinocular;
    };

    call SC_fnc_saveLoadoutToProfile;
};

SC_fnc_isLoadoutValid = {
    _allowedItems = [];
    {{_allowedItems pushBack (toLower _x);} forEach _x;} forEach ([(side (group player)), SC_var_perks, (player getVariable "SC_var_rank")] call SC_fnc_getItems);

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

SC_fnc_arsenalOpened = {
    params ["_display"];

    call SC_fnc_setArsenalVisionMode;

    [_display] spawn {
        params ["_display"];

        _nightVisionScript = [] spawn SC_fnc_arsenalThermalLoop;
        _items = items player;
        _oldWepItems = call SC_fnc_getPlayersWeaponsItems;
        _lockedMags = [side (group player), SC_var_perks, (player getVariable "SC_var_rank"), false] call SC_fnc_getLockedMags;

        waitUntil {
            {
                player removeMagazines _x;
            } forEach ((magazines player) arrayIntersect _lockedMags);

            {
                if (_x in _lockedMags) then {player removePrimaryWeaponItem _x};
            } forEach (primaryWeaponMagazine player);

            {
                if (_x in _lockedMags) then {player removeSecondaryWeaponItem _x};
            } forEach (secondaryWeaponMagazine player);

            {
                if (_x in _lockedMags) then {player removeHandgunItem _x};
            } forEach (handgunMagazine player);
            
            (isNull _display)
        };

        if SC_var_nvGogglesEnabled then {
            player action ["nvGoggles", player];
        };

        terminate _nightVisionScript;
        _newWepItems = call SC_fnc_getPlayersWeaponsItems;
        {player removeItems _x;} forEach (_items arrayIntersect _newWepItems) select {!(_x in _oldWepItems)};

        player linkItem ((switch (side (group player)) do {
            case west: {"B"};
            case east: {"O"};
            case independent: {"I"};
        }) + "_UavTerminal");

        if (!DW_var_skipNight && {(hmd player) == ""} && {!("H_PilotHelmetFighter_" in (headgear player))} && {!(("Viper") in (headgear player))}) then {
            player linkItem (
                switch (side (group player)) do {
                    case west: {"NVGoggles"};
                    case east: {"NVGoggles_OPFOR"};
                    case independent: {"NVGoggles_INDEP"};
                }
            );
        };

        if (call SC_fnc_isLoadoutValid) then {
            _mags = magazines player;

            {
                _weapon = _x;
                {
                    _muzzle = _x;
                    {
                        _mag = _x;
                        if (_mag in _mags) then {
                            player addWeaponItem [_weapon, _mag, true];
                        };
                    } forEach (if (_muzzle == "this") then {
                        getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")
                    } else {
                        getArray (configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "magazines")
                    });                
                } forEach (getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles"));
            } forEach (weapons player);

            SC_var_lastLoadout = getUnitLoadout player;
            SC_var_lastLoadoutInfo = call SC_fnc_getLoadoutInfo;
            call SC_fnc_saveLoadoutToProfile;

            if SC_var_hudEnabled then {
                ["loadoutSaved"] call BIS_fnc_showNotification;
            };
        } else {
            ["loadoutNotSaved"] call BIS_fnc_showNotification;
        };
    };
};

SC_fnc_getLoadoutInfo = {
    _loadoutSide = side (group player);
    _nvGogglesRank = if ((hmd player) == "") then {-1} else {(SC_var_NvGogglesByRank select (SC_var_NvGogglesByRank findIf {(hmd player) in (_x select 1)})) select 0};
    _uniformRank = if ((uniform player) == "") then {-1} else {(SC_var_uniformsByRank select (SC_var_uniformsByRank findIf {(uniform player) in (_x select 1)})) select 0};
    _helmetRank = if ((headgear player) == "") then {-1} else {(SC_var_helmetsByRank select (SC_var_helmetsByRank findIf {(headgear player) in (_x select 1)})) select 0};
    _vestRank = if ((vest player) == "") then {-1} else {(SC_var_vestsByRank select (SC_var_vestsByRank findIf {(vest player) in (_x select 1)})) select 0};
    _backpackRank = if ((backpack player) == "") then {-1} else {(SC_var_BackpacksByRank select (SC_var_BackpacksByRank findIf {(backpack player) in (_x select 1)})) select 0};

    [_loadoutSide, _nvGogglesRank, _uniformRank, _helmetRank, _vestRank, _backpackRank]
};

SC_fnc_rankSystemLoop = {
    _newName = "[" + (str (player getVariable "SC_var_rank")) + "] " + ([player] call SC_fnc_getName);
    player setVariable ["TDI_var_name", _newName, true];
    player setVariable ["MM_var_name", _newName, true];
    
    [SC_var_equip, (side (group player)), (player getVariable "SC_var_rank"), SC_var_perks] call SC_fnc_changePerks;
    waitUntil {!isNil {player getVariable "SC_var_rank"}};
    SC_var_neededXp = SC_var_xpRanks select ((player getVariable "SC_var_rank") - 1);

    if (SC_var_neededXp > 0) then {
        waitUntil {
            waitUntil {(player getVariable "SC_var_xp") >= SC_var_neededXp};

            call {
                _rank = (player getVariable "SC_var_rank") + 1;
                player setVariable ["SC_var_rank", _rank, true];
                profileNamespace setVariable ["SC_var_rank", player getVariable "SC_var_rank"];
                saveProfileNamespace;
                _newName = "[" + (str _rank) + "] " + ([player] call SC_fnc_getName);
                player setVariable ["TDI_var_name", _newName, true];
                player setVariable ["MM_var_name", _newName, true];
                player setVariable ["SC_var_xp", ((player getVariable "SC_var_xp") - SC_var_neededXp), true];
                SC_var_neededXp = SC_var_xpRanks select (_rank - 1);
                SC_var_perks resize [(count ((SC_var_rankForPerkId select [1, 6]) select {_x <= _rank})), ""];
                [SC_var_equip, (side (group player)), _rank, SC_var_perks] call SC_fnc_changePerks;

                if SC_var_hudEnabled then {
                    ["rankUp", [str _rank]] call BIS_fnc_showNotification;
                };
            };

            (SC_var_neededXp <= 0)
        };
    };
};

SC_fnc_saveLoadoutToProfile = {
    _lastLoadout = profileNamespace getVariable ["SC_var_lastLoadout", []];
    _lastLoadout deleteAt (_lastLoadout findIf {(_x select 0) == SC_var_currentWorldGroup});
    _lastLoadout pushBack [SC_var_currentWorldGroup, +SC_var_lastLoadout];
    profileNamespace setVariable ["SC_var_lastLoadout", _lastLoadout];

    _lastLoadoutInfo = profileNamespace getVariable ["SC_var_lastLoadoutInfo", []];
    _lastLoadoutInfo deleteAt (_lastLoadoutInfo findIf {(_x select 0) == SC_var_currentWorldGroup});
    _lastLoadoutInfo pushBack [SC_var_currentWorldGroup, +SC_var_lastLoadoutInfo];
    profileNamespace setVariable ["SC_var_lastLoadoutInfo", _lastLoadoutInfo];

    _perks = profileNamespace getVariable ["SC_var_perks", []];
    _perks deleteAt (_perks findIf {(_x select 0) == SC_var_currentWorldGroup});
    _perks pushBack [SC_var_currentWorldGroup, +SC_var_perks];
    profileNamespace setVariable ["SC_var_perks", _perks];

    saveProfileNamespace;
};

SC_fnc_adjustLoadoutAndInfo = {
    SC_var_lastLoadoutInfo params ["_loadoutSide", "_nvGogglesRank", "_uniformRank", "_helmetRank", "_vestRank", "_backpackRank"];

    if (_loadoutSide != playerSide) then {
        player unlinkItem (((assigneditems player) select {"UavTerminal" in _x}) select 0);
        player linkItem ((switch (side (group player)) do {
            case west: {"B"};
            case east: {"O"};
            case independent: {"I"};
        }) + "_UavTerminal");

        player unlinkItem (hmd player);
        if (_nvGogglesRank != -1) then {
            player linkItem (((SC_var_NvGogglesByRank select (SC_var_NvGogglesByRank findIf {(_x select 0) == _nvGogglesRank})) select 1) select (SC_var_sides find playerSide));
        };

        if (_uniformRank == -1) then {
            removeUniform player;
        } else {
            _uniformItems = uniformItems player;
            removeUniform player;
            player forceAddUniform (((SC_var_UniformsByRank select (SC_var_UniformsByRank findIf {(_x select 0) == _uniformRank})) select 1) select (SC_var_sides find playerSide));
            {player addItemToUniform _x;} forEach _uniformItems;
        };

        removeHeadgear player;
        if (_helmetRank != -1) then {
            _helmetPos = SC_var_HelmetsByRank findIf {((_x select 0) == _helmetRank) && {!isNil {(_x select 1) select (SC_var_sides find playerSide)}}};
            player addHeadgear (if (_helmetPos == -1) then {
                _bestRank = -1;
                _bestHelmet = nil;

                {
                    _x params ["_rank", "_helmets"];

                    if (!(isNil {_helmets select (SC_var_sides find playerSide)}) && {_rank > _bestRank} && {_rank <= _helmetRank}) then {
                        _bestRank = _rank;
                        _bestHelmet = _helmets select (SC_var_sides find playerSide);
                    };
                } forEach SC_var_HelmetsByRank;

                _bestHelmet
            } else {
                ((SC_var_HelmetsByRank select _helmetPos) select 1) select (SC_var_sides find playerSide)
            });
        };

        if (_vestRank == -1) then {
            removeVest player;
        } else {
            _vestItems = vestItems player;
            removeVest player;
            player addVest (((SC_var_VestsByRank select (SC_var_VestsByRank findIf {(_x select 0) == _vestRank})) select 1) select (SC_var_sides find playerSide));
            {player addItemToVest _x;} forEach _vestItems;
        };

        if (_backpackRank == -1) then {
            removeBackpack player;
        } else {
            _backpackItems = backpackItems player;
            removeBackpack player;
            player addBackpack (((SC_var_BackpacksByRank select (SC_var_BackpacksByRank findIf {(_x select 0) == _backpackRank})) select 1) select (SC_var_sides find playerSide));
            {player addItemToBackpack _x;} forEach _backpackItems;
        };

        SC_var_lastLoadoutInfo set [0, playerSide];
        SC_var_lastLoadout = getUnitLoadout player;
    };
};