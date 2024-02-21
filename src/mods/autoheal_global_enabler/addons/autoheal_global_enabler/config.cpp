class CfgPatches {
    class autoheal_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"autoheal"};
    };
};

class CfgFunctions {
    class autoheal_global_enabler {
        class main {
            file = "autoheal_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};