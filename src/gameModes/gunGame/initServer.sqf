call compile preprocessFileLineNumbers "GG\functions.sqf";
["server"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call GG_fnc_initServer;
