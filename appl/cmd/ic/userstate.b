implement IcUserState;

include "ic/userstate.m";

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

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();

	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
	selectid: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel, itemid: int): IcMsg->Msg;
	render: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel): int;
};

sys: Sys;
userdir: IcUserDir;
panelui: IcPanelMod;

StateFileName: con "state.cfg";
DefaultThemeName: con "default";

savedleftitem: string;
savedrightitem: string;
savedtheme: string;

statepath: fn(create: int): string;
readfile: fn(path: string): string;
writefile: fn(path, text: string): int;

cleanline: fn(s: string): string;
splitkv: fn(s: string): (string, string, int);
applykv: fn(state: ref IcState->AppState, key, value: string);

currentitem: fn(p: ref IcState->PanelState): string;
selectitem: fn(state: ref IcState->AppState, p: ref IcState->PanelState, name: string): int;
panelactivevalue: fn(state: ref IcState->AppState): string;
themevalue: fn(state: ref IcState->AppState): string;
readthemefromstate: fn(): string;
validdir: fn(path: string): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	userdir = load IcUserDir IcUserDir->PATH;
	if(userdir == nil)
		raise "fail:load ic/userdir";

	panelui = load IcPanelMod IcPanelMod->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	userdir->init();
	panelui->init();

	savedleftitem = "";
	savedrightitem = "";
	savedtheme = DefaultThemeName;
}

statepath(create: int): string
{
	if(create)
		return userdir->ensurepath(StateFileName);

	return userdir->path(StateFileName);
}

validdir(path: string): int
{
	rc: int;
	d: Sys->Dir;

	if(path == "")
		return 0;

	(rc, d) = sys->stat(path);
	if(rc < 0)
		return 0;

	return (d.mode & Sys->DMDIR) != 0;
}

readfile(path: string): string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	text: string;

	if(path == "")
		return "";

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return "";

	buf = array[4096] of byte;
	text = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		text += string buf[0:n];
	}

	fd = nil;
	return text;
}

writefile(path, text: string): int
{
	fd: ref Sys->FD;

	if(path == "")
		return -1;

	fd = sys->create(path, Sys->OWRITE, 8r666);
	if(fd == nil)
		return -1;

	if(sys->fprint(fd, "%s", text) < 0){
		fd = nil;
		return -1;
	}

	fd = nil;
	return 0;
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

splitkv(s: string): (string, string, int)
{
	i: int;
	key, value: string;

	s = cleanline(s);
	if(s == "" || s[0] == '#')
		return ("", "", 0);

	for(i = 0; i < len s; i++){
		if(s[i] != '=')
			continue;

		key = cleanline(s[0:i]);
		value = cleanline(s[i + 1:]);

		if(key == "")
			return ("", "", 0);

		return (key, value, 1);
	}

	return ("", "", 0);
}

applykv(state: ref IcState->AppState, key, value: string)
{
	if(state == nil)
		return;

	if(key == "theme"){
		savedtheme = value;
		if(state.cfg != nil)
			state.cfg.theme = value;
		return;
	}

	if(key == "activepanel"){
		if(value == "right")
			state.activepanel = IcState->PanelRight;
		else if(value == "left")
			state.activepanel = IcState->PanelLeft;
		return;
	}

	if(key == "left.path"){
		if(state.left != nil && validdir(value))
			state.left.path = value;
		return;
	}

	if(key == "right.path"){
		if(state.right != nil && validdir(value))
			state.right.path = value;
		return;
	}

	if(key == "left.item"){
		savedleftitem = value;
		if(state.left != nil)
			state.left.lastchildname = value;
		return;
	}

	if(key == "right.item"){
		savedrightitem = value;
		if(state.right != nil)
			state.right.lastchildname = value;
		return;
	}
}

loadstate(state: ref IcState->AppState): int
{
	path, text, line, key, value: string;
	i, start, ok: int;

	if(state == nil)
		return -1;

	if(state.cfg != nil && state.cfg.theme != "")
		savedtheme = state.cfg.theme;

	if(!userdir->enabled())
		return 0;

	path = statepath(0);
	if(path == "")
		return 0;

	text = readfile(path);
	if(text == "")
		return 0;

	start = 0;
	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = text[start:i];
		start = i + 1;

		(key, value, ok) = splitkv(line);
		if(ok)
			applykv(state, key, value);
	}

	return 0;
}

currentitem(p: ref IcState->PanelState): string
{
	if(p == nil || p.panel == nil)
		return "";

	return panelui->currentname(p.panel);
}

selectitem(state: ref IcState->AppState, p: ref IcState->PanelState, name: string): int
{
	i: int;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil || p.model == nil)
		return 0;

	if(name == "")
		return 0;

	for(i = 0; i < len p.model.items; i++){
		if(p.model.items[i].name == name){
			panelui->selectid(state.ui, p.panel, p.model.items[i].id);
			panelui->render(state.ui, p.panel);
			return 1;
		}
	}

	return 0;
}

restore(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	if(savedleftitem != "")
		selectitem(state, state.left, savedleftitem);

	if(savedrightitem != "")
		selectitem(state, state.right, savedrightitem);

	return 0;
}

panelactivevalue(state: ref IcState->AppState): string
{
	if(state != nil && state.activepanel == IcState->PanelRight)
		return "right";

	return "left";
}

readthemefromstate(): string
{
	path, text, line, key, value: string;
	i, start, ok: int;

	path = statepath(0);
	if(path == "")
		return "";

	text = readfile(path);
	if(text == "")
		return "";

	start = 0;
	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = text[start:i];
		start = i + 1;

		(key, value, ok) = splitkv(line);
		if(ok && key == "theme")
			return value;
	}

	return "";
}

themevalue(state: ref IcState->AppState): string
{
	filetheme: string;

	filetheme = readthemefromstate();
	if(filetheme != "")
		return filetheme;

	if(state != nil && state.cfg != nil && state.cfg.theme != "")
		return state.cfg.theme;

	if(savedtheme != "")
		return savedtheme;

	return DefaultThemeName;
}

save(state: ref IcState->AppState): int
{
	path, text, leftitem, rightitem: string;

	if(state == nil)
		return -1;

	if(!userdir->enabled())
		return 0;

	path = statepath(1);
	if(path == "")
		return 0;

	leftitem = currentitem(state.left);
	rightitem = currentitem(state.right);

	text = "";
	text += "theme=" + themevalue(state) + "\n";
	text += "activepanel=" + panelactivevalue(state) + "\n";

	if(state.left != nil){
		text += "left.path=" + state.left.path + "\n";
		text += "left.item=" + leftitem + "\n";
	}

	if(state.right != nil){
		text += "right.path=" + state.right.path + "\n";
		text += "right.item=" + rightitem + "\n";
	}

	return writefile(path, text);
}