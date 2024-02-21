class infoDialog {
    idd = 3000;
    movingenable = true;
    enableSimulation = true;
    duration = 999999;
    fadein = 0;
    fadeout = 0;
    onLoad = "uiNamespace setVariable [""SC_var_infoDialog"",_this select 0]";
    class ControlsBackground {
        class RscStructuredText_1101 : RscStructuredText {
            idc = 1101;
            style = ST_LEFT;
            text = "";
            x = 0.396875 * safezoneW + safezoneX;
            y = 0.343 * safezoneH + safezoneY;
            w = 0.20625 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {0.61, 0.41, 0.06, 0.9};
        };
        class RscListbox_1500 : RscListbox {
            style = ST_LEFT;
            text = "Hotkeys:";
            idc = 1500;
            x = 0.396875 * safezoneW + safezoneX;
            y = 0.368 * safezoneH + safezoneY;
            w = 0.20625 * safezoneW;
            h = 0.242 * safezoneH;
            colorBackground[] = {-1, -1, -1, 0.8};
        };
    };
    class controls {
        class RscButton : RscButton {
            Text = "OK";
            idc = 4504;
            style = ST_LEFT;
            x = 0.561875 * safezoneW + safezoneX;
            y = 0.612 * safezoneH + safezoneY;
            w = 0.04125 * safezoneW;
            h = 0.022 * safezoneH;
            colorBackground[] = {-1, -1, -1, 0.8};
            colorText[] = {1, 1, 1, 1};
            SizeEx = 0.045;
            action = "closedialog 0;";
        };
    };
};

hotkeys[] = {
    "F1: Earplugs",
    "F2: Toggle HUD",
    "F3: Toggle GPS-/vehicle panel",
    "F4: Settings",
    "V: Jump",
    "U: Group System",
    "H: Holster/unholster weapon"
};

gameMode[] = {
    "The more sectors your team holds, the more points it",
    "gains per time. You can respawn on sectors captured",
    "by your team. The first team reaching 100 points wins.",
    "Without the Medic Perk, you can only revive groupmates.",
    "With the Medic Perk, you can revive any teammate."
};

ranksystem[] = {
    "Decapturing/capturing sectors gives XP. Reviving",
    "teammates, killing and assisting to kill enemies",
    "adds XP. There are 1000 ranks. By ranking up you",
    "gain access to better equipment, vehicles and perks.",
    "The number of perksyou can choose also rises with",
    "your rank.",
    "",
    "The number of available perks by rank:",
    "  -Ranks 1-5: 1 Perk",
    "  -Ranks 6-17: 2 Perks",
    "  -Ranks 18-34: 3 Perks",
    "  -Ranks 35-66: 4 Perks",
    "  -Ranks 67-99: 5 Perks",
    "  -Rank 100+: 6 Perks"
};

perks[] = {
    "Experience [EXPR] (requires Rank 1):",
    "     -increases the amount of XP earned by 50%",
    "Medic [MEDC] (requires Rank 5):",
    "     -grants access to the Medikit",
    "     -allows you to revive all teammates",
    "Stamina [STAM] (requires Rank 5):",
    "     -doubles your stamina capacity",
    "Marksman [MRKS] (requires Rank 7):",
    "     -grants access to marksman rifles and",
    "      ghillie suits",
    "Machinegunner [MGNR] (requires Rank 10):",
    "     -grants access to machineguns",
    "Launcher [LNCR] (requires Rank 15):",
    "     -grants access to missile launchers",
    "Armor [ARMR] (requires Rank 18):",
    "     -grants access to vests and helmets with",
    "      armor level IV and V",
    "Grenadier [GRND] (requires Rank 20):",
    "     -grants access to underbarrel grenade",
    "      launchers",
    "Suppressor [SUPR] (requires Rank 25):",
    "     -grants access to suppressors"
};

vehiclesystem[] = {
    "You can spawn vehicles at the base (and on sectors",
    "captured by your team, if enabled). If the rank sys-",
    "tem has been enabled, you gain access to better ve-",
    "hicles by ranking up. After spawning one, a five",
    "minute cooldown starts. On huge maps, you can also",
    "spawn vehicles at airfields within the playzone."
};

airdrops[] = {
    "Airdrops containing equipment are dispatched on cap-",
    "tured sectors and randomly in the playzone."
};