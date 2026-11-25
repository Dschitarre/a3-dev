// Shared U-group menu, including its layout, used by SC/OF and BR.
#define UGM_TALL_DIALOG_H 24
#define UGM_QUOTE(PCODE) #PCODE
#define UGM_TALL_DIALOG_Y ((25 - UGM_TALL_DIALOG_H) / 2)
#define UGM_TALL_DIALOG_TOP (UGM_TALL_DIALOG_Y + UI_ROW + UI_PADDING)
#define UGM_TALL_DIALOG_CONTENT_H (UGM_TALL_DIALOG_H - UI_ROW - 2 * UI_PADDING)
#define UGM_DIALOG_FRAME(PX, PY, PW, PBODY, PTITLE) \
    class SC_Body: UI_Panel { \
        idc = 1000; \
        x = UI_X(PX); \
        y = UI_Y((PY) + UI_ROW); \
        w = UI_W(PW); \
        h = UI_H(PBODY); \
    }; \
    class SC_Title: UI_Title { \
        idc = 1002; \
        text = PTITLE; \
        x = UI_X(PX); \
        y = UI_Y(PY); \
        w = UI_W(PW); \
    };

// ---- groups (key U, SC\groupMenu.sqf) ----

// Left the SC groups of the player's side, right the members of the selected group; below the members Kick and the
// group size, then the locks (shown for the selected group, changeable by the leader of the own group); Join, Leave
// and Close in the button row below the body. The lists are dense tables (small text); their column widths in cells
// are written as fractions of the list width in columns[], the header labels use the same cells.
#define SC_GROUPS_X 3
#define SC_GROUPS_W 34
#define SC_GROUPS_LIST_X (SC_GROUPS_X + UI_PADDING)
#define SC_GROUPS_LIST_W 15
#define SC_GROUPS_MEMBERS_X (SC_GROUPS_LIST_X + SC_GROUPS_LIST_W + UI_GAP)
#define SC_GROUPS_MEMBERS_W (SC_GROUPS_W - 2 * UI_PADDING - SC_GROUPS_LIST_W - UI_GAP)
// content height between the paddings of the body (above the button row), the members list leaves two control rows
#define SC_GROUPS_CONTENT_H (UGM_TALL_DIALOG_CONTENT_H - UI_ROW - UI_GAP)
#define SC_GROUPS_MEMBERS_H (SC_GROUPS_CONTENT_H - 3 * UI_ROW - 2 * UI_GAP)
#define SC_GROUPS_ROW_Y(PROW) (UGM_TALL_DIALOG_TOP + SC_GROUPS_CONTENT_H - (2 - (PROW)) * UI_ROW - (1 - (PROW)) * UI_GAP)
#define SC_GROUPS_BUTTON_Y (UGM_TALL_DIALOG_Y + UGM_TALL_DIALOG_H - UI_ROW)

// header row in the accent color like the headers of the table dialogs (SC_fnc_styleTableHeader), white labels
class SC_ListHeader: UI_Text {
    colorBackground[] = UI_COLOR_ACCENT;
    y = UI_Y(UGM_TALL_DIALOG_TOP);
};

#define SC_GROUPS_HEADER_LABEL(PNAME, PTEXT, PX, PW) \
    class PNAME: UI_TextSmall { \
        text = PTEXT; \
        x = UI_X(PX); \
        y = UI_Y(UGM_TALL_DIALOG_TOP); \
        w = UI_W(PW); \
    };

// lock checkbox and its label in the last row: index (0 players, 1 AI), x in cells, label, tooltip (no commas)
#define SC_GROUPS_LOCK(PINDEX, PX, PLABEL, PTOOLTIP) \
    class SC_Lock##PINDEX: UI_CheckBox { \
        idc = 280##PINDEX; \
        tooltip = PTOOLTIP; \
        onCheckedChanged = UGM_QUOTE([PINDEX] call SC_fnc_groupMenuOnLockChanged); \
        x = UI_X(PX); \
        y = UI_Y(SC_GROUPS_ROW_Y(1)); \
    }; \
    class SC_LockLabel##PINDEX: UI_Text { \
        text = PLABEL; \
        tooltip = PTOOLTIP; \
        x = UI_X((PX) + UI_ROW + UI_GAP); \
        y = UI_Y(SC_GROUPS_ROW_Y(1)); \
        w = UI_W(SC_GROUPS_MEMBERS_W / 2 - UI_ROW - UI_GAP); \
    };

class groupMenuDialog {
    idd = 3004;
    onLoad = "uiNamespace setVariable [""SC_var_groupMenuDialog"", _this select 0]; call SC_fnc_groupMenuOpened;";
    onKeyDown = "_this call SC_fnc_groupMenuKeyDown";
    onKeyUp = "_this call SC_fnc_groupMenuKeyUp";

    class ControlsBackground {
        UGM_DIALOG_FRAME(SC_GROUPS_X, UGM_TALL_DIALOG_Y, SC_GROUPS_W, UGM_TALL_DIALOG_H - 2 * UI_ROW - UI_GAP, "Groups")
        class SC_GroupsHeader: SC_ListHeader {
            x = UI_X(SC_GROUPS_LIST_X);
            w = UI_W(SC_GROUPS_LIST_W);
        };
        class SC_MembersHeader: SC_ListHeader {
            x = UI_X(SC_GROUPS_MEMBERS_X);
            w = UI_W(SC_GROUPS_MEMBERS_W);
        };
    };

    class Controls {
        // groups: own group marker 0.9 | name 6.2 | members / size 2 | locked for 3.5 | distance 2.4 (15 cells)
        SC_GROUPS_HEADER_LABEL(SC_GroupsName, "Name", SC_GROUPS_LIST_X + 0.9, 6.2)
        SC_GROUPS_HEADER_LABEL(SC_GroupsSize, "Size", SC_GROUPS_LIST_X + 7.1, 2)
        SC_GROUPS_HEADER_LABEL(SC_GroupsLocked, "Locked", SC_GROUPS_LIST_X + 9.1, 3.5)
        SC_GROUPS_HEADER_LABEL(SC_GroupsDistance, "Distance", SC_GROUPS_LIST_X + 12.6, 2.4)
        class SC_Groups: UI_ListN {
            idc = 1500;
            sizeEx = UI_TEXT_SMALL;
            columns[] = {0, 0.06, 0.4733, 0.6067, 0.84};
            onLBSelChanged = "_this call SC_fnc_groupMenuOnGroupSelected";
            x = UI_X(SC_GROUPS_LIST_X);
            y = UI_Y(UGM_TALL_DIALOG_TOP + UI_ROW);
            w = UI_W(SC_GROUPS_LIST_W);
            h = UI_H(SC_GROUPS_CONTENT_H - UI_ROW);
        };

        // members: state / role icon 0.9 | rank 1.4 | name 6.2 | status 7 | distance 2.4 (17.9 cells); the status
        // (a vehicle name) is cut to its column by SC_fnc_groupMenuMemberState
        SC_GROUPS_HEADER_LABEL(SC_MembersRank, "Rank", SC_GROUPS_MEMBERS_X + 0.9, 1.4)
        SC_GROUPS_HEADER_LABEL(SC_MembersName, "Name", SC_GROUPS_MEMBERS_X + 2.3, 6.2)
        SC_GROUPS_HEADER_LABEL(SC_MembersStatus, "Status", SC_GROUPS_MEMBERS_X + 8.5, 7)
        SC_GROUPS_HEADER_LABEL(SC_MembersDistance, "Distance", SC_GROUPS_MEMBERS_X + 15.5, 2.4)
        class SC_Members: UI_ListN {
            idc = 1501;
            sizeEx = UI_TEXT_SMALL;
            columns[] = {0, 0.0503, 0.1285, 0.4749, 0.8659};
            onLBSelChanged = "_this call SC_fnc_groupMenuOnMemberSelected";
            x = UI_X(SC_GROUPS_MEMBERS_X);
            y = UI_Y(UGM_TALL_DIALOG_TOP + UI_ROW);
            w = UI_W(SC_GROUPS_MEMBERS_W);
            h = UI_H(SC_GROUPS_MEMBERS_H);
        };

        class SC_Kick: UI_Button {
            idc = 1602;
            text = "Kick";
            tooltip = "Remove the selected member from your group (only the group leader). A kicked player gets a new group of his own, a kicked AI is replaced by another one unless the group is locked for AI.";
            onButtonClick = "call SC_fnc_groupMenuKick";
            x = UI_X(SC_GROUPS_MEMBERS_X);
            y = UI_Y(SC_GROUPS_ROW_Y(0));
            w = UI_W(5);
        };
        class SC_SizeLabel: UI_Text {
            style = ST_RIGHT;
            text = "Group Size:";
            x = UI_X(SC_GROUPS_MEMBERS_X + 5 + UI_GAP);
            y = UI_Y(SC_GROUPS_ROW_Y(0));
            w = UI_W(SC_GROUPS_MEMBERS_W - 5 - 3.5 - 2 * UI_GAP);
        };
        class SC_Size: UI_Combo {
            idc = 2100;
            tooltip = "AI fill the group up to this size (only the group leader can change it; players always stay)";
            onLBSelChanged = "_this call SC_fnc_groupMenuOnSizeSelected";
            x = UI_X(SC_GROUPS_MEMBERS_X + SC_GROUPS_MEMBERS_W - 3.5);
            y = UI_Y(SC_GROUPS_ROW_Y(0));
            w = UI_W(3.5);
        };
        SC_GROUPS_LOCK(0, SC_GROUPS_MEMBERS_X, "Lock for Players", "No player can join the group (only the group leader can change it)")
        SC_GROUPS_LOCK(1, SC_GROUPS_MEMBERS_X + SC_GROUPS_MEMBERS_W / 2, "Lock for AI", "No AI fills the group up; its AI stay unless they are kicked (only the group leader can change it)")

        class SC_Join: UI_Button {
            idc = 1600;
            text = "Join";
            tooltip = "Join the selected group; if it is full, one of its AI makes room";
            onButtonClick = "call SC_fnc_groupMenuJoin";
            x = UI_X(SC_GROUPS_X + SC_GROUPS_W - 18.2);
            y = UI_Y(SC_GROUPS_BUTTON_Y);
            w = UI_W(6);
        };
        class SC_Leave: UI_Button {
            idc = 1601;
            text = "Leave";
            tooltip = "Leave your group and start a new group of your own";
            onButtonClick = "call SC_fnc_groupMenuLeave";
            x = UI_X(SC_GROUPS_X + SC_GROUPS_W - 12.1);
            y = UI_Y(SC_GROUPS_BUTTON_Y);
            w = UI_W(6);
        };
        class SC_Close: UI_ButtonOK {
            idc = 1603;
            text = "Close";
            action = "closeDialog 2;";
            x = UI_X(SC_GROUPS_X + SC_GROUPS_W - 6);
            y = UI_Y(SC_GROUPS_BUTTON_Y);
            w = UI_W(6);
        };
    };
};
