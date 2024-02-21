class CfgPatches {
    class earplugs_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"earplugs"};
    };
};

class CfgFunctions {
    class earplugs_global_enabler {
        class main {
            file = "earplugs_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};