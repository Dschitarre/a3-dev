// GunGame lobby params (placed after the Map param, see Description.ext).
// mapSize/weather/startTime/timeMultiplier*/skipNight/thirdPerson/aiSkill come from common\config.hpp.
CMN_PARAM_MAP_SIZE
class teamMode {
    title = "Mode";
    values[] = {0, 1};
    texts[] = {"Free for all", "Team GunGame (two teams, shared ladder)"};
    default = 0;
};
class ai {
    title = "AI Amount";
    values[] = {0, 1, 2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 46};
    texts[] = {"Auto (zone size)", "Off", "Fill up to 2", "Fill up to 4", "Fill up to 6", "Fill up to 8", "Fill up to 10", "Fill up to 12", "Fill up to 16", "Fill up to 20", "Fill up to 24", "Fill up to 32", "Fill up to 46"};
    default = 0;
};
CMN_PARAM_AI_SKILL
class ladderTheme {
    title = "Weapons";
    values[] = {0, 1, 2, 3, 4, 5};
    texts[] = {"Mixed", "Assault rifles", "Sniper rifles", "Machine guns", "Close quarters (SMGs, shotguns, pistols)", "Pistols"};
    default = 0;
};
class ladderLength {
    title = "Ladder length";
    values[] = {0, 1, 2};
    texts[] = {"Full", "Half", "Short"};
    default = 0;
};
class killsPerStage {
    title = "Kills per weapon";
    values[] = {1, 2, 3};
    texts[] = {"1", "2", "3"};
    default = 1;
};
class demotion {
    title = "Suicide costs a weapon";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 0;
};
CMN_PARAM_SKIP_NIGHT
CMN_PARAM_START_TIME
CMN_PARAM_TIME_MULTIPLIER_DAY(3)
CMN_PARAM_TIME_MULTIPLIER_NIGHT
CMN_PARAM_WEATHER
CMN_PARAM_THIRD_PERSON
