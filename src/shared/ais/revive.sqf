// AIS revive: reviving and stabilizing (player and AI helpers), healing, first aid kit handling.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
 * Author: Psycho
 * Check Unit if Revive is possible. If yes, Revive-Action is shown up.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowRevive = {
    private _target = _this;

    _isUnc = _target getVariable ["ais_unconscious",false];
    _isStabil = _target getVariable ["ais_stabilized",false];
    _isUncHealer = player getVariable ["ais_unconscious",false];
    _noHealer = isNull (_target getVariable ['ais_hasHelper', objNull]);
    _noDrag = isNull (_target getVariable ['ais_DragDrop_Player', objNull]);
    _noDraging = isNull (player getVariable ['ais_DragDrop_Torso', objNull]);

    private _station = true;
    if (count AIS_MEDEVAC_STATIONS > 0) then {
        _station = [player, _target] call AIS_System_fnc_medEvacArea;
    };

    _is_able_to_do = switch (AIS_MEDICAL_EDUCATION) do {
        case (0) : {true};
        case (1) : {(items player) find "FirstAidKit" > -1 || {(items player) find "Medikit" > -1}};
        case (2) : {(player call AIS_System_fnc_isMedic) || {_target in (player getVariable ["SC_var_groupUnits", []])}};
        default {true};
    };

    _return = if (

        _isUnc &&
        {(side (group player)) == (side (group _target))} &&
        {_isStabil} &&
        {!_isUncHealer} &&
        {alive _target} &&
        {_noHealer} &&
        {_noDrag} &&
        {_noDraging} &&
        {_is_able_to_do} &&
        {_station}

    ) then {true} else {false};

    _return
};

/*
 * Author: Psycho
 * Check Unit if Revive is possible. If yes, Revive-Action is shown up.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Bool
 */
AIS_System_fnc_allowStabilize = {
    private _target = _this;

    _isUnc = _target getVariable ["ais_unconscious",false];
    _isStabil = _target getVariable ["ais_stabilized",false];
    _isUncHealer = player getVariable ["ais_unconscious",false];
    _noHealer = isNull (_target getVariable ['ais_hasHelper', objNull]);
    _noDrag = isNull (_target getVariable ['ais_DragDrop_Player', objNull]);
    _noDraging = isNull (player getVariable ['ais_DragDrop_Torso', objNull]);

    _return = if (

        _isUnc &&
        {!_isStabil} &&
        {!_isUncHealer} &&
        {alive _target} &&
        {_noHealer} &&
        {_noDrag} &&
        {_noDraging}

    ) then {true} else {false};

    _return
};

/*
 * Author: Psycho
 * Calculate the needed time to revive a unit.
 * Arguments:
    0: Unit (Object)
    1: Injured (Object)
 * Return value:
    NUMBER (Revive Time)
*/
AIS_System_fnc_calculateReviveTime = {
    params ["_unit", "_injured"];

    private _calculated_revive_time = AIS_REVIVETIME;

    // A bigger factor mean we have a bigger deviation in revive time depending in our real damage deviation. (recommended values between 0.5 and 2.0)
    _ais_variation_factor = 0.7;
    // If the unit stay at this avg damage we are near the basic revive time. If the real damage is less or stronger also the real revive time will change. (no big changes recommended!)
    _ais_avg_damage_factor = 6;

    // get real damage (all body parts + overall damage)
    private _summary_damage = 0;
    {
        _summary_damage = _summary_damage + (((getAllHitPointsDamage _injured) select 2) select _x);
        true
    } count [0,1,2,3,4,5,6,7,8,9,10];
    _summary_damage = _summary_damage + (damage _injured);

    // calculate revive time
    _calculated_revive_time =(AIS_REVIVETIME +((_ais_variation_factor *(_summary_damage - _ais_avg_damage_factor
        )) * 2)) max (AIS_REVIVETIME / 2);

    // rezise the time if the helper is a medic
    if (_unit call AIS_System_fnc_isMedic) then {
        _calculated_revive_time = _calculated_revive_time / 1.5;
    };

    _calculated_revive_time
};

/*
 * Author: Psycho
 * Calculate the needed time to stabilize a unit.
 * Arguments:
    0: Unit (Object)
    1: Injured (Object)
 * Return value:
    NUMBER (Stabilize Time)
*/
AIS_System_fnc_calculateStabilizeTime = {
    params ["_unit", "_injured"];

    private _calculated_stabilize_time = AIS_STABILIZETIME;

    // A bigger factor mean we have a bigger deviation in revive time depending in our real damage deviation. (recommended values between 0.5 and 2.0)
    _ais_variation_factor = 0.7;
    // If the unit stay at this avg damage we are near the basic revive time. If the real damage is less or stronger also the real revive time will change. (no big changes recommended!)
    _ais_avg_damage_factor = 6;

    // get real damage (all body parts + overall damage)
    private _summary_damage = 0;
    {
        _summary_damage = _summary_damage + (((getAllHitPointsDamage _injured) select 2) select _x);
        true
    } count [0,1,2,3,4,5,6,7,8,9,10];
    _summary_damage = _summary_damage + (damage _injured);

    // calculate revive time
    _calculated_stabilize_time =(AIS_STABILIZETIME +((_ais_variation_factor *(_summary_damage -
        _ais_avg_damage_factor)) * 2)) max (AIS_STABILIZETIME / 2);

    // rezise the time if the helper is a medic
    if (_unit call AIS_System_fnc_isMedic) then {
        _calculated_stabilize_time = _calculated_stabilize_time / 1.5;
    };

    _calculated_stabilize_time
};

/*
 * Author: Psycho
 * Searching for the best helper in the near of a player.
 * Arguments:
    0: Unit (Object) (Unit which called for help)
    1: Helper (Object (AI which can help)
 * Return value:
    Nothing
*/
AIS_System_fnc_findAIHelper = {
    params [
        ["_injured", objNull, [objNull]],
        ["_helper", objNull, [objNull]]
    ];

    //

    // start searching for a match
    if (isNull _helper) then {

        // looking for a valid AI group member.
        private _all_members = (units group _injured) - [_injured];
        if (count _all_members > 0) then {
            private _matching_members_array = [];
            {if (!(_x getVariable ["ais_unconscious", false]) && {!isPlayer _x}) then {_matching_members_array pushBack _x};true} count _all_members;

            if (count _matching_members_array > 0) then {
                {if (_x call AIS_System_fnc_isMedic) exitWith {_helper = _x};true} count _matching_members_array;
                if (isNull _helper) then {_helper = selectRandom _matching_members_array};
            };
        };

        // if no valid AI group member was found looking for close AI units of the same side
        if (isNull _helper) then {
            private _allMenNear = [];
            if (AIS_AI_HELP_RADIUS > 200) then {AIS_AI_HELP_RADIUS = 200};    // max 200 metres
            _allMenNear = (position _injured) nearEntities ["CAManBase", AIS_AI_HELP_RADIUS];
            _allMenNear = _allMenNear - [_injured];
            if (count _allMenNear > 0) then {
                private _matching_side_array = [];
                _groupUnits = (_injured getVariable ["SC_var_groupUnits", []]) - [_injured];
                private _side = _injured getVariable ["ais_side", civilian];
                    // needed, cause the injured can be captive (captive == side civilian)
                {if((_side isEqualTo (side (group _x))) &&
                    {!(_x getVariable ["ais_unconscious", false])} && {!isPlayer _x} &&
                    {(_x call AIS_System_fnc_isMedic) ||
                    {_x in _groupUnits}}) then {_matching_side_array pushBack _x}; true} count _allMenNear;
                if (count _matching_side_array > 0) then {
                    _matching_side_array = [_matching_side_array, [], {_x distance _injured}, "ASCEND"] call BIS_fnc_sortBy;
                    _helper = _matching_side_array select 0;
                };
            };
        };
    };

    // if no match...
    if (isNull _helper) exitWith {};

    _helper setVariable ["AIS_isHelper", _injured, true];
    _injured setVariable ["AIS_plannedHelper", _helper, true];

    // ...otherwise our new helper will make his way to the injured unit.
    private _acc_time = diag_tickTime + 1;
    if (local _helper) then {
        [{diag_tickTime >(_this select 2)}, {_this call AIS_System_fnc_moveAIHelper},
            [_injured, _helper, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    } else {
        [{diag_tickTime > (_this select 2)}, {
            [_this select 0, _this select 1] remoteExecCall ["AIS_System_fnc_moveAIHelper", 2];
        }, [_injured, _helper, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    };

    true
};

/*
 * Author: Psycho
 * Block the engine heal action during the unit is unconscious. Function is triggered trough the Heal-EH.
    - - > EH is brocken : did not react like the BI description tell it . Work around : remove all faks and give them
        back after the process is done .(without fak, no healing)
 * Engine healing is also blocked by fn_overrideHealAction. Keep this function cause the other function isnt stackable!
 * Arguments:
    0: Unit (Object)
    1: Healer (Object)
 * Example:
    [p1, player] call AIS_System_fnc_handleHeal;
 * Return value:
    BOOL - true to block the engine handling, false to do the engine action
*/
AIS_System_fnc_handleHeal = {
    params ["_injured", "_healer"];
    private _return = false;

    if (_injured getVariable ["ais_unconscious", false]) then {

        // remove FAKS to avoid the damage processing
        if (local _healer) then {
            [_healer] call AIS_System_fnc_removeFaks;
        } else {
            [_healer] remoteExecCall ["AIS_System_fnc_removeFaks", _healer, false];
        };

        if (isPlayer _healer) then {
            ["medicSystem", ["First you have to revive the injured."]] call SC_fnc_showNotificationIfHudIsEnabled;

            AISFinishHeal [_injured, _healer, true];

            [_healer] spawn {
                params ["_healer"];

                _currentWeapon = currentWeapon _healer;
                _primaryWeapon = primaryWeapon _healer;
                _pistol = handgunWeapon _healer;

                sleep 0.4;

                [_healer, (switch (stance _healer) do {
                    case "CROUCH": {
                        switch true do {
                            case (_currentWeapon == ""): {"AmovPknlMstpSnonWnonDnon"};
                            case (_currentWeapon == _primaryWeapon): {"AmovPknlMstpSrasWrflDnon"};
                            case (_currentWeapon == _pistol): {"AmovPknlMstpSrasWpstDnon"};
                            default {"AmovPknlMstpSnonWnonDnon"};
                        }
                    };
                    case "PRONE": {
                        switch true do {
                            case (_currentWeapon == ""): {"AmovPpneMstpSnonWnonDnon"};
                            case (_currentWeapon == _primaryWeapon): {"AmovPpneMstpSrasWrflDnon"};
                            case (_currentWeapon == _pistol): {"AmovPpneMstpSrasWpstDnon"};
                            default {"AmovPpneMstpSnonWnonDnon"};
                        }
                    };
                    default {
                        switch true do {
                            case (_currentWeapon == ""): {"AmovPercMstpSnonWnonDnon"};
                            case (_currentWeapon == _primaryWeapon): {"AmovPercMstpSrasWrflDnon"};
                            case (_currentWeapon == _pistol): {"AmovPercMstpSrasWpstDnon"};
                            default {"AmovPercMstpSnonWnonDnon"};
                        }
                    };
                })] remoteExecCall ["switchMove", 0];
            };
        } else {
            // we can use the AI handling at this point to start our own revive process...
            if (isNull (_injured getVariable ["ais_hasHelper", objNull])) then {
                [_healer, _injured] spawn AIS_System_fnc_ReviveAI;
            };
        };

        // give Faks back after healing process
        if (local _healer) then {
            [_healer, 8] call AIS_System_fnc_restoreFaksDelayed;
        } else {
            [_healer, 8] remoteExecCall ["AIS_System_fnc_restoreFaksDelayed", _healer, false];
        };

        _return = true;
    };

    _return
};

/*
 * Author: Psycho
 * Make the AI moving to a injured unit and start the revive.
 * Arguments:
    0: Injured unit (Object)
    1: Helper AI (Object)
 * Return value:
    Nothing
*/
AIS_System_fnc_moveAIHelper = {
    params ["_injured", "_helper"];

    // help not longer needed or possible
    if (
        !alive _helper ||
        !alive _injured ||
        {!(isNull (objectParent _helper))} ||
        (!(_injured getVariable ["ais_unconscious", false])) ||
        (_helper getVariable ["ais_unconscious", false]) ||
        (!isNull (_injured getVariable ["ais_hasHelper", objNull]))
    ) exitWith {
        _helper setVariable ["AIS_isHelper", objNull, true];
        _injured setVariable ["AIS_plannedHelper", objNull, true];
        (group _helper) setCombatBehaviour "COMBAT";
        _helper setCombatBehaviour "COMBAT";
        (group _helper) setCombatMode "RED";
        _helper setUnitCombatMode "RED";

        if (alive _helper) then {
            _helper enableAI "AUTOCOMBAT";
        } else {
            if (alive _injured && {!isPlayer _injured}) then {
                [_injured] call AIS_System_fnc_AIselfCheck;    // check if another helper is avalible
            };
        };
    };

    // AI instructions
    if (behaviour _helper != "AWARE") then {_helper setBehaviour "AWARE"};    // better "SAFE" ???
    _helper disableAI "AUTOCOMBAT";
    _helper allowFleeing 0;

    if((currentCommand _helper != "MOVE") ||
        {((((expectedDestination _helper) select 0) select [0,
        2]) distance2D (getPos _injured)) > 10}) then {
        _helper stop false;
        _helper doMove (position (vehicle _injured));
    };

    // if injured is in vehicle helper wont go that close --> have to increase the shortest distance
    _dist = if (!isNull objectParent _injured) then {(sizeOf (typeOf (vehicle _injured)) / 2) + 1} else {3};

    // start revive if close enough and ready for handling. Otherwise reset and repeat searching loop.
    if (_helper distance2D (vehicle _injured) < _dist) exitWith {
        _helper setVariable ["AIS_isHelper", objNull, true];
        _injured setVariable ["AIS_plannedHelper", objNull, true];
        (group _helper) setCombatBehaviour "COMBAT";
        _helper setCombatBehaviour "COMBAT";
        (group _helper) setCombatMode "RED";
        _helper setUnitCombatMode "RED";

        if (isNull (_injured getVariable ["ais_hasHelper", objNull])) then {
            _helper disableAI "AUTOCOMBAT";
            [_helper, _injured] spawn AIS_System_fnc_ReviveAI;
        } else {
            _helper enableAI "AUTOCOMBAT";
            [_injured] call AIS_System_fnc_AIselfCheck;
        };
    };

    // if not close enough start the function in a few seconds again
    private _acc_time = diag_tickTime + 4;
    [{diag_tickTime >(_this select 2)}, {_this call AIS_System_fnc_moveAIHelper},
        [_injured, _helper, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;

    true
};

/*
 * Author: Psycho
 * Override the heal action if the unit is unconscious.
 * This is called by a inGameUISetEventHandler. This isnt a stackable EH. This mean it will maybe be overriden by a mod or some 3rd party scripts!
 * Arguments:
    0: Unit (Object)
    1: Unit (Object)
    2: Index (Number)
    3: Action (String)
 * Return value:
    Bool - true to block the engine handling, false to do the engine action
*/
AIS_System_fnc_overrideHealAction = {
    params ["_injured", "_caller", "_index", "_action"];

    private _back = false;
    if (_action isEqualTo "HealSoldier") then {
        if (_injured getVariable ["ais_unconscious", false]) then {
            _txt = if (_injured getVariable ["ais_stabilized", false]) then {
                "First you have to revive the injured."
            } else {
                "First you have to stabilize and then revive the injured."
            };
            _txt call AIS_Core_fnc_dynamicText;
            _back = true;
        };

    };

    _back
};

/*
 * Author: Alwarren
 * Remove first aid and Medikits
 * Arguments:
    0: Unit (Object)
 * Example:
    [player] call AIS_System_fnc_removeFaks;
 * Return value:
    BOOL - false if items already stored
*/
AIS_System_fnc_removeFaks = {
    params ["_unit"];

    _unit setVariable ["AIS_MedicalStore", (getUnitLoadout _unit), true];

    // Faks from the uniform
    {
        if (_x == "FirstAidKit") then {
            _numFakUniform = _numFakUniform + 1;
            _unit removeItemFromUniform "FirstAidKit";
        };
        nil
    } count (uniformItems _unit);

    // Faks and Medikits from the vest
    {
        if (_x == "FirstAidKit") then {
            _numFaksVest = _numFaksVest + 1;
            _unit removeItemFromVest "FirstAidKit";
        };
        if (_x == "Medikit") then {
            _numMedi = _numMedi + 1;
            _unit removeItemFromVest "Medikit";
        };
        nil
    } count (vestItems _unit);

    // Faks and Medikits from the backpack. Kits can only be in backpack, so we don't search for them anywhere else
    {
        if (_x == "FirstAidKit") then {
            _numFaksBackpack = _numFaksBackpack + 1;
            _unit removeItemFromBackpack "FirstAidKit";
        };
        if (_x == "Medikit") then {
            _numMedi = _numMedi + 1;
            _unit removeItemFromBackpack "Medikit";
        };
        nil
    } count (backpackItems _unit);

    _magazines = magazines _unit;

    {
        _unit removeMagazines _x;
    } forEach (_magazines arrayIntersect _magazines);

    true
};

/*
 * Re-add first aid and Medikits after a delay (seconds, measured on the executing machine).
 * Arguments:
    0: Unit (Object)
    1: Delay (Number)
*/
AIS_System_fnc_restoreFaksDelayed = {
    params ["_unit", "_delay"];

    [{diag_tickTime >(_this select 1)}, {[(_this select 0)] call AIS_System_fnc_restoreFaks;},
        [_unit, diag_tickTime + _delay]] call AIS_Core_fnc_waitUntilAndExecute;
};

/*
 * Author: Alwarren
   Changed: Psycho
 * Re-Add first aid and Medikits.
 * Arguments:
    0: Unit (Object)
 * Example:
    [player] call AIS_System_fnc_restoreFaks;
 * Return value:
    -
*/
AIS_System_fnc_restoreFaks = {
    params ["_unit"];
    _unit setUnitLoadout (_unit getVariable "AIS_MedicalStore");
    _unit setVariable ["AIS_MedicalStore", [], true];

    true
};

/*
 * Author: Psycho
 * Handle Revive actions from a PLAYER
 * Arguments:
    0: Healer Unit (Object)
    1: Injured Unit (Object)
 * Return value:
    Nothing
*/
AIS_System_fnc_Revive = {
    params [
        ["_healer", player, [player]],
        "_injured"
    ];

    _injured setVariable ["ais_hasHelper", _healer, true];

    [_injured, "AinjPpneMstpSnonWrflDnon_rolltoback"] remoteExec ["playMove", 0];

    // switch to primary weapon if possible. Small delay for handling is needed.
    if (primaryWeapon _healer != "") then {
        _healer switchMove "amovpercmstpsraswrfldnon";
        _healer selectWeapon (primaryWeapon _healer);
    };

    _healer playAction "medicStart";

    // full heal anim only with primary weapon possible.
    ais_animChangeEVH = _healer addEventHandler ["AnimChanged", {
        params ["_healer","_anim"];
        if (primaryWeapon _healer isEqualTo "") then {
            if (_anim in ["amovpknlmstpsnonwnondnon","amovpknlmstpsraswlnrdnon"]) then {
                _healer playActionNow "medicStart";
            };
        };
    }];

    _offset = [0,0,0]; _dir = 0;
    _relpos = _healer worldToModel position _injured;
    if(((_healer getDir _injured) -(_injured getDir _healer)) < 0) then {_offset =[-0.2, 0.7, 0];
        _dir = 90} else {_offset =[0.2, 0.7, 0]; _dir = 270};

    _injured attachTo [_healer, _offset];
    [_injured, _dir] remoteExec ["setDir", 0, false];

    private _duration = [_healer, _injured] call AIS_System_fnc_calculateReviveTime;

    [
        "Applying First Aid",
        _duration,
        {
            params ["_injured", "_healer"];

            _injured setVariable ["ais_unconscious", false, true];
            _injured setVariable ["ais_unconscious_since", -999, true];

            if (isPlayer _healer) then {
                _xp = [50, 100] select (_healer getVariable ["SC_var_hasExprPerk", false]);
                [_xp] remoteExecCall ["SC_fnc_addXp", _healer];
                [_healer, _injured, _xp] remoteExecCall ["SC_fnc_midFeedHeal", 2];
                [_healer] remoteExecCall ["SC_fnc_addRevive", _healer];
                [_injured] remoteExecCall ["SC_fnc_addRevived", _injured];
            };

            _healer removeEventHandler ["AnimChanged", ais_animChangeEVH];
            detach _healer;
            detach _injured;

            _healer playAction "medicStop";

            _injured setVariable ["ais_hasHelper", objNull, true];
            call AIS_Effects_fnc_garbage;

            // healing if enabled
            if (AIS_REVIVE_HEAL) then {
                _injured setDamage 0;
                _injured setVariable ["ais_fireDamage", 0];
            } else {
                // make sure the unit can walk after revive
            };

            [_injured] remoteExecCall ["AIS_System_fnc_restoreFaks", _injured, false];

            _injured stop false;
            _injured enableAI "all";
            [_injured, false] remoteExecCall ["AIS_System_fnc_unconcsiousRemote", 0, false];

        },
        [_injured, _healer],
        {
            params ["_injured", "_healer"];

            _injured setVariable ["ais_hasHelper", objNull, true];

            _healer removeEventHandler ["AnimChanged", ais_animChangeEVH];
            detach _healer;
            detach _injured;

            call AIS_Effects_fnc_garbage;

            if (alive _healer) then {
                _healer playActionNow "medicStop";
            };
            if (!alive _injured) then {
                ["medicSystem", ["He is not with us anymore."]] call SC_fnc_showNotificationIfHudIsEnabled;
            };
        },
        (!alive _injured || _healer getVariable ["ais_unconscious",false])
    ] call AIS_Core_fnc_progress_showBar;
};

/*
 * Author: Psycho
 * Handle Revive actions from a AI.
 * Arguments:
    0: Healer Unit (Object)
    1: Injured Unit (Object)
 * Return value:
    Nothing
*/
AIS_System_fnc_ReviveAI = {
    params [
        ["_healer", player, [player]],
        "_injured"
    ];

    _injured setVariable ["ais_hasHelper", _healer, true];

    _behaviour = behaviour _healer;

    // move the wounded out of the vehicle
    if (!isNull objectParent _injured) exitWith {
        [_injured, vehicle _injured, 0] remoteExecCall ["AIS_System_fnc_moveCargoRemote", 0];
        _acc_time = diag_tickTime + 1.382;
        [{diag_tickTime >(_this select 2)},
            {[_this select 0, _this select 1] spawn AIS_System_fnc_ReviveAI},
            [_healer, _injured, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    };

    [_injured, "AinjPpneMstpSnonWrflDnon_rolltoback"] remoteExec ['playMove', 0];

    // switch to primary weapon if possible. Small delay for handling is needed.
    if (primaryWeapon _healer != "") then {
        _healer selectWeapon primaryWeapon _healer;
        sleep 0.5;
    };

    _healer setPos (getPosATL _injured);    // avoid to move the injured a few metres away
    [_healer, "medicStart"] remoteExec ['playAction', 0];

    _healer stop true;
    {_healer disableAI _x; true} count ["MOVE","TARGET","AUTOTARGET","ANIM","AUTOCOMBAT"];

    _offset = [0,0,0]; _dir = 0;
    _relpos = _healer worldToModel position _injured;
    if ((_relpos select 0) < 0) then {_offset = [-0.2,0.7,0]; _dir = 90} else {_offset = [0.2,0.7,0]; _dir = 270};

    _injured attachTo [_healer, _offset];
    [_injured, _dir] remoteExec ["setDir", 0, false];

    private _duration = [_healer, _injured] call AIS_System_fnc_calculateReviveTime;

    private _startTime = diag_tickTime + _duration;
    waitUntil {
        diag_tickTime > _startTime ||
        !alive _healer ||
        !alive _injured ||
        _healer getVariable ["ais_unconscious", false]
    };

    _injured setVariable ["ais_hasHelper", objNull, true];

    detach _healer;
    detach _injured;

    if (!alive _healer || _healer getVariable ["ais_unconscious", false]) exitWith {};
    _healer playActionNow "medicStop";

    _healer stop false;
    _healer enableAI "all";
    _healer setBehaviour _behaviour;

    if (alive _injured) then {
        _injured setVariable ["ais_unconscious", false, true];
        _injured setVariable ["ais_unconscious_since", -999, true];

        // healing if enabled
        if (AIS_REVIVE_HEAL) then {
            _injured setDamage 0;
            _injured setVariable ["ais_fireDamage", 0];
        } else {
            // make sure the unit can walk after revive
        };

        [_injured] remoteExecCall ["AIS_System_fnc_restoreFaks", _injured, false];

        if (isPlayer _injured) then {
            [true] remoteExec ['showHud', _injured];
            if (AIS_TOGGLE_RADIO) then {
                [true] remoteExecCall ["AIS_Effects_fnc_toggleRadio", _injured, false];
            };
        } else {
            _injured stop false;
            _injured enableAI "all";
        };

        [_injured, false] remoteExecCall ["AIS_System_fnc_unconcsiousRemote", 0];

    };

    true
};

/*
 * Author: Psycho
 * Stabilize a unit. A stabilized unit stop to bleed and cant die trough the revive timer.
 * Arguments:
    0: Unit Helper (Object)
    1: Unit wounded (Object)
 * Return value:
    -
*/
AIS_System_fnc_stabilize = {
    params ["_healer", "_injured"];

    _injured setVariable ["ais_hasHelper", _healer, true];

    [_injured, "AinjPpneMstpSnonWrflDnon_rolltoback"] remoteExec ["playMove", 0];

    // switch to primary weapon if possible. Small delay for handling is needed.
    if (primaryWeapon _healer != "") then {
        _healer switchMove "amovpercmstpsraswrfldnon";
        _healer selectWeapon (primaryWeapon _healer);
    };

    _healer playAction "medicStart";

    // full heal anim only with primary weapon possible.
    ais_animChangeEVH = _healer addEventHandler ["AnimChanged", {
        params ["_healer","_anim"];
        if (primaryWeapon _healer isEqualTo "") then {
            if (_anim in ["amovpknlmstpsnonwnondnon","amovpknlmstpsraswlnrdnon"]) then {
                _healer playActionNow "medicStart";
            };
        };
    }];

    _offset = [0,0,0]; _dir = 0;
    _relpos = _healer worldToModel position _injured;
    if(((_healer getDir _injured) -(_injured getDir _healer)) < 0) then {_offset =[-0.2, 0.7, 0];
        _dir = 90} else {_offset =[0.2, 0.7, 0]; _dir = 270};

    _injured attachTo [_healer, _offset];
    [_injured, _dir] remoteExec ["setDir", 0, false];

    private _duration = [_healer, _injured] call AIS_System_fnc_calculateStabilizeTime;

    [
        "Stabilizing the Injured",
        _duration,
        {
            params ["_injured", "_healer"];

            _injured setVariable ["ais_stabilized", true, true];

            _healer removeEventHandler ["AnimChanged", ais_animChangeEVH];
            detach _healer;
            detach _injured;

            _healer playAction "medicStop";

            _injured setVariable ["ais_hasHelper", objNull, true];
            call AIS_Effects_fnc_garbage;
        },
        [_injured, _healer],
        {
            params ["_injured", "_healer"];

            _injured setVariable ["ais_hasHelper", objNull, true];

            _healer removeEventHandler ["AnimChanged", ais_animChangeEVH];
            detach _healer;
            detach _injured;

            call AIS_Effects_fnc_garbage;

            if (alive _healer) then {
                _healer playActionNow "medicStop";
            };
            if (!alive _injured) then {
                ["medicSystem", ["He is not with us anymore."]] call SC_fnc_showNotificationIfHudIsEnabled;
            };
        },
        (!alive _injured || _healer getVariable ["ais_unconscious", false])
    ] call AIS_Core_fnc_progress_showBar;

    true
};

// AIS_System_fnc_unconcsiousRemote on machines with an interface only (target of remoteExecCall to all machines)
