if (!hasInterface) exitWith {call compile preprocessFileLineNumbers "ui\culling.sqf";};
call compile preprocessFileLineNumbers "GG\functions.sqf";
["client"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call GG_fnc_initClient;
