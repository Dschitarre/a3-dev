class Extended_PreInit_EventHandlers {
    class Dschitarre_IntegratedMods {
        init = "call compile preprocessFileLineNumbers 'modsIntegrated\registerSettings.sqf'";
    };
};

// CBA's event handlers are initialized during preInit. Attach after preInit, before CBA sends
// CBA_settingsInitialized on the next frame.
class Extended_PostInit_EventHandlers {
    class Dschitarre_IntegratedMods {
        serverInit = "['CBA_settingsInitialized', {MODS_var_settingsReady = true}] call CBA_fnc_addEventHandler";
    };
};
