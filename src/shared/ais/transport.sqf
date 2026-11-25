// AIS transport of the wounded: dragging, carrying, loading into and unloading from vehicles, medevac areas.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
 * Author: psycho
 * Set a object / Vehicle in function of a medevac point and make it public. Usable for spawned objects for example. Public function.
 * Arguments:
    0: Vehicle (Object)
    1: Distance (Number)
 * Return value:
    changed AIS_MEDEVAC_STATIONS array.
    Return a Bool if no new object was added. (error)
 */
AIS_System_fnc_addMedEvacObj = {
    params [["_obj",objNull,[objNull]], ["_distance",0,[0]]];
    private _return = false;

    if (!isNull _obj) then {
        _index = AIS_MEDEVAC_STATIONS pushBackUnique [_obj, _distance];
        if (_index != -1) then {_return = true};
    } else {
        _return = false;
    };

    if (_return) exitWith {
        publicVariable "AIS_MEDEVAC_STATIONS";
        AIS_MEDEVAC_STATIONS
    };

    _return
};

/*
 * Author: psycho
 * Check Unit if carrying is possible/allowed. If yes, drag-action is shown up.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowCarry = {
    private _target = _this;

    _isUnc = _target getVariable ["ais_unconscious",false];
    _isUncHealer = player getVariable ["ais_unconscious",false];
    _Drag = !(isNull (_target getVariable ['ais_DragDrop_Player', objNull]));
    _Draging = !(isNull (player getVariable ['ais_DragDrop_Torso', objNull]));

    _return = if (

        _isUnc &&
        !_isUncHealer &&
        {alive _target} &&
        {_Drag} &&
        {_Draging}

    ) then {true} else {false};

    _return
};

/*
 * Author: psycho
 * Check Unit if dragging/carrying is possible/allowed. If yes, drag-action is shown up.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowDrag = {
    private _target = _this;

    _isUnc = _target getVariable ["ais_unconscious",false];
    _isUncHealer = player getVariable ["ais_unconscious",false];
    _noHealer = isNull (_target getVariable ['ais_hasHelper', objNull]);
    _noDrag = isNull (_target getVariable ['ais_DragDrop_Player', objNull]);
    _noDraging = isNull (player getVariable ['ais_DragDrop_Torso', objNull]);

    _return = if (

        _isUnc &&
        !_isUncHealer &&
        {alive _target} &&
        {_noHealer} &&
        {_noDrag} &&
        {_noDraging}

    ) then {true} else {false};

    _return
};

/*
 * Author: Psycho
 * Check if uncoscious Unit can load in a vehicle..
 * Arguments:
    0: Vehicle (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowPullIn = {
    private _targetVehicle = _this;

    _canload = [false, true] select (count ([_targetVehicle] call AIS_System_fnc_getCargoIndex) > 0);

    _canload
};

/*
 * Author: psycho
 * Check Unit if get a unit out of a vehicle is possible
 * Arguments:
    0: Vehicle (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowPullOut = {
    private _targetVehicle = _this;

    private _crew = crew _targetVehicle;
    private _isUncInside = false;

    if (count _crew > 0) then {
        {
            if (_x getVariable ["ais_unconscious", false]) then {
                if (_x call AIS_System_fnc_checkUnload) exitWith {_isUncInside = true};
            };
            true
        } count _crew;
    };

    _isUncInside
};

/*
 * Author: Psycho
 * Start to carry a unit.
 * Arguments:
    0: Unit Drager (Object)
    1: Unit wounded (Object)
 * Return value:
    -
*/
AIS_System_fnc_carry = {
    params ["_unit"];
    private _target = _unit getVariable ["ais_DragDrop_Torso", objNull];

    // switch to primary weapon, exit if no primary weapon is present (animation cant be played without a primary :(    )
    if (primaryWeapon _unit isEqualTo "") exitWith {
        ["medicSystem", ["This action is only allowed while carrying a primary weapon."]] call SC_fnc_showNotificationIfHudIsEnabled;
    };

    if (primaryWeapon _unit != "") then {
        _unit switchMove "amovpercmstpsraswrfldnon";
        _unit selectWeapon (primaryWeapon _unit);
    };

    if (_unit call AIS_System_fnc_checkLauncher) exitWith {
        ["medicSystem", ["You are not able to carry anyone else while carrying a launcher on your back."]] call SC_fnc_showNotificationIfHudIsEnabled;
    };
    _unit setVariable ["ais_CarryDrop_Torso", true];

    [_target,_unit] spawn {

        _target = _this select 0;
        _unit = _this select 1;
        detach _unit;
        detach _target;

        _pos = _unit modelToWorld [0,1.8,0];
        _target setPos _pos;
        [_target, "grabCarried"] remoteExec ["playActionNow", 0, false];
        disableUserInput true;
        sleep 2.5;
        if (!isPlayer _target) then {_target disableAI "ANIM"};
        [_unit, "grabCarry"] remoteExec ["playActionNow", 0, false];
        _unit playActionNow "grabCarry";
        disableUserInput false;
        disableUserInput true;
        disableUserInput false;

        _timenow = time;
        waitUntil {!alive _target || {!alive _unit} || {_unit getVariable ["ais_unconscious", false]} || {time > _timenow + 16}};
        _state = _unit getVariable ["ais_unconscious", false];
        if (!alive _target || {!alive _unit} || {_state}) then {
            if (alive _target) then {
                [_target, "agonyStart"] remoteExec ["playActionNow", 0, false];
                _target setVariable ["ais_DragDrop_Player", objNull, true];
            };
            if (alive _unit && {!(_state)}) then {
                [_unit, "amovpknlmstpsraswrfldnon"] remoteExec ["playMoveNow", 0, false];
            };
            _unit setVariable ["ais_DragDrop_Torso", objNull];
            _unit setVariable ["ais_CarryDrop_Torso", false];
        } else {
            _target attachTo [_unit, [-0.6, 0.28, -0.05]];
            [_target, 0] remoteExec ["setDir", 0, false];
        };

    };

    true
};

/*
* Author: psycho

* Check if a unit can be unload from a vehicle at the actual situation

* Arguments:
    0: Unit (Object)

* Example:
    [player] call AIS_System_fnc_checkUnload;

* Return value:
    Bool
*/
AIS_System_fnc_checkUnload = {

    params ["_unit"];
    private _vehicle = vehicle _unit;

    if (surfaceIsWater position _unit) exitWith {false};

    ((speed _vehicle < 2) && {((getPosATL _vehicle) select 2) < 2})
};

/*
 * Author: Psycho
 * Start to drag a unit.
 * Arguments:
    0: Unit Drager (Object)
    1: Unit wounded (Object)
 * Return value:
    -
*/
AIS_System_fnc_drag = {
    params ["_unit", "_target"];

    _unit setVariable ["ais_DragDrop_Torso", _target];
    _target setVariable ["ais_DragDrop_Player", _unit, true];

    _target setVariable ["ais_hasHelper", _unit, true];

    detach _unit;
    detach _target;

    [_target, "AinjPpneMrunSnonWnonDb"] remoteExec ["switchMove", 0];
    [_unit, "grabDrag"] remoteExec ["playActionNow", 0, false];

    _attachPoint = [0, 1.1, 0.05];
    _target attachTo [_unit, _attachPoint];
    [_target, 180] remoteExec ["setDir", 0, false];

    // release the injured if the helper getin a vehicle
    [
        {isNull ((_this select 1) getVariable ["ais_DragDrop_Player", objNull]) || {!(isNull objectParent (_this select 0))}},
        {if (!(isNull objectParent (_this select 0))) then {[(_this select 0)] call AIS_System_fnc_release}},
        [_unit,_target]
    ] call AIS_Core_fnc_waitUntilAndExecute;
};

/*
 * Author: Psycho
 * Get a free cargo seat position for given vehicle.
 * Arguments:
    0: Vehicle (Object)
 * Return value:
    [vehicle, cargo index] (ARRAY) (empty Array if nothing found)
 */
AIS_System_fnc_getCargoIndex = {
    params ["_targetVehicle"];
    private _VehicleIndex = [];

    // check if free cargo seats are avalible
    private _allCargoSeats = [];
    _allCargoSeats = fullCrew [_targetVehicle, "cargo", true];
    if ( count _allCargoSeats > 0) then {
        {
            if (isNull (_x select 0)) exitWith {
                _VehicleIndex = [_targetVehicle, _x select 2];
            };
            true
        } count _allCargoSeats;
    };

    if (count _VehicleIndex > 0) exitWith {_VehicleIndex};

    // check if free turret seats are avalible if no cargo seats there
    private _allTurretSeats = [];
    _VehicleIndex = [];
    _allTurretSeats = fullCrew [_targetVehicle, "Turret", true];
    if ( count _allTurretSeats > 0) then {
        {
            if (isNull (_x select 0)) exitWith {
                _VehicleIndex = [_targetVehicle, _x select 2];
            };
            true
        } count _allTurretSeats;
    };

    _VehicleIndex
};

/*
 * Author: Psycho
 * Check if a unconscious unit is pulled out of the vehicle by a AI order and set the correct anim-state. Is called by the getOutMan EH.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    -
 */
AIS_System_fnc_getOutMan = {
    params ["_injured"];

    if (_injured getVariable ["ais_unconscious", false]) then {
        if (!(_injured getVariable ["ais_man_pullOut", false])) then {
            [_injured, "agonyStart"] remoteExec ["playActionNow", 0, false];
        };
    };

    true
};

/*
 * Author: Psycho
 * Load a unit into a vehicles cargo or turret seat.
 * Arguments:
    0: Unit (Object)
    1: Vehicle (Object)
 * Return value:
    -
*/
AIS_System_fnc_loadInjured = {
    params ["_unit", "_vehicle"];

    _injured = _unit getVariable ['ais_DragDrop_Torso', objNull];
    [_unit] call AIS_System_fnc_release;

    _injured setVariable ["ais_man_pullOut", false, true];

    // move the wounded in the vehicle
    [_injured, _vehicle, 1] remoteExecCall ["AIS_System_fnc_moveCargoRemote", 0];

    // unconscious animation in cargo seat
    [{[(_this select 0), 'unconscious'] remoteExec ["playActionNow", 0, false]}, [_injured]] call AIS_Core_fnc_onNextFrame;

    true
};

/*
 * Author: Psycho
 * Check Unit if is in range of a medevac object.
 * Arguments:
    0: Unit (Object)
    1: Injured (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_medEvacArea = {
    params ["_player", "_injured"];

    private _return = false;
    {
        _x params [["_obj", objNull], ["_radius", 0, [0]]];
        if (_return) exitWith {true};
        if (!isNull _obj) then {
            if (_radius > 0) then {
                if ([_obj, _radius] call AIS_Core_fnc_inRange) exitWith {_return = true};
            };
        };
    } count AIS_MEDEVAC_STATIONS;

    _return
};

/*
 * Author: Psycho
 * Load a unit into a vehicles cargo or turret seat. Function is everytime called by a player. Checks if the unit is local, if not, use remoteExec.
 * Arguments:
    0: Unit (Object)
    1: Vehicle (Object)
    2: In/Out (Number)        // 0 = Out / 1 = In
 * Return value:
    -
*/
AIS_System_fnc_moveCargoRemote = {
    params ["_injured", "_vehicle", "_handling"];

    private _VehicleIndex = [_vehicle] call AIS_System_fnc_getCargoIndex;

    if (_handling > 0) then {
        _injured assignAsCargoIndex [_vehicle, _VehicleIndex select 1];
        _injured moveInCargo [_vehicle, _VehicleIndex select 1];
    } else {
        unassignVehicle _injured;
        moveOut _injured;
    };

    true
};

/*
 * Author: Psycho
 * Stop to drag another unit.
 * Arguments:
    0: Unit (Object)
 * Return value:
    -
*/
AIS_System_fnc_release = {
    params ["_unit"];
    private _target = _unit getVariable "ais_DragDrop_Torso";
    private _pos = getPosATL _target;

    _unit setVariable ["ais_DragDrop_Torso", objNull];
    _target setVariable ["ais_DragDrop_Player", objNull, true];
    _unit setVariable ["ais_CarryDrop_Torso", false];

    _target setVariable ["ais_hasHelper", objNull, true];
    _unit playAction "released";

    detach _unit;
    detach _target;

    if (alive _target) then {
        [_target, "AinjPpneMstpSnonWrflDb_release"] remoteExec ["switchMove", 0];
        _target setPos _pos;
    };

    true
};

/*
 * Author: psycho
 * Pull a injured out of a vehicle
 * Arguments:
    0: Unit (Object)
    1: Vehicle (Object)
 * Return value:
    -
*/
AIS_System_fnc_unloadInjured = {
    params ["_unit", "_vehicle"];

    // get the wounded unit
    private _crew = crew _vehicle;
    private _injured = objNull;
    {
        if (_x getVariable ["ais_unconscious", false]) exitWith {_injured = _x};
        true
    } count _crew;

    _injured setVariable ["ais_man_pullOut", true, true];

    // move the wounded out of the vehicle
    [_injured, _vehicle, 0] remoteExecCall ["AIS_System_fnc_moveCargoRemote", 0];

    if (_injured call AIS_System_fnc_allowDrag) then {
        [{[(_this select 0), (_this select 1)] call AIS_System_fnc_drag}, [_unit,_injured]] call AIS_Core_fnc_onNextFrame;
    };

    true
};
