class ai {
    title = "AI Amount";
    values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8};
    texts[] = {"Fill to equalize unit count", "Fill to Map Size", "Fill upto 2", "Fill upto 3", "Fill upto 4", "Fill upto 5", "Fill upto 6", "Fill upto 7", "Fill upto 8"};
    default = 1;
};
class autoHeal {
    title = "Automatic Healing";
    values[] = {0, 1};
    texts[] = {"Disabled", "Enabled"};
    default = 1;
};
class weather {
    title = "Weather";
    values[] = {0, 1, 2, 3, 4};
    texts[] = {"Dynamic", "Dynamic Foggy", "Sun", "Clouds", "Storm"};
    default = 0;
};
class skipNight {
    title = "Skip Night";
    values[] = {0, 1};
    texts[] = {"Enabled", "Disabled"};
    default = 1;
};
class startTime {
    title = "Start Time";
    values[] = {0, 1, 2, 3};
    texts[] = {"Morning", "Noon", "Evening", "Night"};
    default = 0;
};
class timeMultiplierDay {
    title = "Time Multiplier (Day)";
    values[] = {0, 1, 2, 3, 4, 5, 6};
    texts[] = {"0.1", "1", "10", "20", "40", "80", "120"};
    default = 4;
};
class timeMultiplierNight {
    title = "Time Multiplier (Night)";
    values[] = {0, 1, 2, 3, 4, 5, 6};
    texts[] = {"0.1", "1", "10", "20", "40", "80", "120"};
    default = 6;
};
class zoneShrinkSpeed {
    title = "Zone shrink speed";
    values[] = {0, 1, 2, 3};
    texts[] = {"Slow", "Normal", "Fast", "Disabled"};
    default = 1;
};
class warmupTime {
    title = "Warmup Time";
    values[] = {30, 60, 120, 180};
    texts[] = {"30 seconds", "60 seconds", "120 seconds", "180 seconds"};
    default = 120;
};
class 3rdPerson
{
    title = "3rd Person";
    values[] = {0, 1};
    texts[] = {"Allowed", "Not allowed"};
    default = 0;
};
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
    texts[] = {"Enabled", "Disabled"};
    default = 0;
};