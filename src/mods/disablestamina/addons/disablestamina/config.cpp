#define VALUES_SWAY \
    class Values { \
        class 0 {name = "0%"; value = 0;}; \
        class 0_1 {name = "10%"; value = 0.1;}; \
        class 0_2 {name = "20%"; value = 0.2;}; \
        class 0_3 {name = "30%"; value = 0.3;}; \
        class 0_4 {name = "40%"; value = 0.4;}; \
        class 0_5 {name = "50%"; value = 0.5;}; \
        class 0_6 {name = "60%"; value = 0.6;}; \
        class 0_7 {name = "70%"; value = 0.7;}; \
        class 0_8 {name = "80%"; value = 0.8;}; \
        class 0_9 {name = "90%"; value = 0.9;}; \
        class 1 {name = "100%"; value = 1;}; \
    }

class CfgPatches {
    class disablestamina {
        units[] = {"moduleDisableStamina"};
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

    class moduleDisableStamina: Module_F {
        scope = 2;
        displayName = "Disable Stamina";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "DS_fnc_moduleDisableStamina";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class weaponSwayEnabled: Combo {
                property = "moduleDisableStamina_weaponSwayEnabled";
                displayName = "Weapon sway when enabled";
                tooltip = "Amount of weapon sway when stamina is enabled";
                typeName = "NUMBER";
                defaultValue = "1";
                VALUES_SWAY;
            };

            class weaponSwayDisabled: Combo {
                property = "moduleDisableStamina_weaponSwayDisabled";
                displayName = "Weapon sway when disabled";
                tooltip = "Amount of weapon sway when stamina is disabled";
                typeName = "NUMBER";
                defaultValue = "0.3";
                VALUES_SWAY;
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module disables stamina for all units.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class DS {
        class NO_CATEGORY {
            file = "\disablestamina";
            class moduleDisableStamina {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class disablestamina {
        init = "[false] call compile preprocessFileLineNumbers 'disablestamina\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class disablestamina {
        serverInit = "if (!isNil 'DS_fnc_startCbaAddon') then {['CBA_settingsInitialized', DS_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
