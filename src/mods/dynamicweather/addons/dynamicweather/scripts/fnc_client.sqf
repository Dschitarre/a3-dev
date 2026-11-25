// Dynamic weather (client): reports the weather this client sees to the server when it changed (at least every
// DW_var_reportInterval seconds) and shows the night skip announcement.

DW_var_reportInterval = 5;        // seconds
DW_var_reportThreshold = 0.01;    // change of overcast or rain that is reported at once

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
