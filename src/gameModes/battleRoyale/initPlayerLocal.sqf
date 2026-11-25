if (!hasInterface) exitWith {call compile preprocessFileLineNumbers "ui\culling.sqf";};
call compile preprocessFileLineNumbers "BR\functions.sqf";
["client"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call BR_fnc_initClient;
