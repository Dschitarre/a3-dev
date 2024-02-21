/*
 * Author: Psycho
 
 * Impact effect on bullet hit.
 
 * Arguments:
    0: Unit (Object)
    1: Strength (Number)
    
 * Example:
    [player, 0.5] call AIS_Effects_fnc_bulletImpact;
 
 * Return value:
    -
*/

params ["_unit", "_strength"];

if (!local player) exitWith {};
if (_unit getVariable "ais_unconscious") exitWith {};


true