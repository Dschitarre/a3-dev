// Killfeed, clients: the kill feed (top right), mid feed (center), death feed (left) and kill info, drawn with own
// controls on blocks in the player's HUD background color; kill feed and mid feed lines move and fade animated. The
// texts from the server carry color keys ('kf:west', 'kf:you', ...) that this client fills in.
// The kill cam after the own death: killCam.sqf.

KF_var_clientKillFeedVisible = true; // display toggles of this client (KF_fnc_enableKillFeed, ...)
KF_var_clientMidFeedVisible = true;
KF_var_clientDeathFeedVisible = true;
KF_var_killFeedLines = []; // [id, text], oldest first
KF_var_midFeedLines = [];
KF_var_nextLineId = 0;
KF_var_deathFeedParts = []; // the report of the own death, one block per part
KF_var_deathFeedLines = []; // own kills evaluated after the own death (trade kills)
KF_var_deathFeedScript = scriptNull;
KF_var_eliminatedAt = -1;
KF_var_eliminatedUnit = objNull;
KF_var_deathFeedExpired = false;
KF_var_deathFeedExpiryScript = scriptNull;
KF_var_eliminatedDeathFeedDuration = 15;
KF_var_killInfoText = "";
KF_var_killInfoScript = scriptNull;
KF_var_spectatorDisplay = 60492; // RscDisplayEGSpectator
KF_var_highlightedNames = []; // [name, color key] of the player and his group
KF_var_colorList = []; // [color key, hex color]
KF_var_hudBackground = []; // RGBA, the player's HUD background (Options > Game > Colors)
KF_var_colorRefreshInterval = 10; // seconds

// ---- layout ----
// Sizes in GUI grid cells follow the interface size like the vanilla HUD (text size: KF_var_textSizeCells).
// Each feed keeps the layer of its former BIS_fnc_dynamicText: game modes clear a feed with an empty dynamic text on
// it (TDM the death feed on 788), and the order to named layers (the death transition's black screen) stays as it was.

KF_var_feedLayers = createHashMapFromArray [["killFeed", 790], ["midFeed", 787], ["deathFeed", 788], ["killInfo", 700]];
KF_var_screenMargin = 0.01; // screen units between kill feed / death feed and the safe zone edge
KF_var_blockPadding = [0.15, 0]; // cells between a block's edge and its text, horizontal and vertical: the line
// height already leaves about 0.15 cells above and below the letters
// (the same as UI_var_textBlockPadding of the missions)
KF_var_blockGap = 0.15; // cells between two blocks: the standard row gap (UI_var_textBlockGap of the
// missions)
KF_var_deathFeedMaxWidth = 16; // cells: longer lines of the death feed wrap
KF_var_barWidth = 7; // cells: fixed width of a bar entry, as the player's HP bar of GunGame (user)
KF_var_barColor = [0.3, 0.3, 0.3, 0.55]; // fill of a bar entry: the grey of the game modes' HUD fill level bars
KF_var_feedMoveDuration = 0.25; // s: kill feed / mid feed lines move to their new place
KF_var_feedFadeInDuration = 0.3; // s: a new line fades in
KF_var_feedFadeOutDuration = 0.5; // s: an expired or pushed out line fades out before it is removed
KF_var_leavingLineIds = createHashMap; // ids of the lines fading out (they keep their place meanwhile)
KF_var_remeasureDuration = 3; // s: a new kill feed / mid feed line is measured again (KF_fnc_updateAnimatedFeed)
KF_var_remeasureInterval = 0.25; // s: meanwhile its feed is drawn again this often
KF_var_remeasurePending = createHashMap; // feeds with a pending redraw for measuring again
// how an animated feed draws itself with its current lines
KF_var_animatedFeedRedraws = createHashMapFromArray [["killFeed", {call KF_fnc_drawKillFeed}], ["midFeed", {call KF_fnc_drawMidFeed}]];

// ---- colors ----
// The killfeed's own fixed palette (as before the UI rework): side names, the player's own name ("You", yellow),
// friendly fire (red), text white, icons a bit dimmer.
KF_var_fixedColors = [
["kf:west", "#0066B3"],
["kf:east", "#E60000"],
["kf:guer", "#009933"],
["kf:civ", "#808080"],
["kf:unknown", "#808080"],
["kf:you", "#FFD400"],
["kf:warning", "#FF0000"],
["kf:text", "#FFFFFF"],
["kf:dim", "#DDDDDD"]
];

KF_var_hudBackgroundFallback = [0, 1, 1, 0.8]; // vanilla fallbacks (\a3\ui_f\hpp\defineCommonColors.inc)

// an RGBA color of the player's settings (Options > Game > Colors): the profile variables <prefix>R / G / B / A
KF_fnc_profileColor = {
    params ["_prefix", "_fallback"];

    private _color = +_fallback;

    {
        _color set [_forEachIndex, profileNamespace getVariable [_prefix + _x, _color select _forEachIndex]];
    } forEach ["R", "G", "B", "A"];

    _color
};

// builds the color table and reads the HUD background of the player's settings; returns true if anything changed
KF_fnc_refreshColors = {
    private _background = ["IGUI_BCG_RGB_", KF_var_hudBackgroundFallback] call KF_fnc_profileColor;

    if ([KF_var_fixedColors, _background] isEqualTo [KF_var_colorList, KF_var_hudBackground]) exitWith {false};

    KF_var_colorList = +KF_var_fixedColors;
    KF_var_colors = createHashMapFromArray KF_var_colorList;
    KF_var_hudBackground = _background;
    true
};

// Fills in the colors: the player's name gets the accent color and his group members the text color instead of their
// side color, then every color key gets its profile color.
KF_fnc_colorize = {
    params ["_text"];

    private _sideKey = [playerSide] call KF_fnc_sideColorKey;

    {
        _x params ["_name", "_key"];

        _text = [
        _text,
        format ["<t color='%1'>%2</t>", _sideKey, _name],
        format ["<t color='%1'>%2</t>", _key, _name]
        ] call KF_fnc_replaceAll;
    } forEach KF_var_highlightedNames;

    {
        _x params ["_key", "_color"];

        _text = [_text, "'" + _key + "'", "'" + _color + "'"] call KF_fnc_replaceAll;
    } forEach KF_var_colorList;

    _text
};

// ---- group (game modes may replace KF_fnc_getGroupUnits) ----

KF_fnc_getGroupUnits = {
    params ["_unit"];

    units group _unit
};

// the names as the server's name tags contain them (KF_fnc_formatName: cut and escaped)
KF_fnc_getHighlightedNames = {
    private _others = ([player] call KF_fnc_getGroupUnits) - [player];

    ([[player, "kf:you"]] + (_others apply {[_x, "kf:text"]})) apply {
        _x params ["_unit", "_key"];

        [[_unit getVariable ["KF_var_name", ""]] call KF_fnc_formatName, _key]
    }
};

// ---- drawing ----

// the GUI grid cell [width, height] (\a3\ui_f\hpp\defineCommonGrids.inc)
KF_fnc_gridCell = {
    private _gridWidth = (safeZoneW / safeZoneH) min 1.2;

    [_gridWidth / 40, _gridWidth / 1.2 / 25]
};

// The title display of a feed on its layer, created on first use and again after it was closed (mission end, a game
// mode clearing the layer). RscTitleDisplayEmpty stores itself in uiNamespace while cutRsc runs; the own reference
// stays valid when the next feed (or another script) shows the class on another layer.
KF_fnc_feedDisplay = {
    params ["_feed"];

    private _variable = format ["KF_var_%1Display", _feed];
    private _display = uiNamespace getVariable [_variable, displayNull];

    if (!isNull _display) exitWith {_display};

    (KF_var_feedLayers get _feed) cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, true];
    _display = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
    (_display displayCtrl 1202) ctrlShow false; // the vignette of RscDisplayEmpty
    uiNamespace setVariable [_variable, _display];
    _display
};

// an entry in the HUD font, the feeds' text size and the text color, colors filled in
KF_fnc_formatEntry = {
    params ["_text", "_align"];

    [format [
    "<t font='RobotoCondensed' size='%1' color='kf:text' align='%2' shadow='1'>%3</t>",
    KF_var_textSizeCells,
    _align,
    _text
    ]] call KF_fnc_colorize
};

// Draws the entries of a feed one under the other from _top down, aligned at _anchorX by their "left" or "right" edge
// or their "center". An entry is a text (may have several lines) or a bar ["bar", fill 0..1]. _withBlocks: each entry
// on a block in the HUD background color, a text block as wide as its text. The text controls keep the full width
// _maxWidth, so the text never wraps after measuring. Unscheduled (isNil), so two draws of the same feed (line expiry,
// color refresh) never interleave.
KF_fnc_drawEntries = {
    isNil {_this call KF_fnc_createEntryControls};
};

KF_fnc_createEntryControls = {
    params ["_feed", "_entries", "_align", "_anchorX", "_top", "_maxWidth", "_withBlocks"];

    private _controlsVariable = format ["KF_var_%1Controls", _feed];

    {
        ctrlDelete _x;
    } forEach (uiNamespace getVariable [_controlsVariable, []]);

    private _controls = [];

    uiNamespace setVariable [_controlsVariable, _controls];

    if (_entries isEqualTo []) exitWith {};

    (call KF_fnc_gridCell) params ["_cellWidth", "_cellHeight"];

    private _layout = [[_feed] call KF_fnc_feedDisplay, _controls, _align, _anchorX, _maxWidth, _withBlocks, _cellWidth, _cellHeight];
    private _y = _top;
    private _width = 0; // of the entry above: a bar takes it over

    {
        private _size = if (_x isEqualType []) then {
            [_layout, _y, _width, _x select 1] call KF_fnc_createBarEntry
        } else {

            [_layout, _y, _x] call KF_fnc_createTextEntry
        };

        _width = _size select 0;
        _y = _y + (_size select 1) + KF_var_blockGap * _cellHeight;
    } forEach _entries;
};

// the left edge of a block of _width aligned at _anchorX
KF_fnc_blockX = {
    params ["_align", "_anchorX", "_width"];

    switch (_align) do {
        case "left": {_anchorX};
        case "right": {_anchorX - _width};
        default {_anchorX - _width / 2};
    }
};

// a text entry at _y, on a block as wide as its text; returns [width, height] of its block
KF_fnc_createTextEntry = {
    params ["_layout", "_y", "_text"];

    _layout params ["_display", "_controls", "_align", "_anchorX", "_maxWidth", "_withBlocks", "_cellWidth", "_cellHeight"];

    private _paddingX = 0;
    private _paddingY = 0;

    if (_withBlocks) then {
        _paddingX = (KF_var_blockPadding select 0) * _cellWidth;
        _paddingY = (KF_var_blockPadding select 1) * _cellHeight;
    };

    private _textX = switch (_align) do {
        case "left": {_anchorX + _paddingX};
        case "right": {_anchorX - _paddingX - _maxWidth};
        default {_anchorX - _maxWidth / 2};
    };

    // the block first, so the text lies on top of it
    private _block = controlNull;

    if (_withBlocks) then {
        _block = _display ctrlCreate ["RscText", -1];
        _block ctrlSetBackgroundColor KF_var_hudBackground;
        _controls pushBack _block;
    };

    private _textControl = _display ctrlCreate ["RscStructuredText", -1];

    _controls pushBack _textControl;
    _textControl ctrlSetBackgroundColor [0, 0, 0, 0];
    _textControl ctrlSetPosition [_textX, _y + _paddingY, _maxWidth, _cellHeight];
    _textControl ctrlCommit 0;
    _textControl ctrlSetStructuredText parseText ([_text, _align] call KF_fnc_formatEntry);

    private _textHeight = ctrlTextHeight _textControl;
    private _blockWidth = ((ctrlTextWidth _textControl) min _maxWidth) + 2 * _paddingX;
    private _blockHeight = _textHeight + 2 * _paddingY;

    _textControl ctrlSetPosition [_textX, _y + _paddingY, _maxWidth, _textHeight];
    _textControl ctrlCommit 0;

    if (_withBlocks) then {
        _block ctrlSetPosition [[_align, _anchorX, _blockWidth] call KF_fnc_blockX, _y, _blockWidth, _blockHeight];
        _block ctrlCommit 0;
    };

    [_blockWidth, _blockHeight]
};

// A bar entry at _y in the style of the fill level bars of the game modes' HUDs (SC): the whole bar on the HUD
// background, the filled share grey transparent (always, user: no red at low health), "<HP> HP" on it; one
// text line high and always KF_var_barWidth wide (a fixed size, user). Returns [width, height].
KF_fnc_createBarEntry = {
    params ["_layout", "_y", "", "_fill"];

    _layout params ["_display", "_controls", "_align", "_anchorX", "", "", "_cellWidth", "_cellHeight"];

    _fill = (_fill max 0) min 1;

    private _width = KF_var_barWidth * _cellWidth;
    private _blockX = [_align, _anchorX, _width] call KF_fnc_blockX;
    private _paddingY = (KF_var_blockPadding select 1) * _cellHeight;

    // in drawing order: the whole bar, the fill, the text
    private _block = _display ctrlCreate ["RscText", -1];
    private _bar = _display ctrlCreate ["RscText", -1];
    private _text = _display ctrlCreate ["RscStructuredText", -1];

    _controls append [_block, _bar, _text];

    _text ctrlSetBackgroundColor [0, 0, 0, 0];
    _text ctrlSetPosition [_blockX, _y + _paddingY, _width, _cellHeight];
    _text ctrlCommit 0;
    _text ctrlSetStructuredText parseText ([format ["%1 HP", ceil (_fill * 100)], "center"] call KF_fnc_formatEntry);

    private _textHeight = ctrlTextHeight _text;
    private _height = _textHeight + 2 * _paddingY;

    _text ctrlSetPosition [_blockX, _y + _paddingY, _width, _textHeight];
    _text ctrlCommit 0;

    _block ctrlSetBackgroundColor KF_var_hudBackground;
    _block ctrlSetPosition [_blockX, _y, _width, _height];
    _block ctrlCommit 0;

    _bar ctrlSetBackgroundColor KF_var_barColor;
    _bar ctrlSetPosition [_blockX, _y, _width * _fill, _height];
    _bar ctrlCommit 0;

    [_width, _height]
};

// ---- kill feed and mid feed ----
// Animated: each line keeps its block while it exists (KF_var_<feed>Items: id -> controls), so a change only moves
// and fades controls with one ctrlCommit each (no per-frame work). A new line fades in at its place while the others
// move to theirs; an expired or pushed out line fades out at its place, then it is removed and the others close up.

// adds a line to a feed; after the cooldown it fades out, the oldest lines over the maximum length at once
KF_fnc_addFeedLine = {
    params ["_feed", "_lines", "_line", "_cooldown", "_maximumLength", "_draw"];

    private _id = KF_var_nextLineId;

    KF_var_nextLineId = KF_var_nextLineId + 1;
    _lines pushBack [_id, _line];

    if (_maximumLength != -1) then {
        private _liveLines = _lines select {!((_x select 0) in KF_var_leavingLineIds)};

        {
            [_feed, _lines, _x select 0, _draw] call KF_fnc_removeFeedLine;
        } forEach (_liveLines select [0, (count _liveLines - _maximumLength) max 0]);
    };

    call _draw;

    [_feed, _lines, _id, _cooldown, _draw] spawn {
        params ["_feed", "_lines", "_id", "_cooldown", "_draw"];

        sleep _cooldown;
        [_feed, _lines, _id, _draw] call KF_fnc_removeFeedLine;
    };
};

// the line fades out at its place; then it is removed and the lines after it move up
KF_fnc_removeFeedLine = {
    params ["_feed", "_lines", "_id", "_draw"];

    if ((_id in KF_var_leavingLineIds) || {(_lines findIf {(_x select 0) == _id}) == -1}) exitWith {};

    KF_var_leavingLineIds set [_id, true];

    {
        _x ctrlSetFade 1;
        _x ctrlCommit KF_var_feedFadeOutDuration;
    } forEach ((([_feed] call KF_fnc_feedItems) getOrDefault [_id, []]) select [0, 2]);

    [_lines, _id, _draw] spawn {
        params ["_lines", "_id", "_draw"];

        sleep KF_var_feedFadeOutDuration;

        private _index = _lines findIf {(_x select 0) == _id};

        if (_index != -1) then {
            _lines deleteAt _index;
        };

        KF_var_leavingLineIds deleteAt _id;
        call _draw;
    };
};

// the shown lines of an animated feed: id -> [block, text control, shown text, block width, block height, block y]
KF_fnc_feedItems = {
    params ["_feed"];

    private _variable = format ["KF_var_%1Items", _feed];
    private _items = uiNamespace getVariable _variable;

    if (isNil "_items") then {
        _items = createHashMap;
        uiNamespace setVariable [_variable, _items];
    };

    _items
};

// Shows the lines [id, text] of an animated feed one under the other from _top down, each on a block as wide as its
// text, aligned at _anchorX like KF_fnc_drawEntries. Unscheduled (isNil), so two updates never interleave.
KF_fnc_drawAnimatedFeed = {
    isNil {_this call KF_fnc_updateAnimatedFeed};
};

KF_fnc_updateAnimatedFeed = {
    params ["_feed", "_lines", "_align", "_anchorX", "_top", "_maxWidth"];

    private _items = [_feed] call KF_fnc_feedItems;
    private _ids = _lines apply {_x select 0};

    // lines that are gone, and controls lost with their display (a game mode cleared the feed's layer)
    {
        private _item = _items get _x;

        if (!(_x in _ids) || {isNull (_item select 1)}) then {
            {
                ctrlDelete _x;
            } forEach (_item select [0, 2]);

            _items deleteAt _x;
        };
    } forEach (keys _items);

    if (_lines isEqualTo []) exitWith {};

    private _display = [_feed] call KF_fnc_feedDisplay;

    (call KF_fnc_gridCell) params ["_cellWidth", "_cellHeight"];

    private _paddingX = (KF_var_blockPadding select 0) * _cellWidth;
    private _paddingY = (KF_var_blockPadding select 1) * _cellHeight;

    private _textX = switch (_align) do {
        case "left": {_anchorX + _paddingX};
        case "right": {_anchorX - _paddingX - _maxWidth};
        default {_anchorX - _maxWidth / 2};
    };

    private _y = _top;
    private _remeasuring = false;

    {
        _x params ["_id", "_text"];

        private _item = _items getOrDefault [_id, []];
        private _isNew = _item isEqualTo [];

        // the block first, so the text lies on top of it
        if (_isNew) then {
            _item = [_display ctrlCreate ["RscText", -1], _display ctrlCreate ["RscStructuredText", -1], "", 0, 0, -1, -1e6];
            _items set [_id, _item];
            (_item select 1) ctrlSetBackgroundColor [0, 0, 0, 0];
        };

        _item params ["_block", "_textControl", "_shownText", "_width", "_height", "_shownY", "_measuredAt"];

        private _formatted = [_text, _align] call KF_fnc_formatEntry;

        // the HUD background may have changed (KF_fnc_refreshColors)
        _block ctrlSetBackgroundColor KF_var_hudBackground;

        // a new text or new colors: measured at the full width, so the text never wraps afterwards
        if (_formatted isNotEqualTo _shownText) then {
            _textControl ctrlSetPosition [_textX, (ctrlPosition _textControl) select 1, _maxWidth, _cellHeight];
            _textControl ctrlCommit 0;
            _textControl ctrlSetStructuredText parseText _formatted;
            _item set [2, _formatted];
            _item set [6, diag_tickTime];
            _measuredAt = diag_tickTime;
            _width = -1;
        };

        // measured again for a while (the text control keeps the full width): a picture whose texture is not loaded
        // yet (e.g. a weapon's first kill) is measured far too wide - the block would stay as wide as half the screen
        if ((diag_tickTime - _measuredAt) < KF_var_remeasureDuration) then {
            _remeasuring = true;

            private _newWidth = ((ctrlTextWidth _textControl) min _maxWidth) + 2 * _paddingX;
            private _newHeight = (ctrlTextHeight _textControl) + 2 * _paddingY;

            if ([_newWidth, _newHeight] isNotEqualTo [_width, _height]) then {
                _width = _newWidth;
                _height = _newHeight;
                _item set [3, _width];
                _item set [4, _height];
                _shownY = -1;
            };
        };

        if (_y != _shownY) then {
            _item set [5, _y];
            _block ctrlSetPosition [[_align, _anchorX, _width] call KF_fnc_blockX, _y, _width, _height];
            _textControl ctrlSetPosition [_textX, _y + _paddingY, _maxWidth, _height - 2 * _paddingY];

            if (_isNew) then {

                // in place at once, invisible, then fading in (a line pushed out at once stays invisible)
                {
                    _x ctrlSetFade 1;
                    _x ctrlCommit 0;

                    if !(_id in KF_var_leavingLineIds) then {
                        _x ctrlSetFade 0;
                        _x ctrlCommit KF_var_feedFadeInDuration;
                    };
                } forEach [_block, _textControl];
            } else {

                _block ctrlCommit KF_var_feedMoveDuration;
                _textControl ctrlCommit KF_var_feedMoveDuration;
            };
        };

        _y = _y + _height + KF_var_blockGap * _cellHeight;
    } forEach _lines;

    // while a line is measured again, the feed draws itself again shortly (with its lines of then)
    if (_remeasuring && {!(KF_var_remeasurePending getOrDefault [_feed, false])} && {_feed in KF_var_animatedFeedRedraws}) then {
        KF_var_remeasurePending set [_feed, true];

        [_feed] spawn {
            params ["_feed"];

            sleep KF_var_remeasureInterval;
            KF_var_remeasurePending set [_feed, false];
            call (KF_var_animatedFeedRedraws get _feed);
        };
    };
};

KF_fnc_setFeedVisible = {
    params ["_variable", "_visible", "_draw"];

    if ((missionNamespace getVariable _variable) isEqualTo _visible) exitWith {};

    missionNamespace setVariable [_variable, _visible];
    call _draw;
};

KF_fnc_addKillFeedLine = {
    params ["_line"];

    ["killFeed", KF_var_killFeedLines, _line, KF_var_killFeedCooldown, KF_var_killFeedMaximumLength, KF_fnc_drawKillFeed] call KF_fnc_addFeedLine;
};

KF_fnc_enableKillFeed = {
    params ["_enable"];

    ["KF_var_clientKillFeedVisible", _enable, KF_fnc_drawKillFeed] call KF_fnc_setFeedVisible;
};

// one block per line, the newest at the bottom
KF_fnc_drawKillFeed = {
    [
    "killFeed",
    [[], KF_var_killFeedLines] select (KF_var_clientKillFeedVisible && {missionNamespace getVariable ["KF_cba_showKillFeed", true]}),
    "right",
    safeZoneX + safeZoneW - KF_var_screenMargin,
    safeZoneY + safeZoneH / 8,
    safeZoneW / 2
    ] call KF_fnc_drawAnimatedFeed;
};

// the newest line on top
KF_fnc_addMidFeedLine = {
    params ["_line"];

    ["midFeed", KF_var_midFeedLines, _line, KF_var_midFeedCooldown, KF_var_midFeedMaximumLength, KF_fnc_drawMidFeed] call KF_fnc_addFeedLine;
};

KF_fnc_enableMidFeed = {
    params ["_enable"];

    ["KF_var_clientMidFeedVisible", _enable, KF_fnc_drawMidFeed] call KF_fnc_setFeedVisible;
};

// in the lower middle of the screen, the newest line on top, each line on its own block like the kill feed
KF_fnc_drawMidFeed = {
    private _lines = [];

    if (KF_var_clientMidFeedVisible && {missionNamespace getVariable ["KF_cba_showMidFeed", true]}) then {
        _lines = +KF_var_midFeedLines;
        reverse _lines;
    };

    ["midFeed", _lines, "center", 0.5, safeZoneY + safeZoneH / 1.3, 1] call KF_fnc_drawAnimatedFeed;
};

// ---- death feed and death transition ----
// The report stays until the player respawned. With KF_var_deathTransition the screen fades to black and the sound
// out meanwhile (after the kill cam) - until a spectator camera starts.

KF_fnc_playerHasRespawned = {
    alive player && {simulationEnabled player} && {!(player getVariable ["AIS_unconscious", false])} && {focusOn isEqualTo player}
};

// A mode calls this only when the player cannot re-enter until the next round (or match).
KF_fnc_markRoundEliminated = {
    if (KF_var_eliminatedAt < 0 || {KF_var_eliminatedUnit isNotEqualTo player}) then {
        KF_var_eliminatedAt = diag_tickTime;
        KF_var_eliminatedUnit = player;
        KF_var_deathFeedExpired = false;
        terminate KF_var_deathFeedExpiryScript;

        KF_var_deathFeedExpiryScript = [player, KF_var_eliminatedAt, KF_var_eliminatedAt + KF_var_eliminatedDeathFeedDuration] spawn {
            params ["_unit", "_started", "_deadline"];

            waitUntil {
                uiSleep 0.05;
                _unit isNotEqualTo player || {KF_var_eliminatedAt != _started} ||
                    {call KF_fnc_playerHasRespawned} || {diag_tickTime >= _deadline}
            };

            if (_unit isEqualTo player && {KF_var_eliminatedAt == _started} && {!(call KF_fnc_playerHasRespawned)}) then {
                KF_var_deathFeedExpired = true;
                KF_var_deathFeedParts = [];
                KF_var_deathFeedLines = [];
                call KF_fnc_drawDeathFeed;
            };
        };
    };
};

KF_fnc_deathFeedHasExpired = {
    params [["_now", diag_tickTime]];

    KF_var_eliminatedUnit isEqualTo player && {KF_var_eliminatedAt >= 0} &&
        {_now >= KF_var_eliminatedAt + KF_var_eliminatedDeathFeedDuration}
};

// the (EG) spectator display, or the camera on another unit (e.g. the spectator of a game mode)
KF_fnc_isSpectating = {
    !isNull findDisplay KF_var_spectatorDisplay || {focusOn isNotEqualTo player}
};

KF_fnc_addDeathFeed = {
    params ["_parts"];

    if (call KF_fnc_playerHasRespawned) exitWith {};

    if (KF_var_deathFeedExpired && {KF_var_eliminatedUnit isEqualTo player}) exitWith {};

    KF_var_deathFeedParts = [[_parts], _parts] select (_parts isEqualType []);
    call KF_fnc_showDeathFeed;
};

// an own kill evaluated after the own death; after a respawn it goes to the mid feed
KF_fnc_addDeathFeedLine = {
    params ["_line"];

    if (call KF_fnc_playerHasRespawned) exitWith {
        [_line] call KF_fnc_addMidFeedLine;
    };

    if (KF_var_deathFeedExpired && {KF_var_eliminatedUnit isEqualTo player}) exitWith {};

    KF_var_deathFeedLines pushBack _line;
    call KF_fnc_showDeathFeed;
};

KF_fnc_showDeathFeed = {
    if (KF_var_eliminatedUnit isNotEqualTo player) then {KF_var_deathFeedExpired = false};
    if (KF_var_deathFeedExpired) exitWith {};

    call KF_fnc_drawDeathFeed;

    if (scriptDone KF_var_deathFeedScript) then {
        KF_var_deathFeedScript = [] spawn KF_fnc_runDeathFeed;
    };
};

KF_fnc_runDeathFeed = {
    private _shownUntil = time + 2;

    waitUntil {(call KF_fnc_playerHasRespawned) || {time >= _shownUntil && {!KF_var_killCamActive}}};

    // an own layer, so the black screens of game modes stay untouched; the kill cam may have ended in black on it
    // (KF_var_killCamOutro "black"): then the black is held, the own body is never seen
    private _layer = "KF_deathTransition" call BIS_fnc_rscLayer;
    private _black = missionNamespace getVariable ["KF_var_killCamBlack", false];

    KF_var_killCamBlack = false;

    // only for a death report, not for trade kill lines alone
    if (
    KF_var_deathTransition && {KF_var_deathFeedParts isNotEqualTo []} && {!(call KF_fnc_playerHasRespawned)} &&
        {!(call KF_fnc_isSpectating)}

    ) then {
        private _soundVolume = soundVolume;

        switch true do {
            case _black: {
                _layer cutText ["", "BLACK FADED", 999999, true];
            };
            case (!visibleMap): {
                _layer cutText ["", "BLACK OUT", 1, true];
            };
        };

        1 fadeSound 0;
        waitUntil {(call KF_fnc_playerHasRespawned) || {call KF_fnc_isSpectating}};
        _layer cutText ["", "BLACK IN", 1, true];
        1 fadeSound _soundVolume;
    } else {

        // no transition (respawned or spectating meanwhile): the kill cam's black goes
        if (_black) then {
            _layer cutText ["", "BLACK IN", 1, true];
        };
    };

    waitUntil {
        sleep 0.05;
        (call KF_fnc_playerHasRespawned) || {KF_var_deathFeedExpired}
    };

    KF_var_deathFeedExpired = !(call KF_fnc_playerHasRespawned);

    KF_var_deathFeedParts = [];
    KF_var_deathFeedLines = [];
    call KF_fnc_drawDeathFeed;
};

KF_fnc_enableDeathFeed = {
    params ["_enable"];

    ["KF_var_clientDeathFeedVisible", _enable, KF_fnc_drawDeathFeed] call KF_fnc_setFeedVisible;
};

// each part of the report (killer, his health as a bar, hits, assistants, game mode info) and each trade kill line on
// its own block. Missions with their own texts top left set KF_var_deathFeedTop (screen y) to move it below them.
KF_fnc_drawDeathFeed = {
    private _entries = [];

    if (KF_var_clientDeathFeedVisible && {!KF_var_deathFeedExpired} && {missionNamespace getVariable ["KF_cba_showDeathFeed", true]}) then {
        _entries = (KF_var_deathFeedParts + KF_var_deathFeedLines) select {_x isNotEqualTo ""};
    };

    [
    "deathFeed",
    _entries,
    "left",
    safeZoneX + KF_var_screenMargin,
    missionNamespace getVariable ["KF_var_deathFeedTop", 0.66 * ((safeZoneH / 8) + safeZoneY)],
    KF_var_deathFeedMaxWidth * ((call KF_fnc_gridCell) select 0),
    true
    ] call KF_fnc_drawEntries;
};

// ---- kill info: plain text in the middle of the screen ----

KF_fnc_showKillInfo = {
    params ["_text", "_duration"];

    terminate KF_var_killInfoScript;
    KF_var_killInfoText = _text;
    call KF_fnc_drawKillInfo;

    KF_var_killInfoScript = [_duration] spawn {
        params ["_duration"];

        sleep _duration;

        isNil {
            {
                _x ctrlSetFade 1;
                _x ctrlCommit 1;
            } forEach (uiNamespace getVariable ["KF_var_killInfoControls", []]);
        };

        sleep 1;
        call KF_fnc_hideKillInfo;
    };
};

KF_fnc_hideKillInfo = {
    KF_var_killInfoText = "";
    call KF_fnc_drawKillInfo;
};

// at its former position, but inside the safe zone (it was cut off at the top with large interface sizes); on a
// block like the feeds (a centered text at the HUD size that doesn't need the player's whole attention)
KF_fnc_drawKillInfo = {
    [
    "killInfo",
    [KF_var_killInfoText] select {_x != ""},
    "center",
    0.5,
    -0.02 max (safeZoneY + KF_var_screenMargin),
    1,
    true
    ] call KF_fnc_drawEntries;
};

#include "killCam.sqf"

// ---- start: redraws the feeds when the group or the profile colors change ----

call KF_fnc_refreshColors;

[] spawn {

    // KF_fnc_colorize needs the part for every machine; a joining client may get it after this file
    waitUntil {!isNull player && {!isNil "KF_fnc_formatName"}};

    private _seconds = 1;

    while {true} do {
        if (call KF_fnc_playerHasRespawned) then {
            KF_var_eliminatedAt = -1;
            KF_var_eliminatedUnit = objNull;
            KF_var_deathFeedExpired = false
        };

        private _names = call KF_fnc_getHighlightedNames;
        private _changed = _names isNotEqualTo KF_var_highlightedNames;

        if (_seconds mod KF_var_colorRefreshInterval == 0) then {
            _changed = (call KF_fnc_refreshColors) || _changed;
        };

        if (_changed) then {
            KF_var_highlightedNames = _names;
            call KF_fnc_drawKillFeed;
            call KF_fnc_drawMidFeed;
            call KF_fnc_drawDeathFeed;
            call KF_fnc_drawKillInfo;
        };

        _seconds = _seconds + 1;
        sleep 1;
    };
};
