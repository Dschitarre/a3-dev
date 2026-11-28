// Virtual arsenal override (client), loaded by the mode's functions.sqf on every machine; VA_fnc_init runs once in
// the client init. Files: vaOverride.sqf (settings, helpers, init, keys), limits.sqf (locked items and max counts),
// selection.sqf (list / cargo / import handlers, hooks for a mode to decorate the item lists with extra rows, styles,
// order and group headers), templates.sqf (loading saved loadouts, removed-items message).
// - loading a saved loadout only adds the items that are available in the arsenal, the removed items are listed in a
//   message; saved loadouts with unavailable items are highlighted in the load list
// - items the unit carries but the arsenal doesn't contain ("locked" items, the arsenal lists them because they are
//   carried) can only be kept, reduced or removed: never added, increased or equipped in another slot
// - the uniform + vest + backpack contents never exceed VA_maxItemCounts[] = {{"class", max}, ...} of the mission
//   config (optional) through the arsenal
#include "\a3\ui_f\hpp\defineResinclDesign.inc"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"

// ---- settings ----

VA_var_debug = false;           // log to the RPT

VA_var_showMessage = 1;         // message about removed items: -1 until it is closed, 0 never, > 0 seconds

VA_var_randomDisabled = true;   // disable the random loadout button and shortcut

// the arsenal display handlers run in uiNamespace, so the functions are also stored there (VA_fnc_init)
VA_var_functions = [
    "VA_fnc_log",
    "VA_fnc_getCargoIndex",
    "VA_fnc_isItemAllowed",
    "VA_fnc_isInventoryAllowed",
    "VA_fnc_getDisplayName",
    "VA_fnc_onArsenalOpened",
    "VA_fnc_addKeyEvents",
    "VA_fnc_getMaxItemCounts",
    "VA_fnc_getUnlockedCargo",
    "VA_fnc_isUnlocked",
    "VA_fnc_addCount",
    "VA_fnc_countWeapon",
    "VA_fnc_countLoadout",
    "VA_fnc_takeBudget",
    "VA_fnc_clampWeapon",
    "VA_fnc_clampLoadout",
    "VA_fnc_clampLoadoutToMax",
    "VA_fnc_enforceRules",
    "VA_fnc_formatRemoved",
    "VA_fnc_formatRemovedLines",
    "VA_fnc_isWithinMaxCounts",
    "VA_fnc_getWeaponNames",
    "VA_fnc_getActiveWeapon",
    "VA_fnc_getEquippedItems",
    "VA_fnc_selectEquippedRow",
    "VA_fnc_getLockedMessage",
    "VA_fnc_onSelectItem",
    "VA_fnc_skipHeader",
    "VA_fnc_applySelection",
    "VA_fnc_onCargoAdd",
    "VA_fnc_onCargoRemove",
    "VA_fnc_onImport",
    "VA_fnc_onTemplateOk",
    "VA_fnc_loadInventoryWhitelist",
    "VA_fnc_addIfAllowed",
    "VA_fnc_applyListColors",
    "VA_fnc_showRestrictedItems",
    "VA_fnc_onButtonDown",
    "VA_fnc_isDecorated",
    "VA_fnc_callArsenal",
    "VA_fnc_getAffectedTabs",
    "VA_fnc_getActiveTab",
    "VA_fnc_decorateLists",
    "VA_fnc_decorateTab",
    "VA_fnc_decorateAll",
    "VA_fnc_initDecorations",
    "VA_fnc_addDecorationEvents",
    "VA_fnc_onTabSelect",
    "VA_fnc_onSort",
    "VA_fnc_listSize",
    "VA_fnc_listData",
    "VA_fnc_listIsHeader",
    "VA_fnc_listFindItemRow",
    "VA_fnc_listRows",
    "VA_fnc_listAddRow",
    "VA_fnc_listAddHeader",
    "VA_fnc_listRemoveHeaders",
    "VA_fnc_listStyleRows",
    "VA_fnc_listSort",
    "VA_fnc_listSelect",
    "VA_fnc_listSelectData",
    "VA_fnc_listShowSelection",
    "VA_fnc_isCameraViewFree",
    "VA_fnc_findCameraPos",
    "VA_fnc_onArsenalPreOpen"
];

// arsenal camera (BIS_fnc_arsenal orbits a point on the unit: [distance, horizontal angle from the unit's front,
// vertical angle, point in the unit's model space]); candidates in the order they are tried, see VA_fnc_findCameraPos
VA_var_cameraDistances = [5, 4, 3, 2.2];
VA_var_cameraAnglesH = [0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180];
VA_var_cameraAnglesV = [0, 20];
VA_var_cameraTargetPos = [0, 0, 0.85];  // the arsenal's default point (chest height)
VA_var_cameraHeadPos = [0, 0, 1.6];     // must be visible too
VA_var_cameraMargin = 0.5;              // m behind the camera that must be free as well: never right at a wall

// arsenal tabs (IDC_RSCDISPLAYARSENAL_LIST + tab = list)
VA_var_leftTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON,
    IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON,
    IDC_RSCDISPLAYARSENAL_TAB_HANDGUN,
    IDC_RSCDISPLAYARSENAL_TAB_UNIFORM,
    IDC_RSCDISPLAYARSENAL_TAB_VEST,
    IDC_RSCDISPLAYARSENAL_TAB_BACKPACK,
    IDC_RSCDISPLAYARSENAL_TAB_HEADGEAR,
    IDC_RSCDISPLAYARSENAL_TAB_GOGGLES,
    IDC_RSCDISPLAYARSENAL_TAB_NVGS,
    IDC_RSCDISPLAYARSENAL_TAB_BINOCULARS,
    IDC_RSCDISPLAYARSENAL_TAB_MAP,
    IDC_RSCDISPLAYARSENAL_TAB_GPS,
    IDC_RSCDISPLAYARSENAL_TAB_RADIO,
    IDC_RSCDISPLAYARSENAL_TAB_COMPASS,
    IDC_RSCDISPLAYARSENAL_TAB_WATCH,
    IDC_RSCDISPLAYARSENAL_TAB_FACE,
    IDC_RSCDISPLAYARSENAL_TAB_VOICE,
    IDC_RSCDISPLAYARSENAL_TAB_INSIGNIA
];

VA_var_rightTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_ITEMOPTIC,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMACC,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMMUZZLE,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOTHROW,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOPUT,
    IDC_RSCDISPLAYARSENAL_TAB_CARGOMISC
];

VA_var_allTabs = VA_var_leftTabs + VA_var_rightTabs;

VA_var_identityTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_FACE,
    IDC_RSCDISPLAYARSENAL_TAB_VOICE,
    IDC_RSCDISPLAYARSENAL_TAB_INSIGNIA
];

VA_var_weaponTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON,
    IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON,
    IDC_RSCDISPLAYARSENAL_TAB_HANDGUN
];

VA_var_containerTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_UNIFORM,
    IDC_RSCDISPLAYARSENAL_TAB_VEST,
    IDC_RSCDISPLAYARSENAL_TAB_BACKPACK
];

// right tabs of a weapon (lists of its compatible attachments) and of a container (its contents)
VA_var_attachmentTabs = [
    IDC_RSCDISPLAYARSENAL_TAB_ITEMOPTIC,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMACC,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMMUZZLE,
    IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD
];

VA_var_cargoTabs = VA_var_rightTabs - VA_var_attachmentTabs;

// tabs whose list selection equips an item (the others: identity, container cargo)
VA_var_equipmentTabs = (VA_var_leftTabs - VA_var_identityTabs) + VA_var_attachmentTabs;

// ---- helpers ----

VA_fnc_log = {
    params ["_message"];

    if (missionNamespace getVariable ["VA_var_debug", false]) then {
        diag_log _message;
    };
};

// index of the virtual cargo list of a class: [items, weapons, magazines, backpacks], -1 if none
VA_fnc_getCargoIndex = {
    params ["_class"];

    (_class call BIS_fnc_itemType) params ["_category", "_type"];

    switch (toUpper _category) do {
        case "EQUIPMENT": {[0, 3] select ((toUpper _type) == "BACKPACK")};
        case "ITEM": {0};
        case "WEAPON": {1};
        case "MINE";
        case "MAGAZINE": {2};
        default {-1};
    }
};

// whether a class is in the arsenal whitelist: [items, weapons, magazines, backpacks], lower case, "%all" = everything
VA_fnc_isItemAllowed = {
    params ["_class", "_whiteList"];

    private _listIndex = [_class] call VA_fnc_getCargoIndex;

    if (_listIndex == -1) exitWith {false};

    private _list = _whiteList select _listIndex;
    private _allowed = ((toLower _class) in _list) || {"%all" in _list};

    [format ["LOAD: %1 allowed %2", _class, _allowed]] call VA_fnc_log;
    _allowed
};

// whether all classes in (nested) saved inventory data are allowed
VA_fnc_isInventoryAllowed = {
    params ["_itemData", "_whiteList"];

    if (_itemData isEqualType "") exitWith {
        (_itemData == "") || {[_itemData, _whiteList] call VA_fnc_isItemAllowed}
    };

    if (_itemData isEqualType []) exitWith {
        (_itemData findIf {!(isNil "_x") && {!([_x, _whiteList] call VA_fnc_isInventoryAllowed)}}) == -1
    };

    true
};

VA_fnc_getDisplayName = {
    params ["_class"];

    private _name = "";

    {
        private _cfg = configFile >> _x >> _class;

        if (isClass _cfg) exitWith {
            _name = getText (_cfg >> "displayName");
        };
    } forEach ["CfgMagazines", "CfgWeapons", "CfgVehicles", "CfgGlasses"];

    if (_name == "") then {_class} else {_name}
};

// ---- init ----

VA_fnc_init = {
    if !hasInterface exitWith {};

    {
        uiNamespace setVariable [_x, missionNamespace getVariable _x];
    } forEach VA_var_functions;

    ["Adding arsenalOpened SEH"] call VA_fnc_log;
    [missionNamespace, "arsenalPreOpen", {_this call VA_fnc_onArsenalPreOpen}] call BIS_fnc_addScriptedEventHandler;
    [missionNamespace, "arsenalOpened", {_this call VA_fnc_onArsenalOpened}] call BIS_fnc_addScriptedEventHandler;
};

// ---- camera ----
// The arsenal's default camera (5 m straight in front of the unit) often ends up inside a wall or behind an object, so
// the unit can't be seen. Before the arsenal opens (its camera init reads BIS_fnc_arsenal_campos_0), the first
// candidate position with a free view of the unit's chest and head is chosen.

// whether the camera at _cameraPos (ASL) sees all _targets (ASL): no terrain or object surface in between
VA_fnc_isCameraViewFree = {
    params ["_center", "_cameraPos", "_targets"];

    if ((_cameraPos select 2) < ((getTerrainHeightASL _cameraPos) + 0.3)) exitWith {false};

    (_targets findIf {
        (terrainIntersectASL [_cameraPos, _x]) ||
        {(lineIntersectsSurfaces [_cameraPos, _x, _center, (vehicle _center), true, 1, "VIEW", "FIRE"]) isNotEqualTo []}
    }) == -1
};

// [distance, horizontal angle, vertical angle, target point] for BIS_fnc_arsenal_campos: closest to the default
// first (far, in front, level), then around the unit, then closer; the default if nothing is free
VA_fnc_findCameraPos = {
    params ["_center"];

    private _targets = [VA_var_cameraTargetPos, VA_var_cameraHeadPos] apply {_center modelToWorldVisualWorld _x};
    private _result = [];

    {
        private _distance = _x;

        {
            private _angleV = _x;

            {
                private _angleH = _x;
                private _dir = [(sin _angleH) * (cos _angleV), (cos _angleH) * (cos _angleV), sin _angleV];
                private _checkPos = _center modelToWorldVisualWorld (VA_var_cameraTargetPos vectorAdd (_dir
                    vectorMultiply (_distance + VA_var_cameraMargin)));

                if ([_center, _checkPos, _targets] call VA_fnc_isCameraViewFree) exitWith {
                    _result = [_distance, _angleH, _angleV, VA_var_cameraTargetPos];
                };
            } forEach VA_var_cameraAnglesH;

            if (_result isNotEqualTo []) exitWith {};
        } forEach VA_var_cameraAnglesV;

        if (_result isNotEqualTo []) exitWith {};
    } forEach VA_var_cameraDistances;

    if (_result isEqualTo []) then {
        _result = [VA_var_cameraDistances select 0, 0, 0, VA_var_cameraTargetPos];
    };

    _result
};

// scripted "arsenalPreOpen" event: the camera position for the full arsenal (BIS_fnc_arsenal_type 0)
VA_fnc_onArsenalPreOpen = {
    params ["", ["_center", player]];

    if (isNull _center) exitWith {};

    missionNamespace setVariable ["BIS_fnc_arsenal_campos_0", ([_center] call VA_fnc_findCameraPos)];
};

// collects the arsenal content (and the current gear) as the whitelist for loading saved loadouts and the arsenal
// content alone for the locked items; then the mode's list decorations. The event comes at the end of the arsenal's
// init (BIS_fnc_arsenal_center / _cargo / _target exist). Runs unscheduled: at the first opening the arsenal's init
// runs scheduled, and once the scheduler suspends it the script would continue in uiNamespace, where the mode's
// functions are undefined.
VA_fnc_onArsenalOpened = {
    disableSerialization;
    params ["_display"];

    ["arsenalOpened SEH called"] call VA_fnc_log;

    isNil {
        private _center = BIS_fnc_arsenal_center;
        private _cargo = BIS_fnc_arsenal_cargo;

        [format ["SEH: Center: %1, Cargo: %2", _center, _cargo]] call VA_fnc_log;

        private _items =
            (missionNamespace call BIS_fnc_getVirtualItemCargo) +
            (_cargo call BIS_fnc_getVirtualItemCargo) +
            items _center +
            assignedItems _center +
            primaryWeaponItems _center +
            secondaryWeaponItems _center +
            handgunItems _center +
            [uniform _center, vest _center, headgear _center, goggles _center];

        private _weapons =(missionNamespace call BIS_fnc_getVirtualWeaponCargo) +(_cargo call
            BIS_fnc_getVirtualWeaponCargo) + weapons _center +[binocular _center];
        private _magazines =(missionNamespace call BIS_fnc_getVirtualMagazineCargo) +(_cargo call
            BIS_fnc_getVirtualMagazineCargo) + magazines _center;
        private _backpacks =(missionNamespace call BIS_fnc_getVirtualBackpackCargo) +(_cargo call
            BIS_fnc_getVirtualBackpackCargo) +[backpack _center];

        private _virtualCargo = [_items, _weapons, _magazines, _backpacks] apply {
            private _classes = _x apply {toLower _x};

            if ("%all" in _classes) then {["%all"]} else {_classes - [""]}
        };

        uiNamespace setVariable ["VA_var_virtualCargo", _virtualCargo];
        uiNamespace setVariable ["VA_var_unlockedCargo", [_cargo] call VA_fnc_getUnlockedCargo];

        [_display] call VA_fnc_addKeyEvents;
        [_display] call VA_fnc_initDecorations;
    };
};

// replaces the arsenal's template OK / load / delete / import / key handlers with the whitelist versions and wraps the
// list selection and the "+" button (the right arrow key of the cargo lists clicks it too) with the arsenal rules
VA_fnc_addKeyEvents = {
    params ["_display"];

    [format ["SEH: VCargo: %1", uiNamespace getVariable "VA_var_virtualCargo"]] call VA_fnc_log;

    private _ctrlTemplateButtonOk = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONOK;
    _ctrlTemplateButtonOk ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlTemplateButtonOk ctrlAddEventHandler ["ButtonClick", {params ["_ctrl"]; with uiNamespace do {[ctrlParent _ctrl] call VA_fnc_onTemplateOk}}];

    private _ctrlTemplateValue = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_VALUENAME;
    _ctrlTemplateValue ctrlRemoveAllEventHandlers "LBDblClick";
    _ctrlTemplateValue ctrlAddEventHandler ["LBDblClick", {params ["_ctrl"]; with uiNamespace do {[ctrlParent _ctrl] call VA_fnc_onTemplateOk}}];

    // also needed to override ENTER on the template list
    _display displayRemoveAllEventHandlers "KeyDown";
    _display displayAddEventHandler ["KeyDown", {with uiNamespace do {_this call VA_fnc_onButtonDown}}];

    private _ctrlButtonLoad = _display displayCtrl IDC_RSCDISPLAYARSENAL_CONTROLSBAR_BUTTONLOAD;
    _ctrlButtonLoad ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlButtonLoad ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];

        with uiNamespace do {
            ["buttonLoad", [ctrlParent _ctrl]] call VA_fnc_callArsenal;
            [ctrlParent _ctrl] call VA_fnc_applyListColors;
        };
    }];

    private _ctrlTemplateButtonDelete = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONDELETE;
    _ctrlTemplateButtonDelete ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlTemplateButtonDelete ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];

        with uiNamespace do {
            ["buttonTemplateDelete", [ctrlParent _ctrl]] call VA_fnc_callArsenal;
            [ctrlParent _ctrl] call VA_fnc_applyListColors;
        };
    }];

    private _ctrlButtonImport = _display displayCtrl IDC_RSCDISPLAYARSENAL_CONTROLSBAR_BUTTONIMPORT;
    _ctrlButtonImport ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlButtonImport ctrlAddEventHandler ["ButtonClick", {params ["_ctrl"]; with uiNamespace do {[ctrlParent _ctrl] call VA_fnc_onImport}}];

    private _ctrlArrowRight = _display displayCtrl IDC_RSCDISPLAYARSENAL_ARROWRIGHT;
    _ctrlArrowRight ctrlRemoveAllEventHandlers "ButtonClick";
    _ctrlArrowRight ctrlAddEventHandler ["ButtonClick", {params ["_ctrl"]; with uiNamespace do {[ctrlParent _ctrl] call VA_fnc_onCargoAdd}}];

    {
        private _ctrlList = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x);
        _ctrlList ctrlRemoveAllEventHandlers "LBSelChanged";
        _ctrlList ctrlAddEventHandler ["LBSelChanged", {
            params ["_ctrl"];

            with uiNamespace do {
                [ctrlParent _ctrl, _ctrl, (ctrlIDC _ctrl) - IDC_RSCDISPLAYARSENAL_LIST] call VA_fnc_onSelectItem;
            };
        }];
    } forEach ((missionNamespace getVariable "VA_var_leftTabs") + (missionNamespace getVariable "VA_var_rightTabs"));

    if (missionNamespace getVariable ["VA_var_randomDisabled", false]) then {
        (_display displayCtrl IDC_RSCDISPLAYARSENAL_CONTROLSBAR_BUTTONRANDOM) ctrlEnable false;
    };
};

// ---- keys ----

// the arsenal's KeyDown handler with ENTER / ESC going through the whitelist template handling
VA_fnc_onButtonDown = {
    params ["_display", "_key", "_shift", "_ctrl", "_alt"];

    ["Override Button Down"] call VA_fnc_log;

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _inTemplate = (ctrlFade (_display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TEMPLATE)) == 0;
    private _fullVersion = missionNamespace getVariable ["BIS_fnc_arsenal_fullArsenal", false];
    private _isArsenal = BIS_fnc_arsenal_type == 0;
    private _return = false;

    switch true do {
        case (_key == DIK_ESCAPE): {
            if _inTemplate then {
                [_display, "", false] call VA_fnc_showRestrictedItems;
            } else {
                if _fullVersion then {["buttonClose", [_display]] spawn BIS_fnc_arsenal;} else {_display closeDisplay 2;};
            };

            _return = true;
        };

        case (_key in [DIK_RETURN, DIK_NUMPADENTER]): {
            if _inTemplate then {
                if _isArsenal then {
                    [_display] call VA_fnc_onTemplateOk;
                } else {
                    ["buttonTemplateOK", [_display]] spawn BIS_fnc_garage;
                };

                _return = true;
            };
        };

        // prevent opening the commanding menu
        case (_key in [DIK_1, DIK_2, DIK_3, DIK_4, DIK_5, DIK_6, DIK_7, DIK_8, DIK_9, DIK_0]): {
            _return = true;
        };

        // TAB browses the tabs
        case (_key == DIK_TAB): {
            private _leftTabs = missionNamespace getVariable "VA_var_leftTabs";
            private _idc = -1;

            {
                if !(ctrlEnabled (_display displayCtrl (IDC_RSCDISPLAYARSENAL_TAB + _x))) exitWith {
                    _idc = _x;
                };
            } forEach _leftTabs;

            private _idcCount = {!isNull (_display displayCtrl (IDC_RSCDISPLAYARSENAL_TAB + _x))} count _leftTabs;
            _idc = if _ctrl then {(_idc - 1 + _idcCount) % _idcCount} else {(_idc + 1) % _idcCount};

            if _isArsenal then {
                [_display, _idc] call VA_fnc_onTabSelect;
            } else {
                ["TabSelectLeft", [_display, _idc]] call BIS_fnc_garage;
            };

            _return = true;
        };

        // export to script
        case (_key == DIK_C): {
            if _ctrl then {
                private _mode = if _shift then {"config"} else {"init"};

                if _isArsenal then {
                    ["buttonExport", [_display, _mode]] call VA_fnc_callArsenal;
                } else {
                    ["buttonExport", [_display, _mode]] call BIS_fnc_garage;
                };
            };
        };

        // import from script
        case (_key == DIK_V): {
            if _ctrl then {
                if _isArsenal then {
                    [_display] call VA_fnc_onImport;
                } else {
                    ["buttonImport", [_display]] call BIS_fnc_garage;
                };
            };
        };

        case (_key == DIK_S): {
            if _ctrl then {
                ["buttonSave", [_display]] call VA_fnc_callArsenal;
            };
        };

        case (_key == DIK_O): {
            if _ctrl then {
                ["buttonLoad", [_display]] call VA_fnc_callArsenal;
                [_display] call VA_fnc_applyListColors;
            };
        };

        case ((_key == DIK_R) && {!(missionNamespace getVariable ["VA_var_randomDisabled", false])}): {
            if _ctrl then {
                if _isArsenal then {
                    if _shift then {
                        private _soldiers = ("isClass _x && getNumber (_x >> 'scope') > 1 && getText (_x >> 'simulation') == 'soldier'" configClasses (configFile >> "CfgVehicles")) apply {configName _x};
                        [_center, selectRandom _soldiers] call BIS_fnc_loadInventory;
                        ["ListSelectCurrent", [_display]] call VA_fnc_callArsenal;
                    } else {
                        ["buttonRandom", [_display]] call VA_fnc_callArsenal;
                    };

                    [_display] call VA_fnc_decorateAll;
                } else {
                    ["buttonRandom", [_display]] call BIS_fnc_garage;
                };
            };
        };

        // toggle the interface
        case ((_key == DIK_BACKSPACE) && {!_inTemplate}): {
            ["buttonInterface", [_display]] call VA_fnc_callArsenal;
            [_display] call VA_fnc_decorateTab;
            _return = true;
        };

        case (_key in (actionKeys "timeInc")): {
            if (accTime == 0) then {
                setAccTime 1;
            };

            _return = true;
        };

        case (_key in (actionKeys "timeDec")): {
            if (accTime != 0) then {
                setAccTime 0;
            };

            _return = true;
        };

        // vision mode: normal, NVG, thermal
        case ((_key in (actionKeys "nightVision")) && {!_inTemplate}): {
            private _mode = ((missionNamespace getVariable ["BIS_fnc_arsenal_visionMode", -1]) + 1) % 3;
            missionNamespace setVariable ["BIS_fnc_arsenal_visionMode", _mode];

            camUseNVG (_mode == 1);
            (_mode == 2) setCamUseTI 0;

            playSound ["RscDisplayCurator_visionMode", true];
            _return = true;
        };
    };

    _return
};
