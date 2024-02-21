class CfgPatches {
    class dynamicweather_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"dynamicweather"};
    };
};

class CfgFunctions {
    class dynamicweather_global_enabler {
        class main {
            file = "dynamicweather_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};