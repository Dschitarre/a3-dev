class CfgPatches {
    class disabletacticalview {
        units[] = {"moduleDisableTacticalView"};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class ModuleDescription;
        };

        class ModuleDescription;
    };

    class moduleDisableTacticalView: Module_F {
        scope = 2;
        displayName = "Disable Tactical View";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "DTV_fnc_moduleDisableTacticalView";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module disables the tactical view for all players.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class DTV {
        class NO_CATEGORY {
            file = "\disabletacticalview";
            class moduleDisableTacticalView {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class disabletacticalview {
        init = "[false] call compile preprocessFileLineNumbers 'disabletacticalview\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class disabletacticalview {
        serverInit = "if (!isNil 'DTV_fnc_startCbaAddon') then {['CBA_settingsInitialized', DTV_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
