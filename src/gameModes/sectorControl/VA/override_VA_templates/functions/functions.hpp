class VA_overrideVATemplates
{
    tag = "VA";
    class Inventory
    {
        file = "VA\override_VA_templates\functions";
        class initOverride { postInit = 1; };
        class loadInventory_whiteList {};
        class overrideVAButtonDown {};
        class overrideVATemplateOK {};
        class applyLBColors {};
        class showRestrictedItems {};
        class addVAKeyEvents {};
    };
};