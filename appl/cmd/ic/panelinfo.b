implement IcPanelInfo;

include "ic/panelinfo.m";
include "daytime.m";

IcPanelMod: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	init: fn();
	currentname: fn(p: ref IcPanel->Panel): string;
	currentkind: fn(p: ref IcPanel->Panel): string;
};

sys: Sys;
daytime: Daytime;
panelui: IcPanelMod;

DefaultText: con "";
NameFieldWidth: con 20;
ModeFieldWidth: con 4;
DateFieldWidth: con 17;
NameGap: con 2;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	daytime = load Daytime Daytime->PATH;
	if(daytime == nil)
		raise "fail:load daytime";

	panelui = load IcPanelMod IcPanelMod->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	panelui->init();
}

spaces(n: int): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += " ";

	return s;
}

fittext(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s > w)
		return s[0:w];

	if(len s < w)
		return s + spaces(w - len s);

	return s;
}

ellipsis(): string
{
	return "…";
}

fitmiddle(s: string, w: int): string
{
	left, right, remain, markw: int;
	mark: string;

	if(w <= 0)
		return "";

	if(len s <= w)
		return s;

	mark = ellipsis();
	markw = len mark;
	if(w <= markw)
		return s[0:w];

	remain = w - markw;
	left = remain / 2;
	right = remain - left;

	return s[0:left] + mark + s[len s - right:];
}

padleft(s: string, w: int, ch: string): string
{
	if(w <= 0)
		return "";

	if(ch == "")
		ch = " ";

	while(len s < w)
		s = ch + s;

	if(len s > w)
		s = s[len s - w:];

	return s;
}

trimdirsuffix(name: string): string
{
	if(len name > 1 && name[len name - 1] == '/')
		return name[0:len name - 1];

	return name;
}

normalizepath(path: string): string
{
	if(path == "")
		return ".";

	if(len path > 1 && path[len path - 1] == '/')
		return path[0:len path - 1];

	return path;
}

parentpath(path: string): string
{
	i: int;

	path = normalizepath(path);

	if(path == "/")
		return path;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/'){
			if(i == 0)
				return "/";
			return path[0:i];
		}
	}

	return ".";
}

joinpath(base, name: string): string
{
	base = normalizepath(base);
	name = trimdirsuffix(name);

	if(name == "" || name == ".")
		return base;

	if(name == "..")
		return parentpath(base);

	if(len name > 0 && name[0] == '/')
		return normalizepath(name);

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

modetype(d: Sys->Dir): string
{
	if((d.mode & Sys->DMDIR) != 0)
		return "1";

	return "0";
}

modeperm(d: Sys->Dir): string
{
	return modetype(d) + padleft(sys->sprint("%uo", d.mode & 8r777), 3, "0");
}

z2(v: int): string
{
	if(v < 0)
		v = 0;

	if(v < 10)
		return "0" + string v;

	return string v;
}

datestr(mtime: int): string
{
	tm: ref Daytime->Tm;
	year: int;

	tm = daytime->local(mtime);
	if(tm == nil)
		return "00/00/00 00:00:00";

	year = tm.year + 1900;
	year = year % 100;

	return z2(year)
		+ "/" + z2(tm.mon + 1)
		+ "/" + z2(tm.mday)
		+ " " + z2(tm.hour)
		+ ":" + z2(tm.min)
		+ ":" + z2(tm.sec);
}

compactsize(size: big): string
{
	k, m, g: big;

	if(size < big 1024)
		return sys->sprint("%bdB", size);

	k = size / big 1024;
	if(k < big 1024)
		return sys->sprint("%bdK", k);

	m = k / big 1024;
	if(m < big 1024)
		return sys->sprint("%bdM", m);

	g = m / big 1024;
	return sys->sprint("%bdG", g);
}

filepath(p: ref IcState->PanelState): (string, string)
{
	name, kind, path: string;

	if(p == nil)
		return ("", "");

	path = normalizepath(p.path);

	if(p.panel == nil)
		return (path, path);

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(kind == "parent" || name == "..")
		return (parentpath(path), "..");

	if(name == "")
		return (path, path);

	return (joinpath(path, name), trimdirsuffix(name));
}

current(p: ref IcState->PanelState, width: int): string
{
	path, visible, text, name, mode, date, size: string;
	sizew, minw: int;
	rc: int;
	d: Sys->Dir;

	if(p == nil)
		return fittext(DefaultText, width);

	(path, visible) = filepath(p);
	if(path == "")
		return fittext(DefaultText, width);

	(rc, d) = sys->stat(path);
	if(rc < 0){
		text = fittext(fitmiddle(visible, NameFieldWidth), NameFieldWidth)
			+ spaces(NameGap) + "stat failed";
		return fittext(text, width);
	}

	name = fittext(fitmiddle(visible, NameFieldWidth), NameFieldWidth);
	mode = fittext(modeperm(d), ModeFieldWidth);
	date = fittext(datestr(d.mtime), DateFieldWidth);

	minw = NameFieldWidth + NameGap + ModeFieldWidth + 1 + DateFieldWidth + 1;
	sizew = width - minw;
	if(sizew < 1)
		sizew = 1;

	size = fittext(compactsize(d.length), sizew);

	text = name
		+ spaces(NameGap)
		+ mode
		+ " " + date
		+ " " + size;

	return fittext(text, width);
}