if (!hasInterface) exitWith {call compile preprocessFileLineNumbers "ui\culling.sqf";};
call compile preprocessFileLineNumbers "SC\functions.sqf";
call SC_fnc_initCommon;
["client"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call SC_fnc_initClient;
