// TDM lobby params (the MapName param follows, see Description.ext). mapSize/weather/startTime/timeMultiplier*/
// skipNight/thirdPerson/aiSkill come from common\config.hpp (included in Description.ext).
class ai {
    title = "AI Amount";
    values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8};
    texts[] = {"Fill to equalize unit count", "Fill to Map Size", "Fill upto 2", "Fill upto 3", "Fill upto 4", "Fill upto 5", "Fill upto 6", "Fill upto 7", "Fill upto 8"};
    default = 1;
};
CMN_PARAM_AI_SKILL
class autoHeal {
    title = "Automatic Healing";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 1;
};
CMN_PARAM_WEATHER
CMN_PARAM_SKIP_NIGHT
CMN_PARAM_START_TIME
CMN_PARAM_TIME_MULTIPLIER_DAY(4)
CMN_PARAM_TIME_MULTIPLIER_NIGHT
class zoneShrinkSpeed {
    title = "Zone shrink speed";
    values[] = {0, 1, 2, 3};
    texts[] = {"Slow", "Normal", "Fast", "Disabled"};
    default = 1;
};
class zoneShrinkDelay {
    title = "Zone shrinks after";
    values[] = {0, 15, 30, 45, 60, 90, 120};
    texts[] = {"0 seconds", "15 seconds", "30 seconds", "45 seconds", "60 seconds", "90 seconds", "120 seconds"};
    default = 30;
};
class zoneDamage {
    title = "Damage outside of the zone";
    values[] = {1, 2, 3, 5, 10};
    texts[] = {"1 HP per second", "2 HP per second", "3 HP per second", "5 HP per second", "10 HP per second"};
    default = 2;
};
class roundTimeLimit {
    title = "Round time limit";
    values[] = {0, 120, 180, 300, 420, 600, 900};
    texts[] = {"None", "2 minutes", "3 minutes", "5 minutes", "7 minutes", "10 minutes", "15 minutes"};
    default = 0;
};
class warmupTime {
    title = "Warmup Time";
    values[] = {30, 60, 120, 180};
    texts[] = {"30 seconds", "60 seconds", "120 seconds", "180 seconds"};
    default = 120;
};
class equipPhaseDuration {
    title = "Equipment phase";
    values[] = {15, 20, 30, 45, 60, 90};
    texts[] = {"15 seconds", "20 seconds", "30 seconds", "45 seconds", "60 seconds", "90 seconds"};
    default = 30;
};
CMN_PARAM_THIRD_PERSON
class loadouts {
    title = "Loadouts";
    values[] = {0, 1};
    texts[] = {"Not restricted", "Restricted"};
    default = 1;
};
class vehicleType {
    title = "Vehicle Type";
    values[] = {0, 1, 2, 3, 4, 5};
    texts[] = {"No Vehicles", "Quadbike", "Hatchback (Sport)", "Ifrit", "Hunter", "Strider"};
    default = 0;
};
class vehicleAmount {
    title = "Vehicle Amount";
    values[] = {0, 1, 2};
    texts[] = {"One per Team", "One per 2 Players, but at least one", "One per Player"};
    default = 1;
};
class specSettings {
    title = "Spectator Settings";
    values[] = {0, 1};
    texts[] = {"Own Team", "Everyone"};
    default = 0;
};
class winCondition {
    title = "Win Condition";
    values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    texts[] = {"Best of 1", "Best of 3", "Best of 5", "Best of 7", "Best of 11", "Best of 15", "Best of 23", "Best of 31", "Best of 47", "Best of 63", "Best of 127"};
    default = 7;
};
class requireLeadOfTwoPoints {
    title = "Require Lead of two Points";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 1;
};
CMN_PARAM_MAP_SIZE
