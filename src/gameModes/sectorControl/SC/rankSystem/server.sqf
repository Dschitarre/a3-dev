SC_fnc_getItemsUniqueAndGrouped = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    _items = [];

    if (_side == sideEmpty) then {
		{
			_items append (getarray (missionConfigFile >> _x));
		} forEach [
			"general", "grenadier", "westGeneral",
			"eastGeneral", "guerGeneral", "westArmor",
			"eastArmor", "guerArmor", "launcher", "marksman",
			"westMarksman", "eastMarksman", "guerMarksman",
			"machinegunner", "suppressor"
		];
    } else {
        _items = [_side, _perks, _rank, _excludeGeneralPrimWeapons] call SC_fnc_getItemsForUnit;
    };

    _items = _items arrayIntersect _items;

    _mags = _items select {(([_x select 0] call BIS_fnc_itemType) select 0) == "Magazine"};
    _weapons = _items select {(([_x select 0] call BIS_fnc_itemType) select 0) == "Weapon"};
    _optics = _items select {(([_x select 0] call BIS_fnc_itemType) select 1) == "AccessorySights"};
    _suppressors = _items select {(([_x select 0] call BIS_fnc_itemType) select 1) == "AccessoryMuzzle"};

    _items = _items - (_mags + _weapons + _optics + _suppressors);
    _itemsCopy = _items; // I have to do this because of a bug in SQF, that reverts "_items" to a previous state
    _mags = _mags apply {_x select 0};

    {
        _weapon = _x select 0;
        {
            _muzzle = _x;

            if (_muzzle == "this") then {
                _mags append (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines"));
            } else {
                _mags append (getArray (configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "magazines"));
            };
        } forEach (getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles"));
    } forEach _weapons;

    _mags = _mags - ([_side, _perks, _rank, _excludeGeneralPrimWeapons] call SC_fnc_getLockedMags);

    _wepaonCamoIds = ["_blk", "_black", "_Black", "_lush", "_arid", "_hex", "_ghex", "_khk", "_green", "_khaki", "_snd", "_sand", "_plain", "_tna", "_tan", "_Tan", "_woodland", "_sniper", "_camo", "_olive", "_F"];
    _groupedWeapons = [];
    {
        _x params ["_weapon"];

        _posCamoId = _wepaonCamoIds findIf {_x in _weapon};

        if (_posCamoId != -1) then {
            _camoId = _wepaonCamoIds select _posCamoId;
            _weaponBaseStr = _weapon select [0, (_weapon find _camoId)];
            _posGroupedWeapons = _groupedWeapons findIf {(_x findIf {_weaponBaseStr in (_x select 0)}) != -1};

            if (_posGroupedWeapons == -1) then {
                _groupedWeapons pushBack (_weapons select {_weaponBaseStr in (_x select 0)});
            };
        };
    } forEach _weapons;

    _uniqueWeapons = _groupedWeapons apply {_x select 0};

    _groupedOptics = [];
    {
        _x params ["_optic"];

        _opticBaseStr = _optic select [0, 9];
        _posGroupedOptics = _groupedOptics findIf {(_x findIf {_opticBaseStr in (_x select 0)}) != -1};

        if (_posGroupedOptics == -1) then {
            _groupedOptics pushBack (_optics select {_opticBaseStr in (_x select 0)});
        };
    } forEach _optics;
    _uniqueOptics = _groupedOptics apply {_x select 0};

    _groupedSuppressors = [];
    {
        _x params ["_suppressor"];

        _suppressorBaseStr = _suppressor select [0, 13];
        _posGroupedSuppressors = _groupedSuppressors findIf {(_x findIf {_suppressorBaseStr in (_x select 0)}) != -1};

        if (_posGroupedSuppressors == -1) then {
            _groupedSuppressors pushBack (_suppressors select {_suppressorBaseStr in (_x select 0)});
        };
    } forEach _suppressors;
    _uniqueSuppressors = _groupedSuppressors apply {_x select 0};

    _itemsCopy append _uniqueWeapons;
    _itemsCopy append _uniqueOptics;
    _itemsCopy append _uniqueSuppressors;

    [_itemsCopy, _mags, _groupedWeapons, _groupedOptics, _groupedSuppressors]
};