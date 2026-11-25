class CfgPatches {
    class holster {
        units[] = {"moduleHolster"};
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

    class moduleHolster: Module_F {
        scope = 2;
        displayName = "Holster";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "H_fnc_moduleHolster";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module adds a holster action (H-Key) to all players.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class H {
        class NO_CATEGORY {
            file = "\holster";
            class moduleHolster {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class holster {
        init = "[false] call compile preprocessFileLineNumbers 'holster\scripts\cbaSettings.sqf'";
    };
};
