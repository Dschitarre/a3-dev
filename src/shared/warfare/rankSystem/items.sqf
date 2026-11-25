// Items by rank and perk: item types, unlocked items, locked magazines, item tables per rank,
// arsenal content and the equipment dialog (both).

// ---- items ----

// BIS_fnc_itemType is slow, its results are cached per class
SC_var_itemTypeCache = createHashMap;

SC_fnc_getItemType = {
    params ["_class"];

    private _type = SC_var_itemTypeCache get _class;

    if (isNil "_type") then {
        _type = [_class] call BIS_fnc_itemType;
        SC_var_itemTypeCache set [_class, _type];
    };

    _type
};

// the magazines of all muzzles of a weapon (config order)
SC_fnc_getWeaponMagazines = {
    params ["_weapon"];

    private _cfgWeapon = configFile >> "CfgWeapons" >> _weapon;
    private _magazines = [];

    {
        _magazines append (getArray ((if (_x == "this") then {_cfgWeapon} else {_cfgWeapon >> _x}) >> "magazines"));
    } forEach (getArray (_cfgWeapon >> "muzzles"));

    _magazines
};

// item config arrays unlocked by perks ("%1" = side in lower case)
SC_var_perkItemConfigs = [
    ["ARMR", ["%1Armor"]],
    ["LNCR", ["Launcher"]],
    ["MRKS", ["marksman", "%1Marksman"]],
    ["MGNR", ["machinegunner"]],
    ["GRND", ["grenadier"]],
    ["DEMO", ["explosives"]],
    ["SUPR", ["suppressor"]]
];

SC_fnc_getItemsForUnit = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    _excludeGeneralPrimWeapons = _excludeGeneralPrimWeapons && {((["MGNR", "MRKS", "GRND"] arrayIntersect _perks) isNotEqualTo [])};

    private _items = (getArray (missionConfigFile >> "general")) select {
        ((_x select 1) <= _rank) &&
        {_x call SC_fnc_isConfigEntryValid} &&
        {(!_excludeGeneralPrimWeapons) || {
            ([_x select 0] call SC_fnc_getItemType) params ["_category", "_type"];
            ((_category != "Weapon") || {_type == "Handgun"})
        }}
    };

    private _configNames = ["%1General"];

    {
        _x params ["_perk", "_perkConfigNames"];

        if (_perk in _perks) then {
            _configNames append _perkConfigNames;
        };
    } forEach SC_var_perkItemConfigs;

    private _sideStr = toLower (str _side);

    {
        _items append ((getArray (missionConfigFile >> (format [_x, _sideStr]))) select {
            ((_x select 1) <= _rank) && {_x call SC_fnc_isConfigEntryValid}
        });
    } forEach _configNames;

    if ("MEDC" in _perks) then {
        _items pushBack ["Medikit", 1];
    } else {
        _items pushBack ["FirstAidKit", 1];
    };

    _items
};

SC_fnc_getLockedMags = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    ([_side, _perks, 1000, _excludeGeneralPrimWeapons] call SC_fnc_getItemsForUnit) select {
        ((([_x select 0] call SC_fnc_getItemType) select 0) == "Magazine") &&
        {(_x select 1) > _rank}
    } apply {_x select 0}
};

SC_fnc_baseName = {
    params ["_className"];

    // skip the world group's class prefix (e.g. "CUP_")
    private _idxFirstUnderscore = _className find ["_", SC_var_wgClassPrefixLength];
    private _idxSecondUnderscore = _className find ["_", _idxFirstUnderscore + 1];
    private _idxBaseNameEnd = if (_idxSecondUnderscore == -1) then {count _className} else {_idxSecondUnderscore};
    private _baseName = _className select [0, _idxBaseNameEnd];

    _baseName
};

// groups [class, rank] entries whose class contains the same base name
SC_fnc_groupByBaseName = {
    params ["_entries"];

    private _grouped = [];

    {
        private _baseStr = [_x select 0] call SC_fnc_baseName;

        if ((_grouped findIf {(_x findIf {_baseStr in (_x select 0)}) != -1}) == -1) then {
            _grouped pushBack (_entries select {_baseStr in (_x select 0)});
        };
    } forEach _entries;

    _grouped
};

SC_fnc_computeItemsUniqueAndGrouped = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    private _items = [];

    if (_side == sideEmpty) then {
        {
            _items append (getArray (missionConfigFile >> _x));
        } forEach [
            "general", "grenadier", "westGeneral",
            "eastGeneral", "guerGeneral", "westArmor",
            "eastArmor", "guerArmor", "launcher", "marksman",
            "westMarksman", "eastMarksman", "guerMarksman",
            "machinegunner", "explosives", "suppressor"
        ];
    } else {
        _items = [_side, _perks, _rank, _excludeGeneralPrimWeapons] call SC_fnc_getItemsForUnit;
    };

    _items = _items arrayIntersect _items;

    private _mags = _items select {(([_x select 0] call SC_fnc_getItemType) select 0) == "Magazine"};
    private _weapons = _items select {(([_x select 0] call SC_fnc_getItemType) select 0) == "Weapon"};
    private _optics = _items select {(([_x select 0] call SC_fnc_getItemType) select 1) == "AccessorySights"};
    private _suppressors = _items select {(([_x select 0] call SC_fnc_getItemType) select 1) == "AccessoryMuzzle"};

    private _otherItems = _items - (_mags + _weapons + _optics + _suppressors);
    _mags = _mags apply {_x select 0};

    {
        _mags append ([_x select 0] call SC_fnc_getWeaponMagazines);
    } forEach _weapons;

    _mags = _mags - ([_side, _perks, _rank, _excludeGeneralPrimWeapons] call SC_fnc_getLockedMags);

    private _groupedWeapons = [_weapons] call SC_fnc_groupByBaseName;
    private _groupedOptics = [_optics] call SC_fnc_groupByBaseName;
    private _groupedSuppressors = [_suppressors] call SC_fnc_groupByBaseName;

    // one representative per group
    _otherItems append (_groupedWeapons apply {_x select 0});
    _otherItems append (_groupedOptics apply {_x select 0});
    _otherItems append (_groupedSuppressors apply {_x select 0});

    [_otherItems, _mags, _groupedWeapons, _groupedOptics, _groupedSuppressors]
};

SC_var_itemsUniqueAndGroupedCache = createHashMap;

// [items, mags, groupedWeapons, groupedOptics, groupedSuppressors]; results are cached (callers get a copy)
SC_fnc_getItemsUniqueAndGrouped = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    private _sortedPerks = +_perks;
    _sortedPerks sort true;
    private _key = str [_side, _sortedPerks, _rank, _excludeGeneralPrimWeapons];
    private _result = SC_var_itemsUniqueAndGroupedCache get _key;

    // computed in one go (unscheduled, a few ms): in the scheduler, sharing its few ms per frame with all other scripts,
    // it took seconds, and an AI spawn needs it several times (one key per side, perks and rank)
    if (isNil "_result") then {
        isNil {
            _result = [_side, _perks, _rank, _excludeGeneralPrimWeapons] call SC_fnc_computeItemsUniqueAndGrouped;

            if ((count SC_var_itemsUniqueAndGroupedCache) >= 300) then {
                SC_var_itemsUniqueAndGroupedCache = createHashMap;
            };

            SC_var_itemsUniqueAndGroupedCache set [_key, _result];
        };
    };

    +_result
};

// [[rank, [westItems, eastItems, guerItems]], ...] (ascending ranks) of all items of a type (BIS_fnc_itemType select 1)
// in the given config arrays ("%1" = side, e.g. "WESTGeneral"), each side's items of a rank in config order (so the
// variant slots of the sides match); a side without an item of that rank has []
SC_fnc_buildItemsByRank = {
    params ["_itemType", "_configNames"];

    private _sidesItems = SC_var_sides apply {
        private _side = _x;
        private _entries = [];

        {
            _entries append (getArray (missionConfigFile >> (format [_x, str _side])));
        } forEach _configNames;

        (_entries call SC_fnc_filterConfigArr) select {(([_x select 0] call SC_fnc_getItemType) select 1) == _itemType}
    };

    private _ranks = [];

    {
        {
            _ranks pushBackUnique (_x select 1);
        } forEach _x;
    } forEach _sidesItems;

    _ranks sort true;

    _ranks apply {
        private _rank = _x;

        [_rank, _sidesItems apply {
            private _items = (_x select {(_x select 1) == _rank}) apply {_x select 0};

            _items arrayIntersect _items
        }]
    }
};

// [isWeapon, isBackpack, isItem, isMagazine] of a class for the virtual arsenal, cached per class
SC_var_itemCategoriesCache = createHashMap;

SC_fnc_getItemCategories = {
    params ["_class"];

    private _categories = SC_var_itemCategoriesCache get _class;

    if (isNil "_categories") then {
        private _weaponParents = [(configFile >> "CfgWeapons" >> _class), true] call BIS_fnc_returnParents;

        _categories = [
            ((["Rifle", "Pistol", "Launcher"] arrayIntersect _weaponParents) isNotEqualTo []),
            "Bag_Base" in ([(configFile >> "CfgVehicles" >> _class), true] call BIS_fnc_returnParents),
            ("ItemCore" in _weaponParents) ||
                {_class in ["Rangefinder", "Binocular", "Medikit", "FirstAidKit"]} ||
                {(_class find "binoc") != -1} || {(_class find "NVGoggles") != -1} ||
                {_class select [0, 8] == "CUP_NVG_"} ||
            {(([_class] call SC_fnc_getItemType) select 1) in ["Binocular", "LaserDesignator", "NVGoggles"]},
            "CA_Magazine" in ([(configFile >> "CfgMagazines" >> _class), true] call BIS_fnc_returnParents)
        ];

        SC_var_itemCategoriesCache set [_class, _categories];
    };

    _categories
};

SC_fnc_getItems = {
    params ["_side", "_perks", "_rank"];

    private _strings = ([_side, _perks, _rank, false] call SC_fnc_getItemsForUnit) apply {_x select 0};
    private _lockedMags = [_side, _perks, _rank, false] call SC_fnc_getLockedMags;

    private _weps = _strings select {([_x] call SC_fnc_getItemCategories) select 0};
    private _bags = _strings select {([_x] call SC_fnc_getItemCategories) select 1};
    private _items = _strings select {([_x] call SC_fnc_getItemCategories) select 2};
    private _mags = _strings select {([_x] call SC_fnc_getItemCategories) select 3};

    {
        _mags append ([_x] call SC_fnc_getWeaponMagazines);
    } forEach _weps;

    _mags = _mags - _lockedMags;

    [_weps, _bags, _items, _mags]
};

SC_fnc_setupEquipmentDialog = {
    params ["_category"];

    private _equipmentDialog = uiNamespace getVariable "SC_var_equipmentDialog";
    private _controlsTable = _equipmentDialog displayCtrl 1611;
    ctClear _controlsTable;

    // the perk buttons: "MRKS [12]" (abbreviation and required rank, the abbreviation kept on the button), name and
    // rank as tooltip, a red background while the player's rank is too low for the perk
    private _playerRank = player getVariable ["SC_var_rank", 1];

    {
        private _ctrl = _x;
        private _abbreviation = _ctrl getVariable ["SC_var_perkAbbreviation", ctrlText _ctrl];
        private _perkIndex = SC_var_perkConfig findIf {(_x select 1) == _abbreviation};

        if (_perkIndex != -1) then {
            (SC_var_perkConfig select _perkIndex) params ["_perkName", "", "_perkRank"];

            _ctrl setVariable ["SC_var_perkAbbreviation", _abbreviation];
            _ctrl ctrlSetText format ["%1 [%2]", _abbreviation, _perkRank];
            _ctrl ctrlSetTooltip format ["%1 perk (requires rank %2)", _perkName, _perkRank];

            if (_playerRank < _perkRank) then {
                _ctrl ctrlSetBackgroundColor (((["error"] call UI_fnc_color) select [0, 3]) + [0.5]);
            };
        };
    } forEach (allControls _equipmentDialog);
    (ctAddHeader _controlsTable) params ["", "_header"];

    _header params ["",
        "_ctrlHeaderColumn1", "_ctrlHeaderColumn2", "_ctrlHeaderColumn3"
    ];

    [_header] call SC_fnc_styleTableHeader;
    _ctrlHeaderColumn1 ctrlSetText "Picture";
    _ctrlHeaderColumn2 ctrlSetText "Name";
    _ctrlHeaderColumn3 ctrlSetText "Rank";
    private _sideStr = str (side (group player));

    private _items = switch _category do {
        case "vehicles": {+SC_var_allVehicles};
        case "medic": {[["Medikit", 5]]};
        default {
            // config arrays of the category ("%1" = side)
            private _configNames = switch _category do {
                case "general": {["general", "%1General"]};
                case "marksman": {["marksman", "%1Marksman"]};
                case "armor": {["%1Armor"]};
                default {[_category]};
            };

            private _entries = [];

            {
                _entries append (getArray (missionConfigFile >> (format [_x, _sideStr])));
            } forEach _configNames;

            [_entries call SC_fnc_filterConfigArr, [], {_x select 1}, "ASCEND"] call BIS_fnc_sortBy
        };
    };

    private _playerRank = player getVariable ["SC_var_rank", 1];
    private _isVehicles = _category == "vehicles";
    private _vehiclePictures = [];   // [picture control, picture] of the vehicle rows

    {
        _x params ["_type", "_rank"];

        if (isNull _controlsTable) exitWith {};
        (ctAddRow _controlsTable) params ["", "_row"];
        _row params ["", "_ctrlColumn1", "_ctrlColumn2", "_ctrlColumn3"];

        private _state = "normal";

        if (_playerRank < _rank) then {
            _state = "locked";
        };

        if (_isVehicles && {!(_x in SC_var_availableVehicles)}) then {
            _state = "unavailable";
        };

        [_row, _state] call SC_fnc_styleTableRow;

        if (_isVehicles) then {
            _vehiclePictures pushBack [_ctrlColumn1, [_type] call SC_fnc_getPicture];
        } else {
            _ctrlColumn1 ctrlSetText ([_type] call SC_fnc_getPicture);
        };

        _ctrlColumn2 ctrlSetText ([_type] call SC_fnc_getDisplayName);
        _ctrlColumn3 ctrlSetText (str _rank);
    } forEach _items;

    // vehicle pictures sized by their opaque area, once all rows exist (in case adding a row lays out the others again)
    {
        _x call UI_fnc_setVehiclePicture;
    } forEach _vehiclePictures;
};
