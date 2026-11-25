call compile preprocessFileLineNumbers "BR\functions.sqf";
["server"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call BR_fnc_initServer;
