// AIS damage: damage handling of AIS units (hit points, going down instead of dying).
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
 * Author: Psycho
 * Give back a wanted hitDamageIndex. Index number or correspondending Hitpart.
 * Arguments:
    0: Unit (Object)
    1: Hitindex or Hitpart (Number OR String)
 * Return value:
    ["Hitpart" , IndexNumber, partDamage]
 */
AIS_Damage_fnc_getHitIndexValue = {
    params [
        "_unit",
        ["_hitValue", 0, [0,""]]
    ];

    _ret = if (_hitValue isEqualType 0) then {

        if (_hitValue > 10 || _hitValue < 0) exitWith {diag_log format ["AIS ERROR: AIS_Damage_fnc_getHitIndexValue, input number is out of range: %1", _hitValue]; ["",_hitValue, 0]};
        [((getAllHitPointsDamage _unit) select 1) select _hitValue, _hitValue, ((getAllHitPointsDamage _unit) select 2) select _hitValue]

    } else {

        _hitValue = toLower _hitValue;
        private _num = ((getAllHitPointsDamage _unit) select 1) find _hitValue;

        if (_num < 0) then {
            [_hitValue, -1, damage _unit]
        } else {
            [_hitValue, _num, ((getAllHitPointsDamage _unit) select 2) select _num]
        };

    };

    _ret
};

/*
 * Author: Psycho
 * Set the unit to the real dead. (overall damage == 1)
 * Arguments:
    0: Unit (Object)
 * Return value:
    -
 */
AIS_Damage_fnc_goToDead = {
    params ["_unit", ["_killer",objNull,[]], ["_instigator",objNull,[]]];

    if (!alive _unit) exitWith {};
    if (_unit getVariable ["AIS_UnitIsDead", false]) exitWith {};

    _unit setVariable ["AIS_UnitIsDead", true];

    // unit is dragged. So the dragger have to call the release function.
    if (!(isNull (_unit getVariable ["ais_DragDrop_Player", objNull]))) then {
        _dragger = _unit getVariable ["ais_DragDrop_Player", objNull];
        [_unit] remoteExecCall ["AIS_System_fnc_release", _dragger, false];
    };

    _unit call AIS_System_fnc_restoreFaks;

    // kill message and score point
    /*
if (!isNull _killer && {isPlayer _killer}) then {
    [_killer, 1] remoteExec ["addScore", 2];
    if (isPlayer _unit) then {
        _text = format ["%1 was killed by %2", name _unit, name _source];
        [_text] remoteExec ["systemChat", 0];
    };
};
*/

    // dead... if some issues with the deadcam (shown killer) give the dead a deleay of 1 frame --> need testing

    true
};

/*
 * by Psycho
 * Arguments:
 * 0: Unit That Was Hit (Object)
 * 1: Hit Selection (String)
 * 2: Damage (Number)
 * 3: Shooter (object)
 * 4: Projectile (string)
 * 5: HitPartIndex (number)
 * 6: Instigator (object)
 * 7: HitPoint CfgName (String)
 * Return Value:
 * Damage
*/
AIS_Damage_fnc_handleDamage = {
    params [
        "_unit",            // Object the event handler is assigned to.
        "_hitSelection",    // Name of the selection where the unit was damaged. "" for over-all structural damage, "?" for unknown selections.
        "_damage",            // Resulting level of damage for the selection.
        "_source",            // The source unit (shooter) that caused the damage.
        "_projectile",        // Classname of the projectile that caused inflicted the damage. ("" for unknown, such as falling damage.) (String)
        "_hitPartIndex",    // Hit part index of the hit point, -1 otherwise.
        "_instigator",        // Person who pulled the trigger. (Object)
        "_hitPoint",            // hit point Cfg name (String)
        "_directHit"
    ];

    if !(local _unit) exitWith {false};

    private _new_damage = if (_hitPartIndex >= 0) then {_damage - (_unit getHitIndex _hitPartIndex)} else {_damage - (damage _unit)};
    if (diag_frameNo < (_unit getVariable ["ais_protector_delay", 0])) exitWith {_damage - _new_damage};

    if !(isNull _source) then {
        _unit setVariable ["AIS_lastSource", [_source, time]];
    } else {
        (_unit getVariable ["AIS_lastSource", [objNull, -1]]) params ["_lastSource", "_timeOfLastHit"];

        if (!(isNull _lastSource) && {(time - _timeOfLastHit) <= 1}) then {
            _source = _lastSource;
        };
    };

    if !(isNull _instigator) then {
        _unit setVariable ["AIS_lastInstigator", [_instigator, time]];
    } else {
        (_unit getVariable ["AIS_lastInstigator", [objNull, -1]]) params ["_lastInstigator", "_timeOfLastHit"];

        if (!(isNull _lastInstigator) && {(time - _timeOfLastHit) <= 1}) then {
            _instigator = _lastInstigator;
        };
    };

    _hitPart = [_unit, _hitSelection] call AIS_Damage_fnc_getHitIndexValue;

    if (_unit getVariable ["ais_unconscious", false]) exitWith {
        _new_damage = _new_damage * AIS_UNCONSCIOUS_DAMAGE_TOLLERANCE_FACTOR;
        _damage = (_hitPart select 2) + _new_damage;

        if ((_hitPartIndex < 0) && {_damage >= 1}) then {
            [_unit,_source,_instigator] call AIS_Damage_fnc_goToDead;
        };

        _damage
    };

    _new_damage = AIS_DAMAGE_TOLLERANCE_FACTOR * _new_damage;

    if(!(isNull (objectParent _unit)) &&
        {(_directHit && {_projectile == ""}) ||
        {SC_var_launcherAmmos getOrDefault [_projectile, false]}}) then {
        _new_damage = _new_damage * 0.5 * SC_var_vehicleDamageFactor;
    };

    _damage = (_hitPart select 2) + _new_damage;

    if (_hitPartIndex >= 0) then {
        if (_damage >= 1) then {
            _damage = 0.9999;
        };

    } else {
        if (_damage >= 0.8) then {
            _damage = 0.8;
            _unit setVariable ["ais_protector_delay", (diag_frameNo + 5)];
            [_unit, _source, _instigator, true] remoteExecCall ["KF_fnc_EntityKilled", 2];
            _unit setVariable ["AIS_downedBy", [_source, _instigator]];   // for the kill cam (AIS_System_fnc_unconsciousPlayer)
            _unit setVariable ["ais_unconscious", true, true];
            _unit setVariable ["ais_unconscious_since", time, true];
            [{[(_this select 0)] call AIS_System_fnc_setUnconscious}, [_unit]] call AIS_Core_fnc_onNextFrame;
        };
    };

    _damage
};
