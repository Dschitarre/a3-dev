class RscTitles
{
    class ScoreDisplay
    {
        idd = 5000;
        movingenable = false;
        enableSimulation = true;
        duration = 999999;
        fadein = 0;
        fadeout = 0;
        onLoad = "uiNamespace setVariable [""ScoreDisplay"", _this select 0]";
    class ControlsBackground
        {
      class RscStructuredText_1100: RscStructuredText
      {
          idc = 1100;
          text = "Score: 0";
          x = 0.479375 * safezoneW + safezoneX;
          y = 0.00500001 * safezoneH + safezoneY;
          w = 0.0464063 * safezoneW;
          h = 0.033 * safezoneH;
          colorBackground[] = {-1,-1,-1,0.3};
      };
    };
  };
};
