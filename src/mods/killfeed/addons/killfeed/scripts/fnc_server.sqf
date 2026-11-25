// Killfeed, server: collects the hits per victim, evaluates every kill (killer, assistants, death causes, scores) and
// sends the kill feed, mid feed, death feed and kill info texts to the clients. Names in these texts are colored
// with color keys ('kf:west', ...) that each client replaces with its own profile colors.

// ---- settings (defaults; the module and the game modes overwrite them after this file ran) ----

if (isNil "KF_var_running") then {
    KF_var_running = false;
    publicVariable "KF_var_running";
};

KF_var_assists = true;
KF_var_killFeedEnabled = true;
KF_var_killFeedInversed = true;
KF_var_killFeedCooldown = 30;
KF_var_killFeedMaximumLength = 10;
KF_var_addKillFeedInfo = [];
KF_var_showFriendlyFire = true;
KF_var_deathCausesInversed = true;
KF_var_multipleDeathCauses = false;
KF_var_picturesHeadIcon = true;
KF_var_picturesBulletIcon = true;
KF_var_showAiInNames = true;
KF_var_midFeedEnabled = true;
KF_var_midFeedCooldown = 10;
KF_var_midFeedMaximumLength = 10;
KF_var_midFeedYouColorYellow = true;
KF_var_midFeedAssists = true;
KF_var_addMidFeedInfo = [];
KF_var_deathFeedEnabled = true;
KF_var_addDeathFeedInfo = [];
KF_var_killInfoDuration = 20;
KF_var_killInfoIncludeTK = false;
KF_var_deathTransition = true;

// deaths of units reported by the engine (not by KF_fnc_entityKilled calls of a game mode, not UAVs)
KF_var_handleUnitDeaths = true;
KF_var_showFinallyKilledForUnitDeaths = false;
KF_var_addScoreForUnitDeaths = true;
KF_var_showUnitDeathsInKillfeed = true;
KF_var_showUnitDeathsInMidfeed = true;
KF_var_showUnitDeathsInDeathFeed = true;
KF_var_showUnitDeathsInKillInfo = true;

// settings the clients (and game modes on the clients) read. The kill cam settings and hooks have their defaults on
// the clients (killCam.sqf): only those the module or the game mode set here are published.
KF_var_clientSettings = [
    "KF_var_killFeedCooldown",
    "KF_var_killFeedMaximumLength",
    "KF_var_midFeedCooldown",
    "KF_var_midFeedMaximumLength",
    "KF_var_midFeedYouColorYellow",
    "KF_var_deathTransition",
    "KF_var_killCamEnabled",
    "KF_var_killCamMinDistance",
    "KF_var_killCamMaxDistance",
    "KF_var_killCamFlightDuration",
    "KF_var_killCamHoldDuration",
    "KF_var_killCamRequireLineOfSight",
    "KF_var_killCamTeamKills",
    "KF_var_killCamAirMaxHeight",
    "KF_var_killCamIndirectKills",
    "KF_var_killCamOnRoundEnd",
    "KF_var_killCamSkipKey",
    "KF_var_killCamOutro",
    "KF_fnc_killCamCanShow",
    "KF_fnc_killCamRoundOver",
    "KF_fnc_killCamRank"
];

KF_fnc_publishClientSettings = {
    {
        if (!isNil _x) then {
            publicVariable _x;
        };
    } forEach KF_var_clientSettings;
};

call KF_fnc_publishClientSettings;

KF_var_killDelay = 1/3;                                  // a kill is evaluated this long after the death: hits still arrive
KF_var_hitsWithoutProjectile = ["vehHit", "vehExpl", "fall", "fire", "drown", "zone"];
KF_var_projectileHitWindow = 1;                          // such a hit is dropped if the hitter has a projectile hit this close
KF_var_assistWindow = 30;                                // seconds a hit counts for kills and assists
KF_var_maxHitsPerEntity = 200;                           // hits kept per unit or vehicle (machine gun fire on a vehicle)
KF_var_unitCheckInterval = 1;                            // seconds between two refreshes of names, sides and controllers
KF_var_classInfo = createHashMap;                        // class name -> [display name, picture, kind]

#include "vehicleSymbols.sqf"

#include "names.sqf"

#include "hits.sqf"

#include "kills.sqf"

#include "feeds.sqf"

#include "killInfo.sqf"

// ---- start ----

KF_fnc_startKillfeed = {
    if (missionNamespace getVariable ["KF_cba_override", false]) then {
        call KF_fnc_applyCbaSettings;
    };

    if (KF_var_running) exitWith {};

    // the game modes set their client settings (e.g. the kill cam hooks) right before the start
    call KF_fnc_publishClientSettings;

    {
        [_x] call KF_fnc_onEntityCreated;
    } forEach (entities [["AllVehicles"], ["Animal"], true, false]);

    // mines placed before (e.g. in the editor) have no owner: their hits count as self-inflicted
    {
        if (local _x && {(_x getVariable ["KF_var_hitContext", []]) isEqualTo []}) then {
            [_x, [objNull, objNull, getText (configOf _x >> "defaultMagazine"), "Put"]] call KF_fnc_trackProjectile;
        };
    } forEach allMines;

    addMissionEventHandler ["EntityCreated", {
        _this call KF_fnc_onEntityCreated;
    }];

    addMissionEventHandler ["EntityRespawned", {
        _this call KF_fnc_entityRespawned;
    }];

    addMissionEventHandler ["EntityKilled", {
        (_this select [0, 3]) call KF_fnc_entityKilled;
    }];

    [] spawn KF_fnc_watchUnitsLoop;

    KF_var_running = true;
    publicVariable "KF_var_running";
};

KF_var_serverInitDone = true;
