class CfgPatches {
    class disabletacticalview_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"disabletacticalview"};
    };
};

class CfgFunctions {
    class disabletacticalview_global_enabler {
        class main {
            file = "disabletacticalview_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};