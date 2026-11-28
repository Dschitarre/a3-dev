// Battle Royale maps (server; map data on every machine): BR_mapData of BR\maps\mapData<map>.hpp, the play area - the
// first zone always encloses all land of the map - and everything that scales
// with its radius.

BR_var_referenceRadius = 3800;          // play area radius the loot and vehicle tuning values were made for
BR_var_wholeMapSamples = 150;           // land of the map: grid of this many steps per side (BR_fnc_wholeMapArea) ...
BR_var_wholeMapIterations = 400;        // ... the circle around it: steps towards the farthest land (Badoiu-Clarkson)
BR_var_lootScaleRange = [1, 1.6];       // loot chance factor sqrt (reference / radius), kept in this range (big areas
                                        // have more houses and more combatants: no less loot per house)
BR_var_vehicleScaleRange = [0.35, 2.5]; // vehicle count factor radius / reference, kept in this range
BR_var_vehicleSpacingMax = 300;         // vehicles are this far apart in areas of the reference size or larger
BR_var_combatantsRange = [8, 150];      // combatants param Auto: by the map's land area, this many on
BR_var_combatantsReference = [150, 269]; // this many km2 of land (Altis, measured), within BR_var_combatantsRange
BR_var_landAreaSamples = 60;            // land area of the map: grid of (2n + 1)^2 points over its circle

// ---- map data ----

BR_fnc_mapValue = {
    params ["_name", "_default"];

    private _entry = missionConfigFile >> "BR_mapData" >> _name;

    switch (true) do {
        case (isArray _entry): {getArray _entry};
        case (isNumber _entry): {getNumber _entry};
        default {_default};
    }
};

// combatants (players + AI) for the combatants param Auto: in proportion to the map's land area (same land per
// combatant as 150 on Altis), measured once
BR_fnc_mapCombatants = {
    if (isNil "BR_var_mapCombatants") then {
        BR_var_combatantsReference params ["_referenceCount", "_referenceLandKm2"];
        BR_var_combatantsRange params ["_minCount", "_maxCount"];

        (call BR_fnc_wholeMapArea) params ["", "_center", "_radius"];

        private _landKm2 = ([_center, _radius, BR_var_landAreaSamples] call BR_fnc_landShare) * pi * (_radius / 1000) ^ 2;

        BR_var_mapCombatants = _minCount max (round (_referenceCount * _landKm2 / _referenceLandKm2) min _maxCount);
        diag_log format ["BR map combatants: %1 (land %2 km2)", BR_var_mapCombatants, round _landKm2];
    };

    BR_var_mapCombatants
};

// the start area without one in the map data: the world's airfield (its runway, CfgWorlds ilsPosition), else the
// world's middle
BR_fnc_defaultStartArea = {
    private _airfield = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");

    [[worldSize / 2, worldSize / 2], _airfield select [0, 2]] select (count _airfield >= 2)
};

BR_var_startAreaCenter = [["startAreaCenter", call BR_fnc_defaultStartArea] call BR_fnc_mapValue] call BR_fnc_groundPos;
BR_var_startAreaRadius = ["startAreaRadius", 100] call BR_fnc_mapValue;
BR_var_flightHeight = ["flightHeight", 450] call BR_fnc_mapValue;

/*
    [name, center, radius] of the play area: about the smallest circle around all land of the map, measured once - no
    hand-set circle per map that leaves coasts or islands out. The outermost land of each row of a grid over the world
    holds every point that can be farthest from a center; the circle steps towards the farthest of them
    (Badoiu-Clarkson) and finally takes the largest distance plus a grid step (land between the samples).
*/
BR_fnc_wholeMapArea = {
    if (isNil "BR_var_wholeMapArea") then {
        private _step = worldSize / BR_var_wholeMapSamples;
        private _edges = [];

        for "_j" from 0 to BR_var_wholeMapSamples do {
            private _y = _j * _step;
            private _first = -1;
            private _last = -1;

            for "_i" from 0 to BR_var_wholeMapSamples do {
                if (!surfaceIsWater [_i * _step, _y]) exitWith {_first = _i};
            };

            if (_first >= 0) then {
                for "_i" from BR_var_wholeMapSamples to _first step -1 do {
                    if (!surfaceIsWater [_i * _step, _y]) exitWith {_last = _i};
                };

                _edges pushBack [_first * _step, _y];
                _edges pushBack [_last * _step, _y];
            };
        };

        private _center = [worldSize / 2, worldSize / 2];
        private _farthest = {
            private _far = _center;
            private _distance = -1;

            {
                private _d = _x distance2D _center;

                if (_d > _distance) then {_distance = _d; _far = _x};
            } forEach _edges;

            [_far, _distance]
        };

        if (_edges isNotEqualTo []) then {
            _center = [0, 0, 0];
            {_center = _center vectorAdd [_x select 0, _x select 1, 0]} forEach _edges;
            _center = (_center vectorMultiply (1 / count _edges)) select [0, 2];

            for "_k" from 1 to BR_var_wholeMapIterations do {
                private _far = (call _farthest) select 0;

                _center = _center vectorAdd ((([_far select 0, _far select 1, 0] vectorDiff [_center select 0, _center select 1, 0])
                    vectorMultiply (1 / (_k + 1))) select [0, 2]);
            };
        };

        private _radius = if (_edges isEqualTo []) then {worldSize * 0.5} else {((call _farthest) select 1) + _step};
        private _name = getText (configFile >> "CfgWorlds" >> worldName >> "description");

        BR_var_wholeMapArea = [[_name, worldName] select (_name == ""), _center, round _radius];
        diag_log format ["BR whole map: center %1, radius %2 m (%3 land edge points)", _center apply {round _x}, round _radius, count _edges];
    };

    BR_var_wholeMapArea
};

// ---- play area (server) ----

// share 0..1 of the circle that is land (grid of (2n + 1)^2 samples)
BR_fnc_landShare = {
    params ["_center", "_radius", "_samples"];

    private _step = _radius / _samples;
    private _inside = 0;
    private _land = 0;

    for "_i" from -_samples to _samples do {
        for "_j" from -_samples to _samples do {
            private _pos = [(_center select 0) + _i * _step, (_center select 1) + _j * _step];

            if (_pos distance2D _center <= _radius) then {
                _inside = _inside + 1;

                if (!surfaceIsWater _pos) then {
                    _land = _land + 1;
                };
            };
        };
    };

    _land / (_inside max 1)
};

// the play area: the whole map (BR_fnc_wholeMapArea), its zone phases, loot and vehicle scale
BR_fnc_selectPlayArea = {
    params ["_combatantCount"];

    (call BR_fnc_wholeMapArea) params ["_name", "_center", "_radius"];

    BR_var_playAreaName = _name;
    BR_var_playAreaCenter = [_center] call BR_fnc_groundPos;
    BR_var_playAreaRadius = _radius;
    publicVariable "BR_var_playAreaName";
    diag_log format ["BR play area: %1 at %2, radius %3 m, %4 combatants", _name, BR_var_playAreaCenter, _radius, _combatantCount];

    call BR_fnc_applyAreaScale;
    call BR_fnc_initZoneServer;
};

// zone phases, loot chance and vehicles of the play area (the flight follows from its route, BR_fnc_planFlight)
BR_fnc_applyAreaScale = {
    private _scale = BR_var_playAreaRadius / BR_var_referenceRadius;
    private _lootFactor = (BR_var_lootScaleRange select 0) max ((1 / sqrt _scale) min (BR_var_lootScaleRange select 1));
    private _vehicleFactor = (BR_var_vehicleScaleRange select 0) max (_scale min (BR_var_vehicleScaleRange select 1));

    BR_var_lootChance = BR_var_lootChanceBase * _lootFactor;
    BR_var_vehicleCount = round (BR_var_vehicleCountBase * _vehicleFactor);
    BR_var_vehicleSpacing = BR_var_vehicleSpacingMax * (_scale min 1);
    BR_var_zonePhases = [BR_var_playAreaRadius] call BR_fnc_zonePhases;
};
