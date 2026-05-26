implement IcRuntimeTheme;

include "ic/runtheme.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	loadstate: fn(): ref IcState->ConfigState;
};

IcThemeData: module
{
	PATH: con "/dis/ic/theme.dis";

	init: fn();
	loadstate: fn(cfg: ref IcState->ConfigState): ref IcState->ThemeState;
};

cfgdata: IcConfigData;
themedata: IcThemeData;

init()
{
	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	themedata = load IcThemeData IcThemeData->PATH;
	if(themedata == nil)
		raise "fail:load ic/theme";

	cfgdata->init();
	themedata->init();
}

loadcfg(): ref IcState->ConfigState
{
	return cfgdata->loadstate();
}

loadtheme(): ref IcState->ThemeState
{
	cfg: ref IcState->ConfigState;

	cfg = loadcfg();
	if(cfg == nil)
		return nil;

	return themedata->loadstate(cfg);
}