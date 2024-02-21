class CfgPatches {
    class holster_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"holster"};
    };
};

class CfgFunctions {
    class holster_global_enabler {
        class main {
            file = "holster_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};