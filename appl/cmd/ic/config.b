implement IcConfigData;

include "ic/config.m";

IcConfigMod: module
{
	PATH: con "/dis/lib/icurses/config.dis";

	OriginDefault: con 1;
	OriginUser: con 2;

	init: fn();
	new: fn(): ref IcConfig->Config;
	overlay: fn(c: ref IcConfig->Config, path: string, origin: int): int;
	get: fn(c: ref IcConfig->Config, section, key: string): string;
	getint: fn(c: ref IcConfig->Config, section, key: string, def: int): int;
	getbool: fn(c: ref IcConfig->Config, section, key: string, def: int): int;

	set: fn(c: ref IcConfig->Config, file, section, key, value: string): int;
	setint: fn(c: ref IcConfig->Config, file, section, key: string, value: int): int;
	setbool: fn(c: ref IcConfig->Config, file, section, key: string, value: int): int;
	flush: fn(c: ref IcConfig->Config, path: string): int;
};

IcUserDir: module
{
	PATH: con "/dis/ic/userdir.dis";

	init: fn();

	home: fn(): string;
	dir: fn(): string;
	enabled: fn(): int;

	ensure: fn(): int;
	path: fn(name: string): string;
	ensurepath: fn(name: string): string;
};

sys: Sys;
cfgmod: IcConfigMod;
userdir: IcUserDir;

DefaultThemeName: con "default";
DefaultThemeFile: con "/lib/ic/default.theme";
DefaultKeysFile: con "/lib/ic/keys.cfg";
DefaultLayoutFile: con "/lib/ic/layout.cfg";
DefaultMenusFile: con "/lib/ic/menus.cfg";

StateFileName: con "state.cfg";
ThemeSuffix: con ".theme";

KeysFileName: con "keys.cfg";
LayoutFileName: con "layout.cfg";
MenusFileName: con "menus.cfg";

cleanline: fn(s: string): string;
validfile: fn(path: string): int;
endswith: fn(s, suffix: string): int;
themename: fn(name: string): string;
themefilename: fn(name: string): string;
stdthemepath: fn(name: string): string;
userthemepath: fn(name: string): string;
selectedthemepath: fn(name: string): (string, int);
themeexists: fn(name: string): int;
rebuildcfg: fn(c: ref IcState->ConfigState): int;
statefilepath: fn(c: ref IcState->ConfigState): string;
flushstatevalue: fn(c: ref IcState->ConfigState, section, key: string): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	cfgmod = load IcConfigMod IcConfigMod->PATH;
	if(cfgmod == nil)
		raise "fail:load icurses/config";

	userdir = load IcUserDir IcUserDir->PATH;
	if(userdir == nil)
		raise "fail:load ic/userdir";

	cfgmod->init();
	userdir->init();
}

cleanline(s: string): string
{
	while(len s > 0
	&& (s[len s - 1] == '\n'
	|| s[len s - 1] == '\r'
	|| s[len s - 1] == ' '
	|| s[len s - 1] == '\t'))
		s = s[0:len s - 1];

	while(len s > 0 && (s[0] == ' ' || s[0] == '\t'))
		s = s[1:];

	return s;
}

validfile(path: string): int
{
	rc: int;
	d: Sys->Dir;

	if(path == "")
		return 0;

	(rc, d) = sys->stat(path);
	if(rc < 0)
		return 0;

	return (d.mode & Sys->DMDIR) == 0;
}

endswith(s, suffix: string): int
{
	if(len suffix > len s)
		return 0;

	return s[len s - len suffix:] == suffix;
}

themename(name: string): string
{
	i: int;

	name = cleanline(name);
	if(name == "")
		return DefaultThemeName;

	for(i = 0; i < len name; i++){
		if(name[i] == '/' || name[i] == '\\')
			return DefaultThemeName;
	}

	if(endswith(name, ThemeSuffix))
		name = name[0:len name - len ThemeSuffix];

	if(name == "")
		return DefaultThemeName;

	return name;
}

themefilename(name: string): string
{
	name = themename(name);
	return name + ThemeSuffix;
}

stdthemepath(name: string): string
{
	return "/lib/ic/" + themefilename(name);
}

userthemepath(name: string): string
{
	if(!userdir->enabled())
		return "";

	return userdir->path(themefilename(name));
}

selectedthemepath(name: string): (string, int)
{
	path: string;

	name = themename(name);

	path = userthemepath(name);
	if(validfile(path))
		return (path, IcConfigMod->OriginUser);

	path = stdthemepath(name);
	if(validfile(path))
		return (path, IcConfigMod->OriginDefault);

	return (DefaultThemeFile, IcConfigMod->OriginDefault);
}

themeexists(name: string): int
{
	name = themename(name);

	if(validfile(userthemepath(name)))
		return 1;

	if(validfile(stdthemepath(name)))
		return 1;

	return name == DefaultThemeName && validfile(DefaultThemeFile);
}

statefilepath(c: ref IcState->ConfigState): string
{
	if(c == nil || !c.userenabled)
		return "";

	return userdir->ensurepath(StateFileName);
}

rebuildcfg(c: ref IcState->ConfigState): int
{
	themeorigin: int;

	if(c == nil)
		return -1;

	(c.themefile, themeorigin) = selectedthemepath(c.theme);

	c.keysfile = DefaultKeysFile;
	c.layoutfile = DefaultLayoutFile;
	c.menusfile = DefaultMenusFile;
	c.statefile = "";

	c.userthemefile = "";
	c.userkeysfile = "";
	c.userlayoutfile = "";
	c.usermenusfile = "";

	if(c.userenabled){
		c.statefile = userdir->path(StateFileName);
		c.userthemefile = userthemepath(c.theme);
		c.userkeysfile = userdir->path(KeysFileName);
		c.userlayoutfile = userdir->path(LayoutFileName);
		c.usermenusfile = userdir->path(MenusFileName);
	}

	c.cfg = cfgmod->new();
	if(c.cfg == nil)
		return -1;

	cfgmod->overlay(c.cfg, DefaultThemeFile, IcConfigMod->OriginDefault);
	if(c.themefile != DefaultThemeFile)
		cfgmod->overlay(c.cfg, c.themefile, themeorigin);

	cfgmod->overlay(c.cfg, c.keysfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.layoutfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.menusfile, IcConfigMod->OriginDefault);

	if(c.userenabled){
		cfgmod->overlay(c.cfg, c.statefile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.userkeysfile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.userlayoutfile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.usermenusfile, IcConfigMod->OriginUser);
	}

	c.screensavername = get(c, "", "screensaver.name", "");
	c.screensaverenabled = getbool(c, "", "screensaver.enabled", -1);
	c.screensaveridleticks = getint(c, "", "screensaver.idle_ticks", -1);

	return 0;
}

loadstate(): ref IcState->ConfigState
{
	c: ref IcState->ConfigState;

	c = ref IcState->ConfigState;

	c.home = userdir->home();
	c.userenabled = c.home != "";

	if(c.userenabled){
		userdir->ensure();
		c.userdir = userdir->dir();
	}else
		c.userdir = "";

	c.theme = DefaultThemeName;
	c.screensavername = "";
	c.screensaverenabled = -1;
	c.screensaveridleticks = -1;

	if(c.userenabled){
		c.statefile = userdir->path(StateFileName);
		if(c.statefile != ""){
			c.cfg = cfgmod->new();
			if(c.cfg != nil){
				cfgmod->overlay(c.cfg, c.statefile, IcConfigMod->OriginUser);
				c.theme = themename(cfgmod->get(c.cfg, "", "theme"));
				if(c.theme == "")
					c.theme = DefaultThemeName;
			}
		}
	}

	rebuildcfg(c);

	return c;
}

flushstatevalue(c: ref IcState->ConfigState, section, key: string): int
{
	path: string;

	if(c == nil || c.cfg == nil || key == "")
		return -1;

	path = statefilepath(c);
	if(path == "")
		return -1;

	c.statefile = path;
	return cfgmod->flush(c.cfg, path);
}

settheme(c: ref IcState->ConfigState, name: string): int
{
	path: string;

	if(c == nil)
		return -1;

	name = themename(name);
	if(!themeexists(name))
		return -1;

	if(!c.userenabled)
		return -1;

	if(c.cfg == nil){
		c.cfg = cfgmod->new();
		if(c.cfg == nil)
			return -1;
	}

	path = statefilepath(c);
	if(path == "")
		return -1;

	c.statefile = path;

	if(cfgmod->set(c.cfg, path, "", "theme", name) < 0)
		return -1;

	c.theme = name;

	if(cfgmod->flush(c.cfg, path) < 0)
		return -1;

	return rebuildcfg(c);
}

hasuserdir(c: ref IcState->ConfigState): int
{
	return c != nil && c.userenabled && c.userdir != "";
}

userpath(c: ref IcState->ConfigState, name: string): string
{
	if(!hasuserdir(c) || name == "")
		return "";

	if(c.userdir == "/")
		return "/" + name;

	return c.userdir + "/" + name;
}

ensureuserpath(c: ref IcState->ConfigState, name: string): string
{
	if(c == nil || !c.userenabled || name == "")
		return "";

	if(!userdir->ensure())
		return "";

	return userpath(c, name);
}

get(c: ref IcState->ConfigState, section, key, def: string): string
{
	v: string;

	if(c == nil || c.cfg == nil)
		return def;

	v = cfgmod->get(c.cfg, section, key);
	if(v == "")
		return def;

	return v;
}

getint(c: ref IcState->ConfigState, section, key: string, def: int): int
{
	if(c == nil || c.cfg == nil)
		return def;

	return cfgmod->getint(c.cfg, section, key, def);
}

getbool(c: ref IcState->ConfigState, section, key: string, def: int): int
{
	if(c == nil || c.cfg == nil)
		return def;

	return cfgmod->getbool(c.cfg, section, key, def);
}

set(c: ref IcState->ConfigState, section, key, value: string): int
{
	path: string;

	if(c == nil || c.cfg == nil || key == "")
		return -1;

	if(!c.userenabled)
		return -1;

	path = statefilepath(c);
	if(path == "")
		return -1;

	c.statefile = path;

	if(cfgmod->set(c.cfg, path, section, key, value) < 0)
		return -1;

	if(section == "" && key == "theme")
		c.theme = themename(value);

	if(section == "" && key == "screensaver.name")
		c.screensavername = value;

	return cfgmod->flush(c.cfg, path);
}

setint(c: ref IcState->ConfigState, section, key: string, value: int): int
{
	path: string;

	if(c == nil || c.cfg == nil || key == "")
		return -1;

	if(!c.userenabled)
		return -1;

	path = statefilepath(c);
	if(path == "")
		return -1;

	c.statefile = path;

	if(cfgmod->setint(c.cfg, path, section, key, value) < 0)
		return -1;

	if(section == "" && key == "screensaver.idle_ticks")
		c.screensaveridleticks = value;

	return cfgmod->flush(c.cfg, path);
}

setbool(c: ref IcState->ConfigState, section, key: string, value: int): int
{
	path: string;

	if(c == nil || c.cfg == nil || key == "")
		return -1;

	if(!c.userenabled)
		return -1;

	path = statefilepath(c);
	if(path == "")
		return -1;

	c.statefile = path;

	if(cfgmod->setbool(c.cfg, path, section, key, value) < 0)
		return -1;

	if(section == "" && key == "screensaver.enabled")
		c.screensaverenabled = value;

	return cfgmod->flush(c.cfg, path);
}