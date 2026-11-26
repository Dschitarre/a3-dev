// Killfeed hits (server): hits collected per victim and their text/picture form for the feeds.
// Included by fnc_server.sqf.

// ---- hits ----
// A hit on a victim is stored as [hitter, ammo, magazine, source, distance, selections, time]; selections are
// [selection, isDirect] pairs. Source is the weapon or vehicle class, "Throw", "Put" or "Fall Damage".

// unconscious (AIS or vanilla revive)
KF_fnc_isDown = {
    params ["_unit"];

    (_unit getVariable ["AIS_unconscious", false]) || {lifeState _unit == "INCAPACITATED"}
};

// Hits count for KF_var_assistWindow seconds before the kill, or before the unit went down (KF_fnc_entityKilled of a
// game mode), so the attackers of a unit that bleeds out still count.
KF_fnc_hitsSince = {
    params ["_entity"];

    (_entity getVariable ["KF_var_downTime", time]) - KF_var_assistWindow
};

// [[target, hitter, ammo, magazine, source, distance, selections], ...] from KF_fnc_queueHit and KF_fnc_onDamage
KF_fnc_onHits = {
    params ["_hits"];

    {
        _x params ["_target"];

        private _hit = (_x select [1, 6]) + [(_x param [8, serverTime]) - serverTime + time, _x param [7, objNull]];

        if (!isNull _target) then {
            private _targetHits = _target getVariable "KF_var_hits";

            if (isNil "_targetHits") then {
                _targetHits = [];
                _target setVariable ["KF_var_hits", _targetHits];
            };

            // drops the hits that can no longer count (oldest first) and keeps at most KF_var_maxHitsPerEntity
            private _since = [_target] call KF_fnc_hitsSince;
            private _firstValid = _targetHits findIf {(_x select 6) >= _since};

            _targetHits deleteRange [0, [_firstValid, count _targetHits] select (_firstValid == -1)];
            _targetHits pushBack _hit;

            if (count _targetHits > KF_var_maxHitsPerEntity) then {
                _targetHits deleteAt 0;
            };
        };
    } forEach _hits;
};

KF_fnc_entityHealed = {
    params ["_entity"];

    _entity setVariable ["KF_var_hits", []];
};

// the hits that still count on the entity and on the vehicle it sat in, oldest first
KF_fnc_getHits = {
    params ["_entity", "_vehicle"];

    private _since = [_entity] call KF_fnc_hitsSince;
    private _vehicleHits = (_vehicle getVariable ["KF_var_hits", []]) select {(_x select 6) >= _since};
    private _hits = ((_entity getVariable ["KF_var_hits", []]) select {(_x select 6) >= _since}) + _vehicleHits;

    [_hits, [], {_x select 6}] call BIS_fnc_sortBy
};

KF_fnc_getHitType = {
    params ["_ammo", "_selections", "_source"];

    switch (true) do {
        case (_ammo == "vehHit"): {"Vehicle Hit"};
        case (_ammo == "vehExpl"): {"Vehicle Explosion"};
        case (_ammo == "fall"): {"Fall Damage"};
        case (_ammo == "fire"): {"Fire"};
        case (_ammo == "drown"): {"Drowning"};
        case (_ammo == "zone"): {"Restricted Zone"};
        case (_source == "Throw"): {"Hand Grenade"};
        case (_source == "Put"): {"Explosive"};
        default {
            private _kind = ([_source] call KF_fnc_getClassInfo) select 2;
            private _isGrenadeLauncher = (_kind == "grenadeLauncher") || {"G_" in _ammo};
            private _isHeadshot = _selections findIf {(_x select 1) && {toLowerANSI (_x select 0) in ["head", "face_hub", "head_hit", "hithead"]}} >= 0;

            if (_kind == "vehicle") then {
                switch (true) do {
                    case _isGrenadeLauncher: {"Vehicle Grenade Launcher"};
                    case _isHeadshot: {"Vehicle Weapon Headshot"};
                    default {"Vehicle Weapon"};
                }
            } else {
                switch (true) do {
                    case _isGrenadeLauncher: {"Weapon Grenade Launcher"};
                    case (_kind == "launcher"): {"Rocket Launcher"};
                    case _isHeadshot: {"Weapon Headshot"};
                    default {"Weapon"};
                }
            }
        };
    }
};

// A headshot counts as the same death cause as a body shot with the same source; the newest hit decides the type.
KF_var_typeFolds = createHashMapFromArray [
    ["Weapon Headshot", "Weapon"],
    ["Vehicle Weapon Headshot", "Vehicle Weapon"]
];

// Aggregates hits (oldest first) per hitter, newest first: [[hitter, causes, distance], ...] with causes
// [[type, source, selections], ...] and the distance of the newest hit that has one. Only valid hitters count (with
// the hits they dealt since their current controller took over), only the killer without assists; with _onlyHitter,
// only that hitter.
KF_fnc_aggregateHits = {
    params ["_hits", "_killer", ["_onlyHitter", objNull]];

    private _projectileHits = _hits select {!((_x select 1) in KF_var_hitsWithoutProjectile)};
    private _hitData = [];

    // a hit without projectile is dropped when a projectile hit of the same hitter explains it
    _hits = _hits select {
        _x params ["_hitter", "_ammo", "", "", "", "", "_time"];

        !(_ammo in ["vehHit", "vehExpl", "fall"]) ||
        {(_projectileHits findIf {((_x select 0) isEqualTo _hitter) && {abs ((_x select 6) - _time) < KF_var_projectileHitWindow}}) == -1}
    };

    reverse _hits;

    {
        _x params ["_hitter", "_ammo", "_magazine", "_source", "_distance", "_selections", "_time"];

        _hitter = [_hitter] call KF_fnc_getRespawnedEntity;

        if (
            ([_hitter] call KF_fnc_unitIsValid) &&
            {_time >= (_hitter getVariable ["KF_var_controlTime", -1])} &&
            {KF_var_assists || {_hitter isEqualTo _killer}} &&
            {isNull _onlyHitter || {_hitter isEqualTo _onlyHitter}}
        ) then {
            private _type = [_ammo, _selections, _source] call KF_fnc_getHitType;

            // grenades and explosives are shown by their magazine
            if (_type in ["Hand Grenade", "Explosive"]) then {
                _source = _magazine;
            };

            private _index = _hitData findIf {(_x select 0) isEqualTo _hitter};

            if (_index == -1) then {
                _index = _hitData pushBack [_hitter, [], -1];
            };

            private _entry = _hitData select _index;
            private _causes = _entry select 1;
            private _foldedType = KF_var_typeFolds getOrDefault [_type, _type];
            private _causeIndex = _causes findIf {
                ((_x select 1) == _source) && {(KF_var_typeFolds getOrDefault [_x select 0, _x select 0]) == _foldedType}
            };

            if (_causeIndex == -1) then {
                _causes pushBack [_type, _source, +_selections];
            } else {
                ((_causes select _causeIndex) select 2) insert [-1, _selections, true];
            };

            if ((_entry select 2) == -1) then {
                _entry set [2, _distance];
            };
        };
    } forEach _hits;

    _hitData
};

// ---- hits as text and pictures ----

KF_var_bodyPartFolds = [
    [["Left Arm", "Right Arm"], "Both Arms"],
    [["Left Leg", "Right Leg"], "Both Legs"],
    [["Left Foot", "Right Foot"], "Both Feet"],
    [["Both Arms", "Both Legs", "Both Feet", "Head", "Pelvis", "Spine"], "Whole Body"]
];

// types that are not named in the hit texts
KF_var_untitledTypes = ["Weapon", "Explosive", "Hand Grenade", "Tombstone"];

KF_fnc_getBodyPart = {
    params ["_selection"];

    private _side = ["Right", "Left"] select ("left" in _selection);

    switch (true) do {
        case ("leg" in _selection): {_side + " Leg"};
        case ("arm" in _selection): {_side + " Arm"};
        case ("spine" in _selection): {"Spine"};
        case ("pelvis" in _selection): {"Pelvis"};
        case ("foot" in _selection): {_side + " Foot"};
        case ("head" in _selection): {"Head"};
        default {""};
    }
};

// "Head, Both Legs", with _withAt "at Head, Both Legs"
KF_fnc_formatSelections = {
    params ["_selections", "_withAt"];

    private _bodyParts = [];

    {
        _bodyParts pushBackUnique ([_x select 0] call KF_fnc_getBodyPart);
    } forEach _selections;

    _bodyParts = _bodyParts - [""];

    {
        _x params ["_parts", "_whole"];

        if ((_parts findIf {!(_x in _bodyParts)}) == -1) then {
            _bodyParts = (_bodyParts - _parts) + [_whole];
        };
    } forEach KF_var_bodyPartFolds;

    if (_bodyParts isEqualTo []) exitWith {""};

    (["", "at "] select _withAt) + (_bodyParts joinString ", ")
};

KF_fnc_formatIcon = {
    params ["_path", "_size"];

    format ["<img color='kf:dim' size='%1' image='\A3\Ui_f\data\%2'/>", _size, _path]
};

// The pictures of the death causes, e.g. weapon, bullet and head for a headshot. With _limit only the newest cause,
// unless KF_var_multipleDeathCauses. Sizes are in GUI grid cells like the text (structured text sizes are relative to
// the control's base size of 1 cell, not to the enclosing text): _sizeFactor 1 = a weapon picture 1.28 times as high
// as the text (kill feed).
KF_fnc_formatHitsPicture = {
    params ["_causes", "_sizeFactor", "_limit"];

    if (_limit && {!KF_var_multipleDeathCauses}) then {
        _causes = _causes select [0, 1];
    };

    private _scale = _sizeFactor * KF_var_textSizeCells;

    (_causes apply {
        _x params ["_type", "_source"];

        private _picture = switch (true) do {
            case (_type == "Tombstone"): {["IGUI\Cfg\MPTable\killed_ca.paa", _scale] call KF_fnc_formatIcon};
            // the marker fills its whole square: as high as the tombstone, not more (it stood out at 1.26)
            case (_type == "Restricted Zone"): {["map\markers\military\warning_CA.paa", 0.9 * _scale] call KF_fnc_formatIcon};
            // a flame (the "light a fire" action); ico_ON was a tick and looked like a check mark (user 2026-11-26)
            case (_type == "Fire"): {["IGUI\Cfg\Actions\Obsolete\ui_action_fire_in_flame_ca.paa", _scale] call KF_fnc_formatIcon};
            case (_type == "Drowning"): {["IGUI\Cfg\MPTable\killed_ca.paa", _scale] call KF_fnc_formatIcon};
            case (_type == "Fall Damage"): {["GUI\Rsc\RscDisplayMain\menu_singleplayer_ca.paa", 1.26 * _scale] call KF_fnc_formatIcon};
            // vehicles sized by their opaque area (KF_fnc_vehiclePictureScale), never higher than a weapon picture, so the
            // line keeps its height
            case (("Vehicle" in _type) || {_type == "Hand Grenade"}): {
                private _sourcePicture = [_source] call KF_fnc_getPicture;
                private _pictureSize = (0.94 * ([_sourcePicture] call KF_fnc_vehiclePictureScale)) min 1.28;

                format ["<img size='%1' color='kf:dim' image='%2'/>", _pictureSize * _scale, _sourcePicture]
            };
            default {
                format ["<img size='%1' color='kf:text' image='%2'/>", 1.28 * _scale, [_source] call KF_fnc_getPicture]
            };
        };

        private _bullet = "";

        if (KF_var_picturesBulletIcon && {_type in ["Vehicle Weapon", "Weapon Headshot", "Weapon Grenade Launcher", "Vehicle Grenade Launcher", "Vehicle Weapon Headshot"]}) then {
            _bullet = ["GUI\Rsc\RscDisplayArsenal\itemMuzzle_ca.paa", 0.78 * _scale] call KF_fnc_formatIcon;
        };

        private _detail = switch (true) do {
            case (KF_var_picturesHeadIcon && {_type in ["Weapon Headshot", "Vehicle Weapon Headshot"]}): {
                ["GUI\Rsc\RscDisplayArsenal\face_ca.paa", 0.9 * _scale] call KF_fnc_formatIcon
            };
            case (_type in ["Vehicle Grenade Launcher", "Weapon Grenade Launcher"]): {
                ["GUI\Rsc\RscDisplayArsenal\cargoThrow_ca.paa", 1.06 * _scale] call KF_fnc_formatIcon
            };
            case (_type == "Vehicle Hit"): {["GUI\Rsc\RscDisplayMain\menu_singleplayer_ca.paa", 1.26 * _scale] call KF_fnc_formatIcon};
            case (_type == "Fall Damage"): {["IGUI\Cfg\Cursors\getIn_ca.paa", 1.26 * _scale] call KF_fnc_formatIcon};
            case ("Explos" in _type): {["GUI\Rsc\RscDisplayArsenal\cargoPut_ca.paa", 1.06 * _scale] call KF_fnc_formatIcon};
            default {""};
        };

        if (KF_var_deathCausesInversed) then {_detail + _bullet + _picture} else {_picture + _bullet + _detail}
    }) joinString format ["<t size='%1'> | </t>", 1.06 * _scale]
};

KF_var_listBullet = toString [8226];   // the bullet of list lines in the feeds (U+2022)

// one line per death cause, as a list below a heading: "M320 LRR (Weapon Headshot) at Head, Spine", then
// "Friendly Fire" if it was one
KF_fnc_formatHitsLines = {
    params ["_causes", "_isTeamKill"];

    private _lines = _causes apply {
        _x params ["_type", "_source", "_selections"];

        private _words = [];

        if (_source != "") then {
            _words pushBack ([_source] call KF_fnc_getDisplayName);
        };

        if !(_type in KF_var_untitledTypes) then {
            _words pushBack format ["(%1)", _type];
        };

        _words pushBack ([_selections, true] call KF_fnc_formatSelections);

        (_words select {_x != ""}) joinString " "
    };

    if (KF_var_showFriendlyFire && _isTeamKill) then {
        _lines pushBack "<t color='kf:warning'>Friendly Fire</t>";
    };

    _lines select {_x != ""}
};

// "120m M320 LRR (Weapon Headshot) Friendly Fire"; _detailed: with body parts and " | " between the parts
KF_fnc_formatHitsText = {
    params ["_distance", "_causes", "_isTeamKill", "_detailed"];

    private _parts = [];

    if (_distance != -1) then {
        _parts pushBack format ["%1m", floor _distance];
    };

    {
        _x params ["_type", "_source", "_selections"];

        private _words = [];

        if (_source != "") then {
            _words pushBack ([_source] call KF_fnc_getDisplayName);
        };

        if !(_type in KF_var_untitledTypes) then {
            _words pushBack format ["(%1)", _type];
        };

        if (_detailed) then {
            _words pushBack ([_selections, true] call KF_fnc_formatSelections);
        };

        _parts pushBack ((_words select {_x != ""}) joinString " ");
    } forEach _causes;

    if (KF_var_showFriendlyFire && _isTeamKill) then {
        _parts pushBack "<t color='kf:warning'>Friendly Fire</t>";
    };

    (_parts select {_x != ""}) joinString ([" ", " | "] select _detailed)
};
