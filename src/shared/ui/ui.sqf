/*
    Colors for scripted UI (structured text, drawIcon / drawIcon3D, ctrlSetBackgroundColor, markers): accent, title
    and HUD colors from the player's own settings (Options > Game > Colors) like the config macros in ui\ui.hpp,
    side colors and the own-player yellow as a fixed palette shared with the mods. Runs on every machine
    with an interface; compile it from the mode's functions.sqf. Values are cached; call UI_fnc_refreshColors after
    the player may have changed the settings (e.g. when the pause menu closes).
    Also the plain screen texts (client): UI_fnc_showTextBlocks / UI_fnc_hideTextBlocks, UI_fnc_fitText, and the size
    of vehicle pictures in their slots (client): UI_fnc_vehiclePictureFill / UI_fnc_setVehiclePicture.
*/

call compile preprocessFileLineNumbers "ui\settings.sqf";
call compile preprocessFileLineNumbers "ui\culling.sqf";

// [profile variable prefix, fallback RGBA] per color, fallbacks as in \a3\ui_f\hpp\defineCommonColors.inc
UI_var_colorSources = createHashMapFromArray [
    ["accent", ["GUI_BCG_RGB", [0.13, 0.54, 0.21, 0.8]]],
    ["titleText", ["GUI_TITLETEXT_RGB", [1, 1, 1, 0.6]]],
    ["hudPanel", ["IGUI_BCG_RGB", [0, 1, 1, 0.8]]],
    ["hudText", ["", [1, 1, 1, 1]]],               // pure white (not the transparent IGUI_TEXT)
    ["warning", ["IGUI_WARNING_RGB", [0.8, 0.5, 0, 0.8]]],
    ["error", ["IGUI_ERROR_RGB", [0.8, 0, 0, 1]]],
    // fixed colors ("" = no profile variable): sides (map / icon palette of mapmarker) and
    // the player's own highlight (yellow); their text variants are UI_var_fixedHtml (the killfeed / HUD text palette)
    ["west", ["", [0, 0.5, 1, 1]]],
    ["east", ["", [1, 0, 0, 1]]],
    ["guer", ["", [0, 0.8, 0.27, 1]]],
    ["civ", ["", [0.75, 0.75, 0.75, 1]]],
    ["unknown", ["", [0.75, 0.75, 0.75, 1]]],
    ["you", ["", [1, 0.83, 0, 1]]],
    // HUD bars with a fill level: grey, only the player's health green (UI_COLOR_BAR_FILL / UI_COLOR_HEALTH)
    ["barFill", ["", [0.3, 0.3, 0.3, 0.55]]],
    ["health", ["", [0, 0.8, 0, 0.55]]]
];

// structured text colors of the fixed colors, identical to the killfeed's
UI_var_fixedHtml = createHashMapFromArray [
    ["west", "#0066B3"],
    ["east", "#E60000"],
    ["guer", "#009933"],
    ["civ", "#808080"],
    ["unknown", "#808080"],
    ["you", "#FFD400"]
];

UI_fnc_refreshColors = {
    UI_var_colors = createHashMap;

    {
        _y params ["_prefix", "_fallback"];

        private _rgba = +_fallback;

        if (_prefix != "") then {
            {
                _rgba set [_forEachIndex, profileNamespace getVariable [_prefix + _x, _fallback select _forEachIndex]];
            } forEach ["_R", "_G", "_B", "_A"];
        };

        UI_var_colors set [_x, _rgba];
        UI_var_colors set [_x + "Html", UI_var_fixedHtml getOrDefault [_x, _rgba call BIS_fnc_colorRGBAtoHTML]];
    } forEach UI_var_colorSources;
};

// "accent", "titleText", "hudPanel", "hudText", "warning", "error", "west", "east", "guer", "civ", "unknown", "you",
// "barFill", "health"
UI_fnc_color = {
    params ["_name"];

    UI_var_colors getOrDefault [_name, [1, 1, 1, 1]]
};

// same as UI_fnc_color, as "#AARRGGBB" for structured text
UI_fnc_colorHtml = {
    params ["_name"];

    UI_var_colors getOrDefault [_name + "Html", "#ffffffff"]
};

UI_var_sideKeys = createHashMapFromArray [[west, "west"], [east, "east"], [independent, "guer"], [civilian, "civ"]];

UI_fnc_sideColor = {
    params ["_side"];

    [UI_var_sideKeys getOrDefault [_side, "unknown"]] call UI_fnc_color
};

UI_fnc_sideColorHtml = {
    params ["_side"];

    [UI_var_sideKeys getOrDefault [_side, "unknown"]] call UI_fnc_colorHtml
};

call UI_fnc_refreshColors;

// ---- screen texts (client) ----
/*
    Plain texts on the screen (leaderboards, short notes, centered messages) in one font and size, UI_ScreenText of
    ui\ui.hpp (UI_TEXT_SCREEN). At the screen edges each text sits in a dark transparent block in the player's HUD
    background color (UI_HudPanel), like the vanilla HUD; texts in the middle of the screen stay without blocks.
    Every set of texts has its own cut layer (an RscTitleDisplayEmpty with the controls created on it), so showing a
    layer again replaces its texts.
*/

UI_var_textBlockPadding = [0.15, 0];    // grid cells between a block's edge and its text (horizontal, vertical): the line
                                        // height already leaves about 0.15 cells above and below the letters
UI_var_textBlockGap = 0.15;              // grid cells between the blocks of one layer: the standard row gap of all
                                        // row-based text blocks (killfeed KF_var_blockGap, SC group bar)
UI_var_textBlockFadeOut = 1;            // seconds, like BIS_fnc_dynamicText
UI_var_textBlockTokens = createHashMap; // layer -> number of its current texts, so an old timer never hides newer ones
UI_var_fittedTexts = createHashMap;     // [text, width, font, size] -> text cut by UI_fnc_fitText

// [width, height] of one cell of the vanilla GUI grid (GUI_GRID_W / GUI_GRID_H of \a3\ui_f\hpp\defineCommonGrids.inc)
UI_fnc_gridCell = {
    private _gridWidth = (safeZoneW / safeZoneH) min 1.2;

    [_gridWidth / 40, _gridWidth / 1.2 / 25]
};

// font size (screen units) of the screen texts, UI_TEXT_SCREEN of ui\ui.hpp (getNumber evaluates the expression)
UI_fnc_screenTextSize = {
    getNumber (missionConfigFile >> "UI_ScreenText" >> "size")
};

/*
    Shows _rows on _layer (cut layer number or name) instead of what the layer showed before; scheduled or not.
    _rows       structured text String, or an Array of them: one block per row, stacked with UI_var_textBlockGap
    _position   [x, y, alignX, alignY]: anchor point (screen coordinates) and the part of the blocks that sits on it,
                alignX 0 / 0.5 / 1 = left edge / center / right edge, alignY 0 / 0.5 / 1 = top / middle / bottom
    _duration   seconds until the texts fade out (UI_var_textBlockFadeOut), -1 = until replaced or hidden
    _width      grid cells of every block (rows of the same width), -1 = each block as wide as its text,
                0 = every block as wide as the widest text
    _boxed      false = the texts without blocks (texts in the middle of the screen)
    Returns the bottom edge of the lowest block (screen y), so other texts can be placed below.
*/
UI_fnc_showTextBlocks = {
    params ["_layer", "_rows", "_position", ["_duration", -1], ["_width", -1], ["_boxed", true]];

    disableSerialization;

    if (_rows isEqualType "") then {
        _rows = [_rows];
    };

    _position params ["_anchorX", "_anchorY", ["_alignX", 0], ["_alignY", 0]];

    if (_rows isEqualTo []) exitWith {
        [_layer] call UI_fnc_hideTextBlocks;
        _anchorY
    };
    (call UI_fnc_gridCell) params ["_cellW", "_cellH"];

    private _paddingX = [0, (UI_var_textBlockPadding select 0) * _cellW] select _boxed;
    private _paddingY = [0, (UI_var_textBlockPadding select 1) * _cellH] select _boxed;
    private _gap = UI_var_textBlockGap * _cellH;
    private _maxTextWidth = safeZoneW - 2 * _paddingX;
    private _display = displayNull;

    // at once: every RscTitleDisplayEmpty stores itself in the same uiNamespace variable; the layer is cleared first,
    // so it always gets a new, empty display
    isNil {
        _layer cutText ["", "PLAIN"];
        _layer cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, true];
        _display = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
    };

    // the vignette it inherits from RscDisplayEmpty would darken the screen edges
    (_display displayCtrl 1202) ctrlShow false;

    // [background, text, block width, block height] per row; backgrounds first, so the texts are drawn over them
    private _blocks = _rows apply {
        private _background = if (_boxed) then {_display ctrlCreate ["UI_HudPanel", -1]} else {controlNull};
        private _text = _display ctrlCreate ["UI_ScreenText", -1];

        _text ctrlSetPosition [0, 0, _maxTextWidth, _cellH];
        _text ctrlSetStructuredText parseText _x;
        _text ctrlCommit 0;

        private _textWidth = switch (true) do {
            case (_width > 0): {_width * _cellW - 2 * _paddingX};
            // without a block the width does not show: the whole screen, the text aligns itself
            case (!_boxed): {_maxTextWidth};
            // as wide as the text (its longest line); a little extra, so that rounding never wraps the last word
            default {((ctrlTextWidth _text) + 0.1 * _cellW) min _maxTextWidth};
        };

        _text ctrlSetPosition [0, 0, _textWidth, _cellH];
        _text ctrlCommit 0;

        [_background, _text, _textWidth + 2 * _paddingX, (ctrlTextHeight _text) + 2 * _paddingY]
    };

    if (_width == 0) then {
        private _widest = 0;

        {
            _widest = _widest max (_x select 2);
        } forEach _blocks;

        {
            _x set [2, _widest];
        } forEach _blocks;
    };

    private _stackHeight = -_gap;

    {
        _stackHeight = _stackHeight + (_x select 3) + _gap;
    } forEach _blocks;

    private _top = _anchorY - _alignY * _stackHeight;
    private _bottom = _top + _stackHeight;
    private _controls = [];

    {
        _x params ["_background", "_text", "_blockWidth", "_blockHeight"];

        private _left = _anchorX - _alignX * _blockWidth;

        _background ctrlSetPosition [_left, _top, _blockWidth, _blockHeight];
        _background ctrlCommit 0;
        _text ctrlSetPosition [_left + _paddingX, _top + _paddingY, _blockWidth - 2 * _paddingX, _blockHeight - 2 * _paddingY];
        _text ctrlCommit 0;
        _controls append ([[_text], [_background, _text]] select _boxed);
        _top = _top + _blockHeight + _gap;
    } forEach _blocks;

    private _token = (UI_var_textBlockTokens getOrDefault [_layer, 0]) + 1;
    UI_var_textBlockTokens set [_layer, _token];

    if (_duration < 0) exitWith {_bottom};

    [_layer, _token, _duration, _controls] spawn {
        disableSerialization;
        params ["_layer", "_token", "_duration", "_controls"];

        sleep _duration;

        if ((UI_var_textBlockTokens get _layer) isNotEqualTo _token) exitWith {};

        {
            _x ctrlSetFade 1;
            _x ctrlCommit UI_var_textBlockFadeOut;
        } forEach _controls;

        sleep UI_var_textBlockFadeOut;

        if ((UI_var_textBlockTokens get _layer) isEqualTo _token) then {
            _layer cutText ["", "PLAIN"];
        };
    };

    _bottom
};

UI_fnc_hideTextBlocks = {
    params ["_layer"];

    UI_var_textBlockTokens set [_layer, (UI_var_textBlockTokens getOrDefault [_layer, 0]) + 1];
    _layer cutText ["", "PLAIN"];
};

/*
    _text cut to the longest beginning that fits into _maxWidth (screen units) together with "...", measured in _font
    at _size (default: the screen texts). Plain text: cut names before escaping them. Cached, every text is measured once.
*/
UI_fnc_fitText = {
    params ["_text", "_maxWidth", ["_font", "RobotoCondensed"], ["_size", -1]];

    if (_size < 0) then {
        _size = call UI_fnc_screenTextSize;
    };

    private _key = [_text, _maxWidth, _font, _size];
    private _fitted = UI_var_fittedTexts get _key;

    if (isNil "_fitted") then {
        _fitted = _text;

        if ((_text getTextWidth [_font, _size]) > _maxWidth) then {
            // binary search over the characters (toArray: also for non-ASCII names)
            private _chars = toArray _text;
            private _fits = 0;
            private _tooLong = count _chars;

            while {(_tooLong - _fits) > 1} do {
                private _length = floor ((_fits + _tooLong) / 2);

                if ((((toString (_chars select [0, _length])) + "...") getTextWidth [_font, _size]) <= _maxWidth) then {
                    _fits = _length;
                } else {
                    _tooLong = _length;
                };
            };

            _fitted = (toString (_chars select [0, _fits])) + "...";
        };

        if ((count UI_var_fittedTexts) >= 500) then {
            UI_var_fittedTexts = createHashMap;
        };

        UI_var_fittedTexts set [_key, _fitted];
    };

    _fitted
};

// ---- vehicle pictures (client) ----
/*
    The side views of vehicles (config "picture") cover very different shares of their texture: a truck most of it, a
    mortar a few thin lines. UI_var_vehiclePictureInfo (ui\vehicleSymbols.sqf, generated; compiled after this file by
    the modes that show vehicle pictures) holds the scale per picture that makes their colored areas equal. In a slot
    of fixed size a picture can only shrink: one of scale UI_var_vehiclePictureFillScale or more fills the slot, the
    others are drawn smaller, centred - a typical picture (scale 1) at 0.94 / 1.28 of the slot, like the vehicle
    pictures of the killfeed next to its weapon pictures. Pictures the table does not know count as scale 1.
*/

UI_var_vehiclePictureFillScale = 1.28 / 0.94;

// share (0..1] of its slot that a vehicle picture fills, by width and height
UI_fnc_vehiclePictureFill = {
    params ["_picture"];

    if (isNil "UI_var_vehiclePictureInfo") exitWith {1 / UI_var_vehiclePictureFillScale};

    // the table key: lower case, no leading backslash, ".paa" when without extension
    private _key = toLowerANSI _picture;

    if ((_key select [0, 1]) == "\") then {
        _key = _key select [1];
    };

    if ((_key find ".") == -1) then {
        _key = _key + ".paa";
    };

    private _scale = (UI_var_vehiclePictureInfo getOrDefault [_key, [2, 1]]) select 1;

    1 min (_scale / UI_var_vehiclePictureFillScale)
};

// shows a vehicle picture in a picture control, sized by UI_fnc_vehiclePictureFill inside the control's current position
// (its slot) and centred on it: once per control, e.g. for the fresh rows of a controls table
UI_fnc_setVehiclePicture = {
    params ["_ctrl", "_picture"];

    (ctrlPosition _ctrl) params ["_slotX", "_slotY", "_slotW", "_slotH"];

    private _fill = [_picture] call UI_fnc_vehiclePictureFill;

    _ctrl ctrlSetText _picture;
    _ctrl ctrlSetPosition [_slotX + 0.5 * (1 - _fill) * _slotW, _slotY + 0.5 * (1 - _fill) * _slotH, _fill * _slotW, _fill * _slotH];
    _ctrl ctrlCommit 0;
};

call UI_fnc_initSettings;
