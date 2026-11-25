#define VALUES_COOLDOWN \
    class Values { \
        class 1 {name = "1s"; value = 1;}; \
        class 2 {name = "2s"; value = 2;}; \
        class 5 {name = "5s"; value = 5;}; \
        class 8 {name = "8s"; value = 8;}; \
        class 10 {name = "10s"; value = 10;}; \
        class 12 {name = "12s"; value = 12;}; \
        class 15 {name = "15s"; value = 15;}; \
        class 20 {name = "20s"; value = 20;}; \
        class 30 {name = "30s"; value = 30;}; \
        class 40 {name = "40s"; value = 40;}; \
        class 50 {name = "50s"; value = 50;}; \
        class 60 {name = "60s"; value = 60;}; \
    }

class CfgPatches {
    class autoheal {
        units[] = {"moduleAutoHeal"};
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

    class moduleAutoHeal: Module_F {
        scope = 2;
        displayName = "Auto Heal";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "AH_fnc_moduleAutoHeal";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class healSpeed: Combo {
                property = "moduleAutoHeal_healSpeed";
                displayName = "Heal speed";
                tooltip = "factor, by which the default speed of healing gets multiplied";
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

            class healCooldown: Combo {
                property = "moduleAutoHeal_healCooldown";
                displayName = "Heal cooldown";
                tooltip = "time, after which a unit starts to heal";
                typeName = "NUMBER";
                defaultValue = "12";
                VALUES_COOLDOWN;
            };

            class healCooldownMedic: Combo {
                property = "moduleAutoHeal_healCooldownMedic";
                displayName = "Medic heal cooldown";
                tooltip = "time, after which a medic unit starts to heal";
                typeName = "NUMBER";
                defaultValue = "8";
                VALUES_COOLDOWN;
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module makes every unit heal automatically at a configurable speed after a configurable time.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class AH {
        class NO_CATEGORY {
            file = "\autoheal";
            class moduleAutoHeal {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class autoheal {
        init = "[false] call compile preprocessFileLineNumbers 'autoheal\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class autoheal {
        serverInit = "if (!isNil 'AH_fnc_startCbaAddon') then {['CBA_settingsInitialized', AH_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
