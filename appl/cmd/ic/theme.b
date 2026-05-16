implement IcThemeData;

include "ic/theme.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

cfgdata: IcConfigData;

DefaultFrameStyle: con 1;
DefaultPanelShadow: con 0;
DefaultModalAnimTicks: con 1;

DefaultModalCopyCode: con "38;2;25;25;25;48;2;210;210;210";
DefaultModalOverwriteCode: con "38;2;40;15;35;48;2;255;185;225";
DefaultModalFrameCode: con "1;38;2;80;80;80;48;2;210;210;210";
DefaultModalTextCode: con "38;2;25;25;25;48;2;210;210;210";
DefaultModalShadowCode: con "38;2;80;80;80;48;2;80;80;80";

DefaultModalFieldCode: con "38;2;20;20;20;48;2;245;245;245";
DefaultModalFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";
DefaultModalButtonCode: con "1;38;2;20;20;20;48;2;235;235;235";
DefaultModalButtonFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";

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

	t.frame = cfgdata->getint(cfg, "theme", "frame_style", DefaultFrameStyle);
	t.panelshadow = cfgdata->getbool(cfg, "theme", "panel_shadow", DefaultPanelShadow);

	t.modalanimticks = cfgdata->getint(cfg, "theme", "modal_anim_ticks", DefaultModalAnimTicks);

	t.modalcopycode = cfgdata->get(cfg, "theme", "modal_copy_code", DefaultModalCopyCode);
	t.modaloverwritecode = cfgdata->get(cfg, "theme", "modal_overwrite_code", DefaultModalOverwriteCode);
	t.modalframecode = cfgdata->get(cfg, "theme", "modal_frame_code", DefaultModalFrameCode);
	t.modaltextcode = cfgdata->get(cfg, "theme", "modal_text_code", DefaultModalTextCode);
	t.modalshadowcode = cfgdata->get(cfg, "theme", "modal_shadow_code", DefaultModalShadowCode);

	t.modalfieldcode = cfgdata->get(cfg, "theme", "modal_field_code", DefaultModalFieldCode);
	t.modalfocuscode = cfgdata->get(cfg, "theme", "modal_focus_code", DefaultModalFocusCode);
	t.modalbuttoncode = cfgdata->get(cfg, "theme", "modal_button_code", DefaultModalButtonCode);
	t.modalbuttonfocuscode = cfgdata->get(cfg, "theme", "modal_button_focus_code", DefaultModalButtonFocusCode);

	return t;
}