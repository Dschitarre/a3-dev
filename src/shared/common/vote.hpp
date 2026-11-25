// Shared TDM/GunGame vote dialog (common\vote.sqf: CMN_fnc_openVoteDialog). #include from Description.ext after
// ui\ui.hpp. Title bar, list of the options with their vote counts, Close and Vote buttons.

#define CMN_VOTE_X          13
#define CMN_VOTE_W          14
#define CMN_VOTE_Y          8
#define CMN_VOTE_LIST_H     4
#define CMN_VOTE_BODY_Y     (CMN_VOTE_Y + UI_ROW)
#define CMN_VOTE_BODY_H     (CMN_VOTE_LIST_H + 2 * UI_PADDING)
#define CMN_VOTE_BUTTONS_Y  (CMN_VOTE_BODY_Y + CMN_VOTE_BODY_H + UI_GAP)
#define CMN_VOTE_BUTTON_W   5

class CMN_voteDialog {
    idd = 7400;
    movingEnable = false;
    onLoad = "uiNamespace setVariable [""CMN_voteDialog"", _this select 0]";

    class controlsBackground {
        class title: UI_Title {
            idc = 7401;
            text = "Vote";
            x = UI_X(CMN_VOTE_X);
            y = UI_Y(CMN_VOTE_Y);
            w = UI_W(CMN_VOTE_W);
        };
        class body: UI_Panel {
            x = UI_X(CMN_VOTE_X);
            y = UI_Y(CMN_VOTE_BODY_Y);
            w = UI_W(CMN_VOTE_W);
            h = UI_H(CMN_VOTE_BODY_H);
        };
    };

    class controls {
        class options: UI_List {
            idc = 7402;
            x = UI_X(CMN_VOTE_X + UI_PADDING);
            y = UI_Y(CMN_VOTE_BODY_Y + UI_PADDING);
            w = UI_W(CMN_VOTE_W - 2 * UI_PADDING);
            h = UI_H(CMN_VOTE_LIST_H);
            onLBDblClick = "call CMN_fnc_voteSelected";
        };
        class close: UI_ButtonCancel {
            text = "Close";
            x = UI_X(CMN_VOTE_X + CMN_VOTE_W - 2 * CMN_VOTE_BUTTON_W - UI_GAP);
            y = UI_Y(CMN_VOTE_BUTTONS_Y);
            w = UI_W(CMN_VOTE_BUTTON_W);
        };
        class vote: UI_Button {
            idc = 7403;
            text = "Vote";
            x = UI_X(CMN_VOTE_X + CMN_VOTE_W - CMN_VOTE_BUTTON_W);
            y = UI_Y(CMN_VOTE_BUTTONS_Y);
            w = UI_W(CMN_VOTE_BUTTON_W);
            onButtonClick = "call CMN_fnc_voteSelected";
        };
    };
};
