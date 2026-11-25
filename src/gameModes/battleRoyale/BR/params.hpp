// Battle Royale lobby params. CMN_PARAM_* come from common\config.hpp (included in Description.ext).
class teamSize {
    title = "Team Size";
    values[] = {1, 2, 4};
    texts[] = {"Solo", "Duo", "Squad (4)"};
    default = 1;
};
class aiFill {
    title = "AI Fill (slots and teams without players)";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 1;
};
// 0 Auto: by the map's land area, up to 150 participants. Non-playable editor leaders never count.
class combatants {
    title = "Combatants (players + AI)";
    values[] = {0, 8, 12, 16, 24, 32, 40, 60, 100, 150};
    texts[] = {"Auto (by map)", "8", "12", "16", "24", "32", "40", "60", "100", "150"};
    default = 0;
};
CMN_PARAM_AI_SKILL
class warmupTime {
    title = "Warmup Time";
    values[] = {30, 60, 120, 180};
    texts[] = {"30 seconds", "60 seconds", "120 seconds", "180 seconds"};
    default = 60;
};
class teamJump {
    title = "Team Jump";
    values[] = {0, 1};
    texts[] = {"Individually", "Together"};
    default = 0;
};
class zoneSpeed {
    title = "Zone Speed";
    values[] = {0, 1, 2};
    texts[] = {"Slow", "Normal", "Fast"};
    default = 1;
};
class lootAmount {
    title = "Loot Amount";
    values[] = {0, 1, 2};
    texts[] = {"Low", "Normal", "High"};
    default = 1;
};
class vehicleAmount {
    title = "Vehicles";
    values[] = {0, 6, 12, 20};
    texts[] = {"None", "Few", "Normal", "Many"};
    default = 12;
};
class airdrops {
    title = "Supply Drops";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 1;
};
CMN_PARAM_WEATHER
CMN_PARAM_START_TIME
CMN_PARAM_TIME_MULTIPLIER_DAY(1)
CMN_PARAM_TIME_MULTIPLIER_NIGHT
CMN_PARAM_THIRD_PERSON
