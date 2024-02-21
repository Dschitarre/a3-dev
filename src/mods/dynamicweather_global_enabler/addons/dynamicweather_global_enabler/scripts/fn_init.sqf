if isServer then {
    call (compile preprocessFileLineNumbers "dynamicweather\scripts\fn_init.sqf");

    DW_var_skipNight = false;

    [false] call DW_fnc_startDynamicWeather;
};