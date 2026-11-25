// AIS system: start-up per unit, self checks, diary, key handler, reveal and small helpers.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

AIS_System_fnc_postInit = {
    if (isDedicated || !hasInterface) exitWith {};
    if (ais_ace_shutDown) exitWith {diag_log ["AIS: AIS shutdown itself cause ACE mod was detected. ACE and AIS cant work at the same time."]};
    /*
// expample action
_action = [
    "Text",                            // action text
    player,                            // object which the action is assigned
    2,                                // distance where action is shown (0 means max distance = 15m)
    "true",                            // condition to show the action
    {
        my_code                        // code perform on action
    },
    [],                                // Optional: custom variables run trough
    "<t color='#ff0000'>%1</t>"        // Optional: formated text for setUserActionText
] call AIS_Core_fnc_addAction;
*/

    [
        "Revive",
        player,
        1.5,
        "cursorTarget isKindOf 'CAManBase' && {(side (group cursorTarget)) == side (group player)} && {cursorTarget getVariable ['ais_stabilized',false]} && {cursorTarget getVariable ['ais_unconscious',false]} && {cursorTarget call AIS_System_fnc_allowRevive}",
        {
            [player, cursorTarget] spawn AIS_System_fnc_Revive;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='3.5' color='#FDEA1C' image='\a3\ui_f\data\IGUI\Cfg\HoldActions\holdAction_reviveMedic_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Stabilize",
        player,
        1.5,
        "cursorTarget isKindOf 'CAManBase' && {(side (group cursorTarget)) == side (group player)} && {!(cursorTarget getVariable ['ais_stabilized',false])} && {cursorTarget getVariable ['ais_unconscious',false]} && {cursorTarget call AIS_System_fnc_allowStabilize}",
        {
            [player, cursorTarget] spawn AIS_System_fnc_stabilize;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0ff0000' image='\a3\ui_f\data\IGUI\Cfg\Actions\bandage_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Drag",
        player,
        1.8,
        "cursorTarget isKindOf 'CAManBase' && {(side (group cursorTarget)) == side (group player)} && {cursorTarget getVariable ['ais_unconscious',false]} && {cursorTarget call AIS_System_fnc_allowDrag}",
        {
            [player, cursorTarget] call AIS_System_fnc_drag;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0bfbfbf' image='\a3\ui_f\data\IGUI\Cfg\Actions\take_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Carry",
        player,
        0,
        "!(isNull (player getVariable ['ais_DragDrop_Torso', objNull])) && {(side (group cursorTarget)) == side (group player)} && {!(player getVariable ['ais_CarryDrop_Torso', false])}",
        {
            [player] spawn AIS_System_fnc_carry;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0bfbfbf' image='\a3\ui_f\data\IGUI\Cfg\Actions\take_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Release",
        player,
        0,
        "!(isNull (player getVariable ['ais_DragDrop_Torso', objNull]))",
        {
            [player] call AIS_System_fnc_release;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0bfbfbf' image='\a3\ui_f\data\IGUI\Cfg\Actions\ico_OFF_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Unload Injured",
        player,
        4,
        "(cursorTarget isKindOf 'LandVehicle' || cursorTarget isKindOf 'Air') && {alive cursorTarget} && {cursorTarget call AIS_System_fnc_allowPullOut}",
        {
            [player, cursorTarget] call AIS_System_fnc_unloadInjured;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0bfbfbf' image='\a3\ui_f\data\IGUI\Cfg\Actions\unloadAllVehicles_ca.paa'/>"
    ] call AIS_Core_fnc_addAction;

    [
        "Load Injured",
        player,
        4,
        "!(isNull (player getVariable ['ais_DragDrop_Torso', objNull])) && {cursorTarget isKindOf 'LandVehicle' || cursorTarget isKindOf 'Air'} && {cursorTarget call AIS_System_fnc_allowPullIn}",
        {
            [player, cursorTarget] call AIS_System_fnc_loadInjured;
        },
        [],
        "<t color='#E9FDF7'>%1</t><br/><img size='2.5' color='#f0bfbfbf' image='\a3\ui_f\data\IGUI\Cfg\Actions\Obsolete\ui_action_getincargo.paa'/>"
    ] call AIS_Core_fnc_addAction;
};

/*
 * Author: Psycho
 * Check if no player is in this group. (only AI's) If it is so, the AI will call for other AI's to help him. Otherwise a AI-only group cant be revive.
 * Arguments:
    0: Injured Unit (Object)
 * Return value:
    Nothing
*/
AIS_System_fnc_AIselfCheck = {
    params ["_injured_ai"];

    // breack the self check loop if help is no longer needed or possible.
    if (!alive _injured_ai) exitWith {};
    if (!(_injured_ai getVariable ["ais_unconscious", false])) exitWith {};

    // injured is in handling. check some seconds later if handlin was interrupted.
    if (!isNull (_injured_ai getVariable ["ais_hasHelper", objNull])) then {
        private _acc_time = (diag_tickTime + 30);
        [{diag_tickTime > (_this select 1)}, {[(_this select 0)] call AIS_System_fnc_AIselfCheck}, [_injured_ai, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    };

    // searching for players in the group
    private _group_with_player = false;
    private _all_members = (units group _injured_ai) - [_injured_ai];
    if (count _all_members > 0) then {
        {if (isPlayer _x) exitWith {_group_with_player = true};true} count _all_members;
    };

    // do nothing if players in group
    if (_group_with_player) exitWith {};

    // if no player is present call for help (with a short delay)
    private _acc_time = (diag_tickTime + 4);
    [{diag_tickTime > (_this select 2)}, {_this call AIS_System_fnc_findAIHelper}, [_injured_ai, objNull, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;

    true
};

/*
 * Author: Psycho
 * Check if the unit have a launcher.
 * Arguments:
    0: Unit (Object)
 * Return value:
    BOOL (true when Launcer is present)
*/
AIS_System_fnc_checkLauncher = {
    _ret = if (secondaryWeapon _this isEqualTo "") then {false} else {true};

    _ret
};

/*
 * Author: psycho
 * Diary entry.
 * Arguments:
    -
 * Return value:
    Bool
 */
AIS_System_fnc_diary = {
    private _who_can_revive = switch (AIS_MEDICAL_EDUCATION) do {
        case (0) : {"Everyone can revive"};
        case (1) : {"Everybody with a First Aid Kit or Medkit"};
        case (2) : {"Only medics can revive"};
    };
    private _revive_guaranty = if (AIS_REVIVE_GUARANTY) then {"You are protected from insta-death"} else {"Heavy damage can end in insta-death"};
    private _revive_heal = if (AIS_REVIVE_HEAL) then {"completely healed"} else {"separately healing action needed"};

    _subject = player createDiarySubject ["ais_settings", "AIS Settings"];
    _log_briefing = player createDiaryRecord ["ais_settings", ["Medical Education", "
<font face='PuristaMedium' size=15 color='#8E8E8E'>Who can revive: </font>" + _who_can_revive]];
    _log_briefing = player createDiaryRecord ["ais_settings", ["Heavy Damage Handling", "
<font face='PuristaMedium' size=15 color='#8E8E8E'>Revive Chance: </font>" + _revive_guaranty]];
    _log_briefing = player createDiaryRecord ["ais_settings", ["Bleedout Time",
        format ["<font face='PuristaMedium' size=15 color='#8E8E8E'>Average Bleedout Time: </font>%1", AIS_BLEEDOUT_TIME]]];
    _log_briefing = player createDiaryRecord ["ais_settings", ["Healing Status", "
<font face='PuristaMedium' size=15 color='#8E8E8E'>Damage status after revive: </font>" + _revive_heal]];

    _subject = player createDiarySubject ["ais", "First Aid System"];
    _log_briefing = player createDiaryRecord ["ais", ["About and Credits", "
<font face='PuristaMedium' size=18 color='#ffffff'>Made by: </font><font face='PuristaMedium' size=25 color='#8E8E8E'>Psychobastard</font><br/>
<font face='PuristaMedium' size=18 color='#ffffff'>Version: </font><font face='PuristaMedium' size=20 color='#ffffff'>21022016</font><br/><br/>

<font face='PuristaMedium' size=30 color='#014EE3'>Credits</font><br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>BonInf*</font> for the first multiplayer compatible version (Arma 2)<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>BI</font> for the design idea (Wounding module Arma 2)<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>Alwarren</font> for his feedback and fixes<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>Lukio</font> for his text revisions and better translations<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>NetFusion</font> for the way of handling interactions<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>ACE3 Team</font> for damage handling of droping units<br/>
- <font face='PuristaMedium' size=18 color='#8E8E8E'>CBA Team</font> for some functions
"]];

    _log_briefing = player createDiaryRecord ["ais", ["Instructions", "
<font face='PuristaMedium' size=22 color='#014EE3'>If you are unconscious:</font><br/>
- <font face='PuristaMedium' size=15 color='#8E8E8E'>Press 'FORWARD'</font> to go prone and fire your current weapon.<br/><br/>
- You can <font face='PuristaMedium' size=15 color='#8E8E8E'>CRAWL</font> to a safe position.<br/><br/>
- <font face='PuristaMedium' size=15 color='#8E8E8E'>Press 'H'</font> key to call friendly AI for help.<br/><br/><br/><br/>

<font face='PuristaMedium' size=22 color='#014EE3'>How to give first aid:</font><br/>
- Move close to an unconscious unit and select <font face='PuristaMedium' size=15 color='#8E8E8E'>'Stabilize'</font> to stop heavy bleeding. This will prevent the injured unit from bleedout. (death)<br/><br/>
- Move close to an unconscious unit and select <font face='PuristaMedium' size=15 color='#8E8E8E'>'First Aid'</font> to revive the unit.<br/><br/>
- If it is needed and you want to <font face='PuristaMedium' size=15 color='#8E8E8E'>'Abbort'</font> a revive process, simply press 'ESC' Button.<br/><br/>
- Move close to an unconscious unit and select <font face='PuristaMedium' size=15 color='#8E8E8E'>'Drag'</font> to drag the body out of the line of fire (Mousewheel menu).<br/><br/>
- While you are dragging a unit, you can select <font face='PuristaMedium' size=15 color='#8E8E8E'>'Carry'</font> to carry the unit on your shoulders (better to cover long distances).<br/><br/>
- In some cases you need medical equipment (First Aid Kit or Medkit) or must be a medic to start the 'First aid' action.
"]];

    _log_briefing = player createDiaryRecord ["ais", ["About wounding / death:", "
If a unit receives too much damage, the unit goes unconscious. This means that the unit starts to bleed out and needs help from other units.<br/><br/>
If someone comes to help, he can stop the bleeding to prevent the injured from bleeding out and die. After the unit is stabilized you can start the first aid process to revive the unit. After a unit is revived maybe they need a regular healing process too.<br/><br/>
If nobody comes to help the unit eventually bleeds out. The time depends on the amount of damage the unit received. Everyone can stabilize unconscious units. The ability to start the first aid process can depend on the medical education. (medic or not, medical equipment)<br/><br/>
It is possible to load/unload wounded units in vehicles to bring them out of a dangerous area or evacuate them to a field hospital.
"]];

    _log_briefing = player createDiaryRecord ["ais", ["Description", "
<font face='PuristaMedium' size=30 color='#014EE3'>Psycho's Wounding System</font><br/><br/>
This First Aid System (AIS = Alternative Injury System) is an alternative system to all the current normal revive scripts.<br/><br/>
The main difference to a standard revive system is that the unit does not die before going into a state of agony. If critical damage level is reached, the unit goes unconscious and does not immediately die like in most other systems. The advantage: You can use it in missions without a revive option as well!<br/><br/>
Another advantage of the system is that if a unit is gravely wounded and waiting for others to help, the wounded unit is not completely defenseless. A wounded unit can go prone, crawl and use a weapon as last stand (until the magazine is empty).
AIS also supports AI. AI soldiers can be unconscious or give first aid as well.
"]];

    true
};

/*
 * Author: Psycho
 * Chck if the unit is a medic. Also units which set manually to a medic will be found. (setUnitTrait)
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing
 * Example:
    player call AIS_System_fnc_isMedic;
 */
AIS_System_fnc_isMedic = {
    _healer = _this;
    _isMedic = _healer getUnitTrait "Medic";

    _isMedic
};

/*
 * Author: Psycho
 * unbind some key functions while the player is unconcious.
    --> Block the following actions: reload, inventory, weapon change, diary and map, chat, get in/out of a vehicle, throw grenades, open curator interface, eject a vehicle
* Also it handle some special key functions.
    --> press "H" for calling help while unconscious
 * Arguments:
    1: Key (Number)
 * Return value:
    Bool
*/
AIS_System_fnc_keyHandler = {
    private _keyDown = _this select 1;
    private _return = false;

    if !(player getVariable ['ais_unconscious', false]) exitWith {false};

    if (_keyDown isEqualTo 1) then {[] spawn AIS_System_fnc_disableRespawnButton};    // key "Esc" --> disable Respawn Button

    // vehicle actions
    if (!(isNull objectParent player)) then {
        {
            if (_keyDown in (actionKeys _x)) exitWith {
                _return = true;
            };
            nil
        } count ['CarForward','CarBack','HeliCyclicForward','HeliLeft','HeliRudderLeft','HeliRight','HeliRudderRight','AutoHover','CarFastForward','CarSlowForward','submarineForward','submarineBack','SwitchWeapon'];
    };

    {
        if (_keyDown in (actionKeys _x)) exitWith {
            if (AIS_NO_CHAT && {_keyDown in (actionKeys 'Chat')}) then {
            };
            _return = true;
        };
        nil
    } count ['ReloadMagazine','Gear','SwitchWeapon','Diary','DeployWeaponAuto','Chat','Throw','ShowMap','turnIn','turnOut','curatorInterface','Eject'];

    _return
};

/*
 * Author: Psycho
 * Start to init a unit. It's a public function.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    [_unit] call AIS_System_fnc_loadAIS;
 */
AIS_System_fnc_loadAIS = {
    params ["_unit"];
    if (!isNil {_unit getVariable "ais_aisInit"}) exitWith {};

    if (isServer) then {

        if (local _unit) then {
            [_this select 0] call AIS_Core_fnc_aisInitHost;
        } else {
            _id = owner _unit;
            [_unit] remoteExecCall ["AIS_System_fnc_loadAISlocalToPlayer", _id, false];
        };

    } else {

        if (local _unit) then {
            [_unit] call AIS_System_fnc_loadAISlocalToPlayer;
        } else {
            [_unit] remoteExecCall ["AIS_Core_fnc_aisInitHost", 2];
        };

    };

    true
};

/*
 * Author: Psycho
 * Start to init a unit which is local to a player.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Nothing

* Exapmle:
    [_unit] call AIS_System_fnc_loadAISlocalToPlayer;
 */
AIS_System_fnc_loadAISlocalToPlayer = {
    params ["_unit"];
    if (_unit getVariable ["AIS_noReviveInit", false]) exitWith {};

    if (!isNil {_unit getVariable "ais_aisInit"}) then {
        [_unit] call AIS_Core_fnc_setVariables;
    };
    _unit setVariable ["ais_aisInit", true];

    _unit removeAllEventHandlers "handleDamage";
    _unit addEventHandler ["HandleDamage", {_this call AIS_Damage_fnc_handleDamage}];

    _unit addEventHandler ["Killed", {_this call AIS_System_fnc_killed}];

    if ([_unit] call AIS_Core_fnc_isPlayable) then {
        _unit addEventHandler ["Respawn", {_this call AIS_System_fnc_respawn}];
    };

    _unit addEventHandler ["HandleHeal", {_this call AIS_System_fnc_handleHeal}];

    true
};

/*
 * Author: Psycho
 * Reveal near units after revive.
 * Arguments:
    0: Revived Unit (Object)
    1: Range (Number) [optional]
 * Return value:
    Nothing
*/
AIS_System_fnc_reveal = {
    params [
        ["_unit", player, [player]],
        ["_range", 50, [50]]
    ];

    _list = _unit nearEntities ["CAManBase", _range];
    _side = _unit getVariable ["ais_side", civilian];

    {
        if ((side _x) isEqualTo _side) then {
            _unit reveal [_x, 4];
        };
        true

    } count _list;

    true
};

/*
 * Author: Joris-Jan van 't Land (based on work in fn_timeToString)
 * Changed: Psycho (snip out only the needed lines...)
 * Convert seconds to formatted string.
 * Arguments:
    _this select 0: <scalar> time in seconds
 * Return value:
    String
*/
AIS_System_fnc_secondsToString = {
    _sec = _this param [0, 0, [0]];

    _sec = _sec % 60;
    _sec = floor (_sec);
    _sec = (if (_sec <= 9) then {"0"} else {""}) + (str _sec);

    _time = format ["%1", _sec];

    _time
};
