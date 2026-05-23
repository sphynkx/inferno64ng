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

DefaultThemeFile: con "/lib/ic/theme.cfg";
DefaultKeysFile: con "/lib/ic/keys.cfg";
DefaultLayoutFile: con "/lib/ic/layout.cfg";
DefaultMenusFile: con "/lib/ic/menus.cfg";

ThemeFileName: con "theme.cfg";
KeysFileName: con "keys.cfg";
LayoutFileName: con "layout.cfg";
MenusFileName: con "menus.cfg";

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

	c.themefile = DefaultThemeFile;
	c.keysfile = DefaultKeysFile;
	c.layoutfile = DefaultLayoutFile;
	c.menusfile = DefaultMenusFile;

	c.userthemefile = "";
	c.userkeysfile = "";
	c.userlayoutfile = "";
	c.usermenusfile = "";

	if(c.userenabled){
		c.userthemefile = userdir->path(ThemeFileName);
		c.userkeysfile = userdir->path(KeysFileName);
		c.userlayoutfile = userdir->path(LayoutFileName);
		c.usermenusfile = userdir->path(MenusFileName);
	}

	c.cfg = cfgmod->new();
	if(c.cfg == nil)
		return c;

	cfgmod->overlay(c.cfg, c.themefile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.keysfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.layoutfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.menusfile, IcConfigMod->OriginDefault);

	if(c.userenabled){
		cfgmod->overlay(c.cfg, c.userthemefile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.userkeysfile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.userlayoutfile, IcConfigMod->OriginUser);
		cfgmod->overlay(c.cfg, c.usermenusfile, IcConfigMod->OriginUser);
	}

	return c;
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