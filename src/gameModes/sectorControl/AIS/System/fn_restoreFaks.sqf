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

params ["_unit"];
_unit setUnitLoadout (_unit getVariable "AIS_MedicalStore");
_unit setVariable ["AIS_MedicalStore", [], true];


true