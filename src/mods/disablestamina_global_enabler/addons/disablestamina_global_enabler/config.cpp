class CfgPatches {
    class disablestamina_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"disablestamina"};
    };
};

class CfgFunctions {
    class disablestamina_global_enabler {
        class main {
            file = "disablestamina_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};