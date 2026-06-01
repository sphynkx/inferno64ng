implement IcThemeData;

include "ic/theme.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

cfgdata: IcConfigData;

ThemeSection: con "theme";

init()
{
	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	cfgdata->init();
}

loadstate(cfg: ref IcState->ConfigState): ref IcState->ThemeState
{
	t: ref IcState->ThemeState;

	t = ref IcState->ThemeState;

	t.frame = cfgdata->getint(cfg, ThemeSection, "frame_style", 1);
	t.panelshadow = cfgdata->getint(cfg, ThemeSection, "panel_shadow", 0);

	t.paneltopcode = cfgdata->get(cfg, ThemeSection, "panel_top_code", "1;38;2;20;25;30;48;2;225;225;225");
	t.panelbodycode = cfgdata->get(cfg, ThemeSection, "panel_body_code", "38;2;220;230;255;48;2;20;45;90");
	t.panelfocuscode = cfgdata->get(cfg, ThemeSection, "panel_focus_code", "1;38;2;0;0;0;48;2;170;225;255");
	t.paneltitlecode = cfgdata->get(cfg, ThemeSection, "panel_title_code", "1;38;2;255;230;120;48;2;20;45;90");
	t.panelmarkedcode = cfgdata->get(cfg, ThemeSection, "panel_marked_code", "1;38;2;255;120;210;48;2;20;45;90");
	t.panelmarkedfocuscode = cfgdata->get(cfg, ThemeSection, "panel_marked_focus_code", "1;38;2;220;0;0;48;2;170;225;255");

	t.menuwindowcode = cfgdata->get(cfg, ThemeSection, "menu_window_code", t.paneltopcode);
	t.menufocuscode = cfgdata->get(cfg, ThemeSection, "menu_focus_code", t.panelfocuscode);

	t.dialoganimticks = cfgdata->getint(cfg, ThemeSection, "dialog_anim_ticks", 3);

	t.dialogwindowcode = cfgdata->get(cfg, ThemeSection, "dialog_window_code", "38;2;20;20;20;48;2;210;210;210");
	t.dialogframecode = cfgdata->get(cfg, ThemeSection, "dialog_frame_code", "1;38;2;80;80;80;48;2;210;210;210");
	t.dialogtextcode = cfgdata->get(cfg, ThemeSection, "dialog_text_code", "38;2;25;25;25;48;2;210;210;210");
	t.dialogfieldcode = cfgdata->get(cfg, ThemeSection, "dialog_field_code", "38;2;20;20;20;48;2;245;245;245");
	t.dialogfieldfocuscode = cfgdata->get(cfg, ThemeSection, "dialog_field_focus_code", "1;38;2;255;255;255;48;2;35;135;205");
	t.dialogfocuscode = cfgdata->get(cfg, ThemeSection, "dialog_focus_code", "1;38;2;0;0;0;48;2;170;225;255");
	t.dialogcursorcode = cfgdata->get(cfg, ThemeSection, "dialog_cursor_code", "1;38;2;255;255;255;48;2;220;80;40");
	t.dialogbuttoncode = cfgdata->get(cfg, ThemeSection, "dialog_button_code", "1;38;2;20;20;20;48;2;235;235;235");
	t.dialogbuttonfocuscode = cfgdata->get(cfg, ThemeSection, "dialog_button_focus_code", "1;38;2;0;0;0;48;2;170;225;255");
	t.dialogdisabledcode = cfgdata->get(cfg, ThemeSection, "dialog_disabled_code", "38;2;120;120;120;48;2;210;210;210");
	t.dialogshadowcode = cfgdata->get(cfg, ThemeSection, "dialog_shadow_code", "38;2;80;80;80;48;2;80;80;80");

	t.dialogframeh = cfgdata->get(cfg, ThemeSection, "dialog_frame_h", "─");
	t.dialogframev = cfgdata->get(cfg, ThemeSection, "dialog_frame_v", "│");
	t.dialogframenw = cfgdata->get(cfg, ThemeSection, "dialog_frame_nw", "┌");
	t.dialogframene = cfgdata->get(cfg, ThemeSection, "dialog_frame_ne", "┐");
	t.dialogframesw = cfgdata->get(cfg, ThemeSection, "dialog_frame_sw", "└");
	t.dialogframese = cfgdata->get(cfg, ThemeSection, "dialog_frame_se", "┘");

	t.commandbarcode = cfgdata->get(cfg, ThemeSection, "command_bar_code", t.paneltopcode);
	t.commandbaractivecode = cfgdata->get(cfg, ThemeSection, "command_bar_active_code", t.panelfocuscode);
	t.commandbardisabledcode = cfgdata->get(cfg, ThemeSection, "command_bar_disabled_code", t.paneltopcode);
	t.commandlinecode = cfgdata->get(cfg, ThemeSection, "command_line_code", t.panelbodycode);

	return t;
}