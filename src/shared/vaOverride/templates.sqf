// Arsenal templates: loading saved loadouts with only the available items, list colors and the
// message about removed items (client).
#include "\a3\ui_f\hpp\defineResinclDesign.inc"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"

// ---- template save / load ----

VA_fnc_onTemplateOk = {
    params ["_display"];

    ["Override OK"] call VA_fnc_log;

    private _center = missionNamespace getVariable ["BIS_fnc_arsenal_center", player];
    private _hideTemplate = true;
    private _notification = "";
    private _ctrlTemplateName = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_EDITNAME;

    if (ctrlEnabled _ctrlTemplateName) then {
        ["Override OK: Save"] call VA_fnc_log;

        [
            _center,
            [profileNamespace, ctrlText _ctrlTemplateName],
            [
                _center getVariable ["BIS_fnc_arsenal_face", face _center],
                speaker _center,
                _center call BIS_fnc_getUnitInsignia
            ]
        ] call BIS_fnc_saveInventory;
    } else {
        ["Override OK: Load"] call VA_fnc_log;

        private _ctrlTemplateValue = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_VALUENAME;

        if ((_ctrlTemplateValue lbValue (lnbCurSelRow _ctrlTemplateValue)) >= 0) then {
            private _name = _ctrlTemplateValue lnbText [lnbCurSelRow _ctrlTemplateValue, 0];
            private _before = [getUnitLoadout _center] call VA_fnc_countLoadout;
            private _removedLines =[_center,[profileNamespace, _name],
                (uiNamespace getVariable ["VA_var_virtualCargo",[]])] call VA_fnc_loadInventoryWhitelist;

            // locked items only up to the count carried before, container contents up to VA_maxItemCounts
            if (local _center) then {
                _removedLines = _removedLines + ([[_center, _before, true] call VA_fnc_enforceRules] call VA_fnc_formatRemovedLines);
            };

            if (_removedLines != "") then {
                _notification = "Certain items in the selected loadout<br />are not allowed and have been removed<br />" + _removedLines;
            };

            // face, voice and insignia
            private _data = profileNamespace getVariable ["bis_fnc_saveInventory_data", []];
            private _nameId = _data find _name;

            if (_nameId >= 0) then {
                private _inventoryCustom = (_data select (_nameId + 1)) select 10;

                if ((count _inventoryCustom) == 3) then {
                    _center setFace (_inventoryCustom select 0);
                    _center setVariable ["BIS_fnc_arsenal_face", (_inventoryCustom select 0)];
                    _center setSpeaker (_inventoryCustom select 1);
                    [_center, _inventoryCustom select 2] call BIS_fnc_setUnitInsignia;
                };
            };

            ["ListSelectCurrent", [_display]] call VA_fnc_callArsenal;
            [_display] call VA_fnc_decorateAll;
        } else {
            _hideTemplate = false;
        };
    };

    if _hideTemplate then {
        [_display, _notification, (_notification != "")] call VA_fnc_showRestrictedItems;
    };
};

// BIS_fnc_loadInventory for saved loadouts that only adds whitelisted items; returns the notification lines of the
// removed items ("" if none)
VA_fnc_loadInventoryWhitelist = {
    params [["_object", objNull, [objNull]], ["_source", configFile, [configFile, "", []]], ["_whiteList", [], [[]]]];

    ["LoadInventory WhiteList"] call VA_fnc_log;

    // weapons can only be changed where the object is local
    if !(local _object) exitWith {
        [_object, _source, _whiteList] remoteExecCall ["VA_fnc_loadInventoryWhitelist", _object];
        ""
    };

    _source params [["_namespace", missionNamespace, [missionNamespace, grpNull, objNull]], ["_name", "", [""]]];

    private _data = _namespace getVariable ["bis_fnc_saveInventory_data", []];
    private _nameId = _data find _name;

    if (_nameId < 0) exitWith {
        ["Inventory '%1' not found", _name] call BIS_fnc_error;
        ""
    };

    private _inventory = _data select (_nameId + 1);
    [format ["LoadInventory: WL: %1", _whiteList]] call VA_fnc_log;

    private _vest = (_inventory select 1) select 0;
    private _headgear = _inventory select 3;
    private _goggles = _inventory select 4;

    // assigned items, then the primary / secondary / handgun items (weaponAccessories can return nil)
    private _linkedItemsMisc = [_inventory select 9] + ([6, 7, 8] apply {
        private _weaponItems = (_inventory select _x) select 1;

        if (isNil "_weaponItems") then {["", "", ""]} else {_weaponItems}
    });

    removeUniform _object;
    removeVest _object;
    removeHeadgear _object;
    removeGoggles _object;
    removeBackpack _object;
    removeAllItems _object;
    removeAllAssignedItems _object;
    removeAllWeapons _object;

    private _removed = "";

    {
        _x params ["_class", "_label", "_code"];
        _removed = _removed + ([_object, _class, _label, _code, _whiteList] call VA_fnc_addIfAllowed);
    } forEach [
        [(_inventory select 0) select 0, "Uniform", {
            params ["_object", "_class"];

            if (isClass (configFile >> "CfgWeapons" >> _class)) then {
                _object forceAddUniform _class;
            } else {
                ["Uniform '%1' does not exist in CfgWeapons", _class] call BIS_fnc_error;
            };
        }],
        [_vest, "Vest", {
            params ["_object", "_class"];

            if (isClass (configFile >> "CfgWeapons" >> _class)) then {
                _object addVest _class;
            } else {
                ["Vest '%1' does not exist in CfgWeapons", _class] call BIS_fnc_error;
            };
        }],
        [_headgear, "Headgear", {
            params ["_object", "_class"];

            if (isClass (configFile >> "CfgWeapons" >> _class)) then {
                _object addHeadgear _class;
            } else {
                ["Headgear '%1' does not exist in CfgWeapons", _class] call BIS_fnc_error;
            };
        }],
        [_goggles, "Goggles", {
            params ["_object", "_class"];

            if (isClass (configFile >> "CfgGlasses" >> _class)) then {
                _object addGoggles _class;
            } else {
                ["Goggles '%1' does not exist in CfgGlasses", _class] call BIS_fnc_error;
            };
        }],
        [(_inventory select 2) select 0, "Backpack", {
            params ["_object", "_class"];

            if (isClass (configFile >> "CfgVehicles" >> _class)) then {
                _object addBackpack _class;

                // default backpacks have default loadouts, they must be cleared if not loaded from config
                clearAllItemsFromBackpack _object;
            } else {
                ["Backpack '%1' does not exist in CfgVehicles", _class] call BIS_fnc_error;
            };
        }]
    ];

    {
        _removed = _removed + ([_object, _x, "Magazine", {params ["_object", "_class"]; _object addMagazine _class}, _whiteList] call VA_fnc_addIfAllowed);
    } forEach [(_inventory select 6) select 2, (_inventory select 7) select 2, (_inventory select 8) select 2];

    {
        _removed = _removed + ([_object, _x, "Weapon", {params ["_object", "_class"]; _object addWeapon _class}, _whiteList] call VA_fnc_addIfAllowed);
    } forEach [_inventory select 5, (_inventory select 6) select 0, (_inventory select 7) select 0, (_inventory select 8) select 0];

    {
        _x params ["_label", "_code"];
        private _items = _linkedItemsMisc select _forEachIndex;

        {
            _removed = _removed + ([_object, _x, _label, _code, _whiteList] call VA_fnc_addIfAllowed);
        } forEach _items;
    } forEach [
        ["Item", {params ["_object", "_class"]; _object linkItem _class}],
        ["Primary Weapon Item", {params ["_object", "_class"]; _object addPrimaryWeaponItem _class}],
        ["Secondary Weapon Item", {params ["_object", "_class"]; _object addSecondaryWeaponItem _class}],
        ["Handgun Item", {params ["_object", "_class"]; _object addHandgunItem _class}]
    ];

    // container items (empty class names are not skipped here, like the original)
    {
        _x params ["_items", "_label", "_code"];

        {
            _removed = _removed + ([_object, _x, _label, _code, _whiteList, false] call VA_fnc_addIfAllowed);
        } forEach _items;
    } forEach [
        [(_inventory select 0) select 1, "Uniform Item", {params ["_object", "_class"]; _object addItemToUniform _class}],
        [(_inventory select 1) select 1, "Vest Item", {params ["_object", "_class"]; _object addItemToVest _class}],
        [(_inventory select 2) select 1, "Backpack Item", {params ["_object", "_class"]; _object addItemToBackpack _class}]
    ];

    _removed
};

// adds a class with _code ([_object, _class] call _code) if it is whitelisted; returns the notification line otherwise
VA_fnc_addIfAllowed = {
    params ["_object", "_class", "_label", "_code", "_whiteList", ["_skipEmpty", true]];

    if (_skipEmpty && {_class == ""}) exitWith {""};

    if ([_class, _whiteList] call VA_fnc_isItemAllowed) exitWith {
        [_object, _class] call _code;
        ""
    };

    format ["<br />%1 - %2", _label, _class]
};

// colors the saved loadouts in the load list: loadouts with items that are not available or more items than
// VA_maxItemCounts allows are highlighted
VA_fnc_applyListColors = {
    params ["_display"];

    private _whiteList = uiNamespace getVariable ["VA_var_virtualCargo", []];

    if (_whiteList isEqualTo []) exitWith {
        ["No whiteList"] call VA_fnc_log;
    };

    if ((ctrlText (_display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TITLE)) != "Load") exitWith {};

    private _ctrlTemplateValue = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_VALUENAME;
    private _inventoryData = profileNamespace getVariable ["bis_fnc_saveInventory_data", []];
    private _restrictedColor = if (isNil "UI_fnc_color") then {[0.819, 0.670, 0.082, 1]} else {["warning"] call UI_fnc_color};
    private _maxCounts = call VA_fnc_getMaxItemCounts;

    ["showMessage", [_display, "Orange loadouts have restricted items that will be removed when loaded"]] call BIS_fnc_arsenal;

    for "_index" from 0 to ((count _inventoryData) - 1) step 2 do {
        private _name = _inventoryData select _index;
        private _inventory = _inventoryData select (_index + 1);
        private _allowed =([(_inventory select [0, 9]), _whiteList] call VA_fnc_isInventoryAllowed) &&
            {[_inventory, _maxCounts] call VA_fnc_isWithinMaxCounts};

        [format ["Ended with %1", _allowed]] call VA_fnc_log;

        for "_row" from 0 to (((lnbSize _ctrlTemplateValue) select 0) - 1) do {
            if ((_ctrlTemplateValue lnbText [_row, 0]) == _name) then {
                _ctrlTemplateValue lnbSetColor [[_row, 0], ([_restrictedColor, [1, 1, 1, 1]] select _allowed)];
                _ctrlTemplateValue lbSetValue [_row, 1];
            };
        };
    };
};

// ---- message about removed items ----

VA_var_templateControls = [
    IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONDELETE,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONCANCEL,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_VALUENAME,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_EDITNAME,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_COLUMN1,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_COLUMN2,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_COLUMN3,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_COLUMN4,
    IDC_RSCDISPLAYARSENAL_TEMPLATE_COLUMN5
];

// _show: replaces the template list with the notification; otherwise closes the template window (and the message)
VA_fnc_showRestrictedItems = {
    params ["_display", "_notification", ["_show", false]];

    if _show then {
        private _showMessage = missionNamespace getVariable ["VA_var_showMessage", 0];

        if (_showMessage == 0) exitWith {};

        private _ctrlTemplate = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TEMPLATE;
        private _ctrlPos = ctrlPosition (_display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_VALUENAME);

        {
            private _ctrl = _display displayCtrl _x;
            _ctrl ctrlSetFade 1;
            _ctrl ctrlCommit 0;
            _ctrl ctrlEnable false;
        } forEach (missionNamespace getVariable "VA_var_templateControls");

        (_display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TITLE) ctrlSetText "Restricted Items";
        ["showMessage", [_display, "Some restricted items have been removed"]] call BIS_fnc_arsenal;

        private _ctrlGroup = _display ctrlCreate ["RscControlsGroupNoHScrollbars", 1000, _ctrlTemplate];
        _ctrlGroup ctrlSetPosition _ctrlPos;
        _ctrlGroup ctrlCommit 0;

        private _ctrlText = _display ctrlCreate ["RscStructuredText", 1000, _ctrlGroup];
        _ctrlText ctrlSetPosition ((_ctrlPos select [0, 3]) + [2]);
        _ctrlText ctrlCommit 0;
        _ctrlText ctrlSetStructuredText parseText _notification;

        private _buttonOk = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONOK;
        _buttonOk setVariable ["VA_var_messageControls", [_ctrlText, _ctrlGroup]];
        _buttonOk ctrlSetText "OK";
        ctrlSetFocus _ctrlGroup;

        _buttonOk ctrlRemoveAllEventHandlers "ButtonClick";
        _buttonOk ctrlAddEventHandler ["ButtonClick", {
            params ["_buttonOk"];

            [ctrlParent _buttonOk, "", false] call VA_fnc_showRestrictedItems;
        }];

        // ESC / ENTER close the message
        _display displayRemoveAllEventHandlers "KeyDown";
        _display displayAddEventHandler ["KeyDown", {
            params ["_display", "_keyCode"];

            if (_keyCode in [DIK_ESCAPE, DIK_RETURN, DIK_NUMPADENTER]) then {
                [_display, "", false] call VA_fnc_showRestrictedItems;
            };
        }];

        if (_showMessage > 0) then {
            uiNamespace setVariable ["VA_var_messageThread", [_display, _showMessage] spawn {
                disableSerialization;
                params ["_display", "_delay"];

                private _endTime = time + _delay;

                while {time < _endTime} do {
                    (_display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TITLE) ctrlSetText format ["Restricted Items ...%1", floor (_endTime - time)];
                    uiSleep 0.5;
                };

                with uiNamespace do {
                    [_display, "", false] call VA_fnc_showRestrictedItems;
                };
            }];
        };
    } else {
        private _ctrlTemplate = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_TEMPLATE;
        _ctrlTemplate ctrlSetFade 1;
        _ctrlTemplate ctrlCommit 0;
        _ctrlTemplate ctrlEnable false;

        (_display displayCtrl IDC_RSCDISPLAYARSENAL_MOUSEBLOCK) ctrlEnable false;

        private _buttonOk = _display displayCtrl IDC_RSCDISPLAYARSENAL_TEMPLATE_BUTTONOK;
        private _messageControls = _buttonOk getVariable "VA_var_messageControls";

        if !(isNil "_messageControls") then {
            {
                ctrlDelete _x;
            } forEach _messageControls;

            {
                private _ctrl = _display displayCtrl _x;
                _ctrl ctrlSetFade 0;
                _ctrl ctrlCommit 0;
                _ctrl ctrlEnable true;
            } forEach (missionNamespace getVariable "VA_var_templateControls");

            private _thread = uiNamespace getVariable "VA_var_messageThread";

            if (!(isNil "_thread") && {!scriptDone _thread}) then {
                terminate _thread;
            };

            _buttonOk setVariable ["VA_var_messageControls", nil];
            _buttonOk ctrlAddEventHandler ["ButtonClick", {params ["_ctrl"]; with uiNamespace do {[ctrlParent _ctrl] call VA_fnc_onTemplateOk}}];

            [_display] call VA_fnc_addKeyEvents;
        };
    };
};
