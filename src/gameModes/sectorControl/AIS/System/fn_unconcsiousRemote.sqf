/*
 * Author: Psycho
 
 * Broadcast everything across the network which is needed if a unit fall in agony
 
 * Arguments:
    0: Unit (Object)
    1: Unconcsious state of the Unit (Bool)
 
 * Return value:
    Nothing
 */

params [
    ["_unit", objNull, [player]],
    ["_is_unoncsious", false, [false]]
];

if (isNull _unit) exitWith {diag_log format ["Non existing unit or wrong data type passed. AIS_System_fnc_unconcsiousRemote.sqf"];};


if (_is_unoncsious) then {
    [_unit, "agonyStart"] remoteExec ["playActionNow", 0, false];
    //_unit playActionNow "agonyStart";

    if (local _unit) then {
        [_unit] spawn {
            params ["_unit"];

            waitUntil {
                [_unit] call AIS_System_fnc_callHelp;
                sleep 4;
                
                if ((animationState _unit) != "ainjppnemstpsnonwnondnon") then {
                    _unit switchmove "ainjppnemstpsnonwnondnon";
                };

                (!(alive _unit) || {!(_unit getVariable ["AIS_unconscious", false])})
            };
        };
    };
} else {

    [_unit, "agonyStop"] remoteExec ["playActionNow", 0, false];
    //_unit playActionNow "agonyStop";
    
    [_unit, 50] call AIS_system_fnc_reveal;
};


true