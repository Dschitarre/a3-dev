// AIS effects: injured markers (map and 3D), screams and calls for help, radio, medical equipment, cleanup.
// AIS revive system by Psychobastard, consolidated; loaded by the game mode (SC\init\common.sqf) after AIS\setup.sqf.

// from domination
AIS_Effects_fnc_preInit = {
    ais_help_screaming = [
        [
            "Person0",
            [
                "P0_moan_13_words.wss", "P0_moan_14_words.wss", "P0_moan_15_words.wss", "P0_moan_16_words.wss",
                "P0_moan_17_words.wss", "P0_moan_18_words.wss", "P0_moan_19_words.wss", "P0_moan_20_words.wss"
            ]
        ],
        [
            "Person1",
            [
                "P1_moan_19_words.wss", "P1_moan_20_words.wss", "P1_moan_21_words.wss", "P1_moan_22_words.wss",
                "P1_moan_23_words.wss", "P1_moan_24_words.wss", "P1_moan_25_words.wss", "P1_moan_26_words.wss",
                "P1_moan_27_words.wss", "P1_moan_28_words.wss", "P1_moan_29_words.wss", "P1_moan_30_words.wss",
                "P1_moan_31_words.wss", "P1_moan_32_words.wss", "P1_moan_33_words.wss"
            ]
        ],
        [
            "Person2",
            [
                "P2_moan_14_words.wss", "P2_moan_15_words.wss", "P2_moan_16_words.wss", "P2_moan_17_words.wss",
                "P2_moan_18_words.wss", "P2_moan_19_words.wss", "P2_moan_20_words.wss", "P2_moan_21_words.wss"
            ]
        ],
        [
            "Person3",
            [
                "P3_moan_10_words.wss", "P3_moan_11_words.wss", "P3_moan_12_words.wss", "P3_moan_13_words.wss",
                "P3_moan_14_words.wss", "P3_moan_15_words.wss", "P3_moan_16_words.wss", "P3_moan_17_words.wss",
                "P3_moan_18_words.wss", "P3_moan_19_words.wss", "P3_moan_20_words.wss"
            ]
        ]
    ];

    // every player set only onetime his personal voice set.
    ais_personal_soundset = selectRandom ais_help_screaming;
    AIS_BleedoutCameraScript = scriptNull;
    AIS_var_unconsciousHudScript = scriptNull;
};

//if (!isNull (findDisplay 12)) exitWith {};        // Map
AIS_Effects_fnc_draw3D = {
    if (isNull (findDisplay 46)) exitWith {};
    if (!isNull (findDisplay 49)) exitWith {};        // Esc Menu

    // remove the meh if client left the mission
    if (getClientStateNumber in [11,12]) exitWith {
        removeMissionEventHandler ["draw3D", AIS_Core_3DEHId];
    };

    private _targets = [];

    _recognize_distance = if (player call AIS_System_fnc_isMedic) then {35} else {20};
    _targets = player nearEntities ["CAManBase", _recognize_distance];
    if (count _targets < 1) exitWith {};

    // sizes scale like the unit icons and names of the 3D icons mod (tdicons, its settings when loaded): unit icon =
    // 1.8 / camera distance ^ 0.42 x zoom, the medic icon 1.11 times that, the text 1/20 of the unit icon; both with the
    // mod's floors
    private _camPos = positionCameraToWorld [0, 0, 0];
    private _screenPos = worldToScreen (positionCameraToWorld [0, 3, 4]);
    private _zoom = if (_screenPos isEqualTo []) then {1} else {sqrt (([0.5, 0.5] distance2D _screenPos) * (getResolution select 5) * 1.5)};
    private _iconSizeFactor = missionNamespace getVariable ["TDI_var_iconSizeFactor", 1.8];
    private _iconDistanceExponent = missionNamespace getVariable ["TDI_var_iconDistanceExponent", 0.42];
    private _minSizeFactor = missionNamespace getVariable ["TDI_var_minSizeFactor", 1.4];
    private _iconFloor = _minSizeFactor * (missionNamespace getVariable ["TDI_var_minUnitIconSize", 0.08]);
    private _textFloor = _minSizeFactor * (missionNamespace getVariable ["TDI_var_nameMinSize", 0.35]);
    private _textDivisor = missionNamespace getVariable ["TDI_var_nameSizeDivisor", 20];

    {
        private _target = effectiveCommander _x;

        if (
            _target getVariable ["ais_unconscious", false] &&
            {_target != player} &&
            //{isPlayer _target} &&
            {!(_x in allUnitsUAV)} &&
            {alive player} &&
            {AIS_Core_realSide isEqualTo (getNumber (configFile >> "CfgVehicles" >> (typeOf _target) >> "side"))}
        ) then {
            _headPosition = _target modelToWorldVisual (_target selectionPosition "spine");
            _alpha = 0.8;
            //_color = [0.94,1,0,_alpha];//Yellow
            //_color = [0.65,0.15,0,_alpha];//Dark Red
            _color = [0.87,0.03,0,_alpha];//shiny Red
            _text = format ["%1 (%2m)", name _target, ceil (player distance _target)];

            _icon =    if (_target getVariable ["ais_stabilized", false]) then {
                "\a3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa"
            } else {
                "\a3\ui_f\data\IGUI\Cfg\Actions\bandage_ca.paa"
            };

            private _iconPos = _headPosition vectorAdd [0, 0, 0.4];
            private _unitIconSize = _iconSizeFactor / (((_camPos distance _iconPos) max 0.1) ^ _iconDistanceExponent) * _zoom;
            private _size = 1.11 * (_unitIconSize max _iconFloor);
            private _textSize = (_unitIconSize max _textFloor) / _textDivisor;

            drawIcon3D [_icon, _color, _iconPos, _size, _size, 0, _text, 1, _textSize, "PuristaMedium", "center", true];
        };

        true
    } count _targets;
};

/*
 * Author: Alwarren
 * Remove ambient medical equimpment from the ground. If euqipment is marked as "do not delete", the loop will set it to delete list for the next time the function is called.
 * Arguments:
    -
 * Example:
    [player] call AIS_Effects_fnc_garbage;
 * Return value:
    -
*/
AIS_Effects_fnc_garbage = {
    if (!local player) exitWith {};
    private _delete = false;

    if (count ais_medequip_array > 0) then {
        {
            if (count _x > 1) then {
                if ((_x select 0) > 0) then {
                    deleteVehicle (_x select 1);
                    ais_medequip_array set [_forEachIndex, objNull];
                } else {
                    _x set [0,1];
                };
            } else {
                ais_medequip_array set [_forEachIndex, objNull];
                _delete = true;
            };
        } forEach ais_medequip_array;
    };

    ais_medequip_array = ais_medequip_array - [objNull];

    true
};

/*
 * Author: Psycho
 * Play a random screaming sound when a unit go unconcsious
 * Arguments:
    0: Unit (Object)
    1: audible distance (optional)
 * Return value:
    -

* Exapmle:
    [player, 30] call AIS_Effects_fnc_helpScream;
*/
AIS_Effects_fnc_helpScream = {
    params [
        ["_injured", objNull],
        ["_dist", 50, [0]]
    ];

    // playSound is global
    _helpsound = format ["a3\sounds_f\characters\human-sfx\%1\%2", ais_personal_soundset select 0, selectRandom (ais_personal_soundset select 1)];
    playSound3D [_helpsound, _injured, false, getPosASL _injured, 1.5, 1, _dist];

    true
};

/*
 * Author: Psycho
 * Create a local marker for unconcious units
 * Arguments:
    0: Unit (Object)
 * Return value:
    the marker itself

* Exapmle:
    player call AIS_Effects_fnc_injuredMarker
 */
AIS_Effects_fnc_injuredMarker = {
    private _unit = _this;
    private _mark = "";

    _str = name _unit;
    _marker = format ["%1_ais_marker", _str];

    if (!isNil {_unit getVariable ["ais_unitMarker", nil]}) then {
        _unit call AIS_Effects_fnc_removeInjuredMarker;
    };

    _mark = [_marker, position _unit, "ICON", "Color1_FD_F", [0.7, 0.7], format ["%1 down", _str], 0, "loc_Hospital"] call AIS_Core_fnc_createLocalMarker;
    _unit setVariable ["ais_unitMarker", _marker];

    _acc_time = diag_tickTime + 5;
    [{diag_tickTime >(_this select 1)}, {[_this select 0] call AIS_Effects_fnc_posUpdateInjuredMarker},
        [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;

    _mark
};

/*
 * Author: Alwarren
 * Spawn randomized some ambient medical equipment around the injured.
 * Arguments:
    0: Unit Helper (Object)
    1: Unit wounded (Object)
 * Example:
    [player] call AIS_Effects_fnc_medEquip;
 * Return value:
    -
*/
AIS_Effects_fnc_medEquip = {
    params [
        "_healer",
        "_injured"
    ];
    if (!local _healer) exitWith {};

    // spawn defi and a bloodbag
    if (_healer call AIS_System_fnc_isMedic) then {
        _defi_pos = _healer modelToWorld [-0.5,0.2,0];
        _defi = "Land_Defibrillator_F" createVehicle _defi_pos;
        [_defi, [_defi_pos select 0, _defi_pos select 1, 0]] call AIS_Core_fnc_setPosAGLS;
        _defi setDir (getDir _healer - 180);
        ais_medequip_array pushBack [1,_defi];

        if (damage _injured >= 0.5 && {(random 2) >= 1}) then {
            _bb_pos = _healer modelToWorld [0.4,(0.2 - (random 0.5)),0];
            _bb = "Land_BloodBag_F" createVehicle _bb_pos;
            [_bb, [_bb_pos select 0, _bb_pos select 1, 0]] call AIS_Core_fnc_setPosAGLS;
            _bb setDir (random 359);
            ais_medequip_array pushBack [0,_bb];
        };
    };

    // spawn bandages
    for "_i" from 1 to (1 + (round random 3)) do {
        _band_pos = _healer modelToWorld [(random 1.3),(0.8 + (random 0.6)),0];
        _band = "Land_Bandage_F" createVehicle _band_pos;
        [_band, [_band_pos select 0, _band_pos select 1, 0]] call AIS_Core_fnc_setPosAGLS;
        _band setDir (random 359);
        if (_i > 1) then {
            ais_medequip_array pushBack [0,_band];
        } else {
            ais_medequip_array pushBack [1,_band];
        };
    };

    // spawn antibioticum
    if (random 2 >= 1) then {
        _ab_pos = _healer modelToWorld [-0.8,(0.6 - (random 0.4)),0];
        _ab = "Land_Antibiotic_F" createVehicle _ab_pos;
        [_ab, [_ab_pos select 0, _ab_pos select 1, 0]] call AIS_Core_fnc_setPosAGLS;
        _ab setDir (random 359);
        ais_medequip_array pushBack [0,_ab];
    };

    true
};

/*
 * Author: Psycho
 * Delete a local unconcsious marker
 * Arguments:
    0: Unit (Object)
 * Return value:
    -

* Exapmle:
    player call AIS_Effects_fnc_removeInjuredMarker;
 */
AIS_Effects_fnc_removeInjuredMarker = {
    private _unit = _this;
    private _marker = _unit getVariable ["ais_unitMarker", nil];

    if (!isNil "_marker") then {
        deleteMarkerLocal _marker;
        _unit setVariable ["ais_unitMarker", nil];
    };

    true
};

/*
 * Author: Psycho
 * Play a random screaming sound when a unit go unconcsious
 * Arguments:
    0: Unit (Object)
    1: audible distance (optional)
 * Return value:
    -

* Exapmle:
    [player, 30] call AIS_Effects_fnc_Scream;
*/
AIS_Effects_fnc_scream = {
    params [
        ["_injured", objNull],
        ["_dist", 50, [0]]
    ];

    // playSound is global
    if (random 3 > 1.7) then {
        _deathsound = format ["A3\sounds_f\characters\human-sfx\P0%1\Hit_Max_%2.wss", selectRandom [4,5,6,7,8,9], selectRandom [1,2,3,4,5]];
        playSound3D [_deathsound, _injured, false, getPosASL _injured, 1.5, 1, _dist];
    };

    true
};

/*
 * Author: Psycho
 * Visual bleeding effects and counter for revive time. Will self-run in a loop till unit get revived/stabilized or died.
 * Arguments:
    0: Unit (Object)
    1: Revive Time (Number)
 * Return value:
    -
*/
AIS_Effects_fnc_stabil = {
    params ["_unit"];

    // breack out if unit died or revived
    if (!alive _unit || {!(_unit getVariable ["ais_unconscious", false])}) exitWith {};

    // breack out if unit get new damage (no longer stabilized)
    if (!(_unit getVariable ["ais_stabilized", false])) exitWith {
        _unit setBleedingRemaining 10;

        // Function use disableSerialisation and can corrupt some other functions in the same frame. So it need a delay till next frame.

        // get the revive time
        _revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
        _unit setBleedingRemaining _revive_time;

        // loop
        private _acc_time = diag_tickTime + 1;
        [{diag_tickTime >=(_this select 2)}, {_this call AIS_Effects_fnc_bleeding},
            [_unit, _revive_time, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
    };

    // stabilized before the unconscious view started (e.g. during the kill cam)
    [_unit] call AIS_Effects_fnc_startUnconsciousView;

    // loop
    private _acc_time = diag_tickTime + 1.5;
    [{diag_tickTime >= (_this select 1)}, {_this call AIS_Effects_fnc_stabil}, [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
};

/*
 * Author: Psycho
 * Enable/disable the TFAR and/or ACRE radios when player is unconscious.
 * Arguments:
    0: Unit (Object)
 * Return value:
    Bool
 */
AIS_Effects_fnc_toggleRadio = {
    _canUse = param [0, true, [true]];

    if (_canUse) then {
        player setVariable ["tf_globalVolume", 1];
        player setVariable ["tf_voiceVolume", 1];
        player setVariable ["tf_unable_to_use_radio", false];

        player setVariable ["acre_sys_core_isDisabled", false, true];
        player setVariable ["acre_sys_core_globalVolume", 1];

    } else {

        player setVariable ["tf_globalVolume", 0.4];
        player setVariable ["tf_voiceVolume", 0];
        player setVariable ["tf_unable_to_use_radio", true];

        player setVariable ["acre_sys_core_isDisabled", true, true];
        player setVariable ["acre_sys_core_globalVolume", 0];
    };

    true
};

/*
 * Author: Psycho
 * Update the marker position every 5 seconds until the marker is deleted.
 * Arguments:
    0: Unit (Object)
    1: Marker (String)
 * Return value:
    -

* Exapmle:
    -
 */
AIS_Effects_fnc_posUpdateInjuredMarker = {
    params ["_unit"];
    _marker = _unit getVariable ["ais_unitMarker", nil];

    if (!isNil "_marker") then {
        if (_unit getVariable ["ais_unconscious", false]) then {
            _marker setMarkerPosLocal (getPosATL _unit);

            _acc_time = diag_tickTime + 5;
            [{diag_tickTime >(_this select 1)},
                {[_this select 0] call AIS_Effects_fnc_posUpdateInjuredMarker},
                [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
        };

        if (!alive _unit || {isNull _unit}) then {
            _unit call AIS_Effects_fnc_removeInjuredMarker;
        };
    };

    true
};
