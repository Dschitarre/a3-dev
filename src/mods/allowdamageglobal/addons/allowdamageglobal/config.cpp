// Library addon without a module: runs on every mission as soon as the addon is loaded.
class CfgPatches {
    class allowdamageglobal {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {};
    };
};

class CfgFunctions {
    class allowdamageglobal {
        class main {
            file = "allowdamageglobal\scripts";
            class init {
                postInit = 1;
            };
        };
    };
};
