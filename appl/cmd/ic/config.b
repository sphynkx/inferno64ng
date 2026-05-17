implement IcConfigData;

include "ic/config.m";
include "env.m";

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

sys: Sys;
envmod: Env;
cfgmod: IcConfigMod;

DefaultThemeFile: con "/lib/ic/theme.cfg";
DefaultKeysFile: con "/lib/ic/keys.cfg";
DefaultLayoutFile: con "/lib/ic/layout.cfg";
DefaultMenusFile: con "/lib/ic/menus.cfg";

UserBaseDir: con "/usr";
UserConfigDir: con "ic";

ThemeFileName: con "theme.cfg";
KeysFileName: con "keys.cfg";
LayoutFileName: con "layout.cfg";
MenusFileName: con "menus.cfg";

DefaultUserName: con "inferno";

userconfigpath: fn(name: string): string;
username: fn(): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	envmod = load Env Env->PATH;
	if(envmod == nil)
		raise "fail:load env";

	cfgmod = load IcConfigMod IcConfigMod->PATH;
	if(cfgmod == nil)
		raise "fail:load icurses/config";

	cfgmod->init();
}

username(): string
{
	user: string;

	user = envmod->getenv("user");
	if(user == nil || user == "")
		user = DefaultUserName;

	return user;
}

userconfigpath(name: string): string
{
	return UserBaseDir + "/" + username() + "/" + UserConfigDir + "/" + name;
}

loadstate(): ref IcState->ConfigState
{
	c: ref IcState->ConfigState;

	c = ref IcState->ConfigState;

	c.themefile = DefaultThemeFile;
	c.keysfile = DefaultKeysFile;
	c.layoutfile = DefaultLayoutFile;
	c.menusfile = DefaultMenusFile;

	c.userthemefile = userconfigpath(ThemeFileName);
	c.userkeysfile = userconfigpath(KeysFileName);
	c.userlayoutfile = userconfigpath(LayoutFileName);
	c.usermenusfile = userconfigpath(MenusFileName);

	c.cfg = cfgmod->new();
	if(c.cfg == nil)
		return c;

	cfgmod->overlay(c.cfg, c.themefile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.keysfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.layoutfile, IcConfigMod->OriginDefault);
	cfgmod->overlay(c.cfg, c.menusfile, IcConfigMod->OriginDefault);

	cfgmod->overlay(c.cfg, c.userthemefile, IcConfigMod->OriginUser);
	cfgmod->overlay(c.cfg, c.userkeysfile, IcConfigMod->OriginUser);
	cfgmod->overlay(c.cfg, c.userlayoutfile, IcConfigMod->OriginUser);
	cfgmod->overlay(c.cfg, c.usermenusfile, IcConfigMod->OriginUser);

	return c;
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