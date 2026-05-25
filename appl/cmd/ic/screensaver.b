implement IcScreenSaver;

include "ic/screensaver.m";

IcScreenSaverPlugin: module
{
	init: fn();

	name: fn(): string;
	title: fn(): string;

	newstate: fn(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState;

	active: fn(state: ref IcState->AppState): int;
	start: fn(state: ref IcState->AppState): int;
	stop: fn(state: ref IcState->AppState): int;

	resetidle: fn(state: ref IcState->AppState);
	handletick: fn(state: ref IcState->AppState): int;

	build: fn(state: ref IcState->AppState): int;
};

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();

	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

sys: Sys;
cfgdata: IcConfigData;

PluginDir: con "/dis/ic";
PluginPrefix: con "scr_";
PluginSuffix: con ".dis";

ConfigSection: con "screensaver";
DefaultName: con "flashlighter";
DefaultEnabled: con 1;
DefaultIdleSeconds: con 30;
TicksPerSecond: con 10;

selectedplugin: IcScreenSaverPlugin;
selectedpluginname: string;
selectedpluginpath: string;

startswith: fn(s, prefix: string): int;
endswith: fn(s, suffix: string): int;
pluginnamefromfile: fn(file: string): string;
pluginpath: fn(file: string): string;
appendstr: fn(a: array of string, s: string): array of string;

selectedname: fn(cfg: ref IcState->ConfigState): string;
enabled: fn(cfg: ref IcState->ConfigState): int;
idlevalue: fn(cfg: ref IcState->ConfigState): int;
idleticklimit: fn(cfg: ref IcState->ConfigState): int;

loadpluginpath: fn(path: string): IcScreenSaverPlugin;
findpluginpath: fn(name: string): string;
ensureplugin: fn(cfg: ref IcState->ConfigState): IcScreenSaverPlugin;
ensurestate: fn(state: ref IcState->AppState): ref IcState->ScreenSaverState;
dropstate: fn(state: ref IcState->AppState);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	cfgdata->init();

	selectedplugin = nil;
	selectedpluginname = "";
	selectedpluginpath = "";
}

startswith(s, prefix: string): int
{
	if(len prefix > len s)
		return 0;

	return s[0:len prefix] == prefix;
}

endswith(s, suffix: string): int
{
	if(len suffix > len s)
		return 0;

	return s[len s - len suffix:] == suffix;
}

pluginnamefromfile(file: string): string
{
	if(!startswith(file, PluginPrefix))
		return "";

	if(!endswith(file, PluginSuffix))
		return "";

	return file[len PluginPrefix:len file - len PluginSuffix];
}

pluginpath(file: string): string
{
	return PluginDir + "/" + file;
}

appendstr(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(s == "")
		return a;

	if(a == nil){
		b = array[1] of string;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;

	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = s;
	return b;
}

selectedname(cfg: ref IcState->ConfigState): string
{
	if(cfg != nil && cfg.screensavername != "")
		return cfg.screensavername;

	return cfgdata->get(cfg, ConfigSection, "name", DefaultName);
}

enabled(cfg: ref IcState->ConfigState): int
{
	if(cfg != nil && (cfg.screensaverenabled == 0 || cfg.screensaverenabled == 1))
		return cfg.screensaverenabled;

	return cfgdata->getbool(cfg, ConfigSection, "enabled", DefaultEnabled);
}

idlevalue(cfg: ref IcState->ConfigState): int
{
	if(cfg != nil && cfg.screensaveridleticks >= 0)
		return cfg.screensaveridleticks;

	return cfgdata->getint(cfg, ConfigSection, "idle_ticks", DefaultIdleSeconds);
}

idleticklimit(cfg: ref IcState->ConfigState): int
{
	v: int;

	v = idlevalue(cfg);
	if(v <= 0)
		return 0;

	return v * TicksPerSecond;
}

loadpluginpath(path: string): IcScreenSaverPlugin
{
	p: IcScreenSaverPlugin;

	if(path == "")
		return nil;

	p = load IcScreenSaverPlugin path;
	if(p == nil)
		return nil;

	p->init();
	return p;
}

findpluginpath(name: string): string
{
	fd: ref Sys->FD;
	n, i: int;
	dirs: array of Sys->Dir;
	file, pname, path: string;
	p: IcScreenSaverPlugin;

	if(name == "")
		return "";

	path = PluginDir + "/" + PluginPrefix + name + PluginSuffix;
	p = loadpluginpath(path);
	if(p != nil && p->name() == name)
		return path;

	fd = sys->open(PluginDir, Sys->OREAD);
	if(fd == nil)
		return "";

	for(;;){
		(n, dirs) = sys->dirread(fd);
		if(n <= 0)
			break;

		for(i = 0; i < n; i++){
			file = dirs[i].name;
			pname = pluginnamefromfile(file);
			if(pname == "")
				continue;

			path = pluginpath(file);
			p = loadpluginpath(path);
			if(p == nil)
				continue;

			if(p->name() == name)
				return path;
		}
	}

	return "";
}

ensureplugin(cfg: ref IcState->ConfigState): IcScreenSaverPlugin
{
	name, path: string;
	p: IcScreenSaverPlugin;

	name = selectedname(cfg);

	if(selectedplugin != nil && selectedpluginname == name)
		return selectedplugin;

	path = findpluginpath(name);
	if(path == ""){
		name = DefaultName;
		path = findpluginpath(name);
	}

	if(path == "")
		return nil;

	p = loadpluginpath(path);
	if(p == nil)
		return nil;

	selectedplugin = p;
	selectedpluginname = p->name();
	selectedpluginpath = path;

	return selectedplugin;
}

dropstate(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	state.screensaver = nil;
	selectedplugin = nil;
	selectedpluginname = "";
	selectedpluginpath = "";
}

ensurestate(state: ref IcState->AppState): ref IcState->ScreenSaverState
{
	p: IcScreenSaverPlugin;
	name: string;

	if(state == nil)
		return nil;

	p = ensureplugin(state.cfg);
	if(p == nil)
		return nil;

	name = selectedname(state.cfg);
	if(selectedpluginname != name && name != "")
		state.screensaver = nil;

	if(state.screensaver == nil)
		state.screensaver = newstate(state.cfg);

	return state.screensaver;
}

available(): array of string
{
	fd: ref Sys->FD;
	n, i: int;
	dirs: array of Sys->Dir;
	a: array of string;
	file, pname, path: string;
	p: IcScreenSaverPlugin;

	a = array[0] of string;

	fd = sys->open(PluginDir, Sys->OREAD);
	if(fd == nil)
		return a;

	for(;;){
		(n, dirs) = sys->dirread(fd);
		if(n <= 0)
			break;

		for(i = 0; i < n; i++){
			file = dirs[i].name;
			pname = pluginnamefromfile(file);
			if(pname == "")
				continue;

			path = pluginpath(file);
			p = loadpluginpath(path);
			if(p == nil)
				continue;

			a = appendstr(a, p->name());
		}
	}

	return a;
}

titleof(name: string): string
{
	path: string;
	p: IcScreenSaverPlugin;

	path = findpluginpath(name);
	if(path == "")
		return name;

	p = loadpluginpath(path);
	if(p == nil)
		return name;

	return p->title();
}

selected(cfg: ref IcState->ConfigState): string
{
	return selectedname(cfg);
}

isenabled(cfg: ref IcState->ConfigState): int
{
	return enabled(cfg);
}

idlelimit(cfg: ref IcState->ConfigState): int
{
	return idlevalue(cfg);
}

setselected(state: ref IcState->AppState, name: string): int
{
	if(state == nil || state.cfg == nil || name == "")
		return -1;

	if(findpluginpath(name) == "")
		return -1;

	state.cfg.screensavername = name;
	dropstate(state);
	return 0;
}

setenabled(state: ref IcState->AppState, on: int): int
{
	if(state == nil || state.cfg == nil)
		return -1;

	if(on != 0)
		on = 1;

	state.cfg.screensaverenabled = on;

	if(state.screensaver != nil)
		state.screensaver.enabled = enabled(state.cfg);

	if(!enabled(state.cfg))
		stop(state);

	return 0;
}

setidlelimit(state: ref IcState->AppState, seconds: int): int
{
	if(state == nil || state.cfg == nil)
		return -1;

	if(seconds < 0)
		seconds = 0;

	state.cfg.screensaveridleticks = seconds;

	if(state.screensaver != nil){
		state.screensaver.idlelimit = seconds;
		if(seconds <= 0){
			state.screensaver.enabled = 0;
			stop(state);
		}else
			state.screensaver.enabled = enabled(state.cfg);
	}

	return 0;
}

reload(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	stop(state);
	dropstate(state);

	if(ensurestate(state) == nil)
		return -1;

	return 0;
}

newstate(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState
{
	s: ref IcState->ScreenSaverState;
	p: IcScreenSaverPlugin;

	p = ensureplugin(cfg);
	if(p == nil)
		return nil;

	s = p->newstate(cfg);
	if(s == nil)
		return nil;

	s.enabled = enabled(cfg);
	s.idlelimit = idlevalue(cfg);

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
	p: IcScreenSaverPlugin;

	if(ensurestate(state) == nil)
		return -1;

	p = ensureplugin(state.cfg);
	if(p == nil)
		return -1;

	return p->start(state);
}

stop(state: ref IcState->AppState): int
{
	p: IcScreenSaverPlugin;

	if(state == nil || state.screensaver == nil)
		return 0;

	p = ensureplugin(state.cfg);
	if(p == nil)
		return 0;

	return p->stop(state);
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
	p: IcScreenSaverPlugin;

	s = ensurestate(state);
	if(s == nil || !s.enabled)
		return 0;

	p = ensureplugin(state.cfg);
	if(p == nil)
		return 0;

	if(s.active)
		return p->handletick(state);

	s.idleticks++;
	if(s.idleticks >= idleticklimit(state.cfg))
		return start(state) >= 0;

	return 0;
}

build(state: ref IcState->AppState): int
{
	p: IcScreenSaverPlugin;

	if(!active(state))
		return 0;

	p = ensureplugin(state.cfg);
	if(p == nil)
		return 0;

	return p->build(state);
}