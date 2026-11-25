// AIS unconsciousness: falling unconscious (player, AI, remote), bleeding out, calling for help, death and respawn.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

/*
 * Author: Psycho
 * Calculate the time till the unit will die (Revive-Time) and control the injury-effects.
 * Arguments:
    0: Unit (Object)
    1: Killer (Object)
 * Return value:
    -
*/
AIS_System_fnc_bloodloss = {
    params ["_unit"];
    if (!local _unit) exitWith {};

    // Function use disableSerialisation and can corrupt some other functions in the same frame. So it need a delay till next frame.

    // get the revive time
    _revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
    _unit setBleedingRemaining _revive_time;

    // no reset of this variable until the unit fall in a completely new unconsciou state.
    ais_start_unc_time = time;

    // start the timer and the visula effetcs
    private _acc_time = diag_tickTime + 1;
    [{diag_tickTime >=(_this select 2)}, {_this call AIS_Effects_fnc_bleeding},
        [_unit, _revive_time, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;

    true
};

/*
 * Author: Psycho
 * Calculate the time till the AI units will die (Revive-Time) and check if the get revived.
 * Arguments:
    0: Unit (Object)
 * Return value:
    -
*/
AIS_System_fnc_bloodlossAI = {
    params ["_unit"];
    if (!canSuspend) exitWith {[_unit] spawn AIS_System_fnc_bloodlossAI};
    if (!local _unit) exitWith {};

    // AI help AI
    [_unit] call AIS_System_fnc_AIselfCheck;

    // get the revive time
    _revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
    _unit setBleedingRemaining _revive_time;

    // no reset of this variable until the unit fall in a completely new unconsciou state.
    private _ai_time_over = diag_tickTime + _revive_time;

    // wait until something happens
    waitUntil {
        !alive _unit ||
        {!(_unit getVariable ["ais_unconscious", false])} ||
        {_unit getVariable ["ais_stabilized", false]} ||
        {diag_tickTime > _ai_time_over}
    };

    if (diag_tickTime > _ai_time_over) exitWith {
        [_unit, objNull, objNull] call AIS_Damage_fnc_goToDead;
        _unit setDamage 1;};

    if (_unit getVariable ["ais_stabilized", false]) then {
        waitUntil {!alive _unit || {!(_unit getVariable ["ais_unconscious", false])}};
    };

    if (!alive _unit) exitWith {_unit call AIS_System_fnc_restoreFaks};

    _unit stop false;
    _unit enableAI "all";

    /*

... place to some AI stuff after revive if necessary...

*/

    true
};

/*
 * Author: Psycho
 * Calculate the real revive time. Time depends on real summary damage of all body parts.
 * Arguments:
    0: Unit (Object)
 * Return value:
    NUMBER (Life Time)
*/
AIS_System_fnc_calculateLifeTime = {
    params ["_unit"];

    private _calculated_life_time = AIS_BLEEDOUT_TIME;

    // A bigger factor mean we have a bigger deviation in revive time depending in our real damage deviation. (recommended values between 0.5 and 2.0)
    _ais_variation_factor = 1.0;
    // If the unit stay at this avg damage we are near the basic revive time. If the real damage is less or stronger also the real revive time will change. (no big changes recommended!)
    _ais_avg_damage_factor = 6;

    // get real damage (all body parts + overall damage)
    private _summary_damage = 0;
    {
        _summary_damage = _summary_damage + (((getAllHitPointsDamage _unit) select 2) select _x);
        true
    } count [0,1,2,3,4,5,6,7,8,9,10];
    _summary_damage = _summary_damage + (damage _unit);

    // calculate life time
    _calculated_life_time = if (_unit getVariable ["AIS_noBleedOut", false]) then {
        999999999
    } else {
        AIS_BLEEDOUT_TIME + ((_ais_variation_factor * (_ais_avg_damage_factor - _summary_damage)) * 10);
    };

    _calculated_life_time
};

/*
 * Author: Psycho
 * Call for help and also start to check if a AI can help you.
 * Arguments:
    0: Unit (Object)
 * Return value:
    BOOL (true if help is called, false if not)
*/
AIS_System_fnc_callHelp = {
    params ["_unit"];

    if (!isNull (_unit getVariable ["ais_hasHelper", objNull])) exitWith {};

    if ((_unit getVariable ["callHelpDelay", 0]) > diag_tickTime) exitWith { false}; // ["You already have called for help!"] call AIS_Core_fnc_dynamicText;
    _unit setVariable ["callHelpDelay", diag_tickTime + 3];

    if (rating _unit < -1999) exitWith {false};

    [_unit, objNull] call AIS_System_fnc_findAIHelper;
    true
};

/*
 * Author: Psycho
 * Disable the respawn button for given time.
 * Arguments:
    1: Key (Number)
 * Return value:
    Bool
*/
AIS_System_fnc_disableRespawnButton = {
    disableSerialization;
    waitUntil {!(isNull (findDisplay 49))};

    _downTime = player getVariable ["ais_protector_delay", 0];
    private _delay = _downTime + AIS_DISABLE_RESPAWN_BUTTON - 6;
    private _ctrl = (findDisplay 49) displayCtrl 1010;

    while {!isNull (findDisplay 49) && {diag_tickTime < _delay}} do {
        _ctrl ctrlEnable false;
        _ctrl ctrlSetText format ["Respawn Disabled (%1 sec)", [(_delay - diag_tickTime)] call AIS_System_fnc_secondsToString];
        uiSleep 0.08;
    };

    if (!ctrlEnabled _ctrl) then {
        _ctrl ctrlEnable true;
        _ctrl ctrlSetText "Respawn";
    };

    true
};

/*
 * Author: Psycho
 * Clean up the unit if they got killed. Is called by the killed EH.
 * Arguments:
    0: Unit (Object)
    1: Killer (Object)
 * Return value:
    -
*/
AIS_System_fnc_killed = {
    params ["_unit", "_killer"];

    if (!(isNull (_unit getVariable ["ais_DragDrop_Torso", objNull]))) then {
        [_unit] call AIS_System_fnc_release;
    };
};

/*
 * Author: Psycho
 * Re-initialize a respawned unit.
 * Arguments:
    0: Unit (Object)
    1: Corpse (Object)
 * Return value:
    -
*/
AIS_System_fnc_respawn = {
    params ["_unit", "_corpse"];

    _unit setVariable ["ais_unconscious", false, true];
    _unit setVariable ["ais_unconscious_since", -999, true];
    _unit setVariable ["ais_stabilized", false, true];
    _unit setVariable ["ais_fireDamage", 0];
    _unit setVariable ["AIS_UnitIsDead", false];

    if (isPlayer _unit) then {
        if (local player) then {showHUD true};
        if (AIS_TOGGLE_RADIO) then {
            [true] call AIS_Effects_fnc_toggleRadio;
        };
    } else {
        _unit stop false;
        _unit enableAI "all";
    };
};

/*
 * Author: Psycho
 * Set the unit in unconcsious state. This is a public function.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    [player] call AIS_System_fnc_setUnconscious;
 */
AIS_System_fnc_setUnconscious = {
    params ["_unit"];

    if (time <= 0) exitWith {
        [
            {time > 0},
            {_this call AIS_System_fnc_setUnconscious},
            [_unit]
        ] call AIS_Core_fnc_waitUntilAndExecute;
    };

    if (isPlayer _unit) then {
        [_unit] call AIS_System_fnc_unconsciousPlayer
    } else {
        [_unit] call AIS_System_fnc_unconsciousAI
    };

    true
};

AIS_System_fnc_unconcsiousRemoteClient = {
    if (!isDedicated) then {
        _this call AIS_System_fnc_unconcsiousRemote;
    };
};

/*
 * Author: Psycho
 * Broadcast everything across the network which is needed if a unit fall in agony
 * Arguments:
    0: Unit (Object)
    1: Unconcsious state of the Unit (Bool)
 * Return value:
    Nothing
 */
AIS_System_fnc_unconcsiousRemote = {
    params [
        ["_unit", objNull, [player]],
        ["_is_unoncsious", false, [false]]
    ];

    if (isNull _unit) exitWith {diag_log format ["Non existing unit or wrong data type passed. AIS_System_fnc_unconcsiousRemote.sqf"];};

    // this function runs on every machine; playActionNow needs a local unit and has global effect, so only the
    // unit's owner plays the animation (re-broadcasting from every machine sent N^2 messages per knock-down).
    // AI units get their agonyStart from AIS_System_fnc_unconsciousAI on their owner (this function doesn't run on a
    // dedicated server for them).
    if (_is_unoncsious) then {
        if (local _unit) then {
            if (isPlayer _unit) then {
                _unit playActionNow "agonyStart";
            };

            [_unit] spawn {
                params ["_unit"];

                waitUntil {
                    [_unit] call AIS_System_fnc_callHelp;
                    sleep 4;

                    // put the unit back into agony only if it left the injured animations (e.g. pushed out of a vehicle).
                    // Don't force one fixed animation: the engine picks the agony variant for the weapon in hand, and
                    // forcing the no-weapon variant every 4 s made it switch back and roll over again and again.
                    private _animation = toLowerANSI (animationState _unit);

                    if (
                        (isNull objectParent _unit) && {isNull attachedTo _unit} &&
                        {(_animation find "inj") < 0} && {(_animation find "unconscious") < 0}
                    ) then {
                        _unit playActionNow "agonyStart";
                    };

                    (!(alive _unit) || {!(_unit getVariable ["AIS_unconscious", false])})
                };
            };
        };
    } else {
        if (local _unit) then {
            _unit playActionNow "agonyStop";
        };

        [_unit, 50] call AIS_System_fnc_reveal;
    };

    true
};

/*
 * Author: Psycho
 * Set the unit in unconcsious state for Non-players. Set all variables and handle things around.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    [unit] call AIS_System_fnc_unconsciousAI;
 */
AIS_System_fnc_unconsciousAI = {
    params ["_unit"];

    // set the variables; a new unconscious state always starts bleeding (a revive does not reset ais_stabilized)
    _unit setVariable ["ais_unconscious", true, true];
    _unit setVariable ["ais_unconscious_since", time, true];
    _unit setVariable ["ais_stabilized", false, true];

    // if player drag or carry someone release the body
    if (!(isNull (_unit getVariable ["ais_DragDrop_Torso", objNull]))) then {
        [_unit] call AIS_System_fnc_release;
    };

    // do some actions for some special situations...
    if (count attachedObjects _unit > 0) then {
        {detach _x} forEach (attachedObjects _unit);
    };
    if (animationState _unit in ["ladderriflestatic", "laddercivilstatic"]) then {
        _unit action ["ladderOff", (nearestBuilding _unit)];
    };

    // animation on the owner (global effect), other actions across the network to all players
    _unit playActionNow "agonyStart";
    [_unit, true] remoteExecCall ["AIS_System_fnc_unconcsiousRemoteClient", 0];

    // AI actions
    _unit stop true;
    _unit disableAI "all";

    // remove medic euqipment from unconscious unit
    [_unit] call AIS_System_fnc_removeFaks;

    // random screaming

    // set unit as captive

    // countdown for AI's
    [_unit] spawn AIS_System_fnc_bloodlossAI;

    // correkt animation if unit get pushed out of a vehicle on other ways except the pull-out action
    _unit addEventHandler ["getOutMan", {_this call AIS_System_fnc_getOutMan}];

    // avoid to switching in while unc
    removeSwitchableUnit _unit;

    true
};

/*
 * Author: Psycho
 * Set the unit in unconcsious state for PLAYERS. Set all variables and handle things around.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    [player] call AIS_System_fnc_unconsciousPlayer;
 */
AIS_System_fnc_unconsciousPlayer = {
    params ["_unit"];

    // set the variables; a new unconscious state always starts bleeding (a revive does not reset ais_stabilized)
    _unit setVariable ["ais_unconscious", true, true];
    _unit setVariable ["ais_unconscious_since", time, true];
    _unit setVariable ["ais_stabilized", false, true];
    _unit setVariable ["ais_CarryDrop_Torso", false];

    // if player drag or carry someone release the body
    if (!(isNull (_unit getVariable ["ais_DragDrop_Torso", objNull]))) then {
        [_unit] call AIS_System_fnc_release;
    };
    // do some actions for some special situations...
    if (count attachedObjects _unit > 0) then {
        {detach _x} forEach (attachedObjects _unit);
    };
    if (animationState _unit in ["ladderriflestatic", "laddercivilstatic"]) then {
        _unit action ["ladderOff", (nearestBuilding _unit)];
    };

    // animation and other actions across the network
    [_unit, true] remoteExecCall ["AIS_System_fnc_unconcsiousRemote", 0, false];

    // camera actions
    if (dialog) then {closeDialog 0};
    titleCut ["","BLACK IN", 1.5];
    if (visibleMap) then {openMap false};
    showHUD false;
    _unit switchCamera "INTERNAL";
    if (sunOrMoon isEqualTo 0) then {
        _unit action ["nvGogglesOff", _unit];
    };

    // remove medic euqipment from unconscious unit
    [_unit] call AIS_System_fnc_removeFaks;

    // disable radios
    if (AIS_TOGGLE_RADIO) then {
        [false] call AIS_Effects_fnc_toggleRadio;
    };

    // random screaming

    // set unit as captive
    /*
[_unit, true] remoteExec ["setCaptive", 0, false];
_unit addEventHandler ["fired", {
    private _shooter = _this select 0;
    [_shooter, false] remoteExec ["setCaptive", 0, false];
}];
*/

    // value >= 0.5 break the crawl-feature from agony action! (canMove false)

    // the kill cam (killfeed) shows who downed the player; the bleed-out camera and HUD wait for its end
    // (AIS_Effects_fnc_bleeding). A unit that is unconscious since a join has no source.
    (_unit getVariable ["AIS_downedBy", [objNull, objNull]]) params ["_source", "_instigator"];
    _unit setVariable ["AIS_downedBy", nil];

    if (!isNil "KF_fnc_killCamDowned") then {
        [_unit, _source, _instigator] call KF_fnc_killCamDowned;

        // right after the kill cam, not only on the next pass of the bleeding loop
        if (isNil "AIS_var_killCamDoneEhId") then {
            AIS_var_killCamDoneEhId = [missionNamespace, "KF_killCamDone", {
                if (alive player && {player getVariable ["ais_unconscious", false]}) then {
                    [player] call AIS_Effects_fnc_startUnconsciousView;
                };
            }] call BIS_fnc_addScriptedEventHandler;
        };
    };

    // countdown and visual effects
    [_unit] call AIS_System_fnc_bloodloss;

    // correkt animation if unit get pushed out of a vehicle on other ways except the pull-out action
    _unit addEventHandler ["getOutMan", {_this call AIS_System_fnc_getOutMan}];

    // disable teamSwitch while unc
    if (teamSwitchEnabled) then {
        enableTeamSwitch false;
        ais_reenable_teamswitch = true;
    };

    true
};
