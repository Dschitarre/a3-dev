// Arsenal selection (client): list selection, "+" / "-" / arrow key and import handlers that enforce the limits, and
// the list decorations: hooks for a mode to decorate the item lists (extra rows, header rows, texts, colors, order) and
// to react to the open tab, called after the arsenal filled or updated the lists. Without a decorator nothing changes.
#include "\a3\ui_f\hpp\defineResincl.inc"
#include "\a3\ui_f\hpp\defineResinclDesign.inc"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"

// ---- selection ----

VA_fnc_getWeaponNames = {
    params ["_weapon"];

    if (_weapon == "") then {[]} else {[_weapon, _weapon call BIS_fnc_baseWeapon]}
};

// the weapon whose tab is open ("" if no weapon tab is open)
VA_fnc_getActiveWeapon = {
    params ["_display", "_center"];

    private _weapon = "";

    {
        _x params ["_tab", "_class"];

        if (ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _tab))) exitWith {
            _weapon = _class;
        };
    } forEach [
        [IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON, primaryWeapon _center],
        [IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON, secondaryWeapon _center],
        [IDC_RSCDISPLAYARSENAL_TAB_HANDGUN, handgunWeapon _center]
    ];

    _weapon
};

// the classes equipped in the slot of an arsenal tab (attachment tabs: on the weapon whose tab is selected)
VA_fnc_getEquippedItems = {
    params ["_display", "_center", "_idc"];

    switch _idc do {
        case IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON: {[primaryWeapon _center] call VA_fnc_getWeaponNames};
        case IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON: {[secondaryWeapon _center] call VA_fnc_getWeaponNames};
        case IDC_RSCDISPLAYARSENAL_TAB_HANDGUN: {[handgunWeapon _center] call VA_fnc_getWeaponNames};
        case IDC_RSCDISPLAYARSENAL_TAB_UNIFORM: {[uniform _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_VEST: {[vest _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_BACKPACK: {[backpack _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_HEADGEAR: {[headgear _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_GOGGLES: {[goggles _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_NVGS: {[hmd _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_BINOCULARS: {[binocular _center]};
        case IDC_RSCDISPLAYARSENAL_TAB_MAP;
        case IDC_RSCDISPLAYARSENAL_TAB_GPS;
        case IDC_RSCDISPLAYARSENAL_TAB_RADIO;
        case IDC_RSCDISPLAYARSENAL_TAB_COMPASS;
        case IDC_RSCDISPLAYARSENAL_TAB_WATCH: {assignedItems _center};
        case IDC_RSCDISPLAYARSENAL_TAB_ITEMOPTIC;
        case IDC_RSCDISPLAYARSENAL_TAB_ITEMACC;
        case IDC_RSCDISPLAYARSENAL_TAB_ITEMMUZZLE;
        case IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD: {
            private _weapon = [_display, _center] call VA_fnc_getActiveWeapon;

            if (_weapon == "") then {[]} else {_center weaponAccessories _weapon}
        };
        default {[]};
    }
};

// selects the row of the equipped item (else the empty row) without equipping anything; a decorated list keeps its
// scroll position (its locked rows are at the end, far from the equipped one)
VA_fnc_selectEquippedRow = {
    params ["_ctrlList", "_equipped"];

    private _row = -1;
    private _emptyRow = -1;

    for "_index" from 0 to (([_ctrlList] call VA_fnc_listSize) - 1) do {
        private _data = [_ctrlList, _index] call VA_fnc_listData;

        if (_data == "") then {
            if (_emptyRow == -1) then {
                _emptyRow = _index;
            };
        } else {
            if ((_row == -1) && {(_equipped findIf {_x == _data}) != -1}) then {
                _row = _index;
            };
        };
    };

    if (_row == -1) then {
        _row = _emptyRow;
    };

    private _scroll = ctrlScrollValues _ctrlList;
    [_ctrlList, _row] call VA_fnc_listSelect;

    if (call VA_fnc_isDecorated) then {
        _ctrlList ctrlSetScrollValues _scroll;
    };
};

// message for an item that is not in the arsenal (VA_var_lockReason of the mode tells why)
VA_fnc_getLockedMessage = {
    params ["_class"];

    private _reason = "";
    private _lockReason = missionNamespace getVariable "VA_var_lockReason";

    if !(isNil "_lockReason") then {
        with missionNamespace do {
            _reason = [_class] call _lockReason;
        };
    };

    if (_reason == "") then {
        format ["%1 is not available, it can only be kept or removed", [_class] call VA_fnc_getDisplayName]
    } else {
        format ["%1 is locked (%2)", [_class] call VA_fnc_getDisplayName, _reason]
    }
};

// list selection (replaces the arsenal's SelectItem handler): the arsenal rules (VA_fnc_applySelection), then the lists
// the arsenal refilled are decorated again; a header row is never selected (VA_fnc_skipHeader)
VA_fnc_onSelectItem = {
    params ["_display", "_ctrlList", "_idc"];

    if (uiNamespace getVariable ["VA_var_revertingSelection", false]) exitWith {};

    private _cursel = lbCurSel _ctrlList;

    if ((_cursel >= 0) && {[_ctrlList, _cursel] call VA_fnc_listIsHeader}) exitWith {
        [_display, _ctrlList, _idc, _cursel] call VA_fnc_skipHeader;
    };

    [_display, [_display, _ctrlList, _idc] call VA_fnc_applySelection] call VA_fnc_decorateLists;
};

// a header row was selected instead of an item: the arrow / page keys move on to the next item in their direction; a
// click selects the equipped item again in an equipment list (a header equips nothing), the first item of the group in
// a cargo list (selecting there adds nothing)
VA_fnc_skipHeader = {
    params ["_display", "_ctrlList", "_idc", "_row"];

    // the list's KeyDown handler (VA_fnc_addDecorationEvents) runs before the selection changes
    (uiNamespace getVariable ["VA_var_listKey", [-1, -1]]) params ["_key", "_frame"];

    private _byKey = _frame == diag_frameNo;

    if (!_byKey && {_idc in (missionNamespace getVariable ["VA_var_equipmentTabs", []])}) exitWith {
        private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
        [_ctrlList, [_display, _center, _idc] call VA_fnc_getEquippedItems] call VA_fnc_selectEquippedRow;
    };

    private _step = [1, -1] select (_byKey && {_key in [DIK_UP, DIK_PRIOR, DIK_HOME, DIK_NUMPAD7, DIK_NUMPAD8, DIK_NUMPAD9]});
    private _target = [_ctrlList, _row, _step] call VA_fnc_listFindItemRow;

    if (_target == -1) then {
        _target = [_ctrlList, _row, -_step] call VA_fnc_listFindItemRow;
    };

    // like a selection of that row by the player (equips its item in an equipment list)
    _ctrlList lbSetCurSel _target;
};

// a locked item can't be equipped unless it already is in that slot; what the arsenal adds with a selection (e.g. the
// magazines of a new weapon) follows the rules; returns the tabs whose lists the arsenal may have changed
VA_fnc_applySelection = {
    params ["_display", "_ctrlList", "_idc"];

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _cursel = lbCurSel _ctrlList;
    private _item = "";

    if (_cursel >= 0) then {
        _item = [_ctrlList, _cursel] call VA_fnc_listData;
    };

    private _isEquipmentTab = _idc in (missionNamespace getVariable ["VA_var_equipmentTabs", []]);
    private _equipped = [_display, _center, _idc] call VA_fnc_getEquippedItems;

    // identity / cargo tabs, a removal or the current item: nothing is added
    if (!_isEquipmentTab || {_item == ""} || {(_equipped findIf {_x == _item}) != -1}) exitWith {
        ["SelectItem", [_display, _ctrlList, _idc]] call VA_fnc_callArsenal;

        // a decorated cargo list shows its locked items too: clicking one says why "+" won't add it (not for the
        // arsenal's own selections while it refills a list)
        if (
            (_item != "") &&
            {_idc in (missionNamespace getVariable ["VA_var_cargoTabs", []])} &&
            {call VA_fnc_isDecorated} &&
            {(uiNamespace getVariable ["VA_var_arsenalDepth", 0]) == 0} &&
            {!([_item, uiNamespace getVariable ["VA_var_unlockedCargo", []]] call VA_fnc_isUnlocked)}
        ) then {
            ["showMessage", [_display, [_item] call VA_fnc_getLockedMessage]] call BIS_fnc_arsenal;
        };

        if _isEquipmentTab then {[_display, _idc] call VA_fnc_getAffectedTabs} else {[]}
    };

    if !([_item, uiNamespace getVariable ["VA_var_unlockedCargo", []]] call VA_fnc_isUnlocked) exitWith {
        [_ctrlList, _equipped] call VA_fnc_selectEquippedRow;
        ["showMessage", [_display, [_item] call VA_fnc_getLockedMessage]] call BIS_fnc_arsenal;

        []
    };

    private _before = [getUnitLoadout _center] call VA_fnc_countLoadout;
    ["SelectItem", [_display, _ctrlList, _idc]] call VA_fnc_callArsenal;
    private _removed = [_center, _before] call VA_fnc_enforceRules;

    if (_removed isEqualTo []) exitWith {
        [_display, _idc] call VA_fnc_getAffectedTabs
    };

    ["ListSelectCurrent", [_display]] call VA_fnc_callArsenal;
    ["showMessage", [_display, [_removed] call VA_fnc_formatRemoved]] call BIS_fnc_arsenal;

    missionNamespace getVariable ["VA_var_allTabs", []]
};

// "+" of the cargo lists (button and right arrow key): only items that are in the arsenal and below their max count
VA_fnc_onCargoAdd = {
    params ["_display"];

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _item = "";
    private _idc = -1;

    // the selected item of the active right list, like the arsenal's buttonCargo
    {
        private _ctrlList = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x);

        if (ctrlEnabled _ctrlList) exitWith {
            private _cursel = lbCurSel _ctrlList;
            _idc = _x;

            if (_cursel >= 0) then {
                _item = _ctrlList lnbData [_cursel, 0];
            };
        };
    } forEach (missionNamespace getVariable ["VA_var_rightTabs", []]);

    private _message = "";

    if (_item != "") then {
        if !([_item, uiNamespace getVariable ["VA_var_unlockedCargo", []]] call VA_fnc_isUnlocked) exitWith {
            _message = [_item] call VA_fnc_getLockedMessage;
        };

        private _max = (call VA_fnc_getMaxItemCounts) getOrDefault [toLower _item, -1];

        if ((_max >= 0) && {({_x == _item} count ((uniformItems _center) + (vestItems _center) + (backpackItems _center))) >= _max}) then {
            _message = format ["Limit reached: at most %1x %2 in uniform, vest and backpack", _max, [_item] call VA_fnc_getDisplayName];
        };
    };

    if (_message != "") exitWith {
        ["showMessage", [_display, _message]] call BIS_fnc_arsenal;
    };

    ["buttonCargo", [_display, 1]] call VA_fnc_callArsenal;

    if (_idc != -1) then {
        [_display, [_idc]] call VA_fnc_decorateLists;
    };
};

// "-" of the cargo lists (button and left arrow key), like the arsenal's own handler, then the list is decorated again
VA_fnc_onCargoRemove = {
    params ["_display"];

    ["buttonCargo", [_display, -1]] call VA_fnc_callArsenal;

    private _rightTabs = missionNamespace getVariable ["VA_var_rightTabs", []];
    private _index = _rightTabs findIf {ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x))};

    if (_index != -1) then {
        [_display, [_rightTabs select _index]] call VA_fnc_decorateLists;
    };
};

// import from the clipboard (button and CTRL + V): the imported loadout follows the rules like a loaded one
VA_fnc_onImport = {
    params ["_display"];

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _before = [getUnitLoadout _center] call VA_fnc_countLoadout;

    ["buttonImport", [_display]] call VA_fnc_callArsenal;

    private _removed = [_center, _before, true] call VA_fnc_enforceRules;

    if (_removed isNotEqualTo []) then {
        ["ListSelectCurrent", [_display]] call VA_fnc_callArsenal;
        ["showMessage", [_display, [_removed] call VA_fnc_formatRemoved]] call BIS_fnc_arsenal;
    };

    [_display] call VA_fnc_decorateAll;
};

// ---- list decorations: hooks ----

// set by the mode in missionNamespace (the code runs there):
// VA_var_listDecorator  {params ["_display", "_ctrlList", "_idc"]} after the arsenal filled or updated the list of tab
//                       _idc (also for empty lists); it may add rows (VA_fnc_listAddRow) and header rows
//                       (VA_fnc_listAddHeader), style them (VA_fnc_listStyleRows) and order them (VA_fnc_listSort).
//                       The header rows of the previous decoration are removed before, the selected item stays
//                       selected.
// VA_var_tabDecorator   {params ["_display", "_idc"]} after the open tab changed (VA_fnc_getActiveTab, -1 = none) or
//                       the interface was shown / hidden
// VA_var_lockReason     {params ["_class"]} why a class is not in the arsenal ("" = unknown), for the arsenal messages

VA_fnc_isDecorated = {
    !isNil {missionNamespace getVariable "VA_var_listDecorator"}
};

// the locals BIS_fnc_arsenal assigns (generated from the game's fn_arsenal.sqf). It assigns many of them without
// private, e.g. TabSelectLeft / TabSelectRight loop over all tabs with "_idc = _x"; SQF scoping is dynamic, so such
// an assignment overwrites the caller's local of the same name (VA_fnc_onTabSelect's _idc ended as the last tab,
// CARGOMISC, and the right lists the arsenal had just refilled were never decorated).
VA_var_arsenalLocals = [
    "_acc", "_accIndex", "_action", "_active", "_add", "_addons", "_allgear", "_alpha", "_alt", "_appId", "_barMax",
    "_barMin", "_blacklist", "_box", "_boxes", "_buttonID", "_cam", "_camData", "_camPosVar", "_cargo", "_center",
    "_centerOrig", "_centerPos", "_centerSize", "_centerSizeBottom", "_centerSizeUp", "_cfg", "_CFGGLASSES",
    "_cfgMag", "_CFGMAGAZINES", "_cfgMuzzle", "_CFGUNITINSIGNIA", "_CFGVEHICLES", "_CFGVOICE", "_cfgWeapon",
    "_CFGWEAPONS", "_class", "_className", "_color", "_colorWarning", "_columns", "_compatibleItems",
    "_configArray", "_configname", "_confirmAction", "_ctrBackgroundRight", "_ctrFrameRight", "_ctrl",
    "_ctrlArrowLeft", "_ctrlArrowRight", "_ctrlBackground", "_ctrlButton", "_ctrlButtonClose", "_ctrlButtonExport",
    "_ctrlButtonImport", "_ctrlButtonInterface", "_ctrlButtonLoad", "_ctrlButtonOK", "_ctrlButtonRandom",
    "_ctrlButtonSave", "_ctrlButtonTry", "_ctrlDLC", "_ctrlDLCBackground", "_ctrlFade", "_ctrlIcon",
    "_ctrlIconBackground", "_ctrlIconPos", "_ctrlIconPosH", "_ctrlIconPosW", "_ctrlInfo", "_ctrlInfoAuthor",
    "_ctrlInfoName", "_ctrlLineIcon", "_ctrlLinePosX", "_ctrlLineTabLeft", "_ctrlLineTabPosX", "_ctrlLineTabPosY",
    "_ctrlLineTabRight", "_ctrlList", "_ctrlListDisabled", "_ctrlListHandgun", "_ctrlListLeft", "_ctrlListPos",
    "_ctrlListPrimaryWeapon", "_ctrlListSecondaryWeapon", "_ctrlLoad", "_ctrlLoadCargo", "_ctrlMessage",
    "_ctrlMouseArea", "_ctrlMouseBlock", "_ctrlPos", "_ctrlSort", "_ctrlSpace", "_ctrlStat", "_ctrlStats",
    "_ctrlStatsPos", "_ctrlTab", "_ctrlTabPos", "_ctrlTabs", "_ctrlTabsPos", "_ctrlTabsPosX", "_ctrlTabsPosY",
    "_ctrlTemplate", "_ctrlTemplateButtonCancel", "_ctrlTemplateButtonDelete", "_ctrlTemplateButtonOK",
    "_ctrlTemplateName", "_ctrlTemplateValue", "_ctrlText", "_current", "_cursel", "_data", "_defaultItem",
    "_defaultItems", "_defaultShow", "_dis", "_disabledItems", "_disMax", "_display", "_displayMission",
    "_displayName", "_dlc", "_dlcName", "_dlcParams", "_dX", "_dY", "_exportCenter", "_exportInsignia", "_face",
    "_faceIndex", "_faces", "_fade", "_fadeCargo", "_fadeItems", "_fadeRight", "_fastLookupTable",
    "_firstAvailable", "_fnc_addBinoculars", "_fnc_addItem", "_fnc_addItemVerify", "_fnc_addModIcon",
    "_fnc_addWeapon", "_fnc_dataPushBack", "_fnc_getFaceConfig", "_fnc_getUnitInsignia", "_fnc_removeItem",
    "_fnc_removeWeapon", "_fnc_setUnitInsignia", "_fnc_showStats", "_fnc_testItemAndStore", "_fullVersion",
    "_function", "_gridH", "_h", "_hideTemplate", "_idc", "_idcCount", "_idcList", "_idcs", "_import",
    "_importArray", "_index", "_indexLeft", "_input", "_insignia", "_inTemplate", "_intensity", "_inventory",
    "_isArsenal", "_isIncompatible", "_item", "_itemAdded", "_itemCfg", "_itemConfig", "_itemName", "_itemPrevious",
    "_items", "_itemScope", "_itemsCurrent", "_key", "_lbAdd", "_lbcursel", "_light", "_list", "_listDefaults",
    "_LMB", "_load", "_mag", "_magazine", "_magazineCfg", "_magazines", "_magazinesThrowPut", "_mass",
    "_materialArray", "_maximumLoad", "_message", "_missionBlacklist", "_modID", "_modList", "_mods", "_name",
    "_nameID", "_newWeaponItems", "_oldWeaponItems", "_params", "_pos", "_posCenter", "_return", "_rowH", "_rows",
    "_scope", "_script", "_select", "_selected", "_selectedWeaponType", "_selectIndex", "_selections", "_selPos",
    "_shift", "_show", "_showCargo", "_showItems", "_shown", "_showRight", "_soldiers", "_sort", "_sortValues",
    "_speaker", "_sphere", "_statArmorExpl", "_statArmorShot", "_statControls", "_statDispersion", "_statHit",
    "_statInitSpeed", "_statMass", "_statMaximumLoad", "_statMaxRange", "_statReloadSpeed", "_stats",
    "_statsBackpacks", "_statsBackpacksMax", "_statsBackpacksMin", "_statsEquipment", "_statsEquipmentMax",
    "_statsEquipmentMin", "_statsExtremes", "_statsMax", "_statsMin", "_supply", "_tab", "_target", "_targetPos",
    "_testItem", "_text", "_textureArray", "_to", "_toggleSpace", "_type", "_types", "_typesDataIndex", "_uiPos",
    "_unit", "_value", "_virtualAll", "_virtualBackpackCargo", "_virtualCargo", "_virtualItemCargo",
    "_virtualMagazineCargo", "_virtualWeaponCargo", "_weapon", "_weaponAccessories", "_weaponCfg", "_weaponID",
    "_weapons", "_whitelist", "_xCfg", "_z"
];

// BIS_fnc_arsenal behind a scope barrier: its locals are declared here, so the callers' locals stay unchanged. The
// lists it updates are decorated by the caller afterwards, not by the selection events of the arsenal's own list
// updates in between.
VA_fnc_callArsenal = {
    params ["_mode", "_arguments"];

    private (missionNamespace getVariable ["VA_var_arsenalLocals", []]);

    uiNamespace setVariable ["VA_var_arsenalDepth", (uiNamespace getVariable ["VA_var_arsenalDepth", 0]) + 1];
    [_mode, _arguments] call BIS_fnc_arsenal;
    uiNamespace setVariable ["VA_var_arsenalDepth", (uiNamespace getVariable ["VA_var_arsenalDepth", 1]) - 1];
};

// the tabs whose lists the arsenal updates when the item of tab _idc changes or its tab opens: the tab itself, the
// attachment lists of a weapon, the magazine list and the open cargo list of a container
VA_fnc_getAffectedTabs = {
    params ["_display", "_idc"];

    private _tabs = [_idc];

    if (_idc in (missionNamespace getVariable ["VA_var_weaponTabs", []])) then {
        _tabs append (missionNamespace getVariable ["VA_var_attachmentTabs", []]);
    };

    if (_idc in (missionNamespace getVariable ["VA_var_containerTabs", []])) then {
        _tabs append ((missionNamespace getVariable ["VA_var_cargoTabs", []]) select {
            (_x == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG) || {ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x))}
        });
    };

    _tabs
};

// the open tab: the tab opened last while its list is shown, else the open left tab, -1 if none
VA_fnc_getActiveTab = {
    params ["_display"];

    private _lastTab = uiNamespace getVariable ["VA_var_lastTab", -1];

    if ((_lastTab >= 0) && {ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _lastTab))}) exitWith {_lastTab};

    private _leftTabs = missionNamespace getVariable ["VA_var_leftTabs", []];
    private _index = _leftTabs findIf {ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x))};

    if (_index == -1) then {-1} else {_leftTabs select _index}
};

// ---- list decorations: decorating ----

// VA_var_listDecorator for the lists of the tabs (skipped while an arsenal update runs, its caller decorates
// afterwards); selection changes of the decorator don't equip anything. The selected item stays selected; a list that
// was only decorated again keeps its scroll position, one the arsenal refilled shows its selected row.
VA_fnc_decorateLists = {
    params ["_display", "_idcs"];

    private _decorator = missionNamespace getVariable "VA_var_listDecorator";

    if (isNil "_decorator" || {isNull _display} || {(uiNamespace getVariable ["VA_var_arsenalDepth", 0]) > 0}) exitWith {};

    private _silent = uiNamespace getVariable ["VA_var_revertingSelection", false];
    uiNamespace setVariable ["VA_var_revertingSelection", true];

    {
        private _idc = _x;
        private _ctrlList = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _idc);

        if !(isNull _ctrlList) then {
            private _cursel = lbCurSel _ctrlList;
            private _selected = if (_cursel >= 0) then {[_ctrlList, _cursel] call VA_fnc_listData} else {""};
            private _size = [_ctrlList] call VA_fnc_listSize;
            private _scroll = ctrlScrollValues _ctrlList;

            [_ctrlList] call VA_fnc_listRemoveHeaders;

            with missionNamespace do {
                [_display, _ctrlList, _idc] call _decorator;
            };

            if (_cursel >= 0) then {
                [_ctrlList, _selected] call VA_fnc_listSelectData;

                if (([_ctrlList] call VA_fnc_listSize) == _size) then {
                    _ctrlList ctrlSetScrollValues _scroll;
                } else {
                    [_ctrlList] call VA_fnc_listShowSelection;
                };
            };
        };
    } forEach (_idcs arrayIntersect _idcs);

    uiNamespace setVariable ["VA_var_revertingSelection", _silent];
};

VA_fnc_decorateTab = {
    params ["_display"];

    private _decorator = missionNamespace getVariable "VA_var_tabDecorator";

    if (isNil "_decorator" || {isNull _display}) exitWith {};

    private _idc = [_display] call VA_fnc_getActiveTab;

    with missionNamespace do {
        [_display, _idc] call _decorator;
    };
};

VA_fnc_decorateAll = {
    params ["_display"];

    [_display, missionNamespace getVariable ["VA_var_allTabs", []]] call VA_fnc_decorateLists;
    [_display] call VA_fnc_decorateTab;
};

// ---- list decorations: arsenal events (only with a list decorator) ----

VA_fnc_initDecorations = {
    params ["_display"];

    if !(call VA_fnc_isDecorated) exitWith {};

    uiNamespace setVariable ["VA_var_arsenalDepth", 0];
    uiNamespace setVariable ["VA_var_revertingSelection", false];
    uiNamespace setVariable ["VA_var_lastTab", -1];

    [_display] call VA_fnc_addDecorationEvents;
    [_display] call VA_fnc_decorateAll;
};

// the tab buttons, the sort menus and the "-" button call the arsenal like before and decorate afterwards; a click in
// the 3D area (closes the tabs) and the interface button update the tab decoration; the lists note the keys pressed
// on them (VA_fnc_skipHeader)
VA_fnc_addDecorationEvents = {
    params ["_display"];

    private _tabs = missionNamespace getVariable ["VA_var_allTabs", []];

    // without the full arsenal the identity tabs are hidden and have no handlers
    if !(missionNamespace getVariable ["BIS_fnc_arsenal_fullArsenal", false]) then {
        _tabs = _tabs - (missionNamespace getVariable ["VA_var_identityTabs", []]);
    };

    {
        private _idc = _x;

        {
            private _ctrlTab = _display displayCtrl (_x + _idc);
            _ctrlTab setVariable ["VA_var_tab", _idc];
            _ctrlTab ctrlRemoveAllEventHandlers "ButtonClick";
            _ctrlTab ctrlAddEventHandler ["ButtonClick", {
                params ["_ctrlTab"];

                with uiNamespace do {
                    [ctrlParent _ctrlTab, _ctrlTab getVariable ["VA_var_tab", -1]] call VA_fnc_onTabSelect;
                };
            }];
        } forEach [IDC_RSCDISPLAYARSENAL_TAB, IDC_RSCDISPLAYARSENAL_ICON];

        private _ctrlList = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _idc);
        _ctrlList ctrlRemoveAllEventHandlers "KeyDown";
        _ctrlList ctrlAddEventHandler ["KeyDown", {
            params ["", "_key"];

            uiNamespace setVariable ["VA_var_listKey", [_key, diag_frameNo]];
            false
        }];

        private _ctrlSort = _display displayCtrl (IDC_RSCDISPLAYARSENAL_SORT + _idc);

        if !(isNull _ctrlSort) then {
            _ctrlSort ctrlRemoveAllEventHandlers "LBSelChanged";
            _ctrlSort ctrlAddEventHandler ["LBSelChanged", {
                params ["_ctrlSort", "_cursel"];

                with uiNamespace do {
                    [_ctrlSort, _cursel] call VA_fnc_onSort;
                };
            }];
        };
    } forEach _tabs;

    private _ctrlArrowLeft = _display displayCtrl IDC_RSCDISPLAYARSENAL_ARROWLEFT;
    _ctrlArrowLeft ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlArrowLeft ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];

        with uiNamespace do {
            [ctrlParent _ctrl] call VA_fnc_onCargoRemove;
        };
    }];

    // added after the arsenal's own handlers, which run first
    {
        _x params ["_idc", "_event"];

        (_display displayCtrl _idc) ctrlAddEventHandler [_event, {
            params ["_ctrl"];

            with uiNamespace do {
                [ctrlParent _ctrl] call VA_fnc_decorateTab;
            };
        }];
    } forEach [
        [IDC_RSCDISPLAYARSENAL_MOUSEAREA, "MouseButtonClick"],
        [IDC_RSCDISPLAYARSENAL_CONTROLSBAR_BUTTONINTERFACE, "ButtonClick"]
    ];
};

// opens a tab like the arsenal's tab buttons, decorates the lists the arsenal updated and scrolls the shown ones to
// their selected (equipped) row
VA_fnc_onTabSelect = {
    params ["_display", "_idc"];

    private _isLeft = _idc in (missionNamespace getVariable ["VA_var_leftTabs", []]);
    [["TabSelectRight", "TabSelectLeft"] select _isLeft, [_display, _idc]] call VA_fnc_callArsenal;

    if !(call VA_fnc_isDecorated) exitWith {};

    uiNamespace setVariable ["VA_var_lastTab", _idc];

    private _tabs = [_display, _idc] call VA_fnc_getAffectedTabs;
    [_display, _tabs] call VA_fnc_decorateLists;

    {
        private _ctrlList = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x);

        if (ctrlEnabled _ctrlList) then {
            [_ctrlList] call VA_fnc_listShowSelection;
        };
    } forEach _tabs;

    [_display] call VA_fnc_decorateTab;
};

// sort menu of a list, like the arsenal's own handler; the decorator then orders the list again
VA_fnc_onSort = {
    params ["_ctrlSort", "_cursel"];

    private _display = ctrlParent _ctrlSort;
    private _idc = (ctrlIDC _ctrlSort) - IDC_RSCDISPLAYARSENAL_SORT;

    ["lbSort", [[_ctrlSort, _cursel], _idc]] call VA_fnc_callArsenal;
    [_display, [_display, _idc] call VA_fnc_getAffectedTabs] call VA_fnc_decorateLists;
};

// ---- list decorations: helpers for decorators (list boxes and cargo list-n-boxes: picture | name | count) ----

// lbData of the header rows (VA_fnc_listAddHeader), no class name starts with "#"
VA_var_listHeaderData = "#header";

VA_fnc_listSize = {
    params ["_ctrlList"];

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {(lnbSize _ctrlList) select 0} else {lbSize _ctrlList}
};

// the class of a row ("" = the arsenal's <Empty> row)
VA_fnc_listData = {
    params ["_ctrlList", "_row"];

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {_ctrlList lnbData [_row, 0]} else {_ctrlList lbData _row}
};

VA_fnc_listIsHeader = {
    params ["_ctrlList", "_row"];

    ([_ctrlList, _row] call VA_fnc_listData) == (missionNamespace getVariable "VA_var_listHeaderData")
};

// the nearest row after _row in direction _step (1 down, -1 up) that is not a header row, -1 if there is none
VA_fnc_listFindItemRow = {
    params ["_ctrlList", "_row", "_step"];

    private _found = -1;
    private _last = if (_step > 0) then {([_ctrlList] call VA_fnc_listSize) - 1} else {0};

    for "_index" from (_row + _step) to _last step _step do {
        if !([_ctrlList, _index] call VA_fnc_listIsHeader) exitWith {
            _found = _index;
        };
    };

    _found
};

// [[class, text, right picture], ...] of the rows (list-n-boxes: no right picture)
VA_fnc_listRows = {
    params ["_ctrlList"];

    private _rows = [];

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {
        for "_row" from 0 to (([_ctrlList] call VA_fnc_listSize) - 1) do {
            _rows pushBack [_ctrlList lnbData [_row, 0], _ctrlList lnbText [_row, 1], ""];
        };
    } else {
        for "_row" from 0 to ((lbSize _ctrlList) - 1) do {
            _rows pushBack [_ctrlList lbData _row, _ctrlList lbText _row, _ctrlList lbPictureRight _row];
        };
    };

    _rows
};

// adds a row like the arsenal does (for an item that isn't in the arsenal, selecting it equips nothing); returns its
// index
VA_fnc_listAddRow = {
    params ["_ctrlList", "_class", "_text", "_picture"];

    private _row = -1;

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {
        _row = _ctrlList lnbAddRow ["", _text, "0"];
        _ctrlList lnbSetData [[_row, 0], _class];
        _ctrlList lnbSetPicture [[_row, 0], _picture];
    } else {
        _row = _ctrlList lbAdd _text;
        _ctrlList lbSetData [_row, _class];
        _ctrlList lbSetPicture [_row, _picture];
    };

    _row
};

// adds a header row that can't be selected (VA_fnc_skipHeader): a group title with an icon in _color and a right text
// (list-n-boxes: no count), without a text an empty separator row; VA_fnc_listSort puts it in place, the next
// decoration removes it (VA_fnc_listRemoveHeaders); returns its index
VA_fnc_listAddHeader = {
    params [
        "_ctrlList",
        ["_text", ""],
        ["_picture", ""],
        ["_color", [1, 1, 1, 1]],
        ["_textRight", ""],
        ["_colorRight", [1, 1, 1, 1]],
        ["_tooltip", ""]
    ];

    private _data = missionNamespace getVariable "VA_var_listHeaderData";
    private _row = -1;

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {
        _row = _ctrlList lnbAddRow ["", _text, ""];
        _ctrlList lnbSetData [[_row, 0], _data];
        _ctrlList lnbSetPicture [[_row, 0], _picture];
        _ctrlList lnbSetPictureColor [[_row, 0], _color];
        _ctrlList lnbSetPictureColorSelected [[_row, 0], _color];
        _ctrlList lnbSetColor [[_row, 1], _color];
        _ctrlList lnbSetTextRight [[_row, 1], _textRight];
        _ctrlList lnbSetColorRight [[_row, 1], _colorRight];
        _ctrlList lnbSetTooltip [[_row, 0], _tooltip];
    } else {
        _row = _ctrlList lbAdd _text;
        _ctrlList lbSetData [_row, _data];
        _ctrlList lbSetPicture [_row, _picture];
        _ctrlList lbSetPictureColor [_row, _color];
        _ctrlList lbSetPictureColorSelected [_row, _color];
        _ctrlList lbSetColor [_row, _color];
        _ctrlList lbSetSelectColor [_row, _color];
        _ctrlList lbSetTextRight [_row, _textRight];
        _ctrlList lbSetColorRight [_row, _colorRight];
        _ctrlList lbSetSelectColorRight [_row, _colorRight];
        _ctrlList lbSetTooltip [_row, _tooltip];
    };

    _row
};

// removes the header rows (before each decoration, VA_fnc_decorateLists); the arsenal's own list updates in between
// (counts, colors, sorting) treat them like item rows
VA_fnc_listRemoveHeaders = {
    params ["_ctrlList"];

    private _isListN = (ctrlType _ctrlList) == CT_LISTNBOX;

    for "_row" from (([_ctrlList] call VA_fnc_listSize) - 1) to 0 step -1 do {
        if ([_ctrlList, _row] call VA_fnc_listIsHeader) then {
            if _isListN then {
                _ctrlList lnbDeleteRow _row;
            } else {
                _ctrlList lbDelete _row;
            };
        };
    };
};

// styles the rows, one entry per row: [] = unchanged, else [right text, right text color, text color, picture color,
// right picture, right picture color, tooltip] (selected rows look the same); an empty text / picture color keeps the
// arsenal's color (list-n-boxes dim items that don't fit into the container)
VA_fnc_listStyleRows = {
    params ["_ctrlList", "_styles"];

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {
        {
            if (_x isNotEqualTo []) then {
                _x params ["_textRight", "_colorRight", "_colorText", "_colorPicture", "_pictureRight", "_colorPictureRight", "_tooltip"];

                private _row = _forEachIndex;
                _ctrlList lnbSetTextRight [[_row, 1], _textRight];
                _ctrlList lnbSetColorRight [[_row, 1], _colorRight];

                if (_colorText isNotEqualTo []) then {
                    _ctrlList lnbSetColor [[_row, 1], _colorText];
                    _ctrlList lnbSetColor [[_row, 2], _colorText];
                };

                if (_colorPicture isNotEqualTo []) then {
                    _ctrlList lnbSetPictureColor [[_row, 0], _colorPicture];
                    _ctrlList lnbSetPictureColorSelected [[_row, 0], _colorPicture];
                };

                _ctrlList lnbSetPictureRight [[_row, 1], _pictureRight];
                _ctrlList lnbSetPictureColorRight [[_row, 1], _colorPictureRight];
                _ctrlList lnbSetPictureColorSelectedRight [[_row, 1], _colorPictureRight];
                _ctrlList lnbSetTooltip [[_row, 0], _tooltip];
            };
        } forEach _styles;
    } else {
        {
            if (_x isNotEqualTo []) then {
                _x params ["_textRight", "_colorRight", "_colorText", "_colorPicture", "_pictureRight", "_colorPictureRight", "_tooltip"];

                private _row = _forEachIndex;
                _ctrlList lbSetTextRight [_row, _textRight];
                _ctrlList lbSetColorRight [_row, _colorRight];
                _ctrlList lbSetSelectColorRight [_row, _colorRight];

                if (_colorText isNotEqualTo []) then {
                    _ctrlList lbSetColor [_row, _colorText];
                    _ctrlList lbSetSelectColor [_row, _colorText];
                };

                if (_colorPicture isNotEqualTo []) then {
                    _ctrlList lbSetPictureColor [_row, _colorPicture];
                    _ctrlList lbSetPictureColorSelected [_row, _colorPicture];
                };

                _ctrlList lbSetPictureRight [_row, _pictureRight];
                _ctrlList lbSetPictureRightColor [_row, _colorPictureRight];
                _ctrlList lbSetPictureRightColorSelected [_row, _colorPictureRight];
                _ctrlList lbSetTooltip [_row, _tooltip];
            };
        } forEach _styles;
    };
};

// orders the rows by _sortValues (a unique number per row, ascending; VA_fnc_decorateLists keeps the selected item
// selected). The arsenal sorts lists by their values too (sort menu "by mod"), its order is replaced by the next
// decoration.
VA_fnc_listSort = {
    params ["_ctrlList", "_sortValues"];

    private _sorted = true;

    for "_index" from 1 to ((count _sortValues) - 1) do {
        if ((_sortValues select _index) < (_sortValues select (_index - 1))) exitWith {
            _sorted = false;
        };
    };

    if _sorted exitWith {};

    if ((ctrlType _ctrlList) == CT_LISTNBOX) then {
        // the count column: its value is not used by the arsenal (mass: picture column, compatibility: name column)
        private _sortColumn = 2;

        {
            _ctrlList lnbSetValue [[_forEachIndex, _sortColumn], _x];
        } forEach _sortValues;

        _ctrlList lnbSortByValue [_sortColumn, false];
    } else {
        {
            _ctrlList lbSetValue [_forEachIndex, _x];
        } forEach _sortValues;

        lbSortByValue _ctrlList;
    };
};

// selects a row without equipping its item (the arsenal's selection handler ignores it)
VA_fnc_listSelect = {
    params ["_ctrlList", "_row"];

    private _silent = uiNamespace getVariable ["VA_var_revertingSelection", false];
    uiNamespace setVariable ["VA_var_revertingSelection", true];
    _ctrlList lbSetCurSel _row;
    uiNamespace setVariable ["VA_var_revertingSelection", _silent];
};

// selects the (first) row of a class like VA_fnc_listSelect, unless it is selected already
VA_fnc_listSelectData = {
    params ["_ctrlList", "_data"];

    private _cursel = lbCurSel _ctrlList;

    if ((_cursel >= 0) && {([_ctrlList, _cursel] call VA_fnc_listData) == _data}) exitWith {};

    for "_row" from 0 to (([_ctrlList] call VA_fnc_listSize) - 1) do {
        if (([_ctrlList, _row] call VA_fnc_listData) == _data) exitWith {
            [_ctrlList, _row] call VA_fnc_listSelect;
        };
    };
};

// scrolls the list to its selected row (selecting it again makes it visible)
VA_fnc_listShowSelection = {
    params ["_ctrlList"];

    private _row = lbCurSel _ctrlList;

    if (_row >= 0) then {
        [_ctrlList, -1] call VA_fnc_listSelect;
        [_ctrlList, _row] call VA_fnc_listSelect;
    };
};
