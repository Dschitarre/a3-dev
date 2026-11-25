class CfgPatches {
    class tdicons {
        units[] = {"moduleTdIcons"};
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

    class moduleTdIcons: Module_F {
        scope = 2;
        displayName = "3D Icons";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "TDI_fnc_moduleTdIcons";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class ShowAllSides: Checkbox {
                property = "moduleTdIcons_showAllSides";
                displayName = "Show all sides";
                tooltip = "toggles whether units of all sides are displayed";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class showAllSidesOnSpectator: Checkbox {
                property = "moduleTdIcons_showAllSidesOnSpectator";
                displayName = "Show all sides when in spectator";
                tooltip = "toggles whether units of all sides are displayed when in spectator";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class shoWUnitNames: Checkbox {
                property = "moduleTdIcons_shoWUnitNames";
                displayName = "Show Unit Names";
                tooltip = "toggles whether the names of units are shown below the icons";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class hideInvisible: Checkbox {
                property = "moduleTdIcons_hideInvisible";
                displayName = "Hide invisible";
                tooltip = "toggles whether the icons of units, that are not visible, are hidden";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class showGroupIcons: Checkbox {
                property = "moduleTdIcons_showGroupIcons";
                displayName = "Show Group Icons";
                tooltip = "toggles whether to show group icons (if enabled, please disable group icons in the difficulty settings)";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class hideInvisibleGroupMembers: Checkbox {
                property = "moduleTdIcons_hideInvisibleGroupMembers";
                displayName = "Hide invisible Group Members";
                tooltip = "toggles whether the icons of group members, that are not visible, are hidden";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module displays 3D Icons for each unit and UAVs controlled by it.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class TDI {
        class NO_CATEGORY {
            file = "\tdicons";
            class moduleTdIcons {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class tdicons {
        init = "[false] call compile preprocessFileLineNumbers 'tdicons\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class tdicons {
        serverInit = "if (!isNil 'TDI_fnc_startCbaAddon') then {['CBA_settingsInitialized', TDI_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
