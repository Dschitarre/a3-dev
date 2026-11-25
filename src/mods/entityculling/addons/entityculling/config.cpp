class CfgPatches {
    class entityculling {
        units[] = {"moduleEntityCulling"};
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

    class moduleEntityCulling: Module_F {
        scope = 2;
        displayName = "Entity Culling";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "EC_fnc_moduleEntityCulling";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class enabled: Checkbox {
                property = "moduleEntityCulling_enabled";
                displayName = "Enabled";
                tooltip = "culling runs from the start; scripts can pause / resume it any time with EC_var_enabled";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class frameBudget: Combo {
                property = "moduleEntityCulling_frameBudget";
                displayName = "Frame budget";
                tooltip = "time per frame each client may spend on visibility tests; more budget keeps more entities hidden";
                typeName = "NUMBER";
                defaultValue = "0.001";

                class Values {
                    class ms025 {name = "0.25 ms"; value = 0.00025;};
                    class ms05 {name = "0.5 ms"; value = 0.0005;};
                    class ms1 {name = "1 ms"; value = 0.001;};
                    class ms2 {name = "2 ms"; value = 0.002;};
                    class ms4 {name = "4 ms"; value = 0.004;};
                };
            };

            class minDistance: Combo {
                property = "moduleEntityCulling_minDistance";
                displayName = "Minimum distance";
                tooltip = "entities closer to the camera or the player's unit / vehicle are never hidden (plus a margin for the camera's speed)";
                typeName = "NUMBER";
                defaultValue = "10";

                class Values {
                    class m5 {name = "5 m"; value = 5;};
                    class m10 {name = "10 m"; value = 10;};
                    class m15 {name = "15 m"; value = 15;};
                    class m25 {name = "25 m"; value = 25;};
                    class m50 {name = "50 m"; value = 50;};
                    class m100 {name = "100 m"; value = 100;};
                };
            };

            class checkInterval: Combo {
                property = "moduleEntityCulling_checkInterval";
                displayName = "Check interval";
                tooltip = "minimum time between two checks of a visible entity";
                typeName = "NUMBER";
                defaultValue = "0.2";

                class Values {
                    class s01 {name = "0.1 s"; value = 0.1;};
                    class s02 {name = "0.2 s"; value = 0.2;};
                    class s03 {name = "0.3 s"; value = 0.3;};
                    class s05 {name = "0.5 s"; value = 0.5;};
                    class s1 {name = "1 s"; value = 1;};
                };
            };

            class hideAfterChecks: Combo {
                property = "moduleEntityCulling_hideAfterChecks";
                displayName = "Hide after checks";
                tooltip = "invisible checks in a row before an entity is hidden (it is shown again at the first check that sees it)";
                typeName = "NUMBER";
                defaultValue = "3";

                class Values {
                    class c1 {name = "1"; value = 1;};
                    class c2 {name = "2"; value = 2;};
                    class c3 {name = "3"; value = 3;};
                    class c5 {name = "5"; value = 5;};
                };
            };

            class lookahead: Combo {
                property = "moduleEntityCulling_lookahead";
                displayName = "Prediction";
                tooltip = "camera and entity movement a check covers; hidden entities are checked again after half of it";
                typeName = "NUMBER";
                defaultValue = "0.5";

                class Values {
                    class s03 {name = "0.3 s"; value = 0.3;};
                    class s05 {name = "0.5 s"; value = 0.5;};
                    class s075 {name = "0.75 s"; value = 0.75;};
                    class s1 {name = "1 s"; value = 1;};
                };
            };

            class debug: Checkbox {
                property = "moduleEntityCulling_debug";
                displayName = "Debug overlay";
                tooltip = "every client shows its hidden / checked entities, the worker's time per frame and its frame rate";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "Client-side performance: every client stops rendering (hideObject, local) the units, vehicles, static weapons, ammo boxes and weapon holders its camera cannot see - behind terrain, buildings, walls or rocks; vegetation never hides anything. A per-frame worker with a time budget tests occlusion from the camera in every view (first / third person, vehicles, optics, spectator, Zeus) and from where the camera can be soon (movement, leaning, third-person swing); an entity is hidden after several invisible checks in a row and shown again at the first check that sees it. Never hidden: entities within the minimum distance, the player's own unit / vehicle, dead entities, local vehicles and what local AI attacks. Sounds stay. Scripts: EC_var_enabled (pause / resume, also on a single client), EC_var_debug (overlay).";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class EC {
        class NO_CATEGORY {
            file = "\entityculling";
            class moduleEntityCulling {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class entityculling {
        init = "[false] call compile preprocessFileLineNumbers 'entityculling\scripts\cbaSettings.sqf'";
    };
};
