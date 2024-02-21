class CfgPatches {
    class tdicons_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"tdicons"};
    };
};

class CfgFunctions {
    class tdicons_global_enabler {
        class main {
            file = "tdicons_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};