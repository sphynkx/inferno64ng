implement IcRunCmd;

include "draw.m";
include "ic/runcmd.m";

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();
	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
};

Sh: module
{
	PATH: con "/dis/sh.dis";

	initialise: fn();
	init: fn(ctxt: ref Draw->Context, argv: list of string);
	system: fn(drawctxt: ref Draw->Context, cmd: string): string;
	run: fn(drawctxt: ref Draw->Context, argv: list of string): string;
};

panelui: IcPanelMod;
sh: Sh;

activepanel: fn(state: ref IcState->AppState): ref IcState->PanelState;
trimdirsuffix: fn(name: string): string;
joinpath: fn(base, name: string): string;
appendstr: fn(a: array of string, s: string): array of string;
quoted: fn(s: string): string;
joinquoted: fn(a: array of string): string;
currentfilepath: fn(p: ref IcState->PanelState): string;
selectedfiles: fn(p: ref IcState->PanelState): array of string;
selectednames: fn(p: ref IcState->PanelState): array of string;
replaceall: fn(s, old, new: string): string;

init()
{
	panelui = load IcPanelMod IcPanelMod->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	sh = load Sh Sh->PATH;
	if(sh == nil)
		raise "fail:load sh";

	panelui->init();
	sh->initialise();
}

activepanel(state: ref IcState->AppState): ref IcState->PanelState
{
	if(state == nil)
		return nil;

	if(state.activepanel == IcState->PanelLeft)
		return state.left;

	return state.right;
}

trimdirsuffix(name: string): string
{
	if(len name > 1 && name[len name - 1] == '/')
		return name[0:len name - 1];

	return name;
}

joinpath(base, name: string): string
{
	name = trimdirsuffix(name);

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
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

quoted(s: string): string
{
	i: int;
	out: string;

	out = "'";
	for(i = 0; i < len s; i++){
		if(s[i] == '\'')
			out += "''";
		else
			out += s[i:i+1];
	}
	out += "'";

	return out;
}

joinquoted(a: array of string): string
{
	i: int;
	out: string;

	if(a == nil || len a == 0)
		return "";

	out = "";
	for(i = 0; i < len a; i++){
		if(i > 0)
			out += " ";
		out += quoted(a[i]);
	}

	return out;
}

currentfilepath(p: ref IcState->PanelState): string
{
	name, kind: string;

	if(p == nil || p.panel == nil)
		return "";

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(name == "..")
		kind = "parent";

	if(kind != "file")
		return "";

	return joinpath(p.path, name);
}

selectedfiles(p: ref IcState->PanelState): array of string
{
	a: array of string;
	i: int;
	cur: string;

	a = array[0] of string;

	if(p != nil && p.selected != nil){
		for(i = 0; i < len p.selected; i++){
			if(p.selected[i].kind == "file")
				a = appendstr(a, p.selected[i].path);
		}
	}

	if(a == nil || len a == 0){
		cur = currentfilepath(p);
		if(cur != "")
			a = appendstr(a, cur);
	}

	return a;
}

selectednames(p: ref IcState->PanelState): array of string
{
	a: array of string;
	i: int;
	name, kind: string;

	a = array[0] of string;

	if(p != nil && p.selected != nil){
		for(i = 0; i < len p.selected; i++){
			if(p.selected[i].kind == "file")
				a = appendstr(a, p.selected[i].name);
		}
	}

	if(a == nil || len a == 0){
		if(p != nil && p.panel != nil){
			name = panelui->currentname(p.panel);
			kind = panelui->currentkind(p.panel);

			if(name == "..")
				kind = "parent";

			if(kind == "file")
				a = appendstr(a, trimdirsuffix(name));
		}
	}

	return a;
}

replaceall(s, old, new: string): string
{
	i, n: int;
	out: string;

	if(old == "")
		return s;

	out = "";
	n = len old;
	i = 0;

	while(i < len s){
		if(i + n <= len s && s[i:i+n] == old){
			out += new;
			i += n;
		}else{
			out += s[i:i+1];
			i++;
		}
	}

	return out;
}

buildcommand(state: ref IcState->AppState, template: string): string
{
	p: ref IcState->PanelState;
	dir, file, name: string;
	files, names: array of string;
	cmd: string;

	p = activepanel(state);
	if(p == nil)
		return "";

	dir = "";
	if(p != nil)
		dir = p.path;

	file = currentfilepath(p);
	name = "";
	if(file != "" && p != nil && p.panel != nil)
		name = trimdirsuffix(panelui->currentname(p.panel));

	files = selectedfiles(p);
	names = selectednames(p);

	cmd = template;
	cmd = replaceall(cmd, "{dir}", quoted(dir));
	cmd = replaceall(cmd, "{file}", quoted(file));
	cmd = replaceall(cmd, "{name}", quoted(name));
	cmd = replaceall(cmd, "{files}", joinquoted(files));
	cmd = replaceall(cmd, "{names}", joinquoted(names));

	return cmd;
}

runtemplate(state: ref IcState->AppState, template: string): int
{
	p: ref IcState->PanelState;
	dir, cmd, err, fullcmd: string;

	if(state == nil || template == "")
		return -1;

	p = activepanel(state);
	if(p == nil)
		return -1;

	dir = p.path;
	if(dir == "")
		dir = ".";

	cmd = buildcommand(state, template);
	if(cmd == "")
		return -1;

	if(cmd == template)
		fullcmd = cmd;
	else
		fullcmd = "cd " + quoted(dir) + " ; " + cmd;

	err = sh->system(nil, "esh -c " + quoted(fullcmd));
	if(err != nil && err != "")
		return -1;

	return 0;
}