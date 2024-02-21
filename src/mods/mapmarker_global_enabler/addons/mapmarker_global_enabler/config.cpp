class CfgPatches {
    class mapmarker_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"mapmarker"};
    };
};

class CfgFunctions {
    class mapmarker_global_enabler {
        class main {
            file = "mapmarker_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};