/*
 * Author: Psycho
 
 * Visual bleeding effects and counter for revive time. Will self-run in a loop till unit get revived/stabilized or died.
 
 * Arguments:
    0: Unit (Object)
    1: Revive Time (Number)
 
 * Return value:
    -
*/

params ["_unit", "_revive_time"];

// breack out if unit died or revived
if (!alive _unit || {!(_unit getVariable ["ais_unconscious", false])}) exitWith {};

// breack out if unit get stabilized
if (_unit getVariable ["ais_stabilized", false]) exitWith {
    _unit setBleedingRemaining 10;
    // titleText ["You are stabilized.", "PLAIN DOWN", 1];
    
    // loop
    private _acc_time = diag_tickTime + 1.5;
    [{diag_tickTime >= (_this select 1)}, {_this call AIS_Effects_fnc_stabil}, [_unit, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;
};


// get the revive time
_revive_time = [_unit] call AIS_System_fnc_calculateLifeTime;
_unit setBleedingRemaining _revive_time;

private _timeleft = AIS_BLEEDOUT_TIME - (time - ais_start_unc_time);

// to late
if (_timeleft <= 0) exitWith {    
    [_unit, objNull, objNull] call AIS_Damage_fnc_goToDead;
    _unit setDamage 1;
};

if (AIS_SHOW_COUNTDOWN && {isNull AIS_BleedoutCameraScript}) then {
    [] spawn {
        ["<t align='center'>Press space to respawn</t>", [safeZoneX, safeZoneW], [((safeZoneH / 1.09) + safezoneY), safeZoneH], 9999, 0, 0, 1011] spawn BIS_fnc_dynamicText;
        AIS_var_respawn = false;

        _id = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];
            if (_key == 57) then {
                AIS_var_respawn = true;
            };
        }];

        disableSerialization;
        (["AIS_Core_Progress_BarRsc"] call BIS_fnc_rscLayer) cutRsc ["AIS_Core_Progress_BarRsc", "PLAIN", 0, true];
        _progressBar = uiNamespace getVariable "AIS_Core_Progress_ProgressBarRsc";
        _progressBar ctrlSetBackgroundColor [1, 0, 0, 1];
        _oldPosition = ctrlPosition _progressBar;
        _progressBar ctrlSetPosition [safeZoneX + 0.298906 * safeZoneW, safeZoneY + 0.082 * safeZoneH, 0.407344 * safeZoneW, 0.011 * safeZoneH];
        _progressBar ctrlCommit 0;
        _progressBar ctrlSetPosition _oldPosition;
        _progressBar ctrlCommit AIS_BLEEDOUT_TIME;
        _startTime = time;

        waitUntil {
            ["Bleeding out", (1 - ((time - _startTime) / AIS_BLEEDOUT_TIME)) max 0, true] spawn AIS_Core_fnc_progress_showBarText;
            _plannedHelper = player getVariable ["AIS_plannedHelper", objNull];
            _helper = player getVariable ["AIS_hasHelper", objNull];

            _text = if (isNull _helper) then {
                if (isNull _plannedHelper) then {
                    "There is no medic nearby"
                } else {
                    "An AI medic is coming: " + (str (round (player distance _plannedHelper))) + "m"
                }
            } else {
                ""
            };

            [_text, [(safeZoneX + (0.32 * safeZoneW)), safeZoneW], [((safeZoneH / 25) + safezoneY), safeZoneH], 9999, 0, 0, 1067] spawn BIS_fnc_dynamicText;

            sleep 0.5;

            (AIS_var_respawn || {!(alive player)} || {!(player getVariable ["AIS_unconscious", false])} || {player getVariable ["AIS_stabilized", false]})
        };
        
        (uiNamespace getVariable "AIS_Core_Progress_BarRsc") closeDisplay 1;

        if AIS_var_respawn then {
            [player, objNull, objNull] call AIS_Damage_fnc_goToDead;
            player setDamage 1;
        } else {
            if !(alive player) then {
                _text = if ((AIS_BLEEDOUT_TIME - (time - ais_start_unc_time)) <= 0) then {
                    ["bledOut"] call SC_fnc_showNotificationIfHudIsEnabled;
                } else {
                    ["finallyKilled"] call SC_fnc_showNotificationIfHudIsEnabled;
                };
            };
        };

        if ((player getVariable ["AIS_unconscious", false]) && {player getVariable ["AIS_stabilized", false]}) then {
            ["medicSystem", ["You have been stabilized."]] call SC_fnc_showNotificationIfHudIsEnabled;

            waitUntil {!(alive player) || {AIS_var_respawn}};

            if AIS_var_respawn then {
                [player, objNull, objNull] call AIS_Damage_fnc_goToDead;
                player setDamage 1;
            };
        };

        AIS_var_respawn = nil;
        ["", 0, 0, 0, 0, 0, 1067] spawn BIS_fnc_dynamicText;
        ["", 0, 0, 0, 0, 0, 1011] spawn BIS_fnc_dynamicText;
        (findDisplay 46) displayRemoveEventHandler ["KeyDown", _id];
    };
    
    AIS_BleedoutCameraScript = [_timeleft] spawn {
        params ["_timeleft"];
        
        _startTime = diag_tickTime;

        _oldNvgoggles = SC_var_nvGogglesEnabled;
        _camera = "camera" camCreate (getPosATL player);
        _camera cameraEffect ["internal", "back"];
        _camera camSetFOV 0.5;
        showCinemaBorder true;
        SC_var_nvGogglesEnabled = _oldNvgoggles;
        SC_var_forcedMap = false;
        camUseNVG SC_var_nvGogglesEnabled;

        call {
            if (SC_var_alwaysShowHudWhenUnconscious && !SC_var_hudEnabled && !SC_var_hudShown) then {
                [true] call SC_fnc_setHud;
            };
        };

        _syncGpsEnabledLoopScript = [] spawn {
            disableSerialization;
            
            _gpsCtrl = (findDisplay 46) ctrlCreate ["RscMapControl", -420];
            _gpsCtrl ctrlAddEventHandler ["Draw", {
                params ["_display"];

                uiNamespace setVariable ["MM_var_currentDisplay", _display];
                MM_var_showUnitNamesOverride = false;

                if !MM_var_gpsOpened then {
                    MM_var_gpsOpened = true;

                    if !(scriptDone MM_var_updateDrawArrayScript) then {
                        terminate MM_var_updateDrawArrayScript;
                        MM_var_updateDrawArrayScript = scriptNull;
                    };

                    [false] call MM_fnc_updateDrawArray;
                };

                [_display] call MM_fnc_drawIcons;
            }];
            uiNamespace setVariable ["SC_var_customGPS", _gpsCtrl];
            _gpsCtrl ctrlMapSetPosition [1.4, 0.6, 0.295, 0.37];
            _gpsCtrl ctrlCommit 0;

            waitUntil {
                _gpsCtrl ctrlMapAnimAdd [0, (0.06 * SC_var_mapZoomFactor), player];
                ctrlMapAnimCommit _gpsCtrl;

                false
            };
        };

        _keyDownEhId = (findDisplay 46) displayAddEventHandler ["KeyDown", {
            params ["", "_key"];
            
            if ((_key in (actionKeys "nightVision")) || {_key in (actionKeys "TransportNightVision")}) then {
                SC_var_nvGogglesEnabled = !SC_var_nvGogglesEnabled;

                camUseNVG SC_var_nvGogglesEnabled;
                player action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), player];

                {
                    false setCamUseTI _x;
                } forEach [0, 1, 2, 3, 4, 5, 6, 7];

                true
            };
        }];

        waitUntil {
            _pelvisPos = aslToATL (player modelToWorldVisualWorld (player selectionPosition "pelvis"));
            _camera camsetPos (_pelvisPos vectorAdd [0.01, 0.01, 5]);
            _camera camsetTarget _pelvisPos;
            _camera camCommit 0;

            (!(alive player) || {!(player getVariable ["AIS_unconscious", false])} || {player getVariable ["AIS_stabilized", false]})
        };

        if (alive player) then {
            call {
                if (!SC_var_hudEnabled && SC_var_hudShown) then {
                    [false] call SC_fnc_setHud;
                };
            };
        } else {
            sleep 4;
        };

        (findDisplay 46) displayRemoveEventHandler ["KeyDown", _keyDownEhId];
        terminate _syncGpsEnabledLoopScript;
        _gpsCtrl = uiNamespace getVariable ["SC_var_customGPS", controlNull];
        
        if !(isNull _gpsCtrl) then {
            ctrlDelete _gpsCtrl;
        };

        uiNamespace setVariable ["SC_var_customGPS", controlNull];
        _camera cameraEffect ["terminate", "back"];
        camDestroy _camera;
        player action [(["nvGogglesOff", "nvGoggles"] select SC_var_nvGogglesEnabled), player];

        AIS_BleedoutCameraScript = scriptNull;
    };
};

_unit setFatigue 1;

// loop
private _acc_time = diag_tickTime + 1;
[{diag_tickTime >= (_this select 2)}, {_this call AIS_Effects_fnc_bleeding}, [_unit, _revive_time, _acc_time]] call AIS_Core_fnc_waitUntilAndExecute;