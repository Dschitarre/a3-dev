class CfgPatches {
    class holster {
        units[] = {"moduleHolster"};
        requiredVersion = 1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgFactionClasses {
    class NO_CATEGORY;
    class moduleHolster: NO_CATEGORY {
        displayName = "Holster";
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class Default;
            class Edit;
            class Combo;
            class Checkbox;
            class CheckboxNumber;
            class ModuleDescription;
        };

        class ModuleDescription {
            class AnyBrain;
        };
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
        curatorInfoType = "RscDisplayAttributeModuleHolster";

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
    class holster {
        class main {
            file = "holster\scripts";
        };
    };

    class H {
        class NO_CATEGORY {
            file = "\holster\functions";
            class moduleHolster {};
        };
    };
};