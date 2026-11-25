class CfgPatches {
    class earplugs {
        units[] = {"moduleEarplugs"};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

// volumes of the earplugs: 0 to 90 % in steps of 10 % (the players' settings dialog has the same steps)
#define EP_VOLUME_VALUES \
    class 0 {name = "0%"; value = 0;}; \
    class 0_1 {name = "10%"; value = 0.1;}; \
    class 0_2 {name = "20%"; value = 0.2;}; \
    class 0_3 {name = "30%"; value = 0.3;}; \
    class 0_4 {name = "40%"; value = 0.4;}; \
    class 0_5 {name = "50%"; value = 0.5;}; \
    class 0_6 {name = "60%"; value = 0.6;}; \
    class 0_7 {name = "70%"; value = 0.7;}; \
    class 0_8 {name = "80%"; value = 0.8;}; \
    class 0_9 {name = "90%"; value = 0.9;};

// automatic earplugs of a vehicle category: off (-1) or their volume
#define EP_AUTO_ATTRIBUTE(PNAME, PPROPERTY, PLABEL, PTOOLTIP, PDEFAULT) \
    class PNAME: Combo { \
        property = PPROPERTY; \
        displayName = PLABEL; \
        tooltip = PTOOLTIP; \
        typeName = "NUMBER"; \
        defaultValue = PDEFAULT; \
        class Values { \
            class off {name = "Off"; value = -1;}; \
            EP_VOLUME_VALUES \
        }; \
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

    class moduleEarplugs: Module_F {
        scope = 2;
        displayName = "Earplugs";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "EP_fnc_moduleEarplugs";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        // defaults for players without settings of their own (Ctrl+F1 in game)
        class Attributes: AttributesBase {
            class volumeMuted: Combo {
                property = "moduleEarplugs_volumeMuted";
                displayName = "Volume with earplugs (F1)";
                tooltip = "Default game volume while the earplugs of the F1 key are in";
                typeName = "NUMBER";
                defaultValue = "0.3";

                class Values {
                    EP_VOLUME_VALUES
                };
            };

            EP_AUTO_ATTRIBUTE(volumeGround, "moduleEarplugs_volumeGround", "Ground vehicles", "Default of the automatic earplugs while sitting in a ground vehicle: off or the game volume", "0.5")
            EP_AUTO_ATTRIBUTE(volumeAir, "moduleEarplugs_volumeAir", "Aircraft", "Default of the automatic earplugs while sitting in a helicopter or plane: off or the game volume", "0.3")
            EP_AUTO_ATTRIBUTE(volumeBoat, "moduleEarplugs_volumeBoat", "Boats", "Default of the automatic earplugs while sitting in a boat: off or the game volume", "0.5")

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module adds earplugs to all players: the F1 key puts them in and out, automatic earplugs while sitting in vehicles, settings per player with Ctrl+F1.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class EP {
        class NO_CATEGORY {
            file = "\earplugs";
            class moduleEarplugs {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class earplugs {
        init = "[false] call compile preprocessFileLineNumbers 'earplugs\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class earplugs {
        serverInit = "if (!isNil 'E_fnc_startCbaAddon') then {['CBA_settingsInitialized', E_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
