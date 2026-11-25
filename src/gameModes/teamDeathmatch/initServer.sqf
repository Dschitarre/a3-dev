call compile preprocessFileLineNumbers "TDM\functions.sqf";
["server"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call DM_fnc_initServer;
