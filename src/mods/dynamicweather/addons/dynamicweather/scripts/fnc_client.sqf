// Dynamic weather (client): reports the weather this client sees to the server when it changed (at least every
// DW_var_reportInterval seconds), shows the night skip announcement and silences the church bells if the server says
// so (DW_var_bellsSilenced, option DW_var_silenceBells).

DW_var_reportInterval = 5;        // seconds
DW_var_reportThreshold = 0.01;    // change of overcast or rain that is reported at once

// The church bells: the engine rings CfgSFX >> Church at every terrain building whose class has simulation "church"
// (churches, the cathedral, bell towers) while it is simulated, on each machine for itself. A script can't change the
// config, so this machine turns the simulation of these buildings off (once: terrain objects stay).
DW_fnc_silenceChurchBells = {
    if (!hasInterface || {!isNil "DW_var_bellsSilencedHere"}) exitWith {};

    DW_var_bellsSilencedHere = true;

    private _classes = ("getText (_x >> 'simulation') == 'church'" configClasses (configFile >> "CfgVehicles")) apply {configName _x};
    private _half = worldSize / 2;

    {
        _x enableSimulation false;
    } forEach (nearestObjects [[_half, _half], _classes, worldSize, true]);
};

[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["DW_var_bellsSilenced", false]};
    call DW_fnc_silenceChurchBells;
};

DW_fnc_skipNightMessage = {
    params ["_text"];

    systemChat format ["The server skips to the next morning %1. There will be a short freeze.", _text];
};

[] spawn {
    private _reported = [-1, -1];
    private _nextReport = 0;

    waitUntil {
        private _weather = [overcast, rain];

        if (
            diag_tickTime >= _nextReport ||
            {abs ((_weather select 0) - (_reported select 0)) > DW_var_reportThreshold} ||
            {abs ((_weather select 1) - (_reported select 1)) > DW_var_reportThreshold}
        ) then {
            [_weather] remoteExecCall ["DW_fnc_setClientWeather", 2];
            _reported = _weather;
            _nextReport = diag_tickTime + DW_var_reportInterval;
        };

        sleep 1;
        false
    };
};

DW_var_clientInitDone = true;
