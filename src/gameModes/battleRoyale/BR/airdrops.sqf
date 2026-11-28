// Battle Royale supply drops (server): with some zone phases a crate of top gear comes down on a parachute somewhere
// in the next safe zone, announced to everyone; clients draw the crates on the map (BR_var_airdropCrates).

BR_var_airdropFirstPhase = 3;               // zone phases from this one on bring a supply drop (zone 1: the whole map) ...
BR_var_airdropQuietPhases = 2;              // ... except the last ones: more drops in bigger areas (more phases)
BR_var_airdropCrateType = "box_NATO_equip_F";
BR_var_airdropParachuteType = "B_Parachute_02_F";   // the big cargo parachute (as in Sector Control) ...
BR_var_airdropCrateOffset = [0, 0, -1.3];          // ... with the crate hanging below it
BR_var_airdropHeight = 200;                 // start height above the ground
BR_var_airdropFallSpeed = 5;                // m/s
BR_var_airdropFallTimeout = 120;            // s: the descent ends after this at the latest ...
BR_var_airdropLandTimeout = 15;             // ... and the crate gets this long to settle before the parachute goes
BR_var_airdropZoneShare = 0.8;              // the crate lands within this share of the next zone's radius
BR_var_airdropSmoke = "SmokeShellPurple";

/*
    Crate content: a fixed kit worth the risk, picked generically from the loaded pools and the game config (BR_fnc_initAirdropKit,
    once per mission), on every map: a strong primary with an optic and ammo, armor, a big backpack, healing and
    throwables, plus a few random elite rolls on top.
*/
BR_var_airdropWeaponClasses = ["assaultRifles", "marksman", "snipers", "antiMateriel", "machineGuns"]; // the primary's classes (BR_var_lootWeaponClasses), by their military-site shares ...
BR_var_airdropWeaponTopShare = 1 / 3;       // ... and the best third of each class's families (quality score, BR_fnc_initLootWeapons)
BR_var_airdropWeaponMagazines = [4, 6];     // magazines of its default ammo, random in [min, max]
BR_var_airdropOpticZoom = createHashMapFromArray [["assaultRifles", 3], ["machineGuns", 3], ["marksman", 6], ["snipers", 10], ["antiMateriel", 10]]; // wanted magnification of its optic ...
BR_var_airdropOpticZoomDefault = 3;         // ... for other classes (a fallback weapon)
BR_var_airdropOpticSpread = 1.5;            // the optics of the pool that fit the weapon and come within this factor of the best fit
BR_var_airdropArmorLevel = 3;               // vest and helmet of at least this armor level (BR_var_armorLevelThresholds), else the pool's best
BR_var_airdropBackpackTopShare = 1 / 3;     // backpack: the largest third of the pool by capacity
// healing: [cargo type, class, [min, max]]; Bandage and Antibiotic carry the bandage and the energy drink (BR\items.sqf)
BR_var_airdropMedical = [["item", "Medikit", [1, 1]], ["item", "FirstAidKit", [2, 2]], ["magazine", "Bandage", [3, 5]], ["magazine", "Antibiotic", [2, 3]]];
BR_var_airdropThrowables = [1, 2];          // throwables (one class of the pool's best tier), random in [min, max]
BR_var_airdropRolls = 2;                    // random loot rolls on top (BR_var_tierWeightsAirdrop); their ammo is for the crate's weapons
BR_var_airdropKit = nil;                    // BR_fnc_initAirdropKit

BR_fnc_isAirdropPhase = {
    params ["_phase", "_phaseCount"];

    _phase >= BR_var_airdropFirstPhase && {_phase <= _phaseCount - BR_var_airdropQuietPhases}
};

// scheduled
BR_fnc_airdrop = {
    BR_var_zone params ["", "", "", "", "_nextCenter", "_nextRadius"];

    private _landPos = [_nextCenter, _nextRadius * BR_var_airdropZoneShare, true] call BR_fnc_randomLandPos;
    private _crate = createVehicle [BR_var_airdropCrateType, [0, 0, 0], [], 0, "NONE"];
    private _startHeight = ((AGLToASL _landPos) select 2) + BR_var_airdropHeight;
    private _parachute = createVehicle [BR_var_airdropParachuteType, _landPos vectorAdd [0, 0, BR_var_airdropHeight], [], 0, "FLY"];

    [_crate, false] call ADG_fnc_allowDamage;
    clearItemCargoGlobal _crate;
    clearWeaponCargoGlobal _crate;
    clearMagazineCargoGlobal _crate;
    clearBackpackCargoGlobal _crate;
    private _content = call BR_fnc_rollAirdropContent;
    [_crate, _content] call BR_fnc_addLootCargo;
    diag_log format ["BR airdrop content: grid %1: %2", mapGridPosition _landPos, [_content] call BR_fnc_airdropContentText];

    _parachute setPosASL [_landPos select 0, _landPos select 1, _startHeight];
    _crate attachTo [_parachute, BR_var_airdropCrateOffset];

    BR_var_airdropCrates = (BR_var_airdropCrates - [objNull]) + [_crate];
    publicVariable "BR_var_airdropCrates";
    ["brAirdrop", [mapGridPosition _landPos]] call BR_fnc_notifyAll;

    // a scripted descent straight down: no drifting out of the zone
    private _startTime = time;

    waitUntil {
        _parachute setPosASL [_landPos select 0, _landPos select 1, _startHeight - BR_var_airdropFallSpeed * (time - _startTime)];
        _parachute setVectorDirAndUp [[0, 1, 0], [0, 0, 1]];
        _parachute setVelocity [0, 0, 0];

        isNull _parachute || {((getPos _crate) select 2) < 2} || {time > _startTime + BR_var_airdropFallTimeout}
    };

    detach _crate;

    private _landTimeout = time + BR_var_airdropLandTimeout;

    waitUntil {
        sleep 0.5;
        isTouchingGround _crate || {vectorMagnitude velocity _crate < 0.1} || {time > _landTimeout}
    };

    deleteVehicle _parachute;
    _crate setVectorUp (surfaceNormal (getPosATL _crate));
    createVehicle [BR_var_airdropSmoke, getPosATL _crate, [], 0, "CAN_COLLIDE"];
};

// ---- crate content ----

// the armor level of a vest or helmet as the inventory shows it (BR\items.sqf: protection against
// BR_var_armorLevelThresholds by ItemInfo type, 701 vests, 605 headgear)
BR_fnc_airdropArmorLevel = {
    params ["_class", "_itemType"];

    private _protection = ([_class, false] call BR_fnc_aiClothingProfile) select 1;

    {_protection >= _x} count (BR_var_armorLevelThresholds getOrDefault [_itemType, []])
};

// every class of a loot category in the loaded pools, all tiers
BR_fnc_airdropPoolClasses = {
    params ["_category"];

    private _classes = [];
    {_classes append _x} forEach (BR_var_lootPools getOrDefault [_category, []]);

    _classes arrayIntersect _classes
};

// the vests or helmets of the pools of at least BR_var_airdropArmorLevel; a pool without any gives its best protected
BR_fnc_airdropArmorClasses = {
    params ["_category", "_itemType"];

    private _classes = [_category] call BR_fnc_airdropPoolClasses;
    if (_classes isEqualTo []) exitWith {[]};

    private _levels = _classes apply {[_x, _itemType] call BR_fnc_airdropArmorLevel};
    private _minLevel = BR_var_airdropArmorLevel min (selectMax _levels);
    private _chosen = [];
    {if ((_levels select _forEachIndex) >= _minLevel) then {_chosen pushBack _x}} forEach _classes;

    // a lower level says little (a cap and a light helmet can share level 0): then the best protection only
    if (_minLevel < BR_var_airdropArmorLevel) then {
        private _best = selectMax (_chosen apply {([_x, false] call BR_fnc_aiClothingProfile) select 1});
        _chosen = _chosen select {(([_x, false] call BR_fnc_aiClothingProfile) select 1) >= _best};
    };

    _chosen
};

// an optic's magnification: its strongest zoom against the default field of view (as BR_fnc_aiAttachmentValue)
BR_fnc_airdropOpticMagnification = {
    params ["_class"];

    private _magnification = 1;

    {
        private _zoom = getNumber (_x >> "opticsZoomMin");
        if (_zoom > 0) then {_magnification = _magnification max (0.25 / _zoom)};
    } forEach ("true" configClasses (configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "OpticsModes"));

    _magnification
};

/*
    BR_var_airdropKit (hash map), once per mission from the completed loot pools (BR_fnc_initLootServer):
    "weapons": [[[row of BR_var_lootWeaponClassData, [family, ...]], ...], [share, ...]]: the best families of the
        strong classes; "optics": optic (lower case) -> [class, magnification], the sights of the pools; "vests",
        "helmets", "backpacks", "throwables": classes; "medical": the rows of BR_var_airdropMedical whose class exists.
*/
BR_fnc_initAirdropKit = {
    private _kit = createHashMap;
    private _rows = [];
    private _shares = [];

    {
        _x params ["_class", "", "_share", "", "_families"];

        if (_class in BR_var_airdropWeaponClasses && {_families isNotEqualTo []}) then {
            private _count = count _families;
            // the families are ranked worst to best: the end of the list
            private _start = (floor (_count * (1 - BR_var_airdropWeaponTopShare))) min (_count - 1);

            _rows pushBack [_forEachIndex, _families select [_start]];
            _shares pushBack _share;
        };
    } forEach BR_var_lootWeaponClassData;

    _kit set ["weapons", [_rows, _shares]];

    private _optics = createHashMap;

    {
        if (([_x] call BR_fnc_aiItemType) == "AccessorySights") then {
            _optics set [toLowerANSI _x, [_x, [_x] call BR_fnc_airdropOpticMagnification]];
        };
    } forEach (["attachments"] call BR_fnc_airdropPoolClasses);

    _kit set ["optics", _optics];
    _kit set ["vests", ["vests", 701] call BR_fnc_airdropArmorClasses];
    _kit set ["helmets", ["helmets", 605] call BR_fnc_airdropArmorClasses];

    // backpacks: all with at least the capacity of the one at the top share's rank (equal ones stay in)
    private _backpacks = (["backpacks"] call BR_fnc_airdropPoolClasses) apply {[([_x, true] call BR_fnc_aiClothingProfile) select 0, _x]};
    _backpacks sort false;
    private _backpackMin = if (_backpacks isEqualTo []) then {0} else {
        (_backpacks select (0 max ((ceil (count _backpacks * BR_var_airdropBackpackTopShare)) - 1))) select 0
    };
    _kit set ["backpacks", (_backpacks select {(_x select 0) >= _backpackMin}) apply {_x select 1}];

    // throwables of the best tier that has any
    private _throwables = [];
    {if (_x isNotEqualTo []) then {_throwables = _x}} forEach (BR_var_lootPools getOrDefault ["throwables", []]);
    _kit set ["throwables", _throwables];

    _kit set ["medical", BR_var_airdropMedical select {
        isClass (configFile >> (["CfgWeapons", "CfgMagazines"] select ((_x select 0) == "magazine")) >> (_x select 1))
    }];

    BR_var_airdropKit = _kit;

    // e.g. "weapons [assaultRifles 47/140, ...]; optics 120; vests 9, helmets 30 (armor 3+); backpacks 21 (load 300+)"
    diag_log format ["BR airdrop kit: weapons %1; optics %2; vests %3, helmets %4 (armor %5+); backpacks %6 (load %7+); throwables %8; medical %9",
        _rows apply {
            private _data = BR_var_lootWeaponClassData select (_x select 0);
            format ["%1 %2/%3", _data select 0, count (_x select 1), count (_data select 4)]
        },
        count _optics, count (_kit get "vests"), count (_kit get "helmets"), BR_var_airdropArmorLevel,
        count (_kit get "backpacks"), _backpackMin, _throwables, (_kit get "medical") apply {_x select 1}];
};

// a primary of the best families of the strong classes (class by share, then family and variant evenly), "" if the
// pools have none
BR_fnc_rollAirdropWeapon = {
    (BR_var_airdropKit get "weapons") params ["_rows", "_shares"];

    if (_rows isEqualTo []) exitWith {""};

    private _families = (_rows selectRandomWeighted _shares) select 1;

    selectRandom (selectRandom _families)
};

// an optic of the pools for _weapon whose magnification suits its class; "" if the weapon has one already (attachment
// preset) or no optic of the pools fits it
BR_fnc_airdropOptic = {
    params ["_weapon"];

    private _linked = "true" configClasses (configFile >> "CfgWeapons" >> _weapon >> "LinkedItems");
    if ((_linked findIf {([getText (_x >> "item")] call BR_fnc_aiItemType) == "AccessorySights"}) != -1) exitWith {""};

    private _optics = BR_var_airdropKit get "optics";
    private _fits = ((compatibleItems _weapon) apply {_optics getOrDefault [toLowerANSI _x, []]}) select {_x isNotEqualTo []};
    if (_fits isEqualTo []) exitWith {""};

    private _id = BR_var_lootWeaponFamilyOf getOrDefault [toLowerANSI _weapon, []];
    private _class = if (_id isEqualTo []) then {""} else {(BR_var_lootWeaponClassData select (_id select 0)) select 0};
    private _zoom = BR_var_airdropOpticZoom getOrDefault [_class, BR_var_airdropOpticZoomDefault];
    private _misfits = _fits apply {abs (ln ((_x select 1) / _zoom))};
    private _limit = (selectMin _misfits) + ln BR_var_airdropOpticSpread;
    private _best = [];
    {if ((_misfits select _forEachIndex) <= _limit) then {_best pushBack (_x select 0)}} forEach _fits;

    selectRandom _best
};

/*
    The content of a crate (format of BR_fnc_rollLootContent): a strong primary with an optic and its magazines, a vest
    and a helmet of armor level 3+, a big backpack, healing, throwables, then BR_var_airdropRolls elite loot rolls.
*/
BR_fnc_rollAirdropContent = {
    if (isNil "BR_var_airdropKit") then {call BR_fnc_initAirdropKit};

    private _content = [];
    private _weapons = [];
    private _weapon = call BR_fnc_rollAirdropWeapon;

    // pools without any strong class: their best primary of any class
    if (_weapon == "") then {_weapon = ["primaries", BR_var_tierWeightsAirdrop] call BR_fnc_rollLoot};

    if (_weapon != "") then {
        _weapons pushBack _weapon;
        _content append [
            ["weapon", _weapon, 1],
            ["magazine", [_weapon] call BR_fnc_weaponMagazine, BR_var_airdropWeaponMagazines call BR_fnc_randomCount],
            ["item", [_weapon] call BR_fnc_airdropOptic, 1]
        ];
    };

    {
        _x params ["_key", "_cargoType"];

        private _classes = BR_var_airdropKit get _key;
        if (_classes isNotEqualTo []) then {_content pushBack [_cargoType, selectRandom _classes, 1]};
    } forEach [["vests", "item"], ["helmets", "item"], ["backpacks", "backpack"]];

    {
        _x params ["_cargoType", "_class", "_counts"];

        _content pushBack [_cargoType, _class, _counts call BR_fnc_randomCount];
    } forEach (BR_var_airdropKit get "medical");

    private _throwables = BR_var_airdropKit get "throwables";
    if (_throwables isNotEqualTo []) then {
        _content pushBack ["magazine", selectRandom _throwables, BR_var_airdropThrowables call BR_fnc_randomCount];
    };

    // the random rolls, weapons first: the crate's ammo is for them
    private _categories = [];

    for "_i" from 1 to BR_var_airdropRolls do {
        _categories pushBack ([1] call BR_fnc_rollLootCategory); // military loot (BR_var_lootCategories)
    };

    {
        _content append ([BR_var_tierWeightsAirdrop, _weapons, _x] call BR_fnc_rollLootContent);
    } forEach (
        (_categories select {_x in BR_var_lootWeaponCategories}) +
        (_categories select {!(_x in BR_var_lootWeaponCategories)})
    );

    _content select {(_x select 1) != ""}
};

// the content for the server log: "class xN", weapons with their class and family rank (count = best), armor with its
// level
BR_fnc_airdropContentText = {
    params ["_content"];

    (_content apply {
        _x params ["_cargoType", "_class", "_count"];

        private _text = format ["%1 x%2", _class, _count];
        private _id = BR_var_lootWeaponFamilyOf getOrDefault [toLowerANSI _class, []];
        private _itemType = getNumber (configFile >> "CfgWeapons" >> _class >> "ItemInfo" >> "type");

        if (_id isNotEqualTo []) then {
            private _data = BR_var_lootWeaponClassData select (_id select 0);
            _text = _text + format [" (%1 %2/%3)", _data select 0, (_id select 1) + 1, count (_data select 4)];
        } else {
            if (_cargoType == "item" && {_itemType in [701, 605]}) then {
                _text = _text + format [" (armor %1)", [_class, _itemType] call BR_fnc_airdropArmorLevel];
            };
        };

        _text
    }) joinString ", "
};
