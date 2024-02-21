DW_fnc_skipNightMessage = {
    params ["_text"];
    systemChat (format ["The server skips to the next morning %1. There will be a short freeze.", _text]);
};

DW_fnc_syncWeatherToServer = {
    [(getPlayerUid player), [overcast, rain]] remoteExecCall ["DW_fnc_setPlayersWeather", 2];
};

[] spawn {    
    waitUntil {
        call DW_fnc_syncWeatherToServer;
        sleep 1;
        false
    };
};

DW_var_clientInitDone = true;