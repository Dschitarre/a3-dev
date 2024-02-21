class CfgPatches {
    class dynamicweather {
        units[] = {"moduleDynamicWeather"};
        requiredVersion = 1;
        requiredAddons[] = {"A3_Modules_F"};
    };
};

class CfgFactionClasses {
    class NO_CATEGORY;
    class moduleDynamicWeather: NO_CATEGORY {
        displayName = "Dynamic Weather";
    };
};

class CfgVehicles {
    class Logic;

    class Module_F: Logic {
        class AttributesBase {
            class Default;
            class Edit;
            class Combo;
            class Checkbox;
            class CheckboxNumber;
            class ModuleDescription;
        };

        class ModuleDescription {
            class AnyBrain;
        };
    };

    class moduleDynamicWeather: Module_F {
        scope = 2;
        displayName = "Dynamic Weather";
        icon = "\A3\ui_f\data\GUI\Rsc\RscDisplayArcadeMap\cloudly_ca.paa";
        category = "Environment";
        function = "DW_fnc_moduleDynamicWeather";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 1;
        isDisposable = 0;
        is3DEN = 0;
        curatorInfoType = "RscDisplayAttributeModuleDynamicWeather";

        class Attributes: AttributesBase {
            class minOvercast: Combo {
                property = "moduleDynamicWeather_minOvercast";
                displayName = "minimum overcast";
                tooltip = "lower border of the range the overcast can change within";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class maxOvercast: Combo {
                property = "moduleDynamicWeather_maxOvercast";
                displayName = "maximum overcast";
                tooltip = "upper border of the range the overcast can change within";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class minFogSunny: Combo {
                property = "moduleDynamicWeather_minFogSunny";
                displayName = "minimum fog while sunny";
                tooltip = "lower border of the range the fog can change within while it is sunny";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class maxFogSunny: Combo {
                property = "moduleDynamicWeather_maxFogSunny";
                displayName = "maximum fog while sunny";
                tooltip = "upper border of the range the fog can change within while it is sunny";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class minFogStormy: Combo {
                property = "moduleDynamicWeather_minFogStormy";
                displayName = "minimum fog while stormy";
                tooltip = "lower border of the range the fog can change within while it is stormy";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class maxFogStormy: Combo {
                property = "moduleDynamicWeather_maxFogStormy";
                displayName = "maximum fog while stormy";
                tooltip = "upper border of the range the fog can change within while it is stormy";
                typeName = "NUMBER";
                defaultValue = "0.1";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class minRain: Combo {
                property = "moduleDynamicWeather_minRain";
                displayName = "minimum rain";
                tooltip = "lower border of the range the rain can change within";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class maxRain: Combo {
                property = "moduleDynamicWeather_maxRain";
                displayName = "maximum rain";
                tooltip = "upper border of the range the rain can change within";
                typeName = "NUMBER";
                defaultValue = "0.7";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class minWindSunny: Combo {
                property = "moduleDynamicWeather_minWindSunny";
                displayName = "minimum wind while sunny";
                tooltip = "lower border of the range the wind can change within while sunny";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class maxWindSunny: Combo {
                property = "moduleDynamicWeather_maxWindSunny";
                displayName = "maximum wind while sunny";
                tooltip = "upper border of the range the wind can change within while sunny";
                typeName = "NUMBER";
                defaultValue = "0.3";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class minWindStormy: Combo {
                property = "moduleDynamicWeather_minWindStormy";
                displayName = "minimum wind while stormy";
                tooltip = "lower border of the range the wind can change within while stormy";
                typeName = "NUMBER";
                defaultValue = "0";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };
            
            class maxWindStormy: Combo {
                property = "moduleDynamicWeather_maxWindStormy";
                displayName = "maximum wind while stormy";
                tooltip = "upper border of the range the wind can change within while stormy";
                typeName = "NUMBER";
                defaultValue = "0.6";
                
                class Values {
                    class 0 {
                        name = "0%";
                        value = 0;
                    };
                    class 10 {
                        name = "10%";
                        value = 0.1;
                    };
                    class 20 {
                        name = "20%";
                        value = 0.2;
                    };
                    class 30 {
                        name = "30%";
                        value = 0.3;
                    };
                    class 40 {
                        name = "40%";
                        value = 0.4;
                    };
                    class 50 {
                        name = "50%";
                        value = 0.5;
                    };
                    class 60 {
                        name = "60%";
                        value = 0.6;
                    };
                    class 70 {
                        name = "70%";
                        value = 0.7;
                    };
                    class 80 {
                        name = "80%";
                        value = 0.8;
                    };
                    class 90 {
                        name = "90%";
                        value = 0.9;
                    };
                    class 100 {
                        name = "100%";
                        value = 1;
                    };
                };
            };

            class timeMultiplierChangeDay: Combo {
                property = "moduleDynamicWeather_timeMultiplierChangeDay";
                displayName = "change time multiplier during daytime";
                tooltip = "time multiplier during weather change (day)";
                typeName = "NUMBER";
                defaultValue = "15";
                
                class Values {
                    class 1 {
                        name = "1";
                        value = 1;
                    };
                    class 2 {
                        name = "2";
                        value = 2;
                    };
                    class 5 {
                        name = "5";
                        value = 5;
                    };
                    class 7 {
                        name = "7";
                        value = 7;
                    };
                    class 10 {
                        name = "10";
                        value = 10;
                    };
                    class 15 {
                        name = "15";
                        value = 15;
                    };
                    class 20 {
                        name = "20";
                        value = 20;
                    };
                    class 30 {
                        name = "30";
                        value = 30;
                    };
                    class 50 {
                        name = "50";
                        value = 50;
                    };
                    class 80 {
                        name = "80";
                        value = 80;
                    };
                    class 120 {
                        name = "120";
                        value = 120;
                    };
                };
            };

            class timeMultiplierChangeNight: Combo {
                property = "moduleDynamicWeather_timeMultiplierChangeNight";
                displayName = "change time multiplier during night";
                tooltip = "time multiplier during weather change (night)";
                typeName = "NUMBER";
                defaultValue = "15";
                
                class Values {
                    class 1 {
                        name = "1";
                        value = 1;
                    };
                    class 2 {
                        name = "2";
                        value = 2;
                    };
                    class 5 {
                        name = "5";
                        value = 5;
                    };
                    class 7 {
                        name = "7";
                        value = 7;
                    };
                    class 10 {
                        name = "10";
                        value = 10;
                    };
                    class 15 {
                        name = "15";
                        value = 15;
                    };
                    class 20 {
                        name = "20";
                        value = 20;
                    };
                    class 30 {
                        name = "30";
                        value = 30;
                    };
                    class 50 {
                        name = "50";
                        value = 50;
                    };
                    class 80 {
                        name = "80";
                        value = 80;
                    };
                    class 120 {
                        name = "120";
                        value = 120;
                    };
                };
            };

            class timeMultiplierStaticDay: Combo {
                property = "moduleDynamicWeather_timeMultiplierStaticDay";
                displayName = "static time multiplier during daytime";
                tooltip = "time multiplier while weather is static (day)";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 1 {
                        name = "1";
                        value = 1;
                    };
                    class 2 {
                        name = "2";
                        value = 2;
                    };
                    class 5 {
                        name = "5";
                        value = 5;
                    };
                    class 7 {
                        name = "7";
                        value = 7;
                    };
                    class 10 {
                        name = "10";
                        value = 10;
                    };
                    class 15 {
                        name = "15";
                        value = 15;
                    };
                    class 20 {
                        name = "20";
                        value = 20;
                    };
                    class 30 {
                        name = "30";
                        value = 30;
                    };
                    class 50 {
                        name = "50";
                        value = 50;
                    };
                    class 80 {
                        name = "80";
                        value = 80;
                    };
                    class 120 {
                        name = "120";
                        value = 120;
                    };
                };
            };

            class timeMultiplierStaticNight: Combo {
                property = "moduleDynamicWeather_timeMultiplierStaticNight";
                displayName = "static time multiplier during night";
                tooltip = "time multiplier while weather is static (night)";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 1 {
                        name = "1";
                        value = 1;
                    };
                    class 2 {
                        name = "2";
                        value = 2;
                    };
                    class 5 {
                        name = "5";
                        value = 5;
                    };
                    class 7 {
                        name = "7";
                        value = 7;
                    };
                    class 10 {
                        name = "10";
                        value = 10;
                    };
                    class 15 {
                        name = "15";
                        value = 15;
                    };
                    class 20 {
                        name = "20";
                        value = 20;
                    };
                    class 30 {
                        name = "30";
                        value = 30;
                    };
                    class 50 {
                        name = "50";
                        value = 50;
                    };
                    class 80 {
                        name = "80";
                        value = 80;
                    };
                    class 120 {
                        name = "120";
                        value = 120;
                    };
                };
            };

            class skipNightTime: Combo {
                property = "moduleDynamicWeather_skipNightTime";
                displayName = "skip night";
                tooltip = "determines if and when the night is skipped";
                typeName = "NUMBER";
                defaultValue = "19";
                
                class Values {
                    class 0 {
                        name = "do not skip";
                        value = 0;
                    };
                    class 17 {
                        name = "skip at 17:00";
                        value = 17;
                    };
                    class 18 {
                        name = "skip at 18:00";
                        value = 18;
                    };
                    class 19 {
                        name = "skip at 19:00";
                        value = 19;
                    };
                    class 20 {
                        name = "skip at 20:00";
                        value = 20;
                    };
                    class 21 {
                        name = "skip at 21:00";
                        value = 21;
                    };
                    class 22 {
                        name = "skip at 22:00";
                        value = 22;
                    };
                };
            };

            class timeBetweenWeatherChangesMultiplierSunny: Combo {
                property = "moduleDynamicWeather_timeBetweenWeatherChangesMultiplierSunny";
                displayName = "time between weather changes when sunny";
                tooltip = "determines how long the weather stays the same between weather changes when it is sunny";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 0_1 {
                        name = "1 minute";
                        value = 0.1;
                    };
                    class 0_2 {
                        name = "2 minutes";
                        value = 0.2;
                    };
                    class 0_5 {
                        name = "5 minutes";
                        value = 0.5;
                    };
                    class 1 {
                        name = "10 minutes";
                        value = 1;
                    };
                    class 2 {
                        name = "20 minutes";
                        value = 2;
                    };
                    class 3 {
                        name = "30 minutes";
                        value = 3;
                    };
                    class 4 {
                        name = "40 minutes";
                        value = 4;
                    };
                    class 5 {
                        name = "50 minutes";
                        value = 5;
                    };
                    class 6 {
                        name = "1 hour";
                        value = 6;
                    };
                    class 9 {
                        name = "1 1/2 hours";
                        value = 9;
                    };
                    class 12 {
                        name = "2 hours";
                        value = 12;
                    };
                };
            };

            class timeBetweenWeatherChangesMultiplierStormy: Combo {
                property = "moduleDynamicWeather_timeBetweenWeatherChangesMultiplierStormy";
                displayName = "time between weather changes when stormy";
                tooltip = "determines how long the weather stays the same between weather changes when it is stormy";
                typeName = "NUMBER";
                defaultValue = "1";
                
                class Values {
                    class 0_1 {
                        name = "1 minute";
                        value = 0.1;
                    };
                    class 0_2 {
                        name = "2 minutes";
                        value = 0.2;
                    };
                    class 0_5 {
                        name = "5 minutes";
                        value = 0.5;
                    };
                    class 1 {
                        name = "10 minutes";
                        value = 1;
                    };
                    class 2 {
                        name = "20 minutes";
                        value = 2;
                    };
                    class 3 {
                        name = "30 minutes";
                        value = 3;
                    };
                    class 4 {
                        name = "40 minutes";
                        value = 4;
                    };
                    class 5 {
                        name = "50 minutes";
                        value = 5;
                    };
                    class 6 {
                        name = "1 hour";
                        value = 6;
                    };
                    class 9 {
                        name = "1 1/2 hours";
                        value = 9;
                    };
                    class 12 {
                        name = "2 hours";
                        value = 12;
                    };
                };
            };

            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "This module sets random weather once it is triggered. There will be a short freeze. Then it changes the weather randomly according to the settings defined in the module. There are 2 alternating phases. In phase 1 the weather changes. In phase 2 it remains static so the clients can sync to the server. This is necesarry to ensure synced weather in multiplayer. It works in singleplayer as well. In order for this module to work correctly there should not be any other scripts trying to set the time multiplier.";
            sync[] = {};
        };
    };
};

class CfgFunctions {
    class dynamicweather {
        class main {
            file = "dynamicweather\scripts";
        };
    };

    class DW {
        class Environment {
            file = "\dynamicweather\functions";
            class moduleDynamicWeather {};
        };
    };
};