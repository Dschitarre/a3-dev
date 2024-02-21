if isServer then {
    call (compile preprocessFileLineNumbers "killfeed\scripts\fn_init.sqf");

    call KF_fnc_startKillfeed;
};