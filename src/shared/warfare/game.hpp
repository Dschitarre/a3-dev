// Debriefings and notification templates.

class CfgDebriefing {
    class end_west {
        title = "Blufor won";
        description = "Blufor reached point limit.";
    };
    class end_east {
        title = "Opfor won";
        description = "Opfor reached point limit.";
    };
    class end_guer {
        title = "Independent won";
        description = "Independent reached point limit.";
    };
};

class CfgNotifications {
    // defaults of all SC notifications (text in the player's HUD color)
    class SC_Notification {
        color[] = UI_COLOR_HUD_TEXT;
        duration = 5;
        priority = 0;
    };

    class captured: SC_Notification {
        title = "Sector Control";
        iconPicture = "\A3\ui_f\data\Map\VehicleIcons\iconLogic_ca.paa";
        description = "%1 captured %2";
    };

    class inventoryDisabled: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You are not allowed to access your inventory in the Base.";
    };

    class loadoutNotSaved: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Loadout was not saved. Some items are not unlocked in your class/lvl";
        duration = 7;
    };

    class medicSystem: SC_Notification {
        title = "Medic System";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Cursors\unitHealer_ca.paa";
        description = "%1";
    };

    class bledOut: SC_Notification {
        title = "Medic System";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Cursors\unitBleeding_ca.paa";
        description = "You bled out.";
    };

    class finallyKilled: SC_Notification {
        title = "Medic System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You were finally killed.";
    };

    class loadoutLoaded: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa";
        description = "Loadout loaded";
        duration = 3;
    };

    class magsFilled: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa";
        description = "Magazines filled";
        duration = 3;
    };

    class noMags: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You do not have any magazines";
        duration = 3;
    };

    class loadoutSaved: SC_Notification {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa";
        description = "Loadout was saved";
        duration = 3;
    };

    class healed: SC_Notification {
        title = "Base";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Actions\heal_ca.paa";
        description = "Healed";
        duration = 3;
    };

    class vehiclesystem: SC_Notification {
        title = "Vehicle System";
        iconPicture = "\A3\ui_f\data\Map\Markers\NATO\c_car.paa";
        description = "%1";
    };

    class vehicleCooldown: SC_Notification {
        title = "Vehicle System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "%1";
    };

    class spawnProtectionDisabled: SC_Notification {
        title = "Spawn Protection";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Spawnprotection disabled";
        duration = 3;
    };

    class outsidePlayzone: SC_Notification {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Go back into the playZone or you will die in 30 seconds";
        priority = 1;
    };

    class inEnemyBase: SC_Notification {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Leave the enemy base or you will die in 15 seconds";
        priority = 1;
    };

    class backInPlayzone: SC_Notification {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa";
        description = "You are back in the playzone";
        priority = 1;
    };

    class rankUp: SC_Notification {
        title = "Rank System";
        iconText = "%1";
        description = "You ranked up";
        duration = 3;
        priority = 1;
    };

    class airDrop: SC_Notification {
        title = "Airdrop";
        iconPicture = "\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa";
        description = "An airdrop has been dispatched";
        priority = 1;
    };

    class sideAirDrop: SC_Notification {
        title = "Airdrop";
        iconPicture = "\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa";
        description = "%1 receive a supplydrop at %2";
        priority = 1;
    };

    class groupMateSpawned: SC_Notification {
        title = "Group System";
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa";
        description = "Your groupmate %1 spawned %2";
        duration = 3;
        priority = 1;
    };

    // group menu (SC\groupMenu.sqf): joined, left, kicked, locked; the icon of the vanilla Dynamic Groups notifications
    class groupSystem: SC_Notification {
        title = "Group System";
        iconPicture = "\A3\ui_f\data\GUI\Cfg\Ranks\general_gs.paa";
        description = "%1";
        duration = 3;
        priority = 1;
    };
};
