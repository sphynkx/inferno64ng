implement IcScreenSaver;

include "ic/screensaver.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();

	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

IcFlashlighter: module
{
	PATH: con "/dis/ic/flashlighter.dis";

	init: fn();

	newstate: fn(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState;

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	stop: fn(state: ref IcState->AppState): int;

	resetidle: fn(state: ref IcState->AppState);
	handletick: fn(state: ref IcState->AppState): int;

	build: fn(state: ref IcState->AppState): int;
};

cfgdata: IcConfigData;
flashlighter: IcFlashlighter;

ConfigSection: con "screensaver";
DefaultName: con "flashlighter";
DefaultEnabled: con 1;
DefaultIdleTicks: con 300;

selectedname: fn(cfg: ref IcState->ConfigState): string;
enabled: fn(cfg: ref IcState->ConfigState): int;
idlelimit: fn(cfg: ref IcState->ConfigState): int;
ensurestate: fn(state: ref IcState->AppState): ref IcState->ScreenSaverState;

init()
{
	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	flashlighter = load IcFlashlighter IcFlashlighter->PATH;
	if(flashlighter == nil)
		raise "fail:load ic/flashlighter";

	cfgdata->init();
	flashlighter->init();
}

selectedname(cfg: ref IcState->ConfigState): string
{
	return cfgdata->get(cfg, ConfigSection, "name", DefaultName);
}

enabled(cfg: ref IcState->ConfigState): int
{
	return cfgdata->getbool(cfg, ConfigSection, "enabled", DefaultEnabled);
}

idlelimit(cfg: ref IcState->ConfigState): int
{
	return cfgdata->getint(cfg, ConfigSection, "idle_ticks", DefaultIdleTicks);
}

ensurestate(state: ref IcState->AppState): ref IcState->ScreenSaverState
{
	if(state == nil)
		return nil;

	if(state.screensaver == nil)
		state.screensaver = newstate(state.cfg);

	return state.screensaver;
}

newstate(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState
{
	s: ref IcState->ScreenSaverState;
	name: string;

	name = selectedname(cfg);

	if(name == "flashlighter")
		s = flashlighter->newstate(cfg);
	else
		s = flashlighter->newstate(cfg);

	if(s == nil)
		return nil;

	s.enabled = enabled(cfg);
	s.idlelimit = idlelimit(cfg);

	if(s.idlelimit <= 0)
		s.enabled = 0;

	return s;
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.screensaver != nil && state.screensaver.active;
}

start(state: ref IcState->AppState): int
{
	if(ensurestate(state) == nil)
		return -1;

	if(selectedname(state.cfg) == "flashlighter")
		return flashlighter->start(state);

	return flashlighter->start(state);
}

stop(state: ref IcState->AppState): int
{
	if(state == nil || state.screensaver == nil)
		return 0;

	if(selectedname(state.cfg) == "flashlighter")
		return flashlighter->stop(state);

	return flashlighter->stop(state);
}

resetidle(state: ref IcState->AppState)
{
	if(ensurestate(state) == nil)
		return;

	state.screensaver.idleticks = 0;
}

handletick(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;

	s = ensurestate(state);
	if(s == nil || !s.enabled)
		return 0;

	if(s.active){
		if(selectedname(state.cfg) == "flashlighter")
			return flashlighter->handletick(state);

		return flashlighter->handletick(state);
	}

	s.idleticks++;
	if(s.idleticks >= s.idlelimit)
		return start(state) >= 0;

	return 0;
}

build(state: ref IcState->AppState): int
{
	if(!active(state))
		return 0;

	if(selectedname(state.cfg) == "flashlighter")
		return flashlighter->build(state);

	return flashlighter->build(state);
}