class CfgNotifications {
    class captured {
        title = "Sector Control";
        iconPicture = "\A3\ui_f\data\Map\VehicleIcons\iconLogic_ca.paa";
        description = "%1 captured %2";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class inventoryDisabled {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You are not allowed to access your inventory in the Base.";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class loadoutNotSaved {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Loadout was not saved. Some items are not unlocked in your class/lvl";
        color[] = {1, 1, 1, 1};
        duration = 7;
        priority = 0;
    };
    class medicSystem {
        title = "Medic System";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Cursors\unitHealer_ca.paa";
        description = "%1";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class bledOut {
        title = "Medic System";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Cursors\unitBleeding_ca.paa";
        description = "You bled out.";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class finallyKilled {
        title = "Medic System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You were finally killed.";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class loadoutLoaded {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa";
        description = "Loadout loaded";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class magsFilled {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\RscTitles\MPProgress\respawn_ca.paa";
        description = "Magazines filled";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class noMags {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "You do not have any magazines";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class loadoutSaved {
        title = "Loadout System";
        iconPicture = "\A3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa";
        description = "Loadout was saved";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class healed {
        title = "Base";
        iconPicture = "\A3\Ui_f\data\IGUI\Cfg\Actions\heal_ca.paa";
        description = "Healed";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class vehiclesystem {
        title = "Vehicle System";
        iconPicture = "\A3\ui_f\data\Map\Markers\NATO\c_car.paa";
        description = "%1";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class vehicleCooldown {
        title = "Vehicle System";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "%1";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 0;
    };
    class spawnProtectionDisabled {
        title = "Spawn Protection";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Spawnprotection disabled";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 0;
    };
    class outsidePlayzone {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Go back into the playZone or you will die in 30 seconds";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 1;
    };
    class inEnemyBase {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\respawn\icon_enemy_ca.paa";
        description = "Leave the enemy base or you will die in 15 seconds";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 1;
    };
    class backInPlayzone {
        title = "Playzone";
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa";
        description = "You are back in the playzone";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 1;
    };
    class rankUp {
        title = "Rank System";
        iconText = "%1";
        description = "You ranked up";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 1;
    };
    class airDrop {
        title = "Airdrop";
        iconPicture = "\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa";
        description = "An airdrop has been dispatched";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 1;
    };
    class sideAirDrop {
        title = "Airdrop";
        iconPicture = "\A3\ui_f\data\Map\vehicleicons\iconParachute_ca.paa";
        description = "%1 receive a supplydrop at %2";
        color[] = {1, 1, 1, 1};
        duration = 5;
        priority = 1;
    };
    class earplugs {
        title = "Earplugs";
        iconPicture = "\A3\ui_f\data\IGUI\RscIngameUI\RscDisplayChannel\MuteVON%1_ca.paa";
        description = "Earplugs %2";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 1;
    };
    class groupMateSpawned {
        title = "Group System";
        iconPicture = "\A3\ui_f\data\map\mapcontrol\taskIconDone_ca.paa";
        description = "Your groupmate %1 spawned %2";
        color[] = {1, 1, 1, 1};
        duration = 3;
        priority = 1;
    };
};