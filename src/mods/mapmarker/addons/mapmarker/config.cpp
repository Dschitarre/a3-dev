class CfgPatches {
    class mapmarker {
        units[] = {"moduleMapMarker"};
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
            class ModuleDescription;
        };

        class ModuleDescription;
    };

    class moduleMapMarker: Module_F {
        scope = 2;
        displayName = "Map Marker";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "MM_fnc_moduleMapMarker";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class ShowAllSides: Checkbox {
                property = "moduleMapMarker_showAllSides";
                displayName = "Show all sides";
                tooltip = "toggles whether units of all sides are displayed";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class showAllSidesOnSpectator: Checkbox {
                property = "moduleMapMarker_showAllSidesOnSpectator";
                displayName = "Show all sides when in spectator";
                tooltip = "toggles whether units of all sides are displayed when in spectator";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class showUnitNames: Checkbox {
                property = "moduleMapMarker_showUnitNames";
                displayName = "Show Unit Names";
                tooltip = "toggles whether to show the names of units";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class showUnitNamesOnlyOnHover: Checkbox {
                property = "moduleMapMarker_showUnitNamesOnlyOnHover";
                displayName = "Show Unit Names only on Hover";
                tooltip = "toggles whether to show the name of a unit only when hovering over it on the map";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module displays map markers for all units and vehicles.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class MM {
        class NO_CATEGORY {
            file = "\mapmarker";
            class moduleMapMarker {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class mapmarker {
        init = "[false] call compile preprocessFileLineNumbers 'mapmarker\scripts\cbaSettings.sqf'";
    };
};
