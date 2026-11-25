// HUD (client): sector overview with the capture info, player stats and group overview. Created with cutRsc by
// SC_fnc_setHud; positions, sizes and colors are set by script (SC\hud\hud.sqf: SC_fnc_hudUpdateSectorOverview,
// SC_fnc_hudUpdateCaptureInfo, SC_fnc_hudUpdateGroupOverview, SC_fnc_hudUpdatePlayerStats).
// Controls draw in this order: backgrounds and bars first, then frames, pictures and texts last, so that no bar or
// background ever covers a text.
#define SC_HUD_CONTROL(PNAME, PBASE, PIDC) \
    class PNAME: PBASE { \
        idc = PIDC; \
    };

#define SC_HUD_TEXT(PNAME, PBASE, PIDC, PTEXT) \
    class PNAME: PBASE { \
        idc = PIDC; \
        text = PTEXT; \
    };

// one row of the group overview (background, health bar, pictures, texts): idcs PIDC0 - PIDC7, the offsets of
// SC_var_groupRowColumns in SC\hud\hud.sqf
#define SC_HUD_GROUP_ROW(PROW, PIDC) \
    class groupBackground##PROW: SC_HudShade { \
        idc = PIDC##0; \
    }; \
    class groupHealth##PROW: SC_HudHealth { \
        idc = PIDC##1; \
    }; \
    class groupRoleIcon##PROW: SC_HudPicture { \
        idc = PIDC##3; \
    }; \
    class groupVehicle##PROW: SC_HudPictureKeepAspect { \
        idc = PIDC##6; \
    }; \
    class groupRank##PROW: SC_HudText { \
        idc = PIDC##4; \
    }; \
    class groupName##PROW: SC_HudTextLeft { \
        idc = PIDC##5; \
    }; \
    class groupValue##PROW: SC_HudTextRight { \
        idc = PIDC##7; \
    };

class sectorControlDisplay {
    idd = 5000;
    movingEnable = 0;
    enableSimulation = 1;
    duration = 999999;
    fadeIn = 0;
    fadeOut = 0;
    onLoad = "uiNamespace setVariable [""SC_var_sectorControlDisplay"", _this select 0]";

    class ControlsBackground {
        // ---- backgrounds and bars (boxes that carry their own text first) ----
        // rank and perks grey like the fill of the bars (user decision 2026-11-13)
        SC_HUD_TEXT(rankText, SC_HudBarFill, 1005, "Rank: 1")
        SC_HUD_TEXT(bluforScoreText, SC_HudPanel, 1002, "0")
        SC_HUD_TEXT(opforScoreText, SC_HudPanel, 1003, "0")
        SC_HUD_TEXT(independentScoreText, SC_HudPanel, 1004, "0")
        SC_HUD_CONTROL(perk1Text, SC_HudBarFill, 6001)
        SC_HUD_CONTROL(perk2Text, SC_HudBarFill, 6002)
        SC_HUD_CONTROL(perk3Text, SC_HudBarFill, 6003)
        SC_HUD_CONTROL(perk4Text, SC_HudBarFill, 6004)
        SC_HUD_CONTROL(perk5Text, SC_HudBarFill, 6005)
        SC_HUD_CONTROL(perk6Text, SC_HudBarFill, 6006)
        // bars: the whole bar on the panel color, the fill in the accent color over it (its width set by script)
        SC_HUD_CONTROL(xpPanel, SC_HudPanel, 1804)
        SC_HUD_CONTROL(hpPanel, SC_HudPanel, 1803)
        SC_HUD_CONTROL(staminaPanel, SC_HudPanel, 5735)
        SC_HUD_CONTROL(spawnVehiclePanel0, SC_HudPanel, 9420)
        SC_HUD_CONTROL(spawnVehiclePanel1, SC_HudPanel, 9421)
        SC_HUD_CONTROL(spawnVehiclePanel2, SC_HudPanel, 9422)
        SC_HUD_CONTROL(xpBackground, SC_HudBarFill, 998)
        SC_HUD_CONTROL(hpBackground, SC_HudHpFill, 999)
        SC_HUD_CONTROL(staminaBackground, SC_HudBarFill, 5005)
        SC_HUD_CONTROL(spawnVehicleHp0, SC_HudBarFill, 9410)
        SC_HUD_CONTROL(spawnVehicleHp1, SC_HudBarFill, 9411)
        SC_HUD_CONTROL(spawnVehicleHp2, SC_HudBarFill, 9412)
        SC_HUD_CONTROL(numEntitiesBackgroundWest, SC_HudPanel, 2000)
        SC_HUD_CONTROL(numEntitiesBackgroundEast, SC_HudPanel, 2001)
        SC_HUD_CONTROL(numEntitiesBackgroundGuer, SC_HudPanel, 2002)
        SC_HUD_CONTROL(rateBackgroundWest, SC_HudPanel, 9110)
        SC_HUD_CONTROL(rateBackgroundEast, SC_HudPanel, 9111)
        SC_HUD_CONTROL(rateBackgroundGuer, SC_HudPanel, 9112)
        SC_HUD_CONTROL(sectorAUpperColor, SC_HudSectorRemaining, 1020)
        SC_HUD_CONTROL(sectorBUpperColor, SC_HudSectorRemaining, 1021)
        SC_HUD_CONTROL(sectorCUpperColor, SC_HudSectorRemaining, 1022)
        SC_HUD_CONTROL(sectorDUpperColor, SC_HudSectorRemaining, 1023)
        SC_HUD_CONTROL(sectorEUpperColor, SC_HudSectorRemaining, 1024)
        SC_HUD_CONTROL(sectorFUpperColor, SC_HudSectorRemaining, 1025)
        SC_HUD_CONTROL(sectorGUpperColor, SC_HudSectorRemaining, 1026)
        SC_HUD_CONTROL(sectorHUpperColor, SC_HudSectorRemaining, 1027)
        SC_HUD_CONTROL(sectorIUpperColor, SC_HudSectorRemaining, 1028)
        SC_HUD_CONTROL(sectorJUpperColor, SC_HudSectorRemaining, 1029)
        SC_HUD_CONTROL(sectorKUpperColor, SC_HudSectorRemaining, 1030)
        SC_HUD_CONTROL(sectorLUpperColor, SC_HudSectorRemaining, 1031)
        SC_HUD_CONTROL(sectorMUpperColor, SC_HudSectorRemaining, 1032)
        SC_HUD_CONTROL(sectorNUpperColor, SC_HudSectorRemaining, 1033)
        SC_HUD_CONTROL(sectorOUpperColor, SC_HudSectorRemaining, 1034)
        SC_HUD_CONTROL(sectorPUpperColor, SC_HudSectorRemaining, 1035)
        SC_HUD_CONTROL(sectorQUpperColor, SC_HudSectorRemaining, 1036)
        SC_HUD_CONTROL(sectorRUpperColor, SC_HudSectorRemaining, 1037)
        SC_HUD_CONTROL(sectorSUpperColor, SC_HudSectorRemaining, 1038)
        SC_HUD_CONTROL(sectorTUpperColor, SC_HudSectorRemaining, 1039)
        SC_HUD_CONTROL(sectorALowerColor, SC_HudSectorRemaining, 8030)
        SC_HUD_CONTROL(sectorBLowerColor, SC_HudSectorRemaining, 8031)
        SC_HUD_CONTROL(sectorCLowerColor, SC_HudSectorRemaining, 8032)
        SC_HUD_CONTROL(sectorDLowerColor, SC_HudSectorRemaining, 8033)
        SC_HUD_CONTROL(sectorELowerColor, SC_HudSectorRemaining, 8034)
        SC_HUD_CONTROL(sectorFLowerColor, SC_HudSectorRemaining, 8035)
        SC_HUD_CONTROL(sectorGLowerColor, SC_HudSectorRemaining, 8036)
        SC_HUD_CONTROL(sectorHLowerColor, SC_HudSectorRemaining, 8037)
        SC_HUD_CONTROL(sectorILowerColor, SC_HudSectorRemaining, 8038)
        SC_HUD_CONTROL(sectorJLowerColor, SC_HudSectorRemaining, 8039)
        SC_HUD_CONTROL(sectorKLowerColor, SC_HudSectorRemaining, 8040)
        SC_HUD_CONTROL(sectorLLowerColor, SC_HudSectorRemaining, 8041)
        SC_HUD_CONTROL(sectorMLowerColor, SC_HudSectorRemaining, 8042)
        SC_HUD_CONTROL(sectorNLowerColor, SC_HudSectorRemaining, 8043)
        SC_HUD_CONTROL(sectorOLowerColor, SC_HudSectorRemaining, 8044)
        SC_HUD_CONTROL(sectorPLowerColor, SC_HudSectorRemaining, 8045)
        SC_HUD_CONTROL(sectorQLowerColor, SC_HudSectorRemaining, 8046)
        SC_HUD_CONTROL(sectorRLowerColor, SC_HudSectorRemaining, 8047)
        SC_HUD_CONTROL(sectorSLowerColor, SC_HudSectorRemaining, 8048)
        SC_HUD_CONTROL(sectorTLowerColor, SC_HudSectorRemaining, 8049)
        SC_HUD_CONTROL(capturePanel, SC_HudPanel, 9120)
        SC_HUD_CONTROL(captureProgress, SC_HudText, 9123)
        // ---- frames and lines ----
        SC_HUD_CONTROL(frame1807, SC_HudLine, 1807)
        SC_HUD_CONTROL(frame1808, SC_HudLine, 1808)
        SC_HUD_CONTROL(frame1809, SC_HudLine, 1809)
        SC_HUD_CONTROL(frame1810, SC_HudLine, 1810)
        SC_HUD_CONTROL(frame1811, SC_HudLine, 1811)
        SC_HUD_CONTROL(frame1812, SC_HudLine, 1812)
        SC_HUD_CONTROL(frame1813, SC_HudLine, 1813)
        SC_HUD_CONTROL(frame1814, SC_HudLine, 1814)
        SC_HUD_CONTROL(frame1815, SC_HudLine, 1815)
        SC_HUD_CONTROL(frame1816, SC_HudLine, 1816)
        SC_HUD_CONTROL(frame1817, SC_HudLine, 1817)
        SC_HUD_CONTROL(frame1818, SC_HudLine, 1818)
        SC_HUD_CONTROL(frame1819, SC_HudLine, 1819)
        SC_HUD_CONTROL(frame1820, SC_HudLine, 1820)
        SC_HUD_CONTROL(frame1821, SC_HudLine, 1821)
        SC_HUD_CONTROL(frame1822, SC_HudLine, 1822)
        SC_HUD_CONTROL(frame1823, SC_HudLine, 1823)
        SC_HUD_CONTROL(frame1824, SC_HudLine, 1824)
        SC_HUD_CONTROL(frame1825, SC_HudLine, 1825)
        SC_HUD_CONTROL(frame1826, SC_HudLine, 1826)
        SC_HUD_CONTROL(frame1910, SC_HudFrame, 1910)
        SC_HUD_CONTROL(frame1911, SC_HudFrame, 1911)
        SC_HUD_CONTROL(frame1912, SC_HudFrame, 1912)
        SC_HUD_CONTROL(frame1913, SC_HudFrame, 1913)
        SC_HUD_CONTROL(frame1914, SC_HudFrame, 1914)
        SC_HUD_CONTROL(frame1915, SC_HudFrame, 1915)
        SC_HUD_CONTROL(frame1916, SC_HudFrame, 1916)
        SC_HUD_CONTROL(frame1917, SC_HudFrame, 1917)
        SC_HUD_CONTROL(frame1918, SC_HudFrame, 1918)
        SC_HUD_CONTROL(frame1919, SC_HudFrame, 1919)
        SC_HUD_CONTROL(frame1920, SC_HudFrame, 1920)
        SC_HUD_CONTROL(frame1921, SC_HudFrame, 1921)
        SC_HUD_CONTROL(frame1922, SC_HudFrame, 1922)
        SC_HUD_CONTROL(frame1923, SC_HudFrame, 1923)
        SC_HUD_CONTROL(frame1924, SC_HudFrame, 1924)
        SC_HUD_CONTROL(frame1925, SC_HudFrame, 1925)
        SC_HUD_CONTROL(frame1926, SC_HudFrame, 1926)
        SC_HUD_CONTROL(frame1927, SC_HudFrame, 1927)
        SC_HUD_CONTROL(frame1928, SC_HudFrame, 1928)
        SC_HUD_CONTROL(frame1929, SC_HudFrame, 1929)
        SC_HUD_CONTROL(captureFrame, SC_HudFrame, 9127)
        // ---- pictures ----
        // row symbols left of the side columns of the player stats: person (unit counts), points, arrow up (points per
        // minute)
        SC_HUD_TEXT(unitIconWest, SC_HudPictureKeepAspect, 2009, "SC\hud\person_ca.paa")
        SC_HUD_TEXT(pointsIcon, SC_HudPictureKeepAspect, 9495, "SC\hud\points_ca.paa")
        SC_HUD_TEXT(pointsRateArrow, SC_HudPictureKeepAspect, 9497, "SC\hud\increase_ca.paa")
        SC_HUD_TEXT(unitIconEast, SC_HudPictureKeepAspect, 2010, "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa")
        SC_HUD_TEXT(unitIconGuer, SC_HudPictureKeepAspect, 2011, "\A3\Ui_f\data\GUI\Rsc\RscDisplayMain\profile_player_ca.paa")
        SC_HUD_TEXT(vehicleIconWest, SC_HudPictureKeepAspect, 2012, "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\car_ca.paa")
        SC_HUD_TEXT(vehicleIconEast, SC_HudPictureKeepAspect, 2013, "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\car_ca.paa")
        SC_HUD_TEXT(vehicleIconGuer, SC_HudPictureKeepAspect, 2014, "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\car_ca.paa")
        // NATO frame symbols of the sides above their columns of the player stats (SC\hud\side_*_ca.paa: white fill with
        // a dark frame, colored and made transparent by script)
        SC_HUD_TEXT(sideSymbolWest, SC_HudPictureKeepAspect, 9490, "SC\hud\side_west_ca.paa")
        SC_HUD_TEXT(sideSymbolEast, SC_HudPictureKeepAspect, 9491, "SC\hud\side_east_ca.paa")
        SC_HUD_TEXT(sideSymbolGuer, SC_HudPictureKeepAspect, 9492, "SC\hud\side_guer_ca.paa")
        // round panels behind the direction arrows of the spawn vehicles
        SC_HUD_CONTROL(spawnVehicleCircle0, SC_HudCircle, 9460)
        SC_HUD_CONTROL(spawnVehicleCircle1, SC_HudCircle, 9461)
        SC_HUD_CONTROL(spawnVehicleCircle2, SC_HudCircle, 9462)
        // direction arrows (SC\hud\pointer_ca.paa: a plain arrow pointing up in the middle two thirds of its texture,
        // so nothing of it is cut off when it is turned), turned towards the spawn vehicles
        SC_HUD_TEXT(spawnVehicleCompass0, SC_HudPictureKeepAspect, 9440, "SC\hud\pointer_ca.paa")
        SC_HUD_TEXT(spawnVehicleCompass1, SC_HudPictureKeepAspect, 9441, "SC\hud\pointer_ca.paa")
        SC_HUD_TEXT(spawnVehicleCompass2, SC_HudPictureKeepAspect, 9442, "SC\hud\pointer_ca.paa")
        // ---- texts ----
        SC_HUD_TEXT(xpText, SC_HudText, 1000, "XP: 0/600")
        SC_HUD_TEXT(hpText, SC_HudText, 1001, "HP: 0")
        SC_HUD_TEXT(staminaText, SC_HudText, 5006, "Stamina")
        SC_HUD_CONTROL(numUnitsTextWest, SC_HudText, 2003)
        SC_HUD_CONTROL(numUnitsTextEast, SC_HudText, 2004)
        SC_HUD_CONTROL(numUnitsTextGuer, SC_HudText, 2005)
        SC_HUD_CONTROL(numVehiclesTextWest, SC_HudText, 2006)
        SC_HUD_CONTROL(numVehiclesTextEast, SC_HudText, 2007)
        SC_HUD_CONTROL(numVehiclesTextGuer, SC_HudText, 2008)
        SC_HUD_CONTROL(rateTextWest, SC_HudText, 9130)
        SC_HUD_CONTROL(rateTextEast, SC_HudText, 9131)
        SC_HUD_CONTROL(rateTextGuer, SC_HudText, 9132)
        SC_HUD_CONTROL(spawnVehicleLabel0, SC_HudText, 9430)
        SC_HUD_CONTROL(spawnVehicleLabel1, SC_HudText, 9431)
        SC_HUD_CONTROL(spawnVehicleLabel2, SC_HudText, 9432)
        SC_HUD_CONTROL(spawnVehicleTimer0, SC_HudTextRight, 9450)
        SC_HUD_CONTROL(spawnVehicleTimer1, SC_HudTextRight, 9451)
        SC_HUD_CONTROL(spawnVehicleTimer2, SC_HudTextRight, 9452)
        SC_HUD_TEXT(sectorAText, SC_HudSectorLetter, 3040, "A")
        SC_HUD_TEXT(sectorBText, SC_HudSectorLetter, 3041, "B")
        SC_HUD_TEXT(sectorCText, SC_HudSectorLetter, 3042, "C")
        SC_HUD_TEXT(sectorDText, SC_HudSectorLetter, 3043, "D")
        SC_HUD_TEXT(sectorEText, SC_HudSectorLetter, 3044, "E")
        SC_HUD_TEXT(sectorFText, SC_HudSectorLetter, 3045, "F")
        SC_HUD_TEXT(sectorGText, SC_HudSectorLetter, 3046, "G")
        SC_HUD_TEXT(sectorHText, SC_HudSectorLetter, 3047, "H")
        SC_HUD_TEXT(sectorIText, SC_HudSectorLetter, 3048, "I")
        SC_HUD_TEXT(sectorJText, SC_HudSectorLetter, 3049, "J")
        SC_HUD_TEXT(sectorKText, SC_HudSectorLetter, 3050, "K")
        SC_HUD_TEXT(sectorLText, SC_HudSectorLetter, 3051, "L")
        SC_HUD_TEXT(sectorMText, SC_HudSectorLetter, 3052, "M")
        SC_HUD_TEXT(sectorNText, SC_HudSectorLetter, 3053, "N")
        SC_HUD_TEXT(sectorOText, SC_HudSectorLetter, 3054, "O")
        SC_HUD_TEXT(sectorPText, SC_HudSectorLetter, 3055, "P")
        SC_HUD_TEXT(sectorQText, SC_HudSectorLetter, 3056, "Q")
        SC_HUD_TEXT(sectorRText, SC_HudSectorLetter, 3057, "R")
        SC_HUD_TEXT(sectorSText, SC_HudSectorLetter, 3058, "S")
        SC_HUD_TEXT(sectorTText, SC_HudSectorLetter, 3059, "T")
        SC_HUD_CONTROL(captureProgressText, SC_HudText, 9124)
        SC_HUD_CONTROL(captureState, SC_HudTextLeft, 9125)
        SC_HUD_CONTROL(captureRatio, SC_HudStructuredText, 9126)
        // after the capture panel (9120): drawn over it, the holder color is not dimmed by the panel
        SC_HUD_CONTROL(captureSector, SC_HudText, 9121)
        // ---- group overview (rows don't overlap other elements) ----
        SC_HUD_GROUP_ROW(0, 920)
        SC_HUD_GROUP_ROW(1, 921)
        SC_HUD_GROUP_ROW(2, 922)
        SC_HUD_GROUP_ROW(3, 923)
        SC_HUD_GROUP_ROW(4, 924)
        SC_HUD_GROUP_ROW(5, 925)
        SC_HUD_GROUP_ROW(6, 926)
        SC_HUD_GROUP_ROW(7, 927)
        SC_HUD_GROUP_ROW(8, 928)
        SC_HUD_GROUP_ROW(9, 929)
#ifdef WARFARE_EXTRA_HUD_CONTROLS
        WARFARE_EXTRA_HUD_CONTROLS
#endif
    };
};
