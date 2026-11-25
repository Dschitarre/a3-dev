// Eden module "Killfeed" (server): loads the mod, applies the module settings and starts it when the module is activated.
params ["_logic", "", "_activated"];

if (!isServer || {!_activated}) exitWith {};

call compile preprocessFileLineNumbers "killfeed\scripts\fn_init.sqf";

// checkbox attributes are BOOL; missions saved with the former Enabled/Disabled combos store 0/1
private _flag = {
    params ["_name", "_default"];

    private _value = _logic getVariable [_name, _default];

    if (_value isEqualType 0) then {_value != 0} else {_value}
};

KF_var_assists = ["assists", true] call _flag;
KF_var_showFriendlyFire = ["showFriendlyFire", true] call _flag;
KF_var_deathCausesInversed = ["deathCausesInversed", true] call _flag;
KF_var_multipleDeathCauses = ["multipleDeathCauses", false] call _flag;
KF_var_picturesHeadIcon = ["picturesHeadIcon", true] call _flag;
KF_var_picturesBulletIcon = ["picturesBulletIcon", true] call _flag;
KF_var_showAiInNames = ["showAiInNames", true] call _flag;

KF_var_killFeedEnabled = ["killfeedEnabled", true] call _flag;
KF_var_killFeedInversed = ["killfeedInversed", true] call _flag;
KF_var_killFeedCooldown = _logic getVariable ["killfeedCooldown", 30];
KF_var_killFeedMaximumLength = _logic getVariable ["killfeedMaximumLength", 10];

KF_var_midFeedEnabled = ["midFeedEnabled", true] call _flag;
KF_var_midFeedCooldown = _logic getVariable ["midfeedCooldown", 10];
KF_var_midFeedMaximumLength = _logic getVariable ["midfeedMaximumLength", 10];
KF_var_midFeedYouColorYellow = ["midFeedYouColorYellow", true] call _flag;
KF_var_midFeedAssists = ["midFeedAssists", true] call _flag;

KF_var_deathFeedEnabled = ["deathFeedEnabled", true] call _flag;

KF_var_killInfoDuration = _logic getVariable ["killInfoDuration", 20];

KF_var_killCamEnabled = ["killCamEnabled", true] call _flag;
KF_var_killCamHoldDuration = _logic getVariable ["killCamHoldDuration", 5];
KF_var_killCamMaxDistance = _logic getVariable ["killCamMaxDistance", 300];
KF_var_killCamAirMaxHeight = _logic getVariable ["killCamAirMaxHeight", 300];
KF_var_killCamTeamKills = ["killCamTeamKills", true] call _flag;
KF_var_killCamRequireLineOfSight = ["killCamRequireLineOfSight", false] call _flag;
KF_var_killCamIndirectKills = ["killCamIndirectKills", false] call _flag;

call KF_fnc_publishClientSettings;
call KF_fnc_resetKillInfo;
call KF_fnc_startKillfeed;
