if (!hasInterface) exitWith {call compile preprocessFileLineNumbers "ui\culling.sqf";};
call compile preprocessFileLineNumbers "TDM\functions.sqf";
["client"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call DM_fnc_initClient;
