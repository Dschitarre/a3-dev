class CfgPatches {
    class killfeed_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"killfeed"};
    };
};

class CfgFunctions {
    class killfeed_global_enabler {
        class main {
            file = "killfeed_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};