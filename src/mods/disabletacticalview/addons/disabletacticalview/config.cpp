class CfgPatches {
    class disabletacticalview {
        units[] = {"moduleDisableTacticalView"};
        requiredVersion = 1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgFactionClasses {
    class NO_CATEGORY;
    class moduleDisableTacticalView: NO_CATEGORY {
        displayName = "Disable Tactical View";
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
        curatorInfoType = "RscDisplayAttributeModuleDisableTacticalView";

        class Attributes: AttributesBase {
            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module displays tactical view for all players.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class disabletacticalview {
        class main {
            file = "disabletacticalview\scripts";
        };
    };

    class DTV {
        class NO_CATEGORY {
            file = "\disabletacticalview\functions";
            class moduleDisableTacticalView {};
        };
    };
};