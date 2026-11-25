class CfgPatches {
    class jump {
        units[] = {"moduleJump"};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class Combo;
            class ModuleDescription;
        };

        class ModuleDescription;
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

        class Attributes: AttributesBase {
            class jumpSpeed: Combo {
                property = "moduleJump_jumpSpeed";
                displayName = "Jump speed";
                tooltip = "factor, by which the default jump speed gets multiplied";
                typeName = "NUMBER";
                defaultValue = "1";

                class Values {
                    class 0_1 {name = "10%"; value = 0.1;};
                    class 0_25 {name = "25%"; value = 0.25;};
                    class 0_5 {name = "50%"; value = 0.5;};
                    class 0_75 {name = "75%"; value = 0.75;};
                    class 1 {name = "100%"; value = 1;};
                    class 1_25 {name = "125%"; value = 1.25;};
                    class 1_5 {name = "150%"; value = 1.5;};
                    class 2 {name = "200%"; value = 2;};
                    class 5 {name = "500%"; value = 5;};
                    class 10 {name = "1000%"; value = 10;};
                };
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "While running, the 'step over' key (V by default) jumps instead of climbing over; standing or walking, it keeps its normal function.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class J {
        class NO_CATEGORY {
            file = "\jump";
            class moduleJump {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class jump {
        init = "[false] call compile preprocessFileLineNumbers 'jump\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class jump {
        serverInit = "if (!isNil 'J_fnc_startCbaAddon') then {['CBA_settingsInitialized', J_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
