class CfgPatches {
    class jump {
        units[] = {"moduleJump"};
        requiredVersion = 1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgFactionClasses {
    class NO_CATEGORY;
    class moduleJump: NO_CATEGORY {
        displayName = "Jump";
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

    class moduleJump: Module_F {
        scope = 2;
        displayName = "Jump";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "J_fnc_moduleJump";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;
        curatorInfoType = "RscDisplayAttributeModuleJump";

        class Attributes: AttributesBase {
            class jumpSpeed: Combo {
                property = "moduleJump_jumpSpeed";
                displayName = "Jump speed";
                tooltip = "factor, by which the default jump speed gets multiplied";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 0_1 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 0_25 {
                        name = "25%";
                        value = 0.25;
                    };
                    class 0_5 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 0_75 {
                        name = "75%";
                        value = 0.75;
                    };
                    class 1 {
                        name = "100%";
                        value = 1;
                    };
                    class 1_25 {
                        name = "125%";
                        value = 1.25;
                    };
                    class 1_5 {
                        name = "150%";
                        value = 1.5;
                    };
                    class 2 {
                        name = "200%";
                        value = 2;
                    };
                    class 5 {
                        name = "500%";
                        value = 5;
                    };
                    class 10 {
                        name = "1000%";
                        value = 10;
                    };
                };
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module replaces the default 'climb over' action (V-key) with a jump action.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class jump {
        class main {
            file = "jump\scripts";
        };
    };

    class J {
        class NO_CATEGORY {
            file = "\jump\functions";
            class moduleJump {};
        };
    };
};