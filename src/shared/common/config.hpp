// Shared TDM/GunGame lobby params as macros, so each mode keeps its own param order inside class Params.
// #include from Description.ext after ui\ui.hpp. Keep param class names and values[] stable (server.cfg sets Params
// by value); on/off params use 1 = feature on.

#define CMN_PARAM_WEATHER class weather { title = "Weather"; values[] = {0, 1, 2, 3, 4, 5}; texts[] = {"Dynamic", "Dynamic Foggy", "Sun", "Clouds", "Storm", "Rain"}; default = 0; };

#define CMN_PARAM_START_TIME class startTime { title = "Start Time"; values[] = {0, 1, 2, 3}; texts[] = {"Morning", "Noon", "Evening", "Night"}; default = 0; };

#define CMN_PARAM_TIME_MULTIPLIER_DAY(DEFAULT_VALUE) class timeMultiplierDay { title = "Time Multiplier (Day)"; values[] = {0, 1, 2, 3, 4, 5, 6}; texts[] = {"0.1", "1", "10", "20", "40", "80", "120"}; default = DEFAULT_VALUE; };

#define CMN_PARAM_TIME_MULTIPLIER_NIGHT class timeMultiplierNight { title = "Time Multiplier (Night)"; values[] = {0, 1, 2, 3, 4, 5, 6}; texts[] = {"0.1", "1", "10", "20", "40", "80", "120"}; default = 6; };

#define CMN_PARAM_SKIP_NIGHT class skipNight { title = "Skip Night"; values[] = {0, 1}; texts[] = {"Disabled", "Enabled"}; default = 0; };

#define CMN_PARAM_THIRD_PERSON class thirdPerson { title = "Third Person"; values[] = {0, 1}; texts[] = {"Disabled", "Enabled"}; default = 1; };

// read by CMN_fnc_mapsOfWantedSize (common\world.sqf): random maps and map vote candidates of this size
#define CMN_PARAM_MAP_SIZE class mapSize { title = "Map size"; values[] = {0, 1, 2, 3}; texts[] = {"Auto (by player count)", "Small", "Medium", "Large"}; default = 0; };

// the same with a fourth size, the whole map (modes with areas up to the whole island: Battle Royale); PDEFAULT 0 - 4
#define CMN_PARAM_MAP_SIZE_HUGE(PDEFAULT) class mapSize { title = "Map size"; values[] = {0, 1, 2, 3, 4}; texts[] = {"Auto (by player count)", "Small", "Medium", "Large", "Huge (whole map)"}; default = PDEFAULT; };

// read by CMN_fnc_aiSkillLevel (common\units.sqf); Normal is the skill range the modes always had
#define CMN_PARAM_AI_SKILL class aiSkill { title = "AI Skill"; values[] = {0, 1, 2}; texts[] = {"Easy", "Normal", "Hard"}; default = 1; };
