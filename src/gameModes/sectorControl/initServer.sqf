call compile preprocessFileLineNumbers "SC\functions.sqf";
call SC_fnc_initCommon;
["server"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call SC_fnc_initServer;
