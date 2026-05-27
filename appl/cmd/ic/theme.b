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

	t.modalanimticks = cfgdata->getint(cfg, ThemeSection, "modal_anim_ticks", 3);

	t.modalcopycode = cfgdata->get(cfg, ThemeSection, "modal_copy_code", "38;2;25;25;25;48;2;210;210;210");
	t.modaloverwritecode = cfgdata->get(cfg, ThemeSection, "modal_overwrite_code", "38;2;40;15;35;48;2;255;185;225");
	t.modalframecode = cfgdata->get(cfg, ThemeSection, "modal_frame_code", "1;38;2;80;80;80;48;2;210;210;210");
	t.modaltextcode = cfgdata->get(cfg, ThemeSection, "modal_text_code", "38;2;25;25;25;48;2;210;210;210");
	t.modalshadowcode = cfgdata->get(cfg, ThemeSection, "modal_shadow_code", "38;2;80;80;80;48;2;80;80;80");

	t.modalfieldcode = cfgdata->get(cfg, ThemeSection, "modal_field_code", "38;2;20;20;20;48;2;245;245;245");
	t.modalfocuscode = cfgdata->get(cfg, ThemeSection, "modal_focus_code", "1;38;2;0;0;0;48;2;170;225;255");
	t.modalbuttoncode = cfgdata->get(cfg, ThemeSection, "modal_button_code", "1;38;2;20;20;20;48;2;235;235;235");
	t.modalbuttonfocuscode = cfgdata->get(cfg, ThemeSection, "modal_button_focus_code", "1;38;2;0;0;0;48;2;170;225;255");

	t.commandbarcode = cfgdata->get(cfg, ThemeSection, "command_bar_code", t.paneltopcode);
	t.commandbaractivecode = cfgdata->get(cfg, ThemeSection, "command_bar_active_code", t.panelfocuscode);
	t.commandbardisabledcode = cfgdata->get(cfg, ThemeSection, "command_bar_disabled_code", t.paneltopcode);
	t.commandlinecode = cfgdata->get(cfg, ThemeSection, "command_line_code", t.panelbodycode);

	return t;
}