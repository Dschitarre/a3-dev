// Disable tactical view (client): swallows the tactical view key and switches back to the last view when the
// tactical (group) view is opened any other way.

DTV_var_running = false;
DTV_var_ehId = -1;
DTV_var_eachFrameEhId = -1;
DTV_var_lastView = "INTERNAL";

DTV_fnc_keyDown = {
    params ["", "_key"];

    _key in actionKeys "tacticalView"
};

// one string compare per frame: cheaper than throttling it, and the tactical view never shows
DTV_fnc_eachFrame = {
    private _view = cameraView;

    if (_view == "GROUP") exitWith {
        cameraOn switchCamera DTV_var_lastView;
    };

    if (_view in ["INTERNAL", "EXTERNAL"]) then {
        DTV_var_lastView = _view;
    };
};

// Adds / removes the key handler on display 46 to match DTV_var_running. Runs scheduled (waits for the display);
// the change itself runs unscheduled, so a start and a stop in quick succession cannot double or lose it.
// _reload: a loaded singleplayer savegame has a new display 46, so the handler is added again.
DTV_fnc_syncKeyHandler = {
    params [["_reload", false]];

    waitUntil {!isNull player && {!isNull findDisplay 46}};

    isNil {
        private _display = findDisplay 46;

        if (DTV_var_ehId != -1 && {_reload || {!DTV_var_running}}) then {
            _display displayRemoveEventHandler ["KeyDown", DTV_var_ehId];
            DTV_var_ehId = -1;
        };

        if (DTV_var_running && {DTV_var_ehId == -1}) then {
            DTV_var_ehId = _display displayAddEventHandler ["KeyDown", {_this call DTV_fnc_keyDown}];
        };
    };
};

DTV_fnc_startDisableTacticalViewClient = {
    if (DTV_var_running) exitWith {};

    DTV_var_running = true;
    DTV_var_eachFrameEhId = addMissionEventHandler ["EachFrame", {call DTV_fnc_eachFrame}];

    if (!isMultiplayer) then {
        DTV_var_loadedEhId = addMissionEventHandler ["Loaded", {[true] spawn DTV_fnc_syncKeyHandler}];
    };

    [] spawn DTV_fnc_syncKeyHandler;
};

DTV_fnc_stopDisableTacticalViewClient = {
    if (!DTV_var_running) exitWith {};

    DTV_var_running = false;
    removeMissionEventHandler ["EachFrame", DTV_var_eachFrameEhId];
    DTV_var_eachFrameEhId = -1;

    if (!isMultiplayer) then {
        removeMissionEventHandler ["Loaded", DTV_var_loadedEhId];
        DTV_var_loadedEhId = nil;
    };

    [] spawn DTV_fnc_syncKeyHandler;
};

DTV_var_clientInitDone = true;
