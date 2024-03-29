﻿/*
 * Author: Psycho
 
 * Visual bleeding effects and counter for revive time. Will self-run in a loop till unit get revived/stabilized or died.
 
 * Arguments:
    0: Unit (Object)
    1: Revive Time (Number)
 
 * Return value:
    -
*/

params ["_unit"];

// breack out if unit died or revived
if (!alive _unit || {!(_unit getVariable ["ais_unconscious", false])}) exitWith {};

// breack out if unit get new damage (no longer stabilized)
if (!(_unit getVariable ["ais_stabilized", false])) exitWith {
    _unit setBleedingRemaining 10;
    
    // Function use disableSerialisation and can corrupt some other functions in the same frame. So it need a delay till next frame.
    // [{call AIS_Effects_fnc_bloodSplatterScreen}] call AIS_Core_fnc_onNextFrame;
    
    // get the revive time
    _revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
    _unit setBleedingRemaining _revive_time;
    
    // loop
    private _acc_time = diag_tickTime + 1;
    [{diag_tickTime >= (_this select 2)}, {_this call AIS_Effects_fnc_bleeding}, [_unit, _revive_time, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
};

// loop
private _acc_time = diag_tickTime + 1.5;
[{diag_tickTime >= (_this select 1)}, {_this call AIS_Effects_fnc_stabil}, [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;