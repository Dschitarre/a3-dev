class CfgPatches {
    class unflip {
        units[] = {"moduleUnflip"};
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

    class moduleUnflip: Module_F {
        scope = 2;
        displayName = "Unflip";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "UF_fnc_moduleUnflip";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class enabled: Checkbox {
                property = "moduleUnflip_enabled";
                displayName = "Enabled";
                tooltip = "unflipping works from the start; scripts can pause / resume it any time with UF_var_enabled";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class maxDistance: Combo {
                property = "moduleUnflip_maxDistance";
                displayName = "Reach";
                tooltip = "maximum distance between the player's eyes and the vehicle's outline";
                typeName = "NUMBER";
                defaultValue = "6";

                class Values {
                    class m3 {name = "3 m"; value = 3;};
                    class m4 {name = "4 m"; value = 4;};
                    class m6 {name = "6 m"; value = 6;};
                    class m8 {name = "8 m"; value = 8;};
                    class m10 {name = "10 m"; value = 10;};
                };
            };

            class minTilt: Combo {
                property = "moduleUnflip_minTilt";
                displayName = "Flipped from";
                tooltip = "tilt from which a vehicle counts as flipped (0 = upright, 90 = on its side, 180 = on its roof)";
                typeName = "NUMBER";
                defaultValue = "65";

                class Values {
                    class d45 {name = "45 deg"; value = 45;};
                    class d55 {name = "55 deg"; value = 55;};
                    class d65 {name = "65 deg"; value = 65;};
                    class d75 {name = "75 deg"; value = 75;};
                    class d85 {name = "85 deg"; value = 85;};
                };
            };

            class durationMin: Combo {
                property = "moduleUnflip_durationMin";
                displayName = "Hold duration (light)";
                tooltip = "seconds of holding for light vehicles (quad bike); heavier ones take longer, up to the duration for heavy vehicles";
                typeName = "NUMBER";
                defaultValue = "3";

                class Values {
                    class s1 {name = "1 s"; value = 1;};
                    class s2 {name = "2 s"; value = 2;};
                    class s3 {name = "3 s"; value = 3;};
                    class s5 {name = "5 s"; value = 5;};
                    class s8 {name = "8 s"; value = 8;};
                };
            };

            class durationMax: Combo {
                property = "moduleUnflip_durationMax";
                displayName = "Hold duration (heavy)";
                tooltip = "seconds of holding for heavy vehicles (tanks)";
                typeName = "NUMBER";
                defaultValue = "8";

                class Values {
                    class s3 {name = "3 s"; value = 3;};
                    class s5 {name = "5 s"; value = 5;};
                    class s8 {name = "8 s"; value = 8;};
                    class s10 {name = "10 s"; value = 10;};
                    class s15 {name = "15 s"; value = 15;};
                };
            };

            class damageProtection: Combo {
                property = "moduleUnflip_damageProtection";
                displayName = "Damage protection";
                tooltip = "seconds an unflipped vehicle takes no damage, so it cannot break when it lands";
                typeName = "NUMBER";
                defaultValue = "2";

                class Values {
                    class s0 {name = "None"; value = 0;};
                    class s1 {name = "1 s"; value = 1;};
                    class s2 {name = "2 s"; value = 2;};
                    class s3 {name = "3 s"; value = 3;};
                    class s5 {name = "5 s"; value = 5;};
                };
            };

            class aiAutoUnflip: Checkbox {
                property = "moduleUnflip_aiAutoUnflip";
                displayName = "Unflip AI vehicles";
                tooltip = "the server unflips the vehicles of the AI on its own when they have been flipped for a while";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class aiDelay: Combo {
                property = "moduleUnflip_aiDelay";
                displayName = "AI vehicles: delay";
                tooltip = "seconds an AI vehicle must have been flipped (and standing still) before the server unflips it";
                typeName = "NUMBER";
                defaultValue = "10";

                class Values {
                    class s5 {name = "5 s"; value = 5;};
                    class s10 {name = "10 s"; value = 10;};
                    class s20 {name = "20 s"; value = 20;};
                    class s30 {name = "30 s"; value = 30;};
                    class s60 {name = "60 s"; value = 60;};
                };
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "Players turn flipped land vehicles, static weapons and boats back on their wheels with a hold action ('Unflip vehicle'): look at the vehicle within reach; it must have no living crew and stand still. The hold takes longer the heavier the vehicle is. The vehicle is set upright on the ground below it with its heading kept, lifted clear of the ground and of objects and protected from damage for a moment. The server also unflips the vehicles of the AI once they have been flipped for a while. Scripts: UF_var_enabled (pause / resume).";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class UF {
        class NO_CATEGORY {
            file = "\unflip";
            class moduleUnflip {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class unflip {
        init = "[false] call compile preprocessFileLineNumbers 'unflip\scripts\cbaSettings.sqf'";
    };
};
