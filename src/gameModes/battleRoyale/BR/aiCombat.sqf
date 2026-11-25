// a primary weapon with ammo or a loaded handgun
BR_fnc_aiArmed = {
    params ["_unit"];

    !([_unit] call BR_fnc_aiNeedsGear) || {handgunWeapon _unit != "" && {(_unit ammo handgunWeapon _unit) > 0}}
};

// line of sight from the unit's eyes to the enemy's center
BR_fnc_aiSees = {
    params ["_unit", "_enemy"];

    private _angle = abs ((((_unit getDir _enemy) - getDir _unit) + 540) % 360 - 180);
    private _range = BR_var_aiThreatRange * (1 - fog * 0.75);
    if (sunOrMoon < 0.2 && {hmd _unit == ""}) then {_range = _range min 60};
    _angle <= 100 && {_unit distance _enemy <= _range} &&
    {([_unit, "VIEW", _enemy] checkVisibility [eyePos _unit, aimPos _enemy]) > BR_var_aiSightVisibility}
};

/*
    Combat mode RED and targeting on (the travel mode switches it off). Not urgent: all AI features, behaviour COMBAT,
    the engine's pace and stance. Urgent (the zone presses): it fires on the move - behaviour AWARE, no switch to
    COMBAT, running upright (in a fight at COMBAT pace the zone caught the AI: 8 of 13 zone deaths of a medium area).
*/
BR_fnc_aiCombatMode = {
    params ["_unit", "_urgent"];

    [_unit, false] call BR_fnc_aiSetTravelMode;

    private _group = group _unit;
    private _behaviour = ["COMBAT", "AWARE"] select _urgent;

    if (combatMode _group != "RED") then {
        _group setCombatMode "RED";
    };

    if (fleeing _unit) then {
        _group allowFleeing 0;
    };

    if (behaviour _unit != _behaviour) then {
        _group setCombatBehaviour _behaviour;
    };

    if ((_unit getVariable ["BR_var_aiFightOnTheMove", false]) isEqualTo _urgent) exitWith {};

    _unit setVariable ["BR_var_aiFightOnTheMove", _urgent];

    if (_urgent) then {
        _unit disableAI "AUTOCOMBAT";
        _unit setUnitPos "UP";
        _unit forceSpeed (_unit getSpeed "FAST");
    } else {
        _unit enableAI "AUTOCOMBAT";
        _unit setUnitPos "AUTO";
        _unit forceSpeed -1;
    };
};

// once per enemy: the best cover near a spot BR_var_aiCoverDistance away from the enemy, the unit fights from there
BR_fnc_aiTakeCover = {
    params ["_unit", "_enemy"];

    if ((_unit getVariable ["BR_var_aiCoverFrom", objNull]) isEqualTo _enemy) exitWith {};

    _unit setVariable ["BR_var_aiCoverFrom", _enemy];

    private _spot = _unit getPos [BR_var_aiCoverDistance, _enemy getDir _unit];
    private _cover = selectBestPlaces [_spot, BR_var_aiCoverRadius, BR_var_aiCoverExpression, BR_var_aiCoverPrecision, 1];
    private _coverPos = if (_cover isEqualTo []) then {_spot} else {[(_cover select 0) select 0] call BR_fnc_groundPos};

    if (surfaceIsWater _coverPos) then {
        _coverPos = getPosATL _unit;
    };

    [_unit, _coverPos, false] call BR_fnc_aiMoveTo;
};

// Server combat decisions: observed contacts and last seen positions, health/ammo-aware commitment and disengagement.
// Engine targeting is used only on visible enemies. Sound/hits give a bearing, not an exact hidden target.
BR_fnc_aiObserve = {
    params ["_unit"];
    private _contacts = (_unit getVariable ["BR_var_aiContacts", []]) select {
        time - (_x select 2) < 20 && {alive (_x select 0)}
    };
    private _visible = [];
    private _team = _unit getVariable ["BR_var_teamId", -1];
    {
        if (alive _x && {_x getVariable ["BR_var_inMatch", false]} &&
            {!(_x getVariable ["BR_var_aboard", false])} && {!(_x getVariable ["ais_unconscious", false])} &&
            {(_x getVariable ["BR_var_teamId", -1]) != _team} &&
            {(_unit knowsAbout _x) >= 1 || {_unit distance _x < BR_var_aiSightRange}} &&
            {[_unit, _x] call BR_fnc_aiSees}) then {
            private _enemy = _x;
            private _index = _contacts findIf {(_x select 0) isEqualTo _enemy};
            private _record = [_enemy, getPosATL _enemy, time];
            if (_index < 0) then {_contacts pushBack _record} else {_contacts set [_index, _record]};
            _visible pushBack _enemy;
        };
    } forEach (_unit nearEntities [["CAManBase"], BR_var_aiEngageRange]);
    _unit setVariable ["BR_var_aiContacts", _contacts];
    _unit setVariable ["BR_var_aiVisible", _visible];
};

BR_fnc_aiSafeToHeal = {
    params ["_unit"];
    (_unit getVariable ["BR_var_aiVisible", []]) isEqualTo [] &&
    {time - (_unit getVariable ["BR_var_aiUnderFireAt", -100]) > 5} &&
    {time - (_unit getVariable ["BR_var_aiLastFired", -100]) > 3}
};

BR_fnc_aiWithdraw = {
    params ["_unit", "_dangerPos", "_urgent"];
    private _destination = _unit getVariable ["BR_var_aiWithdrawPos", []];
    if (_destination isEqualTo [] || {_unit distance2D _destination < 8} ||
        {time - (_unit getVariable ["BR_var_aiWithdrawPlanAt", -100]) > 8}) then {
        _destination = if (_urgent) then {[_unit] call BR_fnc_aiZoneDestination} else {
            _unit getPos [30 + 25 * damage _unit, _dangerPos getDir _unit]
        };
        BR_var_zone params ["", "", "", "", "_center", "_radius"];
        if (surfaceIsWater _destination || {_destination distance2D _center > _radius}) then {
            _destination = [_unit] call BR_fnc_aiZoneDestination;
        };
        private _cover = selectBestPlaces [_destination, 15, BR_var_aiCoverExpression, 5, 1];
        if (_cover isNotEqualTo []) then {
            private _covered = [(_cover select 0) select 0] call BR_fnc_groundPos;
            if (!surfaceIsWater _covered && {_covered distance2D _center < _radius}) then {_destination = _covered};
        };
        _unit setVariable ["BR_var_aiWithdrawPos", _destination];
        _unit setVariable ["BR_var_aiWithdrawPlanAt", time];
    };
    _unit setVariable ["BR_var_aiDecision", "withdraw"];
    _unit setVariable ["BR_var_aiFight", []];
    [_unit, _destination] call BR_fnc_aiMoveTo;
};

BR_fnc_aiEngage = {
    params ["_unit", "_urgent"];
    private _visible = _unit getVariable ["BR_var_aiVisible", []];
    // A passive contact alone must not make an unarmed looter retreat forever.  A real
    // hit, suppression or nearby shot marks the threat; armed AI may still decide to
    // open a fight on a visible opponent themselves.
    private _underFire = time - (_unit getVariable ["BR_var_aiUnderFireAt", -100]) < 5 ||
        {time < (_unit getVariable ["BR_var_aiThreatUntil", -100])};
    private _armed = [_unit] call BR_fnc_aiArmed;
    if (!_armed && {!_underFire}) exitWith {
        _unit doTarget objNull;
        _unit setVariable ["BR_var_aiFight", []];
        _unit setVariable ["BR_var_aiDecision", "travel"];
        false
    };
    private _enemy = objNull;
    private _best = -1;
    private _current = (_unit getVariable ["BR_var_aiFight", []]) param [0, objNull];
    {
        private _distance = _unit distance _x;
        private _value = 100 / (25 + _distance);
        if (_x isEqualTo (_unit getVariable ["BR_var_aiThreat", objNull])) then {_value = _value + 2};
        if (_x isEqualTo _current) then {_value = _value * 1.25};
        if (_value > _best) then {_best = _value; _enemy = _x};
    } forEach _visible;

    if (isNull _enemy) exitWith {
        _unit doTarget objNull;
        _unit setVariable ["BR_var_aiFight", []];
        if (_underFire) exitWith {
            private _bearingPos = _unit getVariable ["BR_var_aiDangerBearingPos", getPosATL _unit];
            if (time - (_unit getVariable ["BR_var_aiUnderFireAt", -100]) < BR_var_aiFaceShotsTime && {[_unit] call BR_fnc_aiCanFightBack}) then {
                // armed and fit: it faces the shots with its targeting on and spots the shooter (BR_fnc_aiObserve) - the
                // withdrawal ran in travel mode, back to the shooter and targeting off: 0-33 % returned fire after a hit
                [_unit, _bearingPos, _urgent] call BR_fnc_aiFaceShots;
            } else {
                [_unit, _bearingPos, _urgent] call BR_fnc_aiWithdraw;
                _unit doWatch _bearingPos;
            };
            true
        };
        private _last = _unit getVariable ["BR_var_aiLastContact", []];
        if (!_urgent && {damage _unit < 0.4} && {!([_unit] call BR_fnc_aiNeedsGear)} &&
            {_last isNotEqualTo []} && {time - (_last select 1) < 6}) exitWith {
            // Search only the last observed position, never follow the hidden object's live coordinates.
            [_unit, _last select 0] call BR_fnc_aiMoveTo;
            _unit setVariable ["BR_var_aiDecision", "search"];
            true
        };
        _unit setVariable ["BR_var_aiDecision", "travel"];
        false
    };

    private _distance = _unit distance _enemy;
    private _enemyPos = getPosATL _enemy;
    _unit setVariable ["BR_var_aiLastContact", [_enemyPos, time]];
    private _mates = {alive _x && {_x distance2D _unit < 100}} count ([_unit getVariable ["BR_var_teamId", -1]] call BR_fnc_teamUnits);
    private _mags = [getUnitLoadout _unit] call BR_fnc_aiLoadoutMagazines;
    private _weapon = primaryWeapon _unit;
    if (_weapon == "") then {_weapon = handgunWeapon _unit};
    private _compatible = [_weapon] call BR_fnc_weaponMagazines;
    private _rounds = 0;
    {if ((toLowerANSI (_x select 0)) in _compatible) then {_rounds = _rounds + (_x select 1)}} forEach _mags;
    private _needy = [_unit] call BR_fnc_aiNeedsGear;
    // Only an armed enemy, or the one who just shot at the unit, is a danger worth avoiding. Withdrawing from every
    // visible (often unarmed, looting) enemy made AI on open ground keep moving away from each other until they got
    // stuck in places they could not leave (user 2026-11-15).
    private _threat = _unit getVariable ["BR_var_aiThreat", objNull];
    private _dangerous = _visible select {[_x] call BR_fnc_aiArmed || {_underFire && {_x isEqualTo _threat}}};
    private _enemyDangerous = _enemy in _dangerous;
    private _outnumbered = count _dangerous > ((_mates max 1) + 1);
    private _withdraw = _enemyDangerous &&
        {damage _unit > 0.55 || {_rounds < 8} || {_outnumbered && {damage _unit > 0.25 || {getSuppression _unit > 0.5}}}};

    if ((_withdraw && {_distance > 15}) || {_needy && {_enemyDangerous} && {_distance > 25}}) exitWith {
        [_unit, _enemyPos, _urgent] call BR_fnc_aiWithdraw;
        true
    };
    if (!_armed) exitWith {
        // here only under fire (see above); an unarmed unit leaves only when the danger is real
        if (!_enemyDangerous && {_dangerous isEqualTo []}) exitWith {
            _unit doTarget objNull;
            _unit setVariable ["BR_var_aiFight", []];
            _unit setVariable ["BR_var_aiDecision", "travel"];
            false
        };
        [_unit, _enemyPos, _urgent] call BR_fnc_aiWithdraw;
        true
    };
    private _reach = ([_weapon] call BR_fnc_aiWeaponProfile) select 1;
    if (!_underFire && {_distance > _reach * 1.15 || {_needy}}) exitWith {false};
    [_unit, _urgent] call BR_fnc_aiCombatMode;
    _unit doTarget _enemy;
    _unit doFire _enemy;
    _unit setVariable ["BR_var_aiDecision", ["fight", "rotate"] select _urgent];
    if ([_unit, _enemy, _distance] call BR_fnc_aiFightStalled) exitWith {true};
    if (_urgent) exitWith {true};
    if (_distance > (_reach min BR_var_aiChaseRange) && {_distance > BR_var_aiApproachDistance}) then {
        [_unit, _enemy] call BR_fnc_aiTakeCover;
    } else {
        if (_distance > BR_var_aiApproachDistance && {!((_unit getVariable ["BR_var_aiFight", []]) param [4, false])}) then {
            [_unit, _enemyPos, false] call BR_fnc_aiMoveTo;
        };
    };
    true
};

BR_fnc_aiThreat = {
    params ["_unit", "_shooter"];
    if (!local _unit || {!alive _unit} || {isPlayer _unit} ||
        {(_unit getVariable ["BR_var_aiState", ""]) in ["aboard", "falling"]}) exitWith {};
    if (!isNull _shooter && {!(_shooter isKindOf "CAManBase")}) then {_shooter = effectiveCommander _shooter};
    if (isNull _shooter || {[_shooter, _unit] call BR_fnc_isTeammate}) exitWith {};
    _unit setVariable ["BR_var_aiUnderFireAt", time];
    _unit setVariable ["BR_var_bandageInterrupted", true];
    _unit setVariable ["BR_var_aiNextTick", 0];
    // Hearing a shot supplies an approximate bearing. An unseen shooter is not revealed or object-targeted.
    _unit setVariable ["BR_var_aiDangerBearingPos", _unit getPos [60, (_unit getDir _shooter) + random 40 - 20]];
    private _seen = _unit distance _shooter <= BR_var_aiThreatRange && {[_unit, _shooter] call BR_fnc_aiSees};
    if (!_seen) exitWith {
        if (isNull objectParent _unit && {[_unit] call BR_fnc_aiCanFightBack}) then {
            [_unit, _unit getVariable "BR_var_aiDangerBearingPos", [_unit] call BR_fnc_aiZoneUrgent] call BR_fnc_aiFaceShots;
        };
    };
    _unit setVariable ["BR_var_aiThreat", _shooter];
    _unit setVariable ["BR_var_aiThreatUntil", time + BR_var_aiThreatTime];
    private _contacts = _unit getVariable ["BR_var_aiContacts", []];
    private _index = _contacts findIf {(_x select 0) isEqualTo _shooter};
    private _contact = [_shooter, getPosATL _shooter, time];
    if (_index < 0) then {_contacts pushBack _contact} else {_contacts set [_index, _contact]};
    _unit setVariable ["BR_var_aiContacts", _contacts];
    private _vehicle = objectParent _unit;
    if (!isNull _vehicle) exitWith {
        // Do not abandon a sound vehicle just because somebody fires: continue to safety unless it is disabled.
        _unit setVariable ["BR_var_aiDangerBearingPos", getPosATL _shooter];
    };
    if ([_unit] call BR_fnc_aiCanFightBack) then {
        [_unit, true] call BR_fnc_aiCombatMode;
        _unit doTarget _shooter;
        _unit doFire _shooter;
    };
};

BR_fnc_aiCanFightBack = {
    params ["_unit"];
    [_unit] call BR_fnc_aiArmed && {damage _unit < 0.55} && {!(_unit getVariable ["ais_unconscious", false])}
};

/*
    Shot at by an enemy it does not see (a hit, a shot close by): the unit turns towards the bearing of the shots with its
    targeting on (the travel mode had switched it off) - once per burst it stops where it is, unless the zone presses
    (then it keeps going and fires on the move). The engine then takes cover at COMBAT behaviour.
*/
BR_fnc_aiFaceShots = {
    params ["_unit", "_bearingPos", "_urgent"];
    [_unit, _urgent] call BR_fnc_aiCombatMode;
    _unit doWatch _bearingPos;
    _unit setVariable ["BR_var_aiDecision", "faceShots"];
    if (!_urgent && {time - (_unit getVariable ["BR_var_aiFacingShotsAt", -100]) > BR_var_aiFaceShotsTime}) then {
        doStop _unit;
        _unit setVariable ["BR_var_aiDestination", []];
    };
    _unit setVariable ["BR_var_aiFacingShotsAt", time];
};

// Progress, recent actual firing and the available time determine whether to hold, flank or abandon a fight.
BR_fnc_aiFightStalled = {
    params ["_unit", "_enemy", "_distance"];
    (_unit getVariable ["BR_var_aiFight", []]) params [["_previous", objNull], ["_since", time], ["_startDistance", _distance], ["_shotsAt", -100], ["_flanking", false]];
    private _lastShot = _unit getVariable ["BR_var_aiLastFired", -100];
    if (_previous isNotEqualTo _enemy || {_distance < _startDistance - 8} || {_lastShot > _shotsAt}) exitWith {
        _unit setVariable ["BR_var_aiFight", [_enemy, time, _distance, _lastShot, _flanking && {_previous isEqualTo _enemy}]];
        false
    };
    private _budget = (8 max (_distance / 5)) min 30;
    _budget = _budget * (1 - damage _unit * 0.5);
    if ([_unit] call BR_fnc_aiZoneUrgent) then {_budget = _budget min 6};
    if (time - _since < _budget) exitWith {false};
    if (!_flanking && {!([_unit] call BR_fnc_aiZoneUrgent)}) exitWith {
        private _flank = _unit getPos [20, (_unit getDir _enemy) + selectRandom [-70, 70]];
        if (!surfaceIsWater _flank) then {[_unit, _flank, false] call BR_fnc_aiMoveTo};
        _unit setVariable ["BR_var_aiFight", [_enemy, time, _distance, _lastShot, true]];
        false
    };
    _unit setVariable ["BR_var_aiFight", []];
    [_unit, getPosATL _enemy, [_unit] call BR_fnc_aiZoneUrgent] call BR_fnc_aiWithdraw;
    true
};
