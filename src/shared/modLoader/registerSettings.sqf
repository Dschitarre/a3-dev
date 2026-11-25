// This hook runs when CBA is loaded. Mission starts without CBA keep their built-in defaults.
MODS_var_settingsReady = false;

{
    private _path = format ["modsIntegrated\%1\scripts\cbaSettings.sqf", _x];

    if (fileExists _path) then {
        [true] call compile preprocessFileLineNumbers _path;
    };
} forEach (call compile preprocessFileLineNumbers "modsIntegrated\modList.sqf");
