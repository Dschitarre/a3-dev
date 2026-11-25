// AIS core: initialization of the system and of every unit, variables, team switch and disconnect handling.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

AIS_Core_fnc_preInit = {
    diag_log format ["############## %1 ############## - AIS init started", missionName];

    if (isServer) then {
        ais_ace_shutDown = false;
        if (isClass (configFile >> "CfgPatches" >> "ace_medical")) then {
            ais_ace_shutDown = true;
            ["AIS: AIS shutdown itself cause ACE medical system is also running. ACE medical and AIS cant work at the same time."] call BIS_fnc_logFormat;
        };
        publicVariable "ais_ace_shutDown";
    };

    if (!isNil "AIS_Core_3DEHId") then {
        removeMissionEventHandler ["Draw3D", AIS_Core_3DEHId];
    };

    if (!isNil "AIS_Core_eachFrameHandlerId") then {
        removeMissionEventHandler ["EachFrame", AIS_Core_eachFrameHandlerId];
    };

    call AIS_Core_fnc_initEvents;
    AIS_Core_Interaction_Actions = [];
};

AIS_Core_fnc_postInit = {
    if (ais_ace_shutDown) exitWith {["AIS: AIS shutdown itself cause ACE mod was detected. ACE and AIS cant work at the same time."] call BIS_fnc_logFormat};

    if (isServer) then {
        private _allPlayers = allUnits select {isPlayer _x};
            // doesn't use allPlayers at this point, cause it can be delayed in self-hosted env.

        private _ais_revive_units = toLower AIS_REVIVE_INIT_UNITS;
        private _init_units = call {
            if (_ais_revive_units isEqualTo "allunits") exitWith {allUnits};
            if(_ais_revive_units isEqualTo "allplayers") exitWith {_allPlayers};
                // at this point only as a dummy. Cause everytime every player will auto-init, regardless what the setup will say.
            if (_ais_revive_units isEqualTo "allplayables") exitWith {if (isMultiplayer) then {playableUnits} else {switchableUnits}};
            if (_ais_revive_units isEqualTo "allunitsblufor") exitWith {allUnits select {(side _x) isEqualTo blufor}};
            if (_ais_revive_units isEqualTo "allunitsopfor") exitWith {allUnits select {(side _x) isEqualTo opfor}};
            if (_ais_revive_units isEqualTo "allunitsindfor") exitWith {allUnits select {(side _x) isEqualTo resistance}};
            if (_ais_revive_units isEqualTo "allunitscivilian") exitWith {allUnits select {(side _x) isEqualTo civilian}};
            diag_log "AIS ERROR: Issue in Setup-File found! Parameter AIS_REVIVE_UNITS wrong defined."; []
        };

        // run the init for all units present by game/mission start
        _init_units = _init_units - _allPlayers;
        if (count _init_units > 0) then {
            {
                [_x] call AIS_Core_fnc_aisInitHost;
                true
            } count _init_units;
        };

        addMissionEventHandler ["HandleDisconnect", {_this call AIS_Core_fnc_handleDisconnect}];
    };

    if (isNil "AIS_MEDEVAC_STATIONS") then {
        AIS_MEDEVAC_STATIONS = [];
    } else {
        if !(AIS_MEDEVAC_STATIONS isEqualType []) then {
            AIS_MEDEVAC_STATIONS = [];
            ["AIS: AIS_MEDEVAC_STATIONS wasnt defined in the correct way."] call BIS_fnc_logFormat;
        };
    };

    if (isDedicated || !hasInterface) exitWith {};

    // This is needed to provide a player object for zeus controlled units. Important to ensure that player is not null here (which is done in autoload).
    AIS_Core_realPlayer = player;
    AIS_Core_realPlayer call AIS_Core_fnc_aisInitPlayer;
    AIS_Core_realSide = getNumber (configFile >> "CfgVehicles" >> (typeOf AIS_Core_realPlayer) >> "side");

    [{
        // There is no command to get the current player but BI has an variable in mission namespace we can use.
        private _currentPlayer = missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", player];    // Psycho: isNull until a unit is remote controlled

        // If the player changed we trigger an event and update the global variable.
        if (AIS_Core_realPlayer != _currentPlayer) then {
            removeAllActions AIS_Core_realPlayer;
            AIS_Core_realPlayer enableAI "TEAMSWITCH";

            ["AIS_playerChanged", [_currentPlayer, AIS_Core_realPlayer]] call AIS_Core_fnc_triggerEvent;

            AIS_Core_realPlayer = _currentPlayer;
            AIS_Core_realSide = getNumber (configFile >> "CfgVehicles" >> (typeOf AIS_Core_realPlayer) >> "side");
        };
    }] call AIS_Core_fnc_onEachFrame;

    true call AIS_Core_fnc_interaction_loop;

    if (AIS_SHOW_DIARYINFO) then {
        call AIS_System_fnc_diary;
    };

    if (AIS_SHOW_UNC_3D_MARKERS) then {
        true spawn {
            waitUntil {time > 0};
            AIS_Core_3DEHId = addMissionEventHandler ["Draw3D", {_this call AIS_Effects_fnc_draw3D}];
        };
    };
};

// this script run on the server/host for every unit which should be added to the revive system. It run's once by starting the mission.
AIS_Core_fnc_aisInitHost = {
    params ["_unit"];
    if (_unit getVariable ["AIS_noReviveInit", false]) exitWith {};

    if (!isNil {_unit getVariable "ais_aisInit"}) then {
        _unit removeAllEventHandlers "Killed";
        _unit removeAllEventHandlers "Respawn";
        _unit removeAllEventHandlers "HandleHeal";
        [_unit] call AIS_Core_fnc_setVariables;
    };
    _unit setVariable ["ais_aisInit", true];

    // set damage EH only for local and non-player units!
    // last check if unit is local
    if (local _unit && !(isPlayer _unit)) then {
        [_unit] spawn {
            params ["_unit"];

            waitUntil {!isNil {_unit getVariable "BIS_fnc_feedback_hitArrayHandler"} || {time > 0}};
            _unit removeAllEventHandlers "handleDamage";
            ["%1 --- add damageEH to AI %2", diag_tickTime, _unit] call BIS_fnc_logFormat;
            ais_hdEH = _unit addEventHandler ["HandleDamage", {_this call AIS_Damage_fnc_handleDamage}];

            ais_hkEH = _unit addEventHandler ["Killed", {_this call AIS_System_fnc_killed}];

            if ([_unit] call AIS_Core_fnc_isPlayable) then {
                ais_hrEH = _unit addEventHandler ["Respawn", {_this call AIS_System_fnc_respawn}];
            };
            _unit removeAllEventHandlers "HandleHeal";
            ais_hhEH = _unit addEventHandler ["HandleHeal", {_this call AIS_System_fnc_handleHeal}];
        };
    };
};

// this script run only by the player!
AIS_Core_fnc_aisInitPlayer = {
    private _player = _this;
    if (_player != player) exitWith {["%1 --- exit aisInitPlayer cause it's not the local player itself %2", diag_tickTime, _player] call BIS_fnc_logFormat};
    if (isClass (configFile >> "CfgPatches" >> "ace_medical")) exitWith {["AIS: AIS shutdown itself cause ACE medical system is also running. ACE medical and AIS cant work at the same time."] call BIS_fnc_logFormat};

    if (_player getVariable ["AIS_noReviveInit", false]) exitWith {};

    // set damage EH local to the player
    if (local _player) then {
        [_player] call AIS_Core_fnc_setVariables;

        [_player] spawn {
            params ["_player"];
            waitUntil {!isNil {_player getVariable "BIS_fnc_feedback_hitArrayHandler"} || {time > 0}};
            _player removeAllEventHandlers "handleDamage";    // make sure nothing else working byside
            _player addEventHandler ["HandleDamage", {_this call AIS_Damage_fnc_handleDamage}];

            _player addEventHandler ["Killed", {_this call AIS_System_fnc_killed}];

            _player addEventHandler ["Respawn", {_this call AIS_System_fnc_respawn}];

            _player addEventHandler ["HandleHeal", {_this call AIS_System_fnc_handleHeal}];

        };
    };

    // AI is local to the group leader on dedicated environment
    if (!isServer && (count (units group player) > 1)) then {
        if (leader group _player isEqualTo _player) then {

            [_player] spawn {
                params ["_player"];
                _groupWithoutPlayers = ((units group _player) - (allUnits select {isPlayer _x}));
                {[_x] call AIS_Core_fnc_setVariables; true} count _groupWithoutPlayers;

                waitUntil {!isNil {_player getVariable "BIS_fnc_feedback_hitArrayHandler"} || {time > 0}};
                {
                    _x removeAllEventHandlers "handleDamage";
                    _x addEventHandler ["HandleDamage", {_this call AIS_Damage_fnc_handleDamage}];

                    _x addEventHandler ["Killed", {_this call AIS_System_fnc_killed}];

                    if ([_x] call AIS_Core_fnc_isPlayable) then {
                        _x addEventHandler ["Respawn", {_this call AIS_System_fnc_respawn}];
                    };

                    _x addEventHandler ["HandleHeal", {_this call AIS_System_fnc_handleHeal}];

                    true
                } count _groupWithoutPlayers;
            };

        };
    };

    // add handleHeal local to the player for every unit and set the correct anim-state (local)
    private _allPlayers = allUnits select {isPlayer _x};
        // doesn't use allPlayers at this point, cause it can be delayed in self-hosted env.
    private _ais_revive_units = toLower AIS_REVIVE_INIT_UNITS;
    private _init_units = call {
        if (_ais_revive_units isEqualTo "allunits") exitWith {allUnits};
        if(_ais_revive_units isEqualTo "allplayers") exitWith {_allPlayers};
            // at this point only as a dummy. Cause everytime every player will auto-init, regardless what the setup will say.
        if (_ais_revive_units isEqualTo "allplayables") exitWith {if (isMultiplayer) then {playableUnits} else {switchableUnits}};
        if (_ais_revive_units isEqualTo "allunitsblufor") exitWith {allUnits select {(side _x) isEqualTo blufor}};
        if (_ais_revive_units isEqualTo "allunitsopfor") exitWith {allUnits select {(side _x) isEqualTo opfor}};
        if (_ais_revive_units isEqualTo "allunitsindfor") exitWith {allUnits select {(side _x) isEqualTo resistance}};
        if (_ais_revive_units isEqualTo "allunitscivilian") exitWith {allUnits select {(side _x) isEqualTo civilian}};
        diag_log "AIS ERROR: Issue in Setup-File found! Parameter AIS_REVIVE_UNITS wrong defined."; []
    };
    {
        _x addEventHandler ["HandleHeal", {_this call AIS_System_fnc_handleHeal}];

        if (_x getVariable ["ais_unconscious", false]) then {
            if (!isNull(_x getVariable ["ais_DragDrop_Player", objNull])) then {
                _x switchMove "AinjPpneMrunSnonWnonDb";
            } else {
                _x playActionNow "agonyStart";
            };
        };

        true
    } count _init_units;

    ais_medequip_array = [];
    if (AIS_TOGGLE_RADIO) then {
        [true] call AIS_Effects_fnc_toggleRadio;
    };

    // JIP in a unconscious AI... and avoid cheating by left in lobby...
    if (_player getVariable ["ais_unconscious", false]) then {
        [{[(_this select 0)] call AIS_System_fnc_setUnconscious}, [_player]] call AIS_Core_fnc_onNextFrame;
    };

    inGameUISetEventHandler ["Action", "_this call AIS_System_fnc_overrideHealAction"];

    _respawnDelay = getMissionConfigValue ["respawnDelay", 0];
};

// ["my marker",  position player, "ICON", "ColorRed", [0.5,0.5]] call AIS_Core_fnc_createLocalMarker;
AIS_Core_fnc_createLocalMarker = {
    params [
        ["_name","",[""]],
        ["_pos",[0,0],[[]]],
        ["_shape","ICON",[""]],
        ["_color","Default",[""]],
        ["_size",[1,1],[[]]],
        ["_text","",[""]],
        ["_dir",0,[0]],
        ["_type","mil_dot",[""]],
        ["_brush","",[""]]
    ];

    private _marker = createMarkerLocal [_name, _pos];

    _marker setMarkerShapeLocal _shape;
    _marker setMarkerColorLocal _color;
    _marker setMarkerSizeLocal _size;
    _marker setMarkerTextLocal _text;
    _marker setMarkerDirLocal _dir;
    _marker setMarkerTypeLocal _type;
    if (_brush != "") then {_marker setMarkerBrushLocal _brush};

    _marker
};

/*
 * Author: Psycho
 * Check if a unit is a playable unit.
 * Arguments:
    0: Unit (Object)
 * Return value:
    BOOL (true if playable)
*/
AIS_Core_fnc_isPlayable = {
    params ["_unit"];
    private _isplayable = false;
    if (isPlayer _unit) exitWith {true};

    _isplayable = if (isMultiplayer) then {
        if (_unit in playableUnits) then {true} else {false};
    } else {
        if (_unit in switchableUnits) then {true} else {false};
    };

    _isplayable
};

    // from Killzone Kid

    /*
    //---This will place player exactly on top deck of Cargo HQ on Stratis:
        [player, [2437.18,5693.47,0]] call AIS_Core_fnc_setPosAGLS;

    //---This will place player 2m above top deck of Cargo HQ on Stratis:
        [player, [2437.18,5693.47,2]] call AIS_Core_fnc_setPosAGLS;

    //---This will place player 2m below top deck of Cargo HQ on Stratis:
        [player, [2437.18,5693.47,-2]] call AIS_Core_fnc_setPosAGLS;
*/
AIS_Core_fnc_setPosAGLS = {
    params ["_obj", "_pos", "_offset"];

    _offset = _pos select 2;
    if (isNil "_offset") then {_offset = 0};
    _pos set [2, worldSize];
    _obj setPosASL _pos;
    _pos set [2, vectorMagnitude (_pos vectorDiff getPosVisual _obj) + _offset];

    _obj setPosASL _pos;
};

/*
 * Author: Psycho
 * Set all needed vars to the unit.
 * Arguments:
    0: Healer Unit (Object)
 * Return value:
    Nothing
*/
AIS_Core_fnc_setVariables = {
    params ["_unit"];

    // local
    _unit setVariable ["ais_fireDamage", 0];
    _unit setVariable ["ais_frameNo_damageCaching", diag_frameNo];
    _unit setVariable ["AIS_UnitIsDead", false];
    _unit setVariable ["ais_CarryDrop_Torso", false];
    ais_reenable_teamswitch = false;

    // global (players and AI's)
    // set Vars only if it is Nil. Isnt't everytime Nil(f.e. JIP's use AI to join in - get the last state from this AI)
    if (isNil {_unit getVariable "ais_unconscious"}) then {
        _unit setVariable ["ais_unconscious", false, true];
        _unit setVariable ["ais_unconscious_since", -999, true];
        _unit setVariable ["ais_stabilized", false, true];
        _unit setVariable ["ais_hasHelper", objNull, true];
        _unit setVariable ["ais_DragDrop_Player", objNull, true];
        _unit setVariable ["ais_DragDrop_Torso", objNull];// local is enough?
        _unit setVariable ["AIS_MedicalStore", [], true];
        _unit setVariable ["ais_man_pullOut", false, true];
    };

    true
};

/*
 * Author: Psycho
 * Server side handling of disconnected players. The disconnected entity get transfered to the server and re-init the AIS.
 * Arguments:
    0: Entity (Object, old player)
 * Return value:
    -
 * Attention!
 Override : If this EH code returns true, the unit, previously occupied by player, gets transferred to the server,
     becomes AI and continues to live, even with description . ext param disabledAI = 1;
*/
AIS_Core_fnc_handleDisconnect = {
    params ["_entity"];

    // delete unit if mission designer have set disabledAI param set to 1
    _deleteEntity = false;
    _deleteEntity = if ((getMissionConfigValue "disabledAI") isEqualType 0) then {
        _back = if ((getMissionConfigValue ["disabledAI", 0]) != 0) then {true} else {false};_back
    } else {
        _back = if ((toUpper((getMissionConfigValue ["disabledAI", "false"]))) isEqualTo "TRUE") then {true} else {false};_back
    };

    if (_deleteEntity) exitWith {
        if (local _entity) then {
            if (!isNull objectParent _entity) then {
                unassignVehicle _entity;
                moveOut _entity;
            };
            deleteVehicle _entity;
        };
        false
    };

    // othrwise re-init the unit on the new owner (server)
    if (!isNil {_entity getVariable "ais_unconscious"}) then {
        _entity call AIS_Core_fnc_aisInitHost;
    };

    true
};

/*
 * Author: Psycho
 * Handle unit state after a teamswtich was performed.
 * Arguments:
    0: Player New (Object)
    1: Unit Old (Object)
 * Return value:
    -
*/
AIS_Core_fnc_resetOnTeamSwitch = {
    params ["_new_player", "_old_player"];

    removeAllActions _old_player;
    _old_player enableAI "TEAMSWITCH";

    AIS_Core_realSide = getNumber (configFile >> "CfgVehicles" >> (typeOf _new_player) >> "side");

    if (_old_player getVariable ["ais_unconscious", false]) then {
        ais_character_changed = true;    // reset blood splatter screen
    };

    if (_new_player getVariable ["ais_unconscious", false]) then {
        [_new_player] call AIS_System_fnc_bloodloss;
    };

    true
};
