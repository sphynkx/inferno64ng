implement IcThemeData;

include "ic/theme.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

cfgdata: IcConfigData;

DefaultFrameStyle: con 1;
DefaultPanelShadow: con 0;

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

	return t;
}