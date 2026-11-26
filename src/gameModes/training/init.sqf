if (!hasInterface && {!isServer}) exitWith {call compile preprocessFileLineNumbers "ui\culling.sqf";};
call compile preprocessFileLineNumbers "ui\ui.sqf";
call compile preprocessFileLineNumbers "common\world.sqf";
call compile preprocessFileLineNumbers "TR\training.sqf";
["all"] call compile preprocessFileLineNumbers "modsIntegrated\loadMods.sqf";
call TR_fnc_init;
