#define VALUES_5_TO_60 \
    class Values { \
        class 5 {name = "5"; value = 5;}; \
        class 10 {name = "10"; value = 10;}; \
        class 15 {name = "15"; value = 15;}; \
        class 20 {name = "20"; value = 20;}; \
        class 30 {name = "30"; value = 30;}; \
        class 45 {name = "45"; value = 45;}; \
        class 60 {name = "60"; value = 60;}; \
    }

class CfgPatches {
    class killfeed {
        units[] = {"moduleKillfeed"};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class Combo;
            class Checkbox;
            class ModuleDescription;
        };

        class ModuleDescription;
    };

    class moduleKillfeed: Module_F {
        scope = 2;
        displayName = "Killfeed";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayGarage\animationSources_ca.paa";
        category = "NO_CATEGORY";
        function = "KF_fnc_moduleKillfeed";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class assists: Checkbox {
                property = "moduleKillfeed_assists";
                displayName = "Assists";
                tooltip = "toggles assist functionality";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class showFriendlyFire: Checkbox {
                property = "moduleKillfeed_showFriendlyFire";
                displayName = "Show 'Friendly Fire'";
                tooltip = "shows a red 'Friendly Fire' text in the midfeed and the deathfeed in case of friendly fire";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class deathCausesInversed: Checkbox {
                property = "moduleKillfeed_deathCausesInversed";
                displayName = "Invert order of death causes";
                tooltip = "flips the order of death causes";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class multipleDeathCauses: Checkbox {
                property = "moduleKillfeed_multipleDeathCauses";
                displayName = "Show multiple death causes per line";
                tooltip = "toggles whether there can be multiple death causes displayed per line, in case the hitter hit the killed by multiple different means";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class picturesHeadIcon: Checkbox {
                property = "moduleKillfeed_picturesHeadIcon";
                displayName = "Show head icon in case of headshot";
                tooltip = "toggles whether a head icon is displayed in front of the weapon, in case of a headshot";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class picturesBulletIcon: Checkbox {
                property = "moduleKillfeed_picturesBulletIcon";
                displayName = "Show bullet icon";
                tooltip = "toggles whether a bullet icon is displayed between the head and the weapon, in case of a headshot";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class showAiInNames: Checkbox {
                property = "moduleKillfeed_showAiInNames";
                displayName = "Show AI in names";
                tooltip = "toggles whether ' (AI)' is appended to the names of AI units and vehicles";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class killfeedEnabled: Checkbox {
                property = "moduleKillfeed_killfeedEnabled";
                displayName = "Show killfeed";
                tooltip = "toggles killfeed functionality";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class killfeedCooldown: Combo {
                property = "moduleKillfeed_killfeedCooldown";
                displayName = "Killfeed cooldown";
                tooltip = "determines for how long kills should be displayed in the killfeed";
                typeName = "NUMBER";
                defaultValue = "30";
                VALUES_5_TO_60;
            };

            class killfeedMaximumLength: Combo {
                property = "moduleKillfeed_killfeedMaximumLength";
                displayName = "Maximum killfeed length";
                tooltip = "maximum number of kills displayed at one time in the killfeed";
                typeName = "NUMBER";
                defaultValue = "10";
                VALUES_5_TO_60;
            };

            class killfeedInversed: Checkbox {
                property = "moduleKillfeed_killfeedInversed";
                displayName = "Flip killer and killed";
                tooltip = "flips the positions of killer and killed in the killfeed";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class midFeedEnabled: Checkbox {
                property = "moduleKillfeed_midFeedEnabled";
                displayName = "Show midfeed";
                tooltip = "toggles midfeed functionality";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class midfeedCooldown: Combo {
                property = "moduleKillfeed_midfeedCooldown";
                displayName = "Midfeed cooldown";
                tooltip = "determines for how long kills should be displayed in the midfeed";
                typeName = "NUMBER";
                defaultValue = "10";
                VALUES_5_TO_60;
            };

            class midfeedMaximumLength: Combo {
                property = "moduleKillfeed_midfeedMaximumLength";
                displayName = "Maximum midfeed length";
                tooltip = "maximum number of kills displayed at one time in the midfeed";
                typeName = "NUMBER";
                defaultValue = "10";
                VALUES_5_TO_60;
            };

            class midFeedYouColorYellow: Checkbox {
                property = "moduleKillfeed_midFeedYouColorYellow";
                displayName = "Yellow 'You' in the midfeed";
                tooltip = "toggles whether the text 'You' in 'You killed ...' should also be displayed in yellow in the midfeed";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class midFeedAssists: Checkbox {
                property = "moduleKillfeed_midFeedAssists";
                displayName = "Show assists in the midfeed";
                tooltip = "toggles whether there should be assists displayed in the midfeed";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class deathFeedEnabled: Checkbox {
                property = "moduleKillfeed_deathFeedEnabled";
                displayName = "Show deathfeed";
                tooltip = "toggles death-feed functionality";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class killInfoDuration: Combo {
                property = "moduleKillfeed_killInfoDuration";
                displayName = "Kill-info duration";
                tooltip = "determines for how long the kill-info should be displayed";
                typeName = "NUMBER";
                defaultValue = "20";
                VALUES_5_TO_60;
            };

            class killCamEnabled: Checkbox {
                property = "moduleKillfeed_killCamEnabled";
                displayName = "Kill cam";
                tooltip = "after the own death by another unit the camera flies to the killer and circles him (skip: Space)";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class killCamHoldDuration: Combo {
                property = "moduleKillfeed_killCamHoldDuration";
                displayName = "Kill cam duration";
                tooltip = "seconds the kill cam stays on the killer";
                typeName = "NUMBER";
                defaultValue = "5";

                class Values {
                    class 3 {name = "3"; value = 3;};
                    class 5 {name = "5"; value = 5;};
                    class 8 {name = "8"; value = 8;};
                    class 10 {name = "10"; value = 10;};
                };
            };

            class killCamMaxDistance: Combo {
                property = "moduleKillfeed_killCamMaxDistance";
                displayName = "Kill cam maximum distance";
                tooltip = "no kill cam for a killer farther away at the death (m)";
                typeName = "NUMBER";
                defaultValue = "300";

                class Values {
                    class 100 {name = "100 m"; value = 100;};
                    class 200 {name = "200 m"; value = 200;};
                    class 300 {name = "300 m"; value = 300;};
                    class 500 {name = "500 m"; value = 500;};
                    class 1000 {name = "1000 m"; value = 1000;};
                    class 3000 {name = "3000 m"; value = 3000;};
                };
            };

            class killCamAirMaxHeight: Combo {
                property = "moduleKillfeed_killCamAirMaxHeight";
                displayName = "Kill cam maximum aircraft height";
                tooltip = "no kill cam for a killer in an aircraft higher above the ground (m)";
                typeName = "NUMBER";
                defaultValue = "300";

                class Values {
                    class 100 {name = "100 m"; value = 100;};
                    class 300 {name = "300 m"; value = 300;};
                    class 1000 {name = "1000 m"; value = 1000;};
                    class 10000 {name = "Any"; value = 10000;};
                };
            };

            class killCamTeamKills: Checkbox {
                property = "moduleKillfeed_killCamTeamKills";
                displayName = "Kill cam for team kills";
                tooltip = "also shows the kill cam when a friendly unit was the killer";
                typeName = "BOOL";
                defaultValue = "true";
            };

            class killCamRequireLineOfSight: Checkbox {
                property = "moduleKillfeed_killCamRequireLineOfSight";
                displayName = "Kill cam only with line of sight";
                tooltip = "shows the kill cam only if the victim could have seen the killer";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class killCamIndirectKills: Checkbox {
                property = "moduleKillfeed_killCamIndirectKills";
                displayName = "Kill cam for indirect kills";
                tooltip = "also shows the kill cam for kills by mortars, artillery, mines and placed explosives";
                typeName = "BOOL";
                defaultValue = "false";
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module provides kill-feed, mid-feed, death-feed, kill-info and kill cam functionality.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class KF {
        class NO_CATEGORY {
            file = "\killfeed";
            class moduleKillfeed {};
        };
    };
};

// CBA is optional. The Eden module also works without it.
class Extended_PreInit_EventHandlers {
    class killfeed {
        init = "[false] call compile preprocessFileLineNumbers 'killfeed\scripts\cbaSettings.sqf'";
    };
};

class Extended_PostInit_EventHandlers {
    class killfeed {
        serverInit = "if (!isNil 'KF_fnc_startCbaAddon') then {['CBA_settingsInitialized', KF_fnc_startCbaAddon] call CBA_fnc_addEventHandler}";
    };
};
