class CfgPatches {
    class lagswitchdetection {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {};
    };
};

class CfgFunctions {
    class lagswitchdetection {
        class main {
            file = "lagswitchdetection\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};