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