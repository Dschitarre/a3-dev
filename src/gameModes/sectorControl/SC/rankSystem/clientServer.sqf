SC_fnc_getItemsForUnit = {
    params ["_side", "_perks", "_rank", "_excludeGeneralPrimWeapons"];

    _excludeGeneralPrimWeapons = _excludeGeneralPrimWeapons && {!((["MGNR", "MRKS", "GRND"] arrayIntersect _perks) isEqualTo [])};

    _items = (getArray (missionConfigFile >> "general")) select {
        ((_x select 1) <= _rank) && {
        (!_excludeGeneralPrimWeapons) || {
            ([_x select 0] call BIS_fnc_itemType) params ["_category", "_tpye"];
            ((_category != "Weapon") || {_tpye == "Handgun"})
        }}
    };
    
    _items append ((getArray (missionConfigFile >> ((toLower (str _side)) + "General"))) select {(_x select 1) <= _rank});

    if ("ARMR" in _perks) then {
        _items append ((getArray (missionConfigFile >> ((toLower (str _side)) + "Armor"))) select {(_x select 1) <= _rank});
    };

    if ("LNCR" in _perks) then {
        _items append ((getArray (missionConfigFile >> "Launcher")) select {(_x select 1) <= _rank});
    };

    if ("MRKS" in _perks) then {
        _items append ((getArray (missionConfigFile >> "marksman")) select {(_x select 1) <= _rank});
        _items append ((getArray (missionConfigFile >> ((toLower (str _side)) + "Marksman"))) select {(_x select 1) <= _rank});
    };

    if ("MGNR" in _perks) then {
        _items append ((getArray (missionConfigFile >> "machinegunner")) select {(_x select 1) <= _rank});
    };

    if ("GRND" in _perks) then {
        _items append ((getArray (missionConfigFile >> "grenadier")) select {(_x select 1) <= _rank});
    };

    if ("SUPR" in _perks) then {
        _items append ((getArray (missionConfigFile >> "suppressor")) select {(_x select 1) <= _rank});
    };

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
        ((((_x select 0) call BIS_fnc_itemType) select 0) == "Magazine") &&
        {(_x select 1) > _rank}
    } apply {_x select 0}
};