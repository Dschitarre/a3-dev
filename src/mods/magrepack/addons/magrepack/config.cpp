class CfgPatches {
    class magrepack {
        units[] = {"moduleMagRepack"};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class Checkbox;
            class Combo;
            class ModuleDescription;
        };

        class ModuleDescription;
    };

    class moduleMagRepack: Module_F {
        scope = 2;
        displayName = "Magazine Repack";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "MR_fnc_moduleMagRepack";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class enabled: Checkbox {
                property = "moduleMagRepack_enabled";
                displayName = "Enabled";
                tooltip = "repacking is available from the start; scripts can pause / resume it any time with MR_var_enabled";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class secondsPerRound: Combo {
                property = "moduleMagRepack_secondsPerRound";
                displayName = "Time per round";
                tooltip = "time a player needs to move one round from one magazine into another";
                typeName = "NUMBER";
                defaultValue = "0.12";

                class Values {
                    class s005 {name = "0.05 s"; value = 0.05;};
                    class s008 {name = "0.08 s"; value = 0.08;};
                    class s01 {name = "0.1 s"; value = 0.1;};
                    class s012 {name = "0.12 s"; value = 0.12;};
                    class s015 {name = "0.15 s"; value = 0.15;};
                    class s02 {name = "0.2 s"; value = 0.2;};
                    class s03 {name = "0.3 s"; value = 0.3;};
                };
            };

            class aiRepack: Checkbox {
                property = "moduleMagRepack_aiRepack";
                displayName = "AI repacks";
                tooltip = "AI units repack their magazines instantly from time to time when they are not in combat";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class aiInterval: Combo {
                property = "moduleMagRepack_aiInterval";
                displayName = "AI repack interval";
                tooltip = "time between two repacks of the AI units";
                typeName = "NUMBER";
                defaultValue = "60";

                class Values {
                    class s15 {name = "15 s"; value = 15;};
                    class s30 {name = "30 s"; value = 30;};
                    class s60 {name = "60 s"; value = 60;};
                    class s120 {name = "2 min"; value = 120;};
                    class s300 {name = "5 min"; value = 300;};
                };
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "Adds a REPACK MAGAZINES button to the inventory: it repacks the player's partly filled magazines (uniform, vest, backpack and the ones loaded in the weapons) into full ones, one magazine after the other with a progress bar; closing the inventory or pressing the button again stops it and keeps what is done. The weapon ends up with the fullest magazine. Only magazines with more than one round (no grenades, rockets or single shells). AI units repack instantly every interval while not in combat. Scripts: MR_var_enabled (pause / resume, also on a single machine).";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class MR {
        class NO_CATEGORY {
            file = "\magrepack";
            class moduleMagRepack {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class magrepack {
        init = "[false] call compile preprocessFileLineNumbers 'magrepack\scripts\cbaSettings.sqf'";
    };
};
