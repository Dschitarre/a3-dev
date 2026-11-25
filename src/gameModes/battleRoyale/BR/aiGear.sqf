// Server AI equipment decisions. Config profiles are cached; inventory and encounter context stay live.
BR_var_aiGearProfiles = createHashMap;
BR_var_aiGearUpgradeMargin = 1.2;

BR_fnc_aiItemType = {
    params ["_class"];
    private _key = "type:" + _class;
    private _type = BR_var_aiGearProfiles get _key;
    if (isNil "_type") then {
        _type = ([_class] call BIS_fnc_itemType) param [1, ""];
        BR_var_aiGearProfiles set [_key, _type];
    };
    _type
};

BR_fnc_aiWeaponProfile = {
    params ["_weapon"];
    private _key = "weapon:" + _weapon;
    private _profile = BR_var_aiGearProfiles get _key;
    if (isNil "_profile") then {
        private _cfg = configFile >> "CfgWeapons" >> _weapon;
        private _mag = configFile >> "CfgMagazines" >> ([_weapon] call BR_fnc_weaponMagazine);
        private _ammo = configFile >> "CfgAmmo" >> getText (_mag >> "ammo");
        private _hit = getNumber (_ammo >> "hit");
        private _speed = getNumber (_mag >> "initSpeed");
        if (_speed <= 0) then {_speed = getNumber (_ammo >> "typicalSpeed")};
        private _dispersion = 0.002;
        private _reload = 0.2;
        {
            private _mode = _cfg >> _x;
            private _value = getNumber (_mode >> "dispersion");
            if (_value > 0) then {_dispersion = _dispersion min _value};
            _value = getNumber (_mode >> "reloadTime");
            if (_value > 0) then {_reload = _reload min _value};
        } forEach getArray (_cfg >> "modes");
        private _reach = (40 max (_speed * 0.6 / (1 max (_dispersion * 1000)))) min 650;
        _profile = [1 max _hit, _reach, 1 / (0.06 max _reload), getNumber (_cfg >> "inertia"), getNumber (_mag >> "count")];
        BR_var_aiGearProfiles set [_key, _profile];
    };
    _profile
};

BR_fnc_aiExpectedRange = {
    params ["_unit"];
    // Remembered observations, never an unseen enemy's current position.
    private _contacts = _unit getVariable ["BR_var_aiContacts", []];
    private _recent = _contacts select {time - (_x select 2) < 15};
    if (_recent isNotEqualTo []) exitWith {30 max selectMin (_recent apply {_unit distance2D (_x select 1)})};
    60 max (250 min ((BR_var_zone param [5, 600]) * 0.35))
};

// All carried AND loaded rounds, including partially used magazines. Loaded magazines are not counted twice.
BR_fnc_aiLoadoutMagazines = {
    params ["_loadout"];
    private _result = [];
    {
        private _weapon = _loadout param [_x, []];
        {private _mag = _weapon param [_x, []]; if (count _mag >= 2) then {_result pushBack +_mag}} forEach [4, 5];
    } forEach [0, 1, 2];
    {
        {
            if (count _x >= 3 && {(_x select 0) isEqualType ""} && {isClass (configFile >> "CfgMagazines" >> (_x select 0))}) then {
                for "_i" from 1 to (_x select 1) do {_result pushBack [_x select 0, _x select 2]};
            };
        } forEach ((_loadout param [_x, []]) param [1, []]);
    } forEach [3, 4, 5];
    _result
};

BR_fnc_aiWeaponUtility = {
    params ["_unit", "_spec", "_magazines"];
    private _weapon = _spec param [0, ""];
    if (_weapon == "") exitWith {0};
    ([_weapon] call BR_fnc_aiWeaponProfile) params ["_hit", "_reach", "_rate", "_inertia", "_capacity"];
    private _compatible = [_weapon] call BR_fnc_weaponMagazines;
    private _rounds = 0;
    {if ((toLowerANSI (_x select 0)) in _compatible) then {_rounds = _rounds + (_x select 1)}} forEach _magazines;
    private _loaded = _spec param [4, []];
    if (count _loaded >= 2) then {_rounds = _rounds + (_loaded select 1)};
    private _distance = [_unit] call BR_fnc_aiExpectedRange;
    private _fit = (0.15 max (_reach / (_distance max _reach))) / (1 + _inertia * (100 / (_distance max 50)));
    private _supply = if (_rounds <= 0) then {0} else {(_rounds / ((8 max (_capacity * 2)) min 90)) min 1};
    _hit * sqrt _rate * _fit * _supply
};

BR_fnc_aiAttachmentValue = {
    params ["_unit", "_class"];
    if (_class == "") exitWith {[-1, 0]};
    private _key = "attachment:" + _class;
    private _profile = BR_var_aiGearProfiles get _key;
    if (isNil "_profile") then {
        private _cfg = configFile >> "CfgWeapons" >> _class >> "ItemInfo";
        private _type = [_class] call BR_fnc_aiItemType;
        private _slot = switch (_type) do {
            case "AccessorySights": {3}; case "AccessoryMuzzle": {1};
            case "AccessoryPointer": {2}; case "AccessoryBipod": {6}; default {-1};
        };
        private _magnification = 1;
        {
            private _zoom = getNumber (_x >> "opticsZoomMin");
            if (_zoom > 0) then {_magnification = _magnification max (0.25 / _zoom)};
        } forEach ("true" configClasses (_cfg >> "OpticsModes"));
        _profile = [_slot, _magnification];
        BR_var_aiGearProfiles set [_key, _profile];
    };
    _profile params ["_slot", "_magnification"];
    private _desired = 1 max (([_unit] call BR_fnc_aiExpectedRange) / 100) min 6;
    private _value = if (_slot == 3) then {2 / (1 + abs (ln (_magnification / _desired)))} else {
        if (_slot == 6) then {([_unit] call BR_fnc_aiExpectedRange) / 250 min 1} else {1}
    };
    [_slot, _value]
};

BR_fnc_aiObservationValue = {
    params ["_class"];
    if (_class == "") exitWith {0};
    private _key = "observation:" + _class;
    private _value = BR_var_aiGearProfiles get _key;
    if (isNil "_value") then {
        private _cfg = configFile >> "CfgWeapons" >> _class;
        private _modes = (getArray (_cfg >> "visionMode") + getArray (_cfg >> "ItemInfo" >> "visionMode")) apply {toLowerANSI _x};
        private _range = getNumber (_cfg >> "laserRangeFinder") > 0 || {
            (toLowerANSI getText (_cfg >> "weaponInfoType")) find "rangefinder" >= 0
        };
        _value = 1 + ([0, 2] select ("ti" in _modes)) + ([0, 1] select _range) +
            ([0, 2] select (([_class] call BR_fnc_aiItemType) == "LaserDesignator"));
        BR_var_aiGearProfiles set [_key, _value];
    };
    _value
};

// Container capacity and protection of the actual game config, not rarity or hand-written weapon-class lists.
BR_fnc_aiClothingProfile = {
    params ["_class", "_backpack"];
    if (_class == "") exitWith {[0, 0, false]};
    private _key = "clothing:" + _class;
    private _profile = BR_var_aiGearProfiles get _key;
    if (isNil "_profile") then {
        private _cfg = configFile >> "CfgWeapons" >> _class >> "ItemInfo";
        private _capacity = if (_backpack) then {getNumber (configFile >> "CfgVehicles" >> _class >> "maximumLoad")} else {
            getNumber (configFile >> "CfgVehicles" >> getText (_cfg >> "containerClass") >> "maximumLoad")
        };
        private _uniformClass = getText (_cfg >> "uniformClass");
        private _hitPoints = if (_uniformClass == "") then {_cfg >> "HitpointsProtectionInfo"} else {
            configFile >> "CfgVehicles" >> _uniformClass >> "HitPoints"
        };
        private _protection = 0;
        {
            _protection = _protection + getNumber (_x >> "armor") * (1 - getNumber (_x >> "passThrough"));
        } forEach ("true" configClasses _hitPoints);
        // Uniforms inherit their wearer's side. Civilian clothes can have the same storage/protection,
        // so those two numbers alone never cause an upgrade to a combat uniform.
        private _military = _uniformClass != "" && {
            getNumber (configFile >> "CfgVehicles" >> _uniformClass >> "side") in [0, 1, 2]
        };
        _profile = [_capacity, _protection, _military];
        BR_var_aiGearProfiles set [_key, _profile];
    };
    _profile
};

BR_fnc_aiMagazineMass = {
    params ["_class"];
    private _key = "mass:" + toLowerANSI _class;
    private _mass = BR_var_aiGearProfiles get _key;
    if (isNil "_mass") then {
        _mass = getNumber (configFile >> "CfgMagazines" >> _class >> "mass");
        BR_var_aiGearProfiles set [_key, _mass];
    };
    _mass
};

/*
    The largest free space in one of the containers (uniform, vest, backpack) of _loadout - a magazine goes into one of
    them. A worn container swapped for a better one keeps its contents (BR_fnc_aiTakeGear): their mass is the unit's now.
*/
BR_fnc_aiFreeLoad = {
    params ["_unit", "_loadout"];
    private _free = 0;
    {
        _x params ["_slot", "_worn", "_load", "_backpack"];
        private _class = (_loadout select _slot) param [0, ""];
        if (_class != "") then {
            private _used = _load * (([_worn, _backpack] call BR_fnc_aiClothingProfile) select 0);
            _free = _free max ((([_class, _backpack] call BR_fnc_aiClothingProfile) select 0) - _used);
        };
    } forEach [
        [3, uniform _unit, loadUniform _unit, false], [4, vest _unit, loadVest _unit, false],
        [5, backpack _unit, loadBackpack _unit, true]
    ];
    _free
};

/*
    True if the unit can keep _weapon supplied: it carries ammunition for it, or one of its magazines lying here
    (_cargo [class, rounds]) or its standard magazine fits into _free. Machine gunners without vest or backpack could not
    take a single belt, and the engine's rearming tried it for good: they stood until the zone killed them (up to 18 min,
    6-7 AI per match).
*/
BR_fnc_aiCanFeed = {
    params ["_weapon", "_carried", "_cargo", "_free"];
    if (_weapon == "") exitWith {false};
    private _compatible = [_weapon] call BR_fnc_weaponMagazines;
    if ((_carried findIf {(toLowerANSI (_x select 0)) in _compatible}) != -1) exitWith {true};
    private _classes = ((_cargo apply {toLowerANSI (_x select 0)}) select {_x in _compatible}) + [[_weapon] call BR_fnc_weaponMagazine];
    (_classes findIf {([_x] call BR_fnc_aiMagazineMass) <= _free}) != -1
};

// a supply of _class (bandage, drink, grenade, medical item) still leaves room for a spare magazine of the primary
BR_fnc_aiRoomForSupply = {
    params ["_unit", "_class", ["_isItem", false]];
    private _primary = primaryWeapon _unit;
    if (_primary == "") exitWith {true};
    private _mass = if (_isItem) then {getNumber (configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "mass")} else {
        [_class] call BR_fnc_aiMagazineMass
    };
    ([_unit, getUnitLoadout _unit] call BR_fnc_aiFreeLoad) - _mass >= ([[_primary] call BR_fnc_weaponMagazine] call BR_fnc_aiMagazineMass)
};

// Lossless cargo snapshots: weapon attachments, loaded/partial magazines and nested container contents survive a take.
BR_fnc_aiReadCargo = {
    params ["_container"];
    private _nested = everyContainer _container;
    private _items = [];
    private _bags = [];
    {
        private _destination = [_items, _bags] select _forEachIndex;
        {
            private _class = _x;
            private _index = _nested findIf {(_x select 0) == _class};
            private _content = [];
            if (_index >= 0) then {
                private _entry = _nested deleteAt _index;
                _content = [_entry select 1] call BR_fnc_aiReadCargo;
            };
            _destination pushBack [_class, _content];
        } forEach _x;
    } forEach [itemCargo _container, backpackCargo _container];
    [weaponsItemsCargo _container, magazinesAmmoCargo _container, _items, _bags]
};

BR_fnc_aiWriteCargo = {
    params ["_container", "_cargo"];
    _cargo params ["_weapons", "_magazines", "_items", "_bags"];
    // An empty ground holder may be scheduled for deletion before refilling it. Keep one cargo category alive.
    // The temporary tokens are removed within this unscheduled transaction, never offered as loot.
    _container addItemCargoGlobal ["ItemWatch", 1];
    clearWeaponCargoGlobal _container;
    clearMagazineCargoGlobal _container;
    clearBackpackCargoGlobal _container;
    {_container addWeaponWithAttachmentsCargoGlobal [_x, 1]} forEach _weapons;
    {_container addMagazineAmmoCargo [_x select 0, 1, _x select 1]} forEach _magazines;
    {_container addBackpackCargoGlobal [_x select 0, 1]} forEach _bags;
    private _onlyItems = _weapons isEqualTo [] && {_magazines isEqualTo []} && {_bags isEqualTo []};
    if (_onlyItems) then {_container addMagazineCargoGlobal ["SmokeShell", 1]};
    clearItemCargoGlobal _container;
    {_container addItemCargoGlobal [_x select 0, 1]} forEach _items;
    if (_onlyItems) then {clearMagazineCargoGlobal _container};
    private _nested = everyContainer _container;
    {
        _x params ["_class", "_content"];
        private _index = _nested findIf {(_x select 0) == _class};
        if (_index >= 0) then {
            private _entry = _nested deleteAt _index;
            if (_content isNotEqualTo []) then {[_entry select 1, _content] call BR_fnc_aiWriteCargo};
        };
    } forEach (_items + _bags);
};

BR_fnc_aiCanReachLoot = {
    params ["_unit", "_source", ["_reach", BR_var_aiLootReach]];
    if (isNull _source) exitWith {false};
    (boundingBoxReal _source) params ["_min", "_max"];
    private _local = _source worldToModel (getPosATL _unit);
    private _surface = _source modelToWorld [
        ((_local select 0) max (_min select 0)) min (_max select 0),
        ((_local select 1) max (_min select 1)) min (_max select 1), 0
    ];
    // Supply drops use their existing interaction radius; small ground holders retain the shorter pickup reach.
    private _crate = _source in (missionNamespace getVariable ["BR_var_airdropCrates", []]);
    private _inReach = if (_crate) then {_unit distance2D _source <= BR_var_aiCrateReach} else {
        _unit distance2D _surface <= _reach
    };
    _inReach &&
    {abs (((getPosASL _unit) select 2) - ((getPosASL _source) select 2)) <= BR_var_aiLootFloorHeight} && {
        private _points = [(getPosASL _source) vectorAdd [0, 0, 0.2], getPosWorld _source];
        if (_source isKindOf "CAManBase") then {_points pushBack eyePos _source};
        _points findIf {([_unit, "GEOM", _source] checkVisibility [eyePos _unit, _x]) > 0} >= 0
    }
};

// Convert equipped corpse gear only when a looter has physically reached it. The caller runs unscheduled.
// One real holder retains everything the looter leaves behind, including partial magazines and container cargo.
BR_fnc_aiCorpseLoot = {
    params ["_body", "_looter"];
    if (alive _body || {!(_body isKindOf "CAManBase")}) exitWith {objNull};
    if (!isNil {_body getVariable "BR_var_uniformReservation"}) exitWith {objNull};
    if (_body getVariable ["BR_var_lootTransferred", false]) exitWith {
        _body getVariable ["BR_var_corpseLoot", objNull]
    };
    private _loadout = getUnitLoadout _body;
    private _cargo = [[], [], [], []];
    {
        private _weapon = _loadout param [_x, []];
        if ((_weapon param [0, ""]) != "") then {(_cargo select 0) pushBack _weapon};
    } forEach [0, 1, 2, 8];
    {
        _x params ["_slot", "_container"];
        private _class = (_loadout param [_slot, []]) param [0, ""];
        if (_class != "") then {
            (_cargo select ([2, 3] select (_slot == 5))) pushBack [_class, [_container] call BR_fnc_aiReadCargo];
        };
    } forEach [[3, uniformContainer _body], [4, vestContainer _body], [5, backpackContainer _body]];
    {
        if (_x != "") then {(_cargo select 2) pushBack [_x, []]};
    } forEach ([_loadout select 6, _loadout select 7] + (_loadout select 9));
    // Keep the pile beside the reached corpse, rather than inside its collision geometry.
    private _holder = [_looter] call BR_fnc_uniformGroundHolder;
    if (isNull _holder) exitWith {objNull};
    [_holder, _cargo] call BR_fnc_aiWriteCargo;
    // setUnitLoadout on a dead man does not reliably remove worn containers in the engine.
    removeAllWeapons _body;
    removeAllAssignedItems _body;
    removeUniform _body;
    removeVest _body;
    removeBackpack _body;
    removeHeadgear _body;
    removeGoggles _body;
    _body setVariable ["BR_var_lootTransferred", true];
    _body setVariable ["BR_var_corpseLoot", _holder];
    _holder
};

// The function commits atomically in aiTakeLoot, so two units cannot both take the same weapon.
// _rearm: the engine's rearming failed (BR_fnc_aiRearmNearby): ammo for the weapons is taken as long as it fits - the
// engine wanted more than the reserve below (an LMG gunner with a full 200-round box looped for 6 minutes)
BR_fnc_aiTakeGear = {
    params ["_unit", "_container", ["_rearm", false]];
    if (!isNil {_container getVariable "BR_var_uniformReservation"}) exitWith {0};
    if !([_unit, _container] call BR_fnc_aiCanReachLoot) exitWith {0};
    // The engine aborts setUnitLoadout while switching weapons; never remove cargo during that state.
    if (isSwitchingWeapon _unit || {_unit getVariable ["BR_var_bandaging", false]}) exitWith {0};
    private _cargo = [_container] call BR_fnc_aiReadCargo;
    _cargo params ["_weapons", "_magazines", "_items", "_bags"];
    private _loadout = getUnitLoadout _unit;
    private _original = parseSimpleArray str _loadout;
    private _oldWeaponMagazines = [];
    {_oldWeaponMagazines append ([_x param [0, ""]] call BR_fnc_weaponMagazines)} forEach (_loadout select [0, 3]);
    private _taken = 0;

    // Upgrade storage without losing its carried contents. Empty incoming containers back into real loot first.
    {
        _x params ["_slot", "_pool", "_category"];
        private _current = (_loadout select _slot) param [0, ""];
        ([_current, _slot == 5] call BR_fnc_aiClothingProfile) params ["_capacity", "_armor", "_military"];
        private _best = -1;
        private _currentValue = _capacity + _armor * 10 + ([0, 40] select _military);
        private _bestValue = _currentValue;
        {
            private _class = _x select 0;
            if (_category == "backpacks" || {([_class] call BR_fnc_lootCategory) == _category}) then {
                ([_class, _slot == 5] call BR_fnc_aiClothingProfile) params ["_newCapacity", "_newArmor", "_newMilitary"];
                private _value = _newCapacity + _newArmor * 10 + ([0, 40] select _newMilitary);
                if (_newCapacity >= _capacity && {_newArmor >= _armor} &&
                    {_value > _currentValue * 1.1 + 1} && {_value > _bestValue}) then {
                    _best = _forEachIndex;
                    _bestValue = _value;
                };
            };
        } forEach _pool;
        if (_best >= 0) then {
            (_pool deleteAt _best) params ["_class", "_content"];
            if (_content isNotEqualTo []) then {
                {(_cargo select _forEachIndex) append _x} forEach _content;
            };
            _loadout set [_slot, [_class, (_loadout select _slot) param [1, []]]];
            if (_current != "") then {_pool pushBack [_current, []]};
            _taken = _taken + 1;
        };
    } forEach [[5, _bags, "backpacks"], [4, _items, "vests"], [3, _items, "uniforms"]];
    private _helmet = _loadout select 6;
    private _helmetValue = ([_helmet, false] call BR_fnc_aiClothingProfile) select 1;
    private _helmetIndex = -1;
    {
        if (([_x select 0] call BR_fnc_lootCategory) == "helmets") then {
            private _value = ([_x select 0, false] call BR_fnc_aiClothingProfile) select 1;
            if((_helmet == "" && {_helmetIndex < 0}) ||
                {_value > _helmetValue * 1.1 + 0.1}) then {_helmetIndex = _forEachIndex; _helmetValue = _value};
        };
    } forEach _items;
    if (_helmetIndex >= 0) then {
        _loadout set [6, (_items deleteAt _helmetIndex) select 0];
        if (_helmet != "") then {_items pushBack [_helmet, []]};
        _taken = _taken + 1;
    };

    // A replacement must be materially better for this encounter AND its available ammunition. Only ammunition the unit
    // can carry counts, and only weapons it can keep supplied are taken (BR_fnc_aiCanFeed).
    private _free = [_unit, _loadout] call BR_fnc_aiFreeLoad;
    private _fitting = _magazines select {([_x select 0] call BR_fnc_aiMagazineMass) <= _free};
    {
        _x params ["_slot", "_category"];
        private _current = _loadout select _slot;
        private _carried = [_loadout] call BR_fnc_aiLoadoutMagazines;
        // Current loaded rounds are already represented by its weapon spec in the scoring call.
        private _loaded = _current param [4, []];
        private _index = _carried find _loaded;
        if (_index >= 0) then {_carried deleteAt _index};
        private _available = _carried + _fitting;
        // a weapon the unit cannot supply counts as none: any it can supply replaces it
        private _currentUsable = [_current param [0, ""], _carried, _magazines, _free] call BR_fnc_aiCanFeed;
        private _score = if (_currentUsable) then {[_unit, _current, _available] call BR_fnc_aiWeaponUtility} else {0};
        private _minimum = _score * BR_var_aiGearUpgradeMargin + 0.1;
        private _best = -1;
        {
            if (([_x select 0] call BR_fnc_lootCategory) == _category && {[_x select 0, _carried, _magazines, _free] call BR_fnc_aiCanFeed}) then {
                private _value = [_unit, _x, _available] call BR_fnc_aiWeaponUtility;
                if ((_value > _minimum || {!_currentUsable}) &&
                    {(_best < 0) || {_value > _score}}) then {_best = _forEachIndex; _score = _value};
            };
        } forEach _weapons;
        if (_best >= 0) then {
            private _replacement = _weapons deleteAt _best;
            if ((_current param [0, ""]) != "") then {
                // Put old attachments on the same physical loot pile; useful ones may transfer to the new gun below.
                {
                    private _item = _current param [_x, ""];
                    if (_item != "") then {_items pushBack [_item, []]; _current set [_x, ""]};
                } forEach [1, 2, 3, 6];
                _weapons pushBack _current;
            };
            private _mag = _replacement param [4, []];
            if (_mag isEqualTo [] || {(_mag param [1, 0]) == 0}) then {
                private _compatible = [_replacement select 0] call BR_fnc_weaponMagazines;
                private _magIndex = _magazines findIf {(toLowerANSI (_x select 0)) in _compatible && {(_x select 1) > 0}};
                if (_magIndex >= 0) then {
                    if (_mag isNotEqualTo []) then {_magazines pushBack _mag};
                    _replacement set [4, _magazines deleteAt _magIndex];
                };
            };
            _loadout set [_slot, _replacement];
            _taken = _taken + 1;
        };
    } forEach [[0, "primaries"], [2, "handguns"]];
    // Binoculars/rangefinders/designators are engine weapons, including their loaded batteries.
    private _observer = _loadout select 8;
    private _observerValue = [_observer param [0, ""]] call BR_fnc_aiObservationValue;
    private _observerIndex = -1;
    {
        if (([_x select 0] call BR_fnc_aiItemType) in ["Binocular", "LaserDesignator"]) then {
            private _value = [_x select 0] call BR_fnc_aiObservationValue;
            if (_value > _observerValue) then {_observerIndex = _forEachIndex; _observerValue = _value};
        };
    } forEach _weapons;
    if (_observerIndex >= 0) then {
        private _replacement = _weapons deleteAt _observerIndex;
        if ((_replacement param [4, []]) isEqualTo []) then {
            private _compatible = [_replacement select 0] call BR_fnc_weaponMagazines;
            private _index = _magazines findIf {(toLowerANSI (_x select 0)) in _compatible};
            if (_index >= 0) then {_replacement set [4, _magazines deleteAt _index]};
        };
        if ((_observer param [0, ""]) != "") then {_weapons pushBack _observer};
        _loadout set [8, _replacement];
        _taken = _taken + 1;
    };
    private _primarySpec = _loadout select 0;
    private _compatibleItems = (compatibleItems (_primarySpec param [0, ""])) apply {toLowerANSI _x};
    private _remainingItems = [];
    {
        _x params ["_class", "_content"];
        private _take = false;
        private _itemType = [_class] call BR_fnc_aiItemType;
        private _oldNvg = (_loadout select 9) param [5, ""];
        if (_itemType == "NVGoggles" && {([_class] call BR_fnc_aiObservationValue) > ([_oldNvg] call BR_fnc_aiObservationValue)}) then {
            (_loadout select 9) set [5, _class];
            if (_oldNvg != "") then {_remainingItems pushBack [_oldNvg, []]};
            _take = true;
            _taken = _taken + 1;
        };
        private _oldObserver = (_loadout select 8) param [0, ""];
        if (_itemType in ["Binocular", "LaserDesignator"] && {([_class] call BR_fnc_aiObservationValue) > ([_oldObserver] call BR_fnc_aiObservationValue)}) then {
            private _compatible = [_class] call BR_fnc_weaponMagazines;
            private _index = _magazines findIf {(toLowerANSI (_x select 0)) in _compatible};
            private _battery = if (_index >= 0) then {_magazines deleteAt _index} else {[]};
            private _oldBattery = (_loadout select 8) param [4, []];
            if (_oldBattery isNotEqualTo []) then {_magazines pushBack _oldBattery};
            if (_oldObserver != "") then {_remainingItems pushBack [_oldObserver, []]};
            _loadout set [8, [_class, "", "", "", _battery, [], ""]];
            _take = true;
            _taken = _taken + 1;
        };
        if ((toLowerANSI _class) in _compatibleItems) then {
            ([_unit, _class] call BR_fnc_aiAttachmentValue) params ["_slot", "_value"];
            if (_slot >= 0) then {
                private _old = _primarySpec param [_slot, ""];
                private _oldValue = ([_unit, _old] call BR_fnc_aiAttachmentValue) select 1;
                if (_value > _oldValue * 1.2 + 0.1) then {
                    _primarySpec set [_slot, _class];
                    if (_old != "") then {_remainingItems pushBack [_old, []]};
                    _taken = _taken + 1;
                    _take = true;
                };
            };
        };
        if (!_take) then {_remainingItems pushBack _x};
    } forEach _items;
    _cargo set [2, _remainingItems];
    _items = _remainingItems;
    private _usefulMagazines = [];
    {_usefulMagazines append ([_x param [0, ""]] call BR_fnc_weaponMagazines)} forEach (_loadout select [0, 3]);
    {
        private _contents = (_loadout select _x) param [1, []];
        private _keepContents = [];
        {
            private _class = _x param [0, ""];
            if(_class isEqualType "" && {(toLowerANSI _class) in _oldWeaponMagazines} &&
                {!((toLowerANSI _class) in _usefulMagazines)} && {count _x >= 3}) then {
                for "_n" from 1 to (_x select 1) do {_magazines pushBack [_class, _x select 2]};
            } else {_keepContents pushBack _x};
        } forEach _contents;
        if (count (_loadout select _x) >= 2) then {(_loadout select _x) set [1, _keepContents]};
    } forEach [3, 4, 5];
    if (_taken > 0) then {_unit setUnitLoadout [_loadout, false]};
    private _applied = getUnitLoadout _unit;
    private _equipmentApplied = [0, 2, 3, 4, 5, 6, 8, 9] findIf {
        private _wanted = _loadout select _x;
        private _actual = _applied select _x;
        if (_x == 9) then {_wanted = _wanted param [5, ""]; _actual = _actual param [5, ""]} else {
            if (_x != 6) then {_wanted = _wanted param [0, ""]; _actual = _actual param [0, ""]};
        };
        _wanted != _actual
    };
    if (_equipmentApplied >= 0) exitWith {
        _unit setUnitLoadout [_original, false];
        diag_log "BR AI gear: engine rejected equipment change; cargo was not consumed";
        0
    };

    // Keep supplies useful to the CURRENT weapons, with a finite reserve for medical items and throwables.
    private _reserve = [_loadout] call BR_fnc_aiLoadoutMagazines;
    private _primary = primaryWeapon _unit;
    private _handgun = handgunWeapon _unit;
    private _keep = [];
    {
        _x params ["_class", "_rounds"];
        private _weapon = if ((toLowerANSI _class) in ([_primary] call BR_fnc_weaponMagazines)) then {_primary} else {
            [_handgun, ""] select (!((toLowerANSI _class) in ([_handgun] call BR_fnc_weaponMagazines)))
        };
        private _limit = switch (true) do {
            case (_class == BR_var_bandageClass): {6};
            case (_class == BR_var_drinkClass): {3};
            case (([_class] call BR_fnc_lootCategory) == "throwables"): {2};
            default {0};
        };
        private _wanted = false;
        if (_weapon != "" && {_rounds > 0}) then {
            private _compatible = [_weapon] call BR_fnc_weaponMagazines;
            private _carriedRounds = 0;
            {if ((toLowerANSI (_x select 0)) in _compatible) then {_carriedRounds = _carriedRounds + (_x select 1)}} forEach _reserve;
            private _capacity = getNumber (configFile >> "CfgMagazines" >> _class >> "count");
            _wanted = _rearm || {_carriedRounds < ((40 max (_capacity * ([4, 2] select (_weapon == _handgun)))) min 180)};
        } else {
            _wanted = _limit > 0 && {({_class == (_x select 0)} count _reserve) < _limit} && {[_unit, _class] call BR_fnc_aiRoomForSupply};
        };
        if (_wanted && {_unit canAdd _class}) then {
            _unit addMagazine [_class, _rounds];
            _reserve pushBack [_class, _rounds];
            _taken = _taken + 1;
        } else {_keep pushBack _x};
    } forEach _magazines;
    _cargo set [1, _keep];
    private _keptItems = [];
    {
        _x params ["_class", "_content"];
        private _take = ([_class] call BR_fnc_lootCategory) == "medical" &&
            {({_x == _class} count items _unit) < ([3, 1] select (_class == "Medikit"))} && {_unit canAdd _class} &&
            {[_unit, _class, true] call BR_fnc_aiRoomForSupply};
        if (_take) then {_unit addItem _class; _taken = _taken + 1} else {_keptItems pushBack _x};
    } forEach _items;
    _cargo set [2, _keptItems];
    if (_taken > 0) then {[_container, _cargo] call BR_fnc_aiWriteCargo};
    if (_taken > 0 && {_container isKindOf "GroundWeaponHolder"} && {([_container] call BR_fnc_cargoCount) == 0}) then {deleteVehicle _container};
    _taken
};
