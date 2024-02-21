class Params {
    class Map {
        title = "Map";
        values[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44};
        texts[] = {
            "Random",
            "Zaros",
            "Agios Dionysios",
            "Telos",
            "Kavala",
            "Kalochori",
            "Panagia",
            "Selakano",
            "GhostHotel",
            "Antharkia",
            "Kore",
            "Negades",
            "Panochori",
            "Therisa",
            "Poliakko",
            "Katalaki",
            "Alikampos Factory",
            "Alikampos",
            "Neochori",
            "Stavros",
            "Lakka",
            "Lakka Factory",
            "Syrta",
            "Galati",
            "Abdera",
            "Agios Konstantinos",
            "Oreokastro",
            "Frini",
            "Athira",
            "Gravia",
            "Airfield Harbor",
            "Rodopoli",
            "Charkia",
            "Pyrgos",
            "Dorida",
            "Chalkeia",
            "Feres",
            "Paros",
            "Military Base Agios Georgios",
            "Sofia",
            "Molos",
            "Neri",
            "Neri Beach",
            "Kavala City",
            "Aggelochori"
        };
        default = 0;
    };
    class skipNight {
        title = "Skip Night";
        values[] = {0, 1};
        texts[] = {"Disabled", "Enabled"};
        default = 0;
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
        default = 3;
    };
    class timeMultiplierNight {
        title = "Time Multiplier (Night)";
        values[] = {0, 1, 2, 3, 4, 5, 6};
        texts[] = {"0.1", "1", "10", "20", "40", "80", "120"};
        default = 6;
    };
    class weather {
        title = "Weather";
        values[] = {0, 1, 2, 3, 4};
        texts[] = {"Dynamic", "Dynamic Foggy", "Sun", "Clouds", "Storm"};
        default = 0;
    };
    class thirdPerson {
        title = "Third Person";
        values[] = {0, 1};
        texts[] = {"Disabled", "Enabled"};
        default = 1;
    };
};