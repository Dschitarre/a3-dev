// Battle Royale loot (server): item pools (BR\loot\lootPool<mapGroup>.hpp) with rarity tiers and lazy loot in buildings:
// once per building when a player on the ground comes close or an AI searches it (BR\aiLoot.sqf); untouched loot far
// from all combatants is removed and remembered on its building for a later visit.

// [category, config class of its entries, weight of a loot spot [in civilian buildings, at military sites]]; "ammo" is
// rolled from the weapons. The weapon categories' weights only give their sum (all weapon spots): a weapon spot of
// either rolls any weapon class by the shares of its building tier (BR_var_lootWeaponClasses). Military sites hold
// more ammo, armor, attachments and grenades, civilian buildings more clothes, backpacks, food and bandages
BR_var_lootCategories = [
["primaries", "CfgWeapons", [30, 50]],
["handguns", "CfgWeapons", [10, 4]],
["ammo", "", [8, 16]],
["attachments", "CfgWeapons", [5, 12]],
["vests", "CfgWeapons", [6, 14]],
["helmets", "CfgWeapons", [6, 12]],
["uniforms", "CfgWeapons", [14, 8]],
["backpacks", "CfgVehicles", [14, 10]],
["medical", "CfgWeapons", [8, 4]],
["bandages", "", [10, 6]], // BR\items.sqf: carriers outside the pools
["drinks", "", [8, 2]],
["throwables", "CfgMagazines", [3, 10]]
];
BR_var_lootCategoryNames = BR_var_lootCategories apply {_x select 0};

// per loot profile (0 civilian, 1 military: BR_fnc_lootProfile) the category weights
BR_var_lootCategoryWeights = [0, 1] apply {
    private _profile = _x;
    BR_var_lootCategories apply {(_x select 2) select _profile}
};

BR_var_lootWeaponCategories = ["primaries", "handguns"];
BR_var_tierWeightsAirdrop = [0, 0, 0, 100]; // common, uncommon, rare, elite: supply drops contain only elite gear

/*
    Weapon spawns: a weapon spot rolls a weapon class by fixed shares first, then a weapon family of
    that class (one weapon: all its skins and attachment presets, BR_fnc_weaponFamilyKeys), then one of its variants.
    So neither a class nor a weapon gets more common because a mod ships it in many variants.
    The shares go by the building tier: civilian buildings hold handguns,
    shotguns, SMGs and hunting rifles, now and then a rifle; military sites rifles, machine guns, precision rifles and
    launchers. A class with share 0 in a tier is never found there: machine guns, anti-materiel rifles and launchers
    only at military sites (and in supply drops). Rows [class, shares in % per building tier [poor (ruins, sheds),
    medium (houses), rare (churches, offices, industry), elite (military sites, supply drops)]]; a class without weapons
    in the loaded pools drops out and the others are renormalised. The class "handguns" is the loot category
    "handguns", all others are "primaries"; a weapon spot of either rolls any class of its tier. BR_fnc_weaponClass
    sorts a weapon into its class.
*/
BR_var_lootWeaponClasses = [
["assaultRifles", [6, 10, 22, 34]],
["smgs", [18, 22, 22, 8]],
["handguns", [32, 26, 18, 6]],
["shotguns", [26, 24, 16, 0]],
["snipers", [18, 14, 14, 8]], // bolt and lever action: the hunting rifles of civilian buildings
["marksman", [0, 4, 8, 14]],
["machineGuns", [0, 0, 0, 14]],
["antiMateriel", [0, 0, 0, 6]],
["launchers", [0, 0, 0, 10]]
];
// Quality: per family a config score (BR_fnc_weaponQualityScore), ranked within its class: quality 0 (worst family of
// the class) .. 1 (best). A family's weight runs linearly from 1 (quality 0) to BR_var_lootQualityRatio ^ exponent
// (quality 1); families outside the tier's quality range are not rolled. Every family keeps a chance, none dominates.
BR_var_lootQualityRatio = 4; // normal houses: the best family of a class spawns 4x less often than the worst
// per building tier (poor, medium, rare, elite): [exponent, lowest quality, highest quality]. Poor: best 8x rarer;
// medium (normal houses): 4x rarer; rare (churches, offices, industry): all alike; elite (military sites, supply
// drops): the better half of each class only, its best 2x more common. The best families of each class (above the
// civilian tiers' highest quality) only at military sites
BR_var_lootTierQuality = [[-1.5, 0, 0.6], [-1, 0, 0.75], [0, 0, 0.85], [0.5, 0.5, 1]];
// Gear apart by kind (BR_fnc_lootItemKind: 0 civilian, 1 military, 2 military only): civilian buildings roll their
// vests, helmets, uniforms, attachments and throwables from the civilian ones, military sites from the military ones,
// BR_var_lootKindMain of the time (else the other kind); military-only gear (armor level BR_var_lootMilitaryOnlyArmor+,
// night and thermal vision, laser designators, explosive grenades) is never found in civilian buildings
BR_var_lootKindCategories = ["vests", "helmets", "uniforms", "attachments", "throwables"];
BR_var_lootKindMain = 0.85;
BR_var_lootMilitaryOnlyArmor = 3; // vests and helmets of this armor level (BR_var_armorLevelThresholds) and up
// weapon class rules (BR_fnc_weaponClass), all from the config of the weapon and its default magazine
BR_var_lootSmgMaxHit = 7.5; // automatic weapons with weaker ammo (9 mm, 5.7 mm, ...) are SMGs
BR_var_lootSmgSlowAmmo = [450, 9]; // ... as well as with ammo slower than 450 m/s and hit below 9 (.45 ACP)
BR_var_lootMgMinRounds = 75; // automatic weapons with a belt or drum of at least this many rounds are machine guns
BR_var_lootBoltActionReload = 0.5; // s between two shots at least: bolt or lever action -> sniper rifle
BR_var_lootAntiMaterielMinHit = 20; // .50 / 12.7 mm and up: sniper rifle, also when semi-automatic
BR_var_lootMarksmanMinHit = 11; // full-power cartridges (7.62x51, 7.62x54R and up) ...
BR_var_lootMarksmanMaxRounds = 20; // ... in a semi-automatic rifle with at most 20 rounds: marksman rifle

// Ammo follows the weapons: a weapon comes with some of its own magazines; an ammo spot of a building (or crate) with
// weapons is for one of them (they are rolled first), else for a caliber of the weapon pool, as likely as a weapon of
// that caliber is (BR_var_ammoFamilies: one magazine per caliber, however many weapons and magazine classes share it)
// per loot profile [civilian, military]: a hunting rifle in a farm house comes with a
// magazine or two, a rifle in a barrack with a few; an ammo spot of a barrack is a bigger stash
BR_var_lootWeaponMagazines = [[1, 2], [2, 4]]; // magazines that come with a weapon, random in [min, max]
BR_var_lootAmmoMatchChance = 0.85; // ammo fits a weapon of the same building (or crate) this often
BR_var_lootAmmoCount = [[1, 2], [2, 4]]; // magazines of an ammo spot, random in [min, max]
// a weapon comes with a fitting attachment this often (BR_fnc_rollWeaponAttachment): a flashlight or plain sight in
// civilian buildings, any attachment of its own at military sites
BR_var_lootWeaponAttachmentChance = [0.1, 0.35];
// medical spots: their tier weights by profile, not the building's: the first aid kits are common and poor, the
// Medikit is the pools' elite medical item: 1 in 10 medical spots of a military site, none in other civilian
// buildings; hospitals and medical tents have their own share (theme row 0)
BR_var_lootMedicalTiers = [[60, 40, 0, 0], [40, 50, 0, 10]];

// building loot by class (BR_fnc_buildingLootQuality; a map object without a class by its model name): [[parts of the class name], tier weights, loot spots at most],
// the first row whose part the (lower case) class contains; else BR_var_buildingLootDefault (normal houses). The parts
// cover the base game and CUP terrains (Land_Mil_*, Land_Barrack2, Land_A_Office01, Land_A_GeneralStore_01, ...)
BR_var_buildingLootClasses = [
// military: the container houses Land_Cargo_House_V1-3_F, not the slum huts Land_Cargo_House_Slum_F; also the
// watchtowers and the airfield control tower (Livonia models of Chernarus 2020)
[["cargo_hq", "cargo_patrol", "cargo_tower", "cargo_house_v", "miloffices", "barrack", "bunker", "mil_", "military", "tent_east", "tent2_west", "tent_west", "tent_small_west",
    "guardtower", "controltower"], [0, 0, 0, 100], 9],
[["ruin", "land_d_", "_d_", "land_u_", "slum", "unfinished", "shed", "garage", "shack"], [100, 0, 0, 0], 4],
[["church", "chapel", "castle", "office", "factory", "ind_", "hospital", "hangar", "airport", "lighthouse", "warehouse", "shop_city", "store", "house_big", "tower"], [0, 75, 25, 0], 8]
];
BR_var_buildingLootDefault = [[0, 100, 0, 0], 7];
BR_var_buildingLootCache = createHashMap;

// Themed buildings: medical buildings and tents hold mostly medical loot, hunting
// stands and lodges mostly hunting gear, so a place looks like what it is. Rows [[parts of the building class], share
// of its loot spots rolled from the theme, [[category, weight, [parts of the item class]], ...]], the first row whose
// part the (lower case) building class contains (BR_fnc_buildingLootTheme); the other spots roll as usual. An entry
// with item parts rolls only the pool classes of its category that contain one, of any tier (the place decides what
// lies there, not the rarity); without parts its category is rolled as usual. Entries whose parts match nothing in
// the loaded pools are dropped (BR_fnc_initLootThemes): a theme only acts in map groups that have its gear. Ammo
// follows the weapons as everywhere: the theme's weapons are rolled first, its ammo spots are for them.
// Building parts: Land_Hospital_*_F, Land_Medevac_*_F, Land_MedicalTent_01_*, Land_HealthCenter_01_F (base game),
// Land_A_Hospital, Land_Hospital, Land_CUP_OPX_Clinic, MASH (CUP); Land_Misc_deerstand and Land_Posed (Czech: hunter's
// raised hide) of the CUP terrains, Land_DeerStand_0*_F of the base game.
// Entries of category "weapons" name weapon classes (BR_var_lootWeaponClasses) instead of item parts: a weapon of one
// of them as the building tier rolls it (heavy weapons in bunkers, precision rifles in watchtowers, shotguns and
// hunting rifles in barns). Rows 0 (medical) and 1 (hunting) are also loot site
// kinds of the map markers (BR_var_lootSiteKinds); the others only shape the loot.
BR_var_lootThemes = [
[["hospital", "medicaltent", "medevac", "healthcenter", "clinic", "mash", "stan_ep1"], 0.75, [
    ["medical", 4, ["firstaidkit"]],
    ["medical", 2, ["medikit"]],
    ["bandages", 4, []],
    ["uniforms", 1, ["labcoat", "medic"]]
]],
// hunting camps of Chernarus 2020: camp cabins, deer feeding shacks, forest huts; castles hold hunting loot as in DayZ,
// and so do the log houses (Land_House_2W05_F)
[["deerstand", "land_posed", "hunt", "camp_house", "feedshack", "hut06", "castle", "house_2w05"], 0.75, [
    ["primaries", 6, ["hunter", "cz550", "cz584", "remington700", "mosin", "leeenfield", "kar98", "winchester"]],
    ["handguns", 1, ["hunter"]], // the sawed-off hunter shotgun of the base game
    ["ammo", 3, []],
    ["uniforms", 1, ["hunter", "woodlander"]],
    ["helmets", 1, ["ushanka", "booniehat", "_hat"]],
    ["attachments", 1, ["binocular"]]
]],
// military sites by building: watch and guard towers - precision rifles, optics, ammo
[["guardtower", "watchtower", "cargo_patrol", "cargo_tower", "bagbunker_tower"], 0.5, [
    ["weapons", 4, ["marksman", "snipers", "antiMateriel"]],
    ["attachments", 3, ["optic"]],
    ["ammo", 3, []],
    ["attachments", 1, ["binocular", "rangefinder"]]
]],
// bunkers - heavy weapons, grenades, ammo
[["bunker", "pillbox", "dugout"], 0.5, [
    ["weapons", 4, ["machineGuns", "launchers"]],
    ["ammo", 4, []],
    ["throwables", 3, []]
]],
// command posts - night vision, binoculars and rangefinders, sidearms
[["cargo_hq", "miloffices", "controltower", "radar_01_hq"], 0.5, [
    ["attachments", 2, ["nvgoggles", "nvg"]],
    ["attachments", 2, ["binocular", "rangefinder", "laserdesignator"]],
    ["weapons", 2, ["handguns"]],
    ["vests", 1, []]
]],
// barracks and army tents - a soldier's kit: uniforms, vests, helmets, backpacks, rifles
[["barrack", "cargo_house_v", "mil_house", "tent"], 0.5, [
    ["uniforms", 3, []],
    ["vests", 3, []],
    ["helmets", 3, []],
    ["backpacks", 2, []],
    ["weapons", 3, ["assaultRifles", "smgs"]]
]],
// police stations - sidearms, SMGs, shotguns, police vests and uniforms
[["police"], 0.6, [
    ["weapons", 6, ["handguns", "smgs", "shotguns"]],
    ["ammo", 3, []],
    ["vests", 2, ["police", "press"]],
    ["uniforms", 1, ["police"]]
]],
// fire stations (CUP: Land_Sara_hasic_zbroj) - firemen's gear, first aid
[["hasic_zbroj", "firestation", "fire_station"], 0.6, [
    ["uniforms", 2, ["fireman"]],
    ["medical", 3, ["firstaidkit"]],
    ["bandages", 3, []],
    ["backpacks", 2, []]
]],
// shops, pubs, the fuel stations' shops - drinks, bandages, bags, clothes
// (whole names: "shop" alone would also match the workshops)
[["generalstore", "villagestore", "fuelstation_03_shop", "fuelstation_shop", "shop_city", "shop_town", "supermarket",
    "market", "kiosk", "a_pub"], 0.6, [
    ["drinks", 4, []],
    ["bandages", 3, []],
    ["backpacks", 3, []],
    ["uniforms", 3, []]
]],
// barns and farms - shotguns and hunting rifles
[["barn", "farm", "stable", "kravin"], 0.5, [
    ["weapons", 4, ["shotguns", "snipers"]],
    ["ammo", 3, []],
    ["drinks", 2, []],
    ["uniforms", 1, ["worker", "woodlander", "hunter"]]
]],
// garages, workshops, industry - flashlights, bags, work clothes, a pistol or shotgun
[["garage", "workshop", "repair", "ind_", "factory", "tovarna", "hangar"], 0.4, [
    ["attachments", 2, ["flashlight"]],
    ["backpacks", 3, []],
    ["drinks", 2, []],
    ["weapons", 2, ["handguns", "shotguns"]],
    ["uniforms", 1, ["mechanic", "worker", "coverall"]]
]]
];
// the theme rows that are loot site kinds of the map markers (medical, hunting); the others count as no theme there
BR_var_lootMarkerThemes = [0, 1];
BR_var_buildingThemeCache = createHashMap;

BR_var_lootRadius = 140; // buildings within this distance of a player get their loot
BR_var_lootSeekHeight = 60; // players higher above the ground (aircraft, early free fall) spawn nothing
BR_var_lootInterval = 2;
BR_var_lootCleanupInterval = 15;
BR_var_lootCleanupDistance = 450; // untouched loot farther than this from every combatant is removed
BR_var_holderSearchMargin = 2; // loot holders this far outside a building's bounding sphere still belong to it
BR_var_magazineCache = createHashMap;
BR_var_weaponMagazinesCache = createHashMap;
BR_var_lootBuildingCache = createHashMap;
// Army tents of the A2/CUP terrains (Chernarus) are map objects without a class and without building positions: their
// loot lies on a grid on the floor (BR_fnc_lootPositions). They are found once per mission (BR_fnc_findLootTents).
// Also the big OA tents (stan_ep1 is the medical one) and the bag bunkers without building positions.
BR_var_lootTentModels = ["tent_east.p3d", "tent2_west.p3d", "tent_west.p3d", "tent_small_west.p3d", "stan_east_ep1.p3d",
    "stan_east.p3d", "stan_ep1.p3d", "bagbunker_tower_f.p3d", "bagbunker_small_f.p3d"];
BR_var_lootTentTypes = ["HOUSE", "BUNKER", "FORTRESS", "HOSPITAL", "BUILDING", "VIEW-TOWER"]; // their terrain types
BR_var_lootTentSpacing = 3; // m between two loot points on a tent floor
BR_var_lootTents = [];

// the class of a building in lower case, for a map object without one its model name ("tent_east.p3d")
BR_fnc_lootClassKey = {
    params ["_building"];

    private _class = toLowerANSI typeOf _building;
    if (_class == "") then {_class = toLowerANSI ((getModelInfo _building) select 0)};
    _class
};

// the loot positions (AGL) of a building: its building positions, for an army tent a grid on its floor (cached)
BR_fnc_lootPositions = {
    params ["_building"];

    private _positions = _building buildingPos -1;

    if (_positions isEqualTo [] && {(toLowerANSI ((getModelInfo _building) select 0)) in BR_var_lootTentModels}) then {
        _positions = [_building, "BR_var_tentPositions", nil] call BR_fnc_bGet;

        if (isNil "_positions") then {
            (boundingBoxReal _building) params ["_min", "_max"];
            private _size = _max vectorDiff _min;
            private _columns = 1 max floor (0.6 * (_size select 0) / BR_var_lootTentSpacing);
            private _rows = 1 max floor (0.6 * (_size select 1) / BR_var_lootTentSpacing);
            _positions = [];

            for "_i" from 1 to _columns do {
                for "_j" from 1 to _rows do {
                    private _world = _building modelToWorld [
                    (_min select 0) + (_size select 0) * (0.2 + 0.6 * (_i - 0.5) / _columns),
                    (_min select 1) + (_size select 1) * (0.2 + 0.6 * (_j - 0.5) / _rows),
                    0
                    ];
                    _positions pushBack [_world select 0, _world select 1, 0];
                };
            };

            [_building, "BR_var_tentPositions", _positions] call BR_fnc_bSet;
        };
    };

    _positions
};

// scheduled (server), once per mission at its start (BR_fnc_matchLoop; ~15 s on Chernarus, in the background of the
// warmup): the army tents of the whole world (BR_var_lootTents); users filter them by distance
BR_fnc_findLootTents = {
    BR_var_lootTents =(nearestTerrainObjects [[worldSize / 2, worldSize / 2], BR_var_lootTentTypes,
        worldSize * 0.71, false, true]) select {
        (toLowerANSI ((getModelInfo _x) select 0)) in BR_var_lootTentModels &&
        // the classed ones (bag bunker towers) are found as houses already (BR_fnc_lootBuildingsNear)
        {typeOf _x == ""}
    };

    diag_log format ["BR loot tents: %1", count BR_var_lootTents];
};

// loot buildings within _radius of _pos (object or position), nearest first: houses and army tents
BR_fnc_lootBuildingsNear = {
    params ["_pos", "_radius"];

    private _houses = nearestObjects [_pos, ["House"], _radius, true];
    private _tents = BR_var_lootTents select {_x distance2D _pos <= _radius};
    if (_tents isEqualTo []) exitWith {_houses};

    [_houses + _tents, [_pos], {_x distance2D _input0}, "ASCEND"] call BIS_fnc_sortBy
};

// Harbour infrastructure exposes buildingPos too, but is not a loot-bearing building.
BR_fnc_isLootBuilding = {
    params ["_building"];

    private _class = [_building] call BR_fnc_lootClassKey;
    private _allowed = BR_var_lootBuildingCache get _class;

    if (isNil "_allowed") then {
        _allowed = (["pier", "quay", "harbor", "harbour", "breakwater"] findIf {_class find _x >= 0}) < 0;
        BR_var_lootBuildingCache set [_class, _allowed];
    };

    _allowed && {([_building] call BR_fnc_lootPositions) isNotEqualTo []}
};

// ---- pools ----

// The hand-tuned pool assigns the intended quality to common and elite gear.  Complete it with every other public,
// player-usable weapon and wearable item loaded by the server (classes the pool lists keep their tier), so a newly
// loaded official/DLC variant cannot silently be absent.  Missing firearms land in rare facilities; launchers and thermal items are elite.  This keeps ordinary
// homes medium/poor and military buildings/airdrops best-only while still making the complete usable catalogue occur.
// Weapons only take their category from the pools, not their tier: their roll goes by class, family and quality
// (BR_fnc_initLootWeapons).
BR_fnc_publicLootCategory = {
    params ["_class"];

    private _kind = [_class] call BIS_fnc_itemType;
    _kind params [["_major", ""], ["_minor", ""]];

    if (_major == "Weapon") exitWith {
        // only weapons whose ammunition does harm: the spectrum device's antennas count as handguns, and an AI that takes
        // one tries to rearm it for good
        private _magazine = [_class] call BR_fnc_weaponMagazine;
        private _hit = getNumber (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo") >> "hit");

        if (_minor in ["Handgun", "AssaultRifle", "MachineGun", "Rifle", "SniperRifle", "Shotgun", "SubmachineGun", "SMG"] && {_hit <= 0}) exitWith {""};

        if (_minor == "Handgun") exitWith {"handguns"};

        if (_minor in ["AssaultRifle", "MachineGun", "Rifle", "SniperRifle", "Shotgun", "SubmachineGun", "SMG", "RocketLauncher", "MissileLauncher"]) exitWith {"primaries"};

        if (_minor in ["Binocular", "LaserDesignator"]) exitWith {"attachments"};

        ""
    };

    if (_major == "Equipment") exitWith {
        switch (_minor) do {
            case "Uniform": {"uniforms"};
            case "Vest": {"vests"};
            case "Headgear": {"helmets"};
            default {""};
        }
    };

    if (_major == "Item" && {_minor in ["AccessoryMuzzle", "AccessoryPointer", "AccessorySights", "NVGoggles"]}) exitWith {"attachments"};

    ""
};

// The pool's "completeOnly" class name prefixes (e.g. {"CUP_"}) limit the completion to that content; empty: all.
BR_fnc_completeLootPools = {
    private _prefixes = (getArray (missionConfigFile >> "BR_lootPool" >> "completeOnly")) apply {toLowerANSI _x};

    private _wanted = {
        params ["_class"];

        private _lower = toLowerANSI _class;
        _prefixes isEqualTo [] || {(_prefixes findIf {(_lower find _x) == 0}) >= 0}
    };

    private _append = {
        params ["_category", "_class", "_tier"];

        private _tiers = BR_var_lootPools get _category;
        (_tiers select _tier) pushBackUnique _class;
        BR_var_lootPools set [_category, _tiers];
        BR_var_lootClassCategories set [toLowerANSI _class, _category];
    };

    {
        private _class = configName _x;
        private _category = [_class] call BR_fnc_publicLootCategory;

        if (_category != "" && {!((toLowerANSI _class) in BR_var_lootClassCategories)} && {[_class] call _wanted}) then {
            private _kind = [_class] call BIS_fnc_itemType;

            private _tier = if ((_kind select 1) in ["RocketLauncher", "MissileLauncher"] || {"TI" in (getArray (_x >> "visionMode"))}) then {3} else {
                [1, 2] select (_category in ["primaries", "handguns"])
            };

            [_category, _class, _tier] call _append;
        };
    } forEach ("getNumber (_x >> 'scope') >= 2" configClasses (configFile >> "CfgWeapons"));

    {
        private _class = configName _x;

        if(_class isKindOf "Bag_Base" && {!isClass (_x >> "assembleInfo")} &&
            {!((toLowerANSI _class) in BR_var_lootClassCategories)} && {[_class] call _wanted}) then {
            ["backpacks", _class, 1] call _append;
        };
    } forEach ("getNumber (_x >> 'scope') >= 2" configClasses (configFile >> "CfgVehicles"));
};

/*
    Category -> [[common classes], [uncommon], [rare]], only classes that exist and are public in the loaded game; and
    BR_var_lootClassCategories: class (lower case) -> category, for the AI picking up loot.
*/
BR_fnc_initLootServer = {
    private _poolConfig = missionConfigFile >> "BR_lootPool";

    BR_var_lootPools = createHashMap;
    BR_var_lootClassCategories = createHashMap;
    BR_var_lootHolders = [];

    {
        _x params ["_category", "_configRoot"];

        private _tiers = [[], [], [], []];

        if (_configRoot != "") then {
            {
                _x params ["_class", "_tier"];

                private _classConfig = configFile >> _configRoot >> _class;

                // no static weapon bags (assembleInfo: CUP's *_Gun_Bag, tripods), as in the completion
                if (isClass _classConfig && {getNumber (_classConfig >> "scope") >= 2} &&
                    {_category != "backpacks" || {!isClass (_classConfig >> "assembleInfo")}}) then {
                    (_tiers select (0 max _tier min 3)) pushBackUnique _class;
                    BR_var_lootClassCategories set [toLowerANSI _class, _category];
                };
            } forEach (getArray (_poolConfig >> _category));
        };

        BR_var_lootPools set [_category, _tiers];
    } forEach BR_var_lootCategories;

    call BR_fnc_completeLootPools;
    call BR_fnc_initLootKinds;
    call BR_fnc_initLootWeapons;
    call BR_fnc_initAmmoFamilies;
    call BR_fnc_initLootThemes;
};

/*
    BR_var_lootThemePools: per row of BR_var_lootThemes [[[category, classes], ...], [weight, ...]], the classes of an
    entry with item parts taken from the completed pools (so they exist and the AI knows their category), [] for an
    entry without parts (its category rolled as usual). An entry whose parts match nothing is left out.
*/
BR_fnc_initLootThemes = {
    BR_var_lootThemePools = BR_var_lootThemes apply {
        private _entries = [];
        private _weights = [];

        {
            _x params ["_category", "_weight", "_parts"];

            private _classes = [];

            // a weapon entry: its weapon classes that have weapons in the loaded pools
            if (_category == "weapons") then {
                _classes = _parts select {
                    private _class = _x;
                    (BR_var_lootWeaponClassData findIf {(_x select 0) == _class && {(_x select 4) isNotEqualTo []}}) != -1
                };
                _parts = [];
            };

            if (_parts isNotEqualTo []) then {
                {
                    {
                        private _lower = toLowerANSI _x;

                        if ((_parts findIf {(_lower find _x) != -1}) != -1) then {
                            _classes pushBackUnique _x;
                        };
                    } forEach _x;
                } forEach (BR_var_lootPools getOrDefault [_category, []]);
            };

            if ((_parts isEqualTo [] && {_category != "weapons"}) || {_classes isNotEqualTo []}) then {
                _entries pushBack [_category, _classes];
                _weights pushBack _weight;
            };
        } forEach (_x select 2);

        [_entries, _weights]
    };

    // e.g. [["medical:0", "bandages:0", "uniforms:3"], ...]: the entries per theme and their item classes
    diag_log format ["BR loot themes: %1", BR_var_lootThemePools apply {
        (_x select 0) apply {format ["%1:%2", _x select 0, count (_x select 1)]}
    }];
};

// the sum of an array of numbers
BR_fnc_lootSum = {
    private _sum = 0;
    {_sum = _sum + _x} forEach _this;
    _sum
};

/*
    [hit, speed, dispersion, reload, rounds, inertia, automatic, ammo simulation] of a weapon with its default magazine
    (config only). Only the fire modes a player can select count (AI modes have showToPlayer = 0); "this" is the weapon
    class itself. hit includes half the splash damage (indirectHit: grenades, rockets).
*/
BR_fnc_lootWeaponStats = {
    params ["_weapon"];

    private _config = configFile >> "CfgWeapons" >> _weapon;
    private _magazine = configFile >> "CfgMagazines" >> ([_weapon] call BR_fnc_weaponMagazine);
    private _ammo = configFile >> "CfgAmmo" >> getText (_magazine >> "ammo");
    private _speed = getNumber (_magazine >> "initSpeed");
    if (_speed <= 0) then {_speed = getNumber (_ammo >> "typicalSpeed")};
    private _dispersion = -1;
    private _reload = -1;
    private _automatic = false;

    {
        private _mode = if (_x == "this") then {_config} else {_config >> _x};

        if (!isNumber (_mode >> "showToPlayer") || {getNumber (_mode >> "showToPlayer") != 0}) then {
            private _value = getNumber (_mode >> "dispersion");
            if (_value > 0) then {_dispersion = [_value, _dispersion min _value] select (_dispersion > 0)};
            _value = getNumber (_mode >> "reloadTime");
            if (_value > 0) then {_reload = [_value, _reload min _value] select (_reload > 0)};
            if (getNumber (_mode >> "autoFire") == 1 || {getNumber (_mode >> "burst") > 1}) then {_automatic = true};
        };
    } forEach getArray (_config >> "modes");

    if (_dispersion <= 0) then {_dispersion = 0.002};
    if (_reload <= 0) then {_reload = 0.1};

    [getNumber (_ammo >> "hit") + 0.5 * getNumber (_ammo >> "indirectHit"), _speed, _dispersion, _reload,
    getNumber (_magazine >> "count"), getNumber (_config >> "inertia"), _automatic, toLowerANSI getText (_ammo >> "simulation")]
};

/*
    The weapon class (a row name of BR_var_lootWeaponClasses) of a weapon of loot category _category, generic from the
    config, the first rule that fits:
    handguns: the loot category "handguns" (the handgun slot).
    launchers: the launcher slot (type 4), BIS_fnc_itemType Rocket/Missile/GrenadeLauncher, or explosive default ammo
        (simulation shotShell/shotRocket/shotMissile: grenade launchers like the M79 or M32 in the primary slot).
    shotguns: BIS_fnc_itemType Shotgun, or a magazine of the weapon fires pellets (shotSpread, or submunitions with a
        cone: buckshot) - a pump gun with slugs as default ammo is still a shotgun.
    smgs: BIS_fnc_itemType SubmachineGun/SMG, or automatic with pistol ammo (BR_var_lootSmgMaxHit, BR_var_lootSmgSlowAmmo).
    machineGuns: BIS_fnc_itemType MachineGun, or automatic with a belt/drum (BR_var_lootMgMinRounds).
    antiMateriel: anti-materiel ammo (BR_var_lootAntiMaterielMinHit), whatever BIS_fnc_itemType says.
    snipers: bolt or lever action (BR_var_lootBoltActionReload between shots), whatever BIS_fnc_itemType says.
    marksman: the other rifles of BIS_fnc_itemType SniperRifle (M14, SVD, EBR, Mk12, VSS: semi-auto precision rifles),
        and semi-automatic rifles with full-power ammo and small magazines (BR_var_lootMarksmanMinHit/MaxRounds).
    assaultRifles: everything else (automatic rifles, battle rifles like the FAL or G3).
*/
BR_fnc_weaponClass = {
    params ["_weapon", "_category"];

    if (_category == "handguns") exitWith {"handguns"};

    private _config = configFile >> "CfgWeapons" >> _weapon;
    private _minor = ([_weapon] call BIS_fnc_itemType) param [1, ""];
    ([_weapon] call BR_fnc_lootWeaponStats) params ["_hit", "_speed", "", "_reload", "_rounds", "", "_automatic", "_simulation"];

    if (getNumber (_config >> "type") == 4 || {_minor in ["RocketLauncher", "MissileLauncher", "GrenadeLauncher", "Launcher"]} ||
        {_simulation in ["shotshell", "shotrocket", "shotmissile"]}) exitWith {"launchers"};

    private _pellets = (getArray (_config >> "magazines")) findIf {
        private _ammo = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        private _ammoSimulation = toLowerANSI getText (_ammo >> "simulation");

        _ammoSimulation == "shotspread" || {_ammoSimulation == "shotsubmunitions" && {count getArray (_ammo >> "submunitionConeType") >= 2}}
    };

    if (_minor == "Shotgun" || {_pellets != -1}) exitWith {"shotguns"};

    BR_var_lootSmgSlowAmmo params ["_slowSpeed", "_slowHit"];

    if (_minor in ["SubmachineGun", "SMG"] ||
        {_automatic && {_hit < BR_var_lootSmgMaxHit || {_speed < _slowSpeed && {_hit < _slowHit}}}}) exitWith {"smgs"};

    if (_minor == "MachineGun" || {_automatic && {_rounds >= BR_var_lootMgMinRounds}}) exitWith {"machineGuns"};

    if (_hit >= BR_var_lootAntiMaterielMinHit) exitWith {"antiMateriel"};

    if (_reload >= BR_var_lootBoltActionReload) exitWith {"snipers"};

    if (_minor == "SniperRifle" || {!_automatic && {_hit >= BR_var_lootMarksmanMinHit} && {_rounds <= BR_var_lootMarksmanMaxRounds}}) exitWith {"marksman"};

    "assaultRifles"
};

/*
    The keys that make weapons one family: its model (of the base weapon without attachments, baseWeapon) - skins
    share the model and only swap textures, attachment presets (LinkedItems) are their base weapon - and its display
    name without the bracketed suffix ("MX 6.5 mm (Black)" -> "mx 6.5 mm"), for mods that give a skin its own model.
    Two weapons of the same class that share a key are one family (BR_fnc_initLootWeapons).
*/
BR_fnc_weaponFamilyKeys = {
    params ["_weapon"];

    private _config = configFile >> "CfgWeapons" >> _weapon;
    private _base = getText (_config >> "baseWeapon");
    if (_base == "" || {!isClass (configFile >> "CfgWeapons" >> _base)}) then {_base = _weapon};

    private _model = toLowerANSI getText (configFile >> "CfgWeapons" >> _base >> "model");
    if ((_model select [0, 1]) == "\") then {_model = _model select [1]};
    if (count _model > 4 && {(_model select [count _model - 4]) == ".p3d"}) then {_model = _model select [0, count _model - 4]};

    private _keys = [if (_model == "") then {"c:" + toLowerANSI _base} else {"m:" + _model}];
    private _name = toLowerANSI getText (_config >> "displayName");
    private _bracket = _name find "(";
    if (_bracket != -1) then {_name = _name select [0, _bracket]};
    _name = (_name splitString " ") joinString " ";
    if (_name != "") then {_keys pushBack ("n:" + _name)};

    _keys
};

// a weapon's quality score: damage x sqrt(rate of fire x reach) x magazine^0.25 / (1 + inertia); only its rank within
// its class matters (BR_fnc_initLootWeapons)
BR_fnc_weaponQualityScore = {
    params ["_weapon"];

    ([_weapon] call BR_fnc_lootWeaponStats) params ["_hit", "_speed", "_dispersion", "_reload", "_rounds", "_inertia"];
    private _reach = 40 max (_speed * 0.6 / (1 max (_dispersion * 1000))) min 1500;

    (1 max _hit) * sqrt ((1 / (0.06 max _reload)) * _reach) * ((1 max _rounds) ^ 0.25) / (1 + (0 max _inertia))
};

/*
    Weapon roll data (BR_fnc_rollWeapon), once per mission from the completed pools:
    BR_var_lootWeaponClassData: per row of BR_var_lootWeaponClasses [class, loot category, share at military sites,
        shares per tier, [family (its variants), ...] worst to best, per tier [family weight, ...]].
    BR_var_lootWeaponTierClasses: "" (any weapon) / category -> per tier [[row, ...], [share, ...]]: the classes a
        building tier rolls.
    BR_var_lootWeaponFamilyOf: weapon (lower case) -> [row, family] (probes, logs).
    A building's weapon spot rolls any class of its tier, so the classes come out at the tier's shares.
*/
BR_fnc_initLootWeapons = {
    private _classNames = BR_var_lootWeaponClasses apply {_x select 0};
    private _keyMaps = _classNames apply {createHashMap}; // per row: family key -> family index
    private _familyLists = _classNames apply {[]};

    {
        private _category = _x;
        private _weapons = [];
        {_weapons append _x} forEach (BR_var_lootPools getOrDefault [_category, []]);
        _weapons = _weapons arrayIntersect _weapons;

        {
            private _weapon = _x;
            // a weapon without a magazine is useless as loot
            private _row = if (([_weapon] call BR_fnc_weaponMagazine) == "") then {-1} else {
                _classNames find ([_weapon, _category] call BR_fnc_weaponClass)
            };

            if (_row != -1) then {
                private _keyMap = _keyMaps select _row;
                private _families = _familyLists select _row;
                private _keys = [_weapon] call BR_fnc_weaponFamilyKeys;
                private _found = (_keys apply {_keyMap getOrDefault [_x, -1]}) select {_x != -1};
                _found = _found arrayIntersect _found;
                private _family = if (_found isEqualTo []) then {_families pushBack []} else {_found select 0};

                // a weapon that links two families (model of one, name of the other) merges them
                {
                    private _other = _x;

                    if (_other != _family) then {
                        (_families select _family) append (_families select _other);
                        _families set [_other, []];
                        {_keyMap set [_x, _family]} forEach ((keys _keyMap) select {(_keyMap get _x) == _other});
                    };
                } forEach _found;

                (_families select _family) pushBack _weapon;
                {_keyMap set [_x, _family]} forEach _keys;
            };
        } forEach _weapons;
    } forEach BR_var_lootWeaponCategories;

    BR_var_lootWeaponFamilyOf = createHashMap;

    BR_var_lootWeaponClassData = BR_var_lootWeaponClasses apply {
        _x params ["_class", "_shares"];

        private _row = _classNames find _class;
        private _families = (_familyLists select _row) select {_x isNotEqualTo []};

        // worst to best by the best variant's score (variants differ in attachments at most)
        private _ranked = [];
        {_ranked pushBack [selectMax (_x apply {[_x] call BR_fnc_weaponQualityScore}), _forEachIndex]} forEach _families;
        _ranked sort true;
        _families = _ranked apply {_families select (_x select 1)};

        private _count = count _families;
        private _tierWeights = [];

        {
            _x params ["_exponent", "_minQuality", "_maxQuality"];

            private _best = BR_var_lootQualityRatio ^ _exponent;
            private _weights = [];

            for "_i" from 0 to _count - 1 do {
                private _quality = 0.5;
                if (_count > 1) then {_quality = _i / (_count - 1)};
                _weights pushBack ([0, 1 + (_best - 1) * _quality] select (_quality >= _minQuality && {_quality <= _maxQuality}));
            };

            // a class the tier does not hold (share 0) has no family there
            _tierWeights pushBack ([_weights apply {0}, _weights] select ((_shares select _forEachIndex) > 0));
        } forEach BR_var_lootTierQuality;

        {
            private _family = _forEachIndex;
            {BR_var_lootWeaponFamilyOf set [toLowerANSI _x, [_row, _family]]} forEach _x;
        } forEach _families;

        // [class, category, share in supply drops / at military sites, shares per tier, families, weights per tier]
        [_class, ["primaries", "handguns"] select (_class == "handguns"), _shares select 3, _shares, _families, _tierWeights]
    };

    // per key ("": any weapon - a weapon spot of a building; "primaries"/"handguns": that slot) per tier [[row, ...],
    // [share, ...]]: the classes the tier holds that have weapons
    BR_var_lootWeaponTierClasses = createHashMap;

    {
        private _category = _x;

        BR_var_lootWeaponTierClasses set [_category, [0, 1, 2, 3] apply {
            private _tier = _x;
            private _rows = [];
            private _shares = [];

            {
                _x params ["", "_rowCategory", "", "_tierShares", "_families", "_tierWeights"];

                if ((_category == "" || {_rowCategory == _category}) && {(_tierShares select _tier) > 0} &&
                    {((_tierWeights select _tier) call BR_fnc_lootSum) > 0}) then {
                    _rows pushBack _forEachIndex;
                    _shares pushBack (_tierShares select _tier);
                };
            } forEach BR_var_lootWeaponClassData;

            [_rows, _shares]
        }];
    } forEach ([""] + BR_var_lootWeaponCategories);

    // e.g. "assaultRifles [6,10,22,34]: 41 families, 160 weapons, families per tier [12,20,30,21]": per class its shares
    // in % per tier, its families and weapons and the families each tier rolls
    diag_log format ["BR loot weapons: %1", (BR_var_lootWeaponClassData apply {
        _x params ["_class", "", "", "_tierShares", "_families", "_tierWeights"];

        format ["%1 %2: %3 families, %4 weapons, families per tier %5", _class, _tierShares, count _families,
            (_families apply {count _x}) call BR_fnc_lootSum, _tierWeights apply {{_x > 0} count _x}]
    }) joinString "; "];
};

/*
    BR_var_ammoFamilies: per tier [[caliber, ...], [weight, ...], [magazine, ...]]: a caliber's weight is its chance in
    a weapon roll of the tier (BR_fnc_rollWeapon: spot category, class, family, variant), its magazine the one its
    weapons take most - ammo without a weapon nearby is as common as the weapons of its caliber.
*/
BR_fnc_initAmmoFamilies = {
    BR_var_ammoFamilies = [];

    for "_tier" from 0 to 3 do {
        private _families = createHashMap; // caliber -> [weight, magazine -> weight]
        ((BR_var_lootWeaponTierClasses get "") select _tier) params ["_rows", "_shares"];
        private _shareTotal = 1e-9 max (_shares call BR_fnc_lootSum);

        {
            private _classChance = (_shares select _forEachIndex) / _shareTotal;
            (BR_var_lootWeaponClassData select _x) params ["", "", "", "", "_classFamilies", "_tierWeights"];
            private _weights = _tierWeights select _tier;
            private _weightTotal = 1e-9 max (_weights call BR_fnc_lootSum);

            {
                private _variantChance = _classChance * (_weights select _forEachIndex) / _weightTotal / (count _x);

                if (_variantChance > 0) then {
                    {
                        private _magazine = [_x] call BR_fnc_weaponMagazine;
                        private _entry = _families getOrDefaultCall [[_magazine] call BR_fnc_magazineFamily, {[0, createHashMap]}, true];
                        private _magazines = _entry select 1;

                        _entry set [0, (_entry select 0) + _variantChance];
                        _magazines set [_magazine, (_magazines getOrDefault [_magazine, 0]) + _variantChance];
                    } forEach _x;
                };
            } forEach _classFamilies;
        } forEach _rows;

        private _names = keys _families;

        BR_var_ammoFamilies pushBack [
        _names,
        _names apply {(_families get _x) select 0},

        _names apply {
            private _magazines = (_families get _x) select 1;
            private _counts = values _magazines;

            (keys _magazines) select (_counts find (selectMax _counts))
        }

        ];
    };
};

// the caliber of a magazine: its ammo class (lower case)
BR_fnc_magazineFamily = {
    params ["_magazine"];

    toLowerANSI getText (configFile >> "CfgMagazines" >> _magazine >> "ammo")
};

// a magazine for no weapon in particular: a caliber of the weapon pool by its weapons' chance (BR_fnc_initAmmoFamilies)
BR_fnc_rollAmmoFamily = {
    params ["_tierWeights"];

    private _available =[0, 1, 2, 3] select {((BR_var_ammoFamilies select _x) select 0) isNotEqualTo [] &&
        {(_tierWeights param [_x, 0]) > 0}};

    if (_available isEqualTo []) exitWith {""};

    (BR_var_ammoFamilies select (_available selectRandomWeighted (_available apply {_tierWeights select _x}))) params ["", "_weights", "_magazines"];

    _magazines selectRandomWeighted _weights
};

// _class if the loaded game has that magazine (the item carriers come from DLC content), else ""
BR_fnc_existingMagazine = {
    params ["_class"];

    ["", _class] select (isClass (configFile >> "CfgMagazines" >> _class))
};

// the loot category of a class ("" for classes outside the pools, e.g. magazines of the "ammo" loot)
BR_fnc_lootCategory = {
    params ["_class"];

    BR_var_lootClassCategories getOrDefault [toLowerANSI _class, ""]
};

/*
    A weapon of loot category _category ("primaries"/"handguns"; "": any weapon, a building's weapon spot) for
    _tierWeights [poor, medium, rare, elite]: a tier (only tiers in which the category has a class), a class of it by
    its share in that tier, a family by its weight in that tier (quality), one of the family's variants (skins,
    presets) evenly; "" if nothing fits (BR_fnc_initLootWeapons).
*/
BR_fnc_rollWeapon = {
    params ["_category", "_tierWeights", ["_onlyClasses", []]];

    private _tierClasses = BR_var_lootWeaponTierClasses getOrDefault [_category, []];

    // a theme's weapon classes (BR_var_lootThemes): only their rows, at their shares of the tier
    if (_onlyClasses isNotEqualTo []) then {
        _tierClasses = _tierClasses apply {
            _x params ["_rows", "_shares"];
            private _keep = [[], []];

            {
                if (((BR_var_lootWeaponClassData select _x) select 0) in _onlyClasses) then {
                    (_keep select 0) pushBack _x;
                    (_keep select 1) pushBack (_shares select _forEachIndex);
                };
            } forEach _rows;

            _keep
        };
    };
    private _tiers = [0, 1, 2, 3] select {(_tierWeights param [_x, 0]) > 0 && {((_tierClasses param [_x, [[]]]) select 0) isNotEqualTo []}};

    if (_tiers isEqualTo []) exitWith {""};

    private _tier = _tiers selectRandomWeighted (_tiers apply {_tierWeights select _x});
    (_tierClasses select _tier) params ["_rows", "_shares"];
    (BR_var_lootWeaponClassData select (_rows selectRandomWeighted _shares)) params ["", "", "", "", "_families", "_familyWeights"];

    selectRandom (_families selectRandomWeighted (_familyWeights select _tier))
};

// a random class of a category; _tierWeights [common, uncommon, rare, elite]; "" if nothing fits. _classes: the
// classes of a theme entry (BR_fnc_initLootThemes), one of them regardless of the tiers
BR_fnc_rollLoot = {
    params ["_category", "_tierWeights", ["_classes", []]];

    if (_classes isNotEqualTo []) exitWith {selectRandom _classes};

    // weapons: class, family and quality (BR_fnc_rollWeapon); "": any weapon class
    if (_category == "" || {_category in BR_var_lootWeaponCategories}) exitWith {[_category, _tierWeights] call BR_fnc_rollWeapon};

    private _tiers = BR_var_lootPools getOrDefault [_category, [[], [], [], []]];

    // gear apart by kind (BR_var_lootKindPools): the building's own kind mostly, the other one now and then; the kind
    // first, then the tier: a kind without classes in the rolled tier takes its nearest tier that has some (CUP's
    // civilian clothes are all in the poor tier)
    private _kindPools = BR_var_lootKindPools get _category;

    if (!isNil "_kindPools") exitWith {
        (_kindPools select ([_tierWeights] call BR_fnc_lootProfile)) params ["_main", "_other"];
        private _kind = [_other, _main] select (random 1 < BR_var_lootKindMain);
        if ((_kind findIf {_x isNotEqualTo []}) == -1) then {_kind = [_main, _other] select (_kind isEqualTo _main)};

        private _weighted = [0, 1, 2, 3] select {(_tierWeights param [_x, 0]) > 0};
        private _filled = [0, 1, 2, 3] select {(_kind select _x) isNotEqualTo []};
        if (_weighted isEqualTo [] || {_filled isEqualTo []}) exitWith {""};

        private _rolled = _weighted selectRandomWeighted (_weighted apply {_tierWeights select _x});
        private _distances = _filled apply {abs (_x - _rolled)};

        selectRandom (_kind select (_filled select (_distances find (selectMin _distances))))
    };

    private _available = [0, 1, 2, 3] select {(_tiers select _x) isNotEqualTo [] && {(_tierWeights param [_x, 0]) > 0}};

    if (_available isEqualTo []) exitWith {""};

    private _tier = _available selectRandomWeighted (_available apply {_tierWeights select _x});

    selectRandom (_tiers select _tier)
};

// the loot profile of tier weights: 1 (military) when the elite tier has at least half of them (military sites,
// supply drops), else 0 (civilian)
BR_fnc_lootProfile = {
    params ["_tierWeights"];

    [0, 1] select ((_tierWeights param [3, 0]) * 2 >= (1e-9 max (_tierWeights call BR_fnc_lootSum)))
};

/*
    The kind of a gear class of loot category _category: 0 civilian, 1 military, 2 military only (never in civilian
    buildings). Uniforms by their wearer's side, vests and helmets by armor level (level 0 civilian, from
    BR_var_lootMilitaryOnlyArmor military only), attachments: night/thermal vision and laser designators military only,
    suppressors military, the rest (sights, lights, bipods, binoculars) civilian; throwables: explosive ones military
    only, smoke and light civilian.
*/
BR_fnc_lootItemKind = {
    params ["_class", "_category"];

    if (_category in ["vests", "helmets"]) exitWith {
        private _level = [_class, [605, 701] select (_category == "vests")] call BR_fnc_airdropArmorLevel;
        [[0, 1] select (_level > 0), 2] select (_level >= BR_var_lootMilitaryOnlyArmor)
    };

    switch (_category) do {
        case "uniforms": {[0, 1] select (([_class, false] call BR_fnc_aiClothingProfile) select 2)};
        case "attachments": {
            private _config = configFile >> "CfgWeapons" >> _class;
            private _minor = ([_class] call BIS_fnc_itemType) param [1, ""];
            private _vision = getArray (_config >> "visionMode");
            {_vision append getArray (_x >> "visionMode")} forEach ("true" configClasses (_config >> "ItemInfo" >> "OpticsModes"));
            _vision = _vision apply {toUpperANSI _x};

            if (_minor in ["NVGoggles", "LaserDesignator"] || {"TI" in _vision} || {"NVG" in _vision}) then {2} else {
                [0, 1] select (_minor == "AccessoryMuzzle")
            }
        };
        case "throwables": {
            private _ammo = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _class >> "ammo");
            [0, 2] select (getNumber (_ammo >> "indirectHit") > 0)
        };
        default {0};
    };
};

/*
    BR_var_lootKindPools: category (of BR_var_lootKindCategories) -> per profile [main, other], each per tier [classes]:
    civilian buildings [civilian, military], military sites [military + military only, civilian] (BR_fnc_rollLoot).
*/
BR_fnc_initLootKinds = {
    BR_var_lootKindPools = createHashMap;
    BR_var_lootAttachmentKinds = createHashMap; // attachment (lower case) -> [class, kind] (BR_fnc_rollWeaponAttachment)
    BR_var_lootWeaponAttachments = createHashMap; // weapon -> [[civilian attachments], [all]] (cache)
    private _counts = [];

    {
        private _category = _x;
        private _tiers = BR_var_lootPools getOrDefault [_category, [[], [], [], []]];
        private _byKind = [0, 1, 2] apply {[[], [], [], []]};

        {
            private _tier = _forEachIndex;
            {((_byKind select ([_x, _category] call BR_fnc_lootItemKind)) select _tier) pushBack _x} forEach _x;
        } forEach _tiers;

        _byKind params ["_civilian", "_military", "_militaryOnly"];

        if (_category == "attachments") then {
            {
                private _kind = _forEachIndex;
                {{BR_var_lootAttachmentKinds set [toLowerANSI _x, [_x, _kind]]} forEach _x} forEach _x;
            } forEach _byKind;
        };
        private _militaryAll = [0, 1, 2, 3] apply {(_military select _x) + (_militaryOnly select _x)};
        BR_var_lootKindPools set [_category, [[_civilian, _military], [_militaryAll, _civilian]]];
        _counts pushBack format ["%1 %2", _category, _byKind apply {(_x apply {count _x}) call BR_fnc_lootSum}];
    } forEach BR_var_lootKindCategories;

    // e.g. "vests [12, 40, 9]": civilian, military, military-only classes per category
    diag_log format ["BR loot kinds: %1", _counts joinString ", "];
};

// the default magazine of a weapon (cached), "" if it has none
BR_fnc_weaponMagazine = {
    params ["_weapon"];

    if (_weapon == "") exitWith {""};

    private _magazine = BR_var_magazineCache get _weapon;

    if (isNil "_magazine") then {
        _magazine = (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")) param [0, ""];

        if (_magazine == "") then {
            _magazine = (compatibleMagazines _weapon) param [0, ""];
        };

        BR_var_magazineCache set [_weapon, _magazine];
    };

    _magazine
};

// every magazine a weapon takes, lower case (cached); [] for ""
BR_fnc_weaponMagazines = {
    params ["_weapon"];

    if (_weapon == "") exitWith {[]};

    private _magazines = BR_var_weaponMagazinesCache get _weapon;

    if (isNil "_magazines") then {
        _magazines = (compatibleMagazines _weapon) apply {toLowerANSI _x};
        BR_var_weaponMagazinesCache set [_weapon, _magazines];
    };

    _magazines
};

// a random count in [min, max]
BR_fnc_randomCount = {
    params ["_minCount", "_maxCount"];

    _minCount + floor random (1 + _maxCount - _minCount)
};

// a weapon of the category with some of its own magazines (content format of BR_fnc_rollLootContent); _classes: see
// BR_fnc_rollLoot
BR_fnc_rollWeaponLoot = {
    params ["_category", "_tierWeights", ["_magazineCount", -1], ["_classes", []], ["_weaponClasses", []]];

    private _profile = [_tierWeights] call BR_fnc_lootProfile;
    private _weapon = "";

    // a theme's weapon classes; a tier without any of them rolls any weapon
    if (_weaponClasses isNotEqualTo []) then {_weapon = ["", _tierWeights, _weaponClasses] call BR_fnc_rollWeapon};
    if (_weapon == "") then {_weapon = [_category, _tierWeights, _classes] call BR_fnc_rollLoot};

    if (_magazineCount < 0) then {
        _magazineCount = (BR_var_lootWeaponMagazines select _profile) call BR_fnc_randomCount;
    };

    private _content = [["weapon", _weapon, 1], ["magazine", [_weapon] call BR_fnc_weaponMagazine, _magazineCount]];

    if (_weapon != "" && {random 1 < (BR_var_lootWeaponAttachmentChance select _profile)}) then {
        _content pushBack ["item", [_weapon, _profile] call BR_fnc_rollWeaponAttachment, 1];
    };

    _content
};

// an attachment of the pools that fits _weapon (compatibleItems, cached): civilian ones (sights, lights, bipods) for
// profile 0, any for profile 1; "" if none fits
BR_fnc_rollWeaponAttachment = {
    params ["_weapon", "_profile"];

    private _fits = BR_var_lootWeaponAttachments get _weapon;

    if (isNil "_fits") then {
        _fits = [[], []];

        {
            private _entry = BR_var_lootAttachmentKinds get toLowerANSI _x;

            if (!isNil "_entry") then {
                _entry params ["_class", "_kind"];
                if (_kind == 0) then {(_fits select 0) pushBackUnique _class};
                (_fits select 1) pushBackUnique _class;
            };
        } forEach (compatibleItems _weapon);

        BR_var_lootWeaponAttachments set [_weapon, _fits];
    };

    private _list = _fits select _profile;
    if (_list isEqualTo []) exitWith {""};

    selectRandom _list
};

// a loot category by the weights of BR_var_lootCategories for loot profile _profile (0 civilian, 1 military)
BR_fnc_rollLootCategory = {
    params [["_profile", 0]];

    BR_var_lootCategoryNames selectRandomWeighted (BR_var_lootCategoryWeights select _profile)
};

/*
    The content of one loot spot: [[cargo type, class, count], ...] with cargo type "weapon", "magazine", "backpack" or
    "item"; entries without a class are dropped. _weapons (filled with every weapon rolled here) are the weapons of the
    same building or crate, rolled before its other spots: ammo is mostly for one of them, else for a caliber of the
    pool (BR_fnc_rollAmmoFamily). _category: a rolled one (BR_fnc_rollLootCategory), else one is rolled here. _classes:
    the classes of a theme entry (BR_fnc_rollLootSpot), else the category's pool.
*/
BR_fnc_rollLootContent = {
    params ["_tierWeights", ["_weapons", []], ["_category", ""], ["_classes", []]];

    if (_category == "") then {
        _category = [[_tierWeights] call BR_fnc_lootProfile] call BR_fnc_rollLootCategory;
    };

    private _content = switch (_category) do {
        // a weapon spot rolls any weapon class of the tier (handgun or primary by its shares), a theme entry its classes
        case "primaries": {
            private _weaponContent = [["", _category] select (_classes isNotEqualTo []), _tierWeights, -1, _classes] call BR_fnc_rollWeaponLoot;
            _weapons pushBack ((_weaponContent select 0) select 1);
            _weaponContent
        };
        case "handguns": {
            private _weaponContent = [["", _category] select (_classes isNotEqualTo []), _tierWeights, -1, _classes] call BR_fnc_rollWeaponLoot;
            _weapons pushBack ((_weaponContent select 0) select 1);
            _weaponContent
        };
        // a theme entry of weapon classes (BR_var_lootThemes)
        case "weapons": {
            private _weaponContent = ["", _tierWeights, -1, [], _classes] call BR_fnc_rollWeaponLoot;
            _weapons pushBack ((_weaponContent select 0) select 1);
            _weaponContent
        };
        case "ammo": {
            private _magazine = if (_weapons isNotEqualTo [] && {random 1 < BR_var_lootAmmoMatchChance}) then {
                [selectRandom _weapons] call BR_fnc_weaponMagazine
            } else {

                [_tierWeights] call BR_fnc_rollAmmoFamily
            };

            [["magazine", _magazine, (BR_var_lootAmmoCount select ([_tierWeights] call BR_fnc_lootProfile)) call BR_fnc_randomCount]]
        };
        case "backpacks": {
            [["backpack", [_category, _tierWeights, _classes] call BR_fnc_rollLoot, 1]]
        };
        case "throwables": {
            [["magazine", [_category, _tierWeights, _classes] call BR_fnc_rollLoot, 1 + floor random 2]]
        };
        case "bandages": {
            [["magazine", [BR_var_bandageClass] call BR_fnc_existingMagazine, 1 + floor random 3]]
        };
        case "drinks": {
            [["magazine", [BR_var_drinkClass] call BR_fnc_existingMagazine, 1]]
        };
        case "medical": {
            private _medicalTiers = BR_var_lootMedicalTiers select ([_tierWeights] call BR_fnc_lootProfile);
            [["item", [_category, _medicalTiers, _classes] call BR_fnc_rollLoot, 1 + floor random 2]]
        };
        default {
            private _class = [_category, _tierWeights, _classes] call BR_fnc_rollLoot;
            private _entries = [["item", _class, 1]];

            if (_category == "attachments") then {
                if ((([_class] call BIS_fnc_itemType) param [1, ""]) in ["Binocular", "LaserDesignator"]) then {
                    (_entries select 0) set [0, "weapon"];
                };

                private _magazine = [_class] call BR_fnc_weaponMagazine;
                if (_magazine != "") then {_entries pushBack ["magazine", _magazine, 1]};
            };

            _entries
        };
    };

    _content select {(_x select 1) != ""}
};

BR_fnc_addLootCargo = {
    params ["_container", "_content"];

    {
        _x params ["_cargoType", "_class", "_count"];

        // "": the class is missing in the loaded game (an empty pool, an item carrier of a DLC)
        if (_class != "") then {
            switch (_cargoType) do {
                case "weapon": {_container addWeaponCargoGlobal [_class, _count]};
                case "magazine": {_container addMagazineCargoGlobal [_class, _count]};
                case "backpack": {_container addBackpackCargoGlobal [_class, _count]};
                default {_container addItemCargoGlobal [_class, _count]};
            };
        };
    } forEach _content;
};

// ---- loot in buildings ----

// Fast cargo count; cleanup also compares the full snapshot to detect equal-count swaps and partial-mag changes.
BR_fnc_cargoCount = {
    params ["_container"];

    count (weaponCargo _container) + count (magazineCargo _container) + count (itemCargo _container) + count (backpackCargo _container)
};

// the loot holders in a building that still hold something (also loot others dropped there)
BR_fnc_buildingLootHolders = {
    params ["_building"];

    (boundingBoxReal _building) params ["_corner1", "_corner2"];

    (nearestObjects [_building, ["GroundWeaponHolder"], (_corner1 distance _corner2) / 2 + BR_var_holderSearchMargin]) select {
        ([_x] call BR_fnc_cargoCount) > 0
    }
};

/*
    [tier weights, loot spots at most] of a building by its class (cached): military sites best, then big and special
    buildings (churches, castles, offices, industry), then normal houses; run-down and ruined houses worst.
*/
BR_fnc_buildingLootQuality = {
    params ["_building"];

    private _class = [_building] call BR_fnc_lootClassKey;
    private _quality = BR_var_buildingLootCache get _class;

    if (isNil "_quality") then {
        private _index = BR_var_buildingLootClasses findIf {
            private _parts = _x select 0;

            (_parts findIf {(_class find _x) != -1}) != -1
        };

        _quality = if (_index == -1) then {BR_var_buildingLootDefault} else {(BR_var_buildingLootClasses select _index) select [1, 2]};
        BR_var_buildingLootCache set [_class, _quality];
    };

    _quality
};

// the row of BR_var_lootThemes of a building by its class (cached), -1 for a building without a theme
BR_fnc_buildingLootTheme = {
    params ["_building"];

    private _class = [_building] call BR_fnc_lootClassKey;
    private _theme = BR_var_buildingThemeCache get _class;

    if (isNil "_theme") then {
        _theme = BR_var_lootThemes findIf {
            private _parts = _x select 0;

            (_parts findIf {(_class find _x) != -1}) != -1
        };

        BR_var_buildingThemeCache set [_class, _theme];
    };

    _theme
};

// [category, theme classes] of one loot spot of a building with theme row _theme (-1: none): the theme's share of the
// spots rolls an entry of the theme (BR_var_lootThemePools), the rest a category as usual
BR_fnc_rollLootSpot = {
    params ["_theme", ["_profile", 0]];

    if (_theme == -1) exitWith {[[_profile] call BR_fnc_rollLootCategory, []]};

    (BR_var_lootThemePools select _theme) params ["_entries", "_weights"];

    if (_entries isEqualTo [] || {random 1 >= ((BR_var_lootThemes select _theme) select 1)}) exitWith {
        [[_profile] call BR_fnc_rollLootCategory, []]
    };

    +(_entries selectRandomWeighted _weights)
};

/*
    Variables of buildings and loot sources (server-local), kept in a HashMap by hashValue: setVariable does nothing on
    terrain objects without a config class (e.g. the army tents ca\misc3\tent_east.p3d of the map mod).
*/
BR_var_buildingVars = createHashMap;

BR_var_buildingVarsNone = createHashMap; // never written: the vars of a building without any
BR_fnc_bGet = {
    params ["_object", "_name", "_default"];
    private _vars = BR_var_buildingVars getOrDefault [hashValue _object, BR_var_buildingVarsNone];
    // a nil default (tent positions): the plain get, which returns nil for a missing entry
    if (isNil "_default") exitWith {_vars get _name};
    _vars getOrDefault [_name, _default]
};

BR_fnc_bSet = {
    params ["_object", "_name", "_value"];
    private _vars = BR_var_buildingVars getOrDefaultCall [hashValue _object, {createHashMap}, true];
    if (isNil "_value") then {_vars deleteAt _name} else {_vars set [_name, _value]};
};

/*
    BR_var_lootState of a building (server-local): nil = never visited, "spawned" = its loot lies there, "cached" =
    removed again, BR_var_lootCache holds the specs [posASL, content] to spawn it once more.
*/
BR_fnc_spawnBuildingLoot = {
    params ["_building"];

    if !([_building] call BR_fnc_isLootBuilding) exitWith {
        [_building, "BR_var_lootState", "excluded"] call BR_fnc_bSet;
    };

    private _specs = [_building, "BR_var_lootCache", []] call BR_fnc_bGet;

    if (_specs isEqualTo []) then {
        ([_building] call BR_fnc_buildingLootQuality) params ["_tierWeights", "_maxSpots"];

        private _theme = [_building] call BR_fnc_buildingLootTheme;
        private _profile = [_tierWeights] call BR_fnc_lootProfile;
        private _weapons = [];
        private _spots = []; // [position, category, theme classes]

        {
            if (count _spots >= _maxSpots) exitWith {};

            if (random 1 < BR_var_lootChance) then {
                _spots pushBack ([_x] + ([_theme, _profile] call BR_fnc_rollLootSpot));
            };
        } forEach (([_building] call BR_fnc_lootPositions) call BIS_fnc_arrayShuffle);

        // the weapons first: the building's ammo is for them
        {
            _x params ["_pos", "_category", "_classes"];

            private _content = [_tierWeights, _weapons, _category, _classes] call BR_fnc_rollLootContent;

            if (_content isNotEqualTo []) then {
                // on the floor under the building position: the Livonia barracks have theirs up to 0.43 m above it,
                // Land_i_Barracks_V1_F 0.52 m
                private _posASL = AGLToASL _pos;
                private _floor = lineIntersectsSurfaces [_posASL vectorAdd [0, 0, 0.1], _posASL vectorAdd [0, 0, -1],
                    objNull, objNull, true, 1, "GEOM", "FIRE"];
                if (_floor isNotEqualTo []) then {_posASL = (_floor select 0) select 0};
                _specs pushBack [_posASL vectorAdd [0, 0, 0.05], _content];
            };
        } forEach (

        (_spots select {(_x select 1) in BR_var_lootWeaponCategories || {(_x select 1) == "weapons"}}) +
        (_spots select {!((_x select 1) in BR_var_lootWeaponCategories) && {(_x select 1) != "weapons"}})
        );
    };

    [_building, "BR_var_lootCache", nil] call BR_fnc_bSet;
    [_building, "BR_var_lootState", "spawned"] call BR_fnc_bSet;

    {
        _x params ["_posASL", "_content"];

        private _holder = createVehicle ["GroundWeaponHolder", [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _holder setDir random 360;
        _holder setPosASL _posASL;
        [_holder, _content] call BR_fnc_addLootCargo;
        BR_var_lootHolders pushBack [_holder, _building, _x, [_holder] call BR_fnc_cargoCount,
        str ([_holder] call BR_fnc_aiReadCargo)];
    } forEach _specs;
};

// scheduled, from the flight on: loot around players (AI spawns the loot of the buildings it searches), cleanup now and
// then
BR_fnc_lootLoop = {
    private _nextCleanup = time + BR_var_lootCleanupInterval;

    waitUntil {
        private _seekers = BR_var_rosterUnits select {
            alive _x && {isPlayer _x} && {simulationEnabled _x} && {((getPos _x) select 2) < BR_var_lootSeekHeight}
        };

        {
            {
                private _state = [_x, "BR_var_lootState", nil] call BR_fnc_bGet;

                if (isNil "_state" || {_state == "cached"}) then {
                    [_x] call BR_fnc_spawnBuildingLoot;
                };
            } forEach ([getPosATL _x, BR_var_lootRadius] call BR_fnc_lootBuildingsNear);
        } forEach _seekers;

        if (time >= _nextCleanup) then {
            _nextCleanup = time + BR_var_lootCleanupInterval;
            [BR_var_rosterUnits select {alive _x && {simulationEnabled _x}}] call BR_fnc_cleanUpLoot;
        };

        sleep BR_var_lootInterval;
        BR_var_state == "ended"
    };
};

/*
    Removes untouched loot far from all combatants (players and AI, _watchers) and remembers it on its building. The
    watchers are sorted into a grid of BR_var_lootCleanupDistance cells first: a holder only looks at its 3x3 cells.
*/
BR_fnc_cleanUpLoot = {
    params ["_watchers"];

    private _grid = createHashMap;

    {
        private _pos = getPosATL _x;

        (_grid getOrDefaultCall [[floor ((_pos select 0) / BR_var_lootCleanupDistance),
            floor ((_pos select 1) / BR_var_lootCleanupDistance)], {[]}, true]) pushBack _x;
    } forEach _watchers;

    BR_var_lootHolders = BR_var_lootHolders select {
        _x params ["_holder", "_building", "_spec", "_cargoCount", ["_initialCargo", ""]];

        private _keep = false;

        if (!isNull _holder) then {
            private _holderPos = getPosATL _holder;
            private _cellX = floor ((_holderPos select 0) / BR_var_lootCleanupDistance);
            private _cellY = floor ((_holderPos select 1) / BR_var_lootCleanupDistance);
            private _isWatched = false;

            for "_offsetX" from -1 to 1 do {
                for "_offsetY" from -1 to 1 do {
                    if (!_isWatched) then {
                        _isWatched = ((_grid getOrDefault [[_cellX + _offsetX, _cellY + _offsetY], []]) findIf {
                            _x distance2D _holderPos < BR_var_lootCleanupDistance

                        }) != -1;
                    };
                };
            };

            // touched loot is no longer tracked: it belongs to the combatants now
            if(_isWatched || {([_holder] call BR_fnc_cargoCount) != _cargoCount} ||
                {_initialCargo == "" || {str ([_holder] call BR_fnc_aiReadCargo) != _initialCargo}}) then {
                _keep = _isWatched;
            } else {

                deleteVehicle _holder;
                [_building, "BR_var_lootCache", ([_building, "BR_var_lootCache", []] call BR_fnc_bGet) + [_spec]] call BR_fnc_bSet;
                [_building, "BR_var_lootState", "cached"] call BR_fnc_bSet;
            };
        };

        _keep
    };
};

// ---- loot sites and airfields (map markers) ----

// Four kinds of marked sites only:
// [how, what, marker type, color, link distance, least counted buildings of a site, class parts left out, [smallest,
// largest marker size], class parts of which a site needs one, class parts that only place the marker, true: one
// building of those core parts is a site by itself, else the least buildings are needed]. A themed
// building only counts for its theme; a lone tent is no site of any kind. The order is the drawing order, bottom to
// top: green, white, blue, red, then the airfields.
// - green, hunting camps: buildings of the hunting theme (row 1) within 300 m, 2 or more, with a camp cabin or a castle
//   (keep, bastion) among them: deer stands and feed shacks alone are no camp, and the map does not even show them;
//   a single cabin in the forest is none either. Left out: log houses and the small huts (hut06) - they hold hunting
//   loot but stand in every village. Castle walls, stairs and gates do not count but place the marker: on the castle,
//   not on a ruin beside it (Devil's Castle);
// - white, special civilian buildings: churches, office blocks (CUP A_Office, Altis Offices_01 - not the military
//   offices MilOffices, they are red), airport buildings, schools
//   ... by class parts - a single one counts, plain houses, sheds, barns and shops never. Not: halls (hangars, factory
//   halls), lighthouses, castles (hunting places), wayside chapels (1 loot spot), radar stations (military sites, the
//   NWAF satellite dish);
// - blue, medical places: buildings and tents of the medical theme (row 0 of BR_var_lootThemes), a single one counts;
// - red, military places: buildings of the military loot class (row 0 of BR_var_buildingLootClasses) within 350 m: 2 or
//   more, or a single barrack, bunker or control tower - every base, also a small one, gets a marker; a lone
//   watchtower is none (they stand all around the bases). Balota
//   airfield: its barrack with two watchtowers and its control tower.
BR_var_lootSiteKinds = [
["theme", 1, "n_recon", "ColorGreen", 300, 2, ["house_2w05", "hut06"], [0.5, 0.9],
    ["camp_house", "castle_bergfrit", "castleruins", "bastion"], ["castle_wall", "castle_stairs", "castle_gate"]],
["parts", ["church", "a_office", "offices_01", "airport", "school", "police", "stadium", "hotel", "power_plant",
    "powerplant", "observatory"],
    "c_unknown", "ColorWhite", 150, 1, [], [0.65, 0.8], [], []],
["theme", 0, "n_med", "ColorBlue", 150, 1, [], [0.65, 0.9], [], []],
["quality", 0, "n_installation", "ColorRed", 350, 2, [], [0.5, 1],
    ["barrack", "bunker", "mil_", "military", "miloffices", "cargo_hq", "cargo_house_v", "controltower", "tent"], [], true]
];
BR_var_lootSiteLink = 150; // default link distance of a kind
// towers on a base's perimeter join a site but never link it on and never start one
BR_var_lootSiteTowers = ["guardtower", "watchtower"];
// marker size by the counted buildings of a site: 1 building the kind's smallest, each step up as
// the square root, at most its largest; the civilian icon is drawn smaller than the NATO ones at the same size
BR_var_lootSiteSizeStep = 0.1; // size per square root of the further buildings (2: +0.1, 5: +0.2, 10: +0.3, 26: +0.5)
// two markers of different kinds closer than this (a camp with a medical tent) move apart to this distance, so both
// show when zoomed in; farther apart they stay on their buildings
BR_var_lootSiteMarkerNudge = 80;
// airfields: a plain grey plane icon (a NATO box would read as one more loot site)
BR_var_airfieldMarkerType = "c_plane";
BR_var_airfieldMarkerColor = "ColorGrey";
BR_var_lootSiteMarkers = [];

/*
    Scheduled (server): global map markers on the play area's loot sites and airfields. A site: buildings of one kind
    (BR_var_lootSiteKinds) linked by BR_var_lootSiteLink; its marker sits on the building closest to their middle (the
    middle itself can lie in the forest beside a spread camp) and grows with its buildings
    (BR_var_lootSiteSizeStep). Airfields: the world's runways
    (CfgWorlds ilsPosition and secondary airports).
*/
BR_fnc_markLootSites = {
    {deleteMarker _x} forEach BR_var_lootSiteMarkers;
    BR_var_lootSiteMarkers = [];

    private _houses = ((nearestObjects [BR_var_playAreaCenter, ["House"], BR_var_playAreaRadius, true]) +
    (BR_var_lootTents select {_x distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius})) select {[_x] call BR_fnc_isLootBuilding};
    private _counts = [];
    private _placed = []; // [position, kind index] of the markers so far

    {
        _x params ["_by", "_row", "_markerType", "_color", ["_link", BR_var_lootSiteLink], ["_leastBuildings", 1], ["_leftOut", []],
            ["_sizes", [0.5, 1]], ["_core", []], ["_placeOnly", []], ["_coreOrLeast", false]];
        private _kind = _forEachIndex;
        private _weights = if (_by == "quality") then {(BR_var_buildingLootClasses select _row) select 1} else {[]};
        private _buildings = []; // [position, loot spots, class for the log, counted, core, tent, tower]
        private _cells = createHashMap; // grid cell (_link) -> building indices

        {
            private _theme = [_x] call BR_fnc_buildingLootTheme;
            if !(_theme in BR_var_lootMarkerThemes) then {_theme = -1}; // the loot-only themes (police, barns, ...)
            private _class = toLowerANSI typeOf _x;
            // a terrain object without a class (army tents) by its model, as BR_fnc_buildingLootQuality
            if (_class == "") then {_class = "model " + toLowerANSI ((getModelInfo _x) select 0)};
            ([_x] call BR_fnc_buildingLootQuality) params ["_buildingWeights", "_maxSpots"];

            if ((_leftOut findIf {_x in _class}) < 0 && {switch (_by) do {
                case "quality": {_theme == -1 && {_buildingWeights isEqualTo _weights}};
                case "theme": {_theme == _row};
                default {_theme == -1 && {(_row findIf {_x in _class}) >= 0}};
            }}) then {
                private _pos = getPosATL _x;

                (_cells getOrDefaultCall [[floor ((_pos select 0) / _link),
                    floor ((_pos select 1) / _link)], {[]}, true]) pushBack count _buildings;
                _buildings pushBack [
                    _pos, (count ([_x] call BR_fnc_lootPositions)) min _maxSpots, _class,
                    (_placeOnly findIf {_x in _class}) < 0, (_core findIf {_x in _class}) >= 0, _x in BR_var_lootTents,
                    (BR_var_lootSiteTowers findIf {_x in _class}) >= 0
                ];
            };
        } forEach _houses;

        // sites: connected groups of buildings (flood fill over the grid neighbours)
        private _site = _buildings apply {-1};
        private _sites = []; // [marker position, loot spots, counted buildings, classes]

        {
            if ((_site select _forEachIndex) < 0 && {!(_x select 6)}) then {
                private _id = count _sites;
                private _queue = [_forEachIndex];
                private _counted = 0;
                private _spots = 0;
                private _hasCore = false;
                private _allTents = true;
                private _classes = createHashMap;
                private _positions = [];
                private _placing = []; // core and place-only buildings: they place the marker if the site has any

                _site set [_forEachIndex, _id];

                while {_queue isNotEqualTo []} do {
                    private _index = _queue deleteAt 0;
                    (_buildings select _index) params ["_pos", "_count", "_buildingClass", "_isCounted", "_isCore", "_isTent", "_isTower"];
                    private _gx = floor ((_pos select 0) / _link);
                    private _gy = floor ((_pos select 1) / _link);

                    _positions pushBack _pos;
                    if (_isCore || {!_isCounted}) then {_placing pushBack _pos};
                    if (_isCounted) then {
                        _counted = _counted + 1;
                        _spots = _spots + _count;
                    };
                    if (_isCore) then {_hasCore = true};
                    if (!_isTent) then {_allTents = false};
                    _classes set [_buildingClass, (_classes getOrDefault [_buildingClass, 0]) + 1];

                    if (!_isTower) then {for "_dx" from -1 to 1 do {
                        for "_dy" from -1 to 1 do {
                            {
                                if (
                                    (_site select _x) < 0 &&
                                    {((_buildings select _x) select 0) distance2D _pos <= _link}
                                ) then {
                                    _site set [_x, _id];
                                    _queue pushBack _x;
                                };
                            } forEach (_cells getOrDefault [[_gx + _dx, _gy + _dy], []]);
                        };
                    }};
                };

                // too small a site is no base / camp (a lone hunting stand, a lone tent)
                if (
                    ([_counted >= _leastBuildings && {_core isEqualTo [] || {_hasCore}}, _counted >= _leastBuildings || {_hasCore}] select _coreOrLeast) &&
                    {!_allTents || {_counted >= 2}}
                ) then {
                    // the marker on the building closest to the middle of them (not on the empty middle itself: in the
                    // forest beside a spread camp); a camp's on its cabins, a castle's on the castle - the deer stands
                    // of a camp can reach a kilometre into the fields
                    if (_placing isNotEqualTo []) then {_positions = _placing};

                    private _middle = [0, 0, 0];
                    {_middle = _middle vectorAdd _x} forEach _positions;
                    _middle = _middle vectorMultiply (1 / count _positions);
                    private _distances = _positions apply {_x distance2D _middle};

                    _sites pushBack [_positions select (_distances find selectMin _distances), _spots, _counted, _classes];
                };
            };
        } forEach _buildings;

        _sizes params ["_minSize", "_maxSize"];

        {
            _x params ["_pos", "_spots", "_members", "_classes"];

            {
                _x params ["_otherPos", "_otherKind"];

                if (_otherKind != _kind && {_pos distance2D _otherPos < BR_var_lootSiteMarkerNudge}) then {
                    _pos = _otherPos getPos [BR_var_lootSiteMarkerNudge, [_otherPos getDir _pos, 90] select (_pos distance2D _otherPos < 1)];
                };
            } forEach _placed;

            _placed pushBack [_pos, _kind];

            private _marker = createMarker [format ["BR_lootSite_%1_%2", _markerType, _forEachIndex], _pos];
            private _size = (_minSize + BR_var_lootSiteSizeStep * sqrt (_members - 1)) min _maxSize;

            // which buildings make each marker (questionable sites are found by their classes)
            diag_log format ["BR loot site: %1 %2 at %3 (%4), %5 buildings, %6 loot spots: %7", _markerType, _color,
                mapGridPosition _pos, text nearestLocation [_pos, ""], _members, _spots,
                (keys _classes) apply {format ["%1 x%2", _x, _classes get _x]}];

            _marker setMarkerType _markerType;
            _marker setMarkerColor _color;
            _marker setMarkerSize [_size, _size];
            BR_var_lootSiteMarkers pushBack _marker;
        } forEach _sites;

        _counts pushBack format ["%1 %2: %3 sites of %4 buildings", _markerType, _color, count _sites, count _buildings];
    } forEach BR_var_lootSiteKinds;

    // airfields: the main runway and the secondary airports of the world
    private _world = configFile >> "CfgWorlds" >> worldName;
    private _runways = [getArray (_world >> "ilsPosition")] + (("true" configClasses (_world >> "SecondaryAirports")) apply {getArray (_x >> "ilsPosition")});

    {
        if (count _x >= 2 && {_x distance2D BR_var_playAreaCenter <= BR_var_playAreaRadius}) then {
            private _marker = createMarker [format ["BR_airfield_%1", _forEachIndex], [_x select 0, _x select 1]];

            _marker setMarkerType BR_var_airfieldMarkerType;
            _marker setMarkerColor BR_var_airfieldMarkerColor;
            BR_var_lootSiteMarkers pushBack _marker;
        };
    } forEach _runways;

    diag_log format ["BR loot sites: %1, %2 airfield markers", _counts joinString "; ", count (BR_var_lootSiteMarkers select {_x find "BR_airfield" == 0})];
};