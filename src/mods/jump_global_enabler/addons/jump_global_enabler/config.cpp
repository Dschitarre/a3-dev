class CfgPatches {
    class jump_global_enabler {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"jump"};
    };
};

class CfgFunctions {
    class jump_global_enabler {
        class main {
            file = "jump_global_enabler\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};