implement IcViewer;

include "ic/viewer.m";
include "ic/viewcommon.m";
include "ic/codepage.m";

IcursesApp: module
{
	PATH: con "/dis/lib/icurses/app.dis";

	ScreenNormal: con 0;
	ScreenAlternate: con 1;

	Options: adt
	{
		screenmode: int;
		mouse: int;
		tickms: int;
	};

	Context: adt
	{
		out: ref Sys->FD;
		ui: ref IcUi->Ui;

		w: int;
		h: int;

		screenmode: int;
		mouse: int;
		tickms: int;

		appscreen: int;
		opened: int;
		started: int;
	};

	init: fn(name: string);
	defaultopts: fn(): Options;
	newctx: fn(out: ref Sys->FD, opts: Options): ref Context;

	open: fn(c: ref Context): int;
	close: fn(c: ref Context);

	ui: fn(c: ref Context): ref IcUi->Ui;
	width: fn(c: ref Context): int;
	height: fn(c: ref Context): int;

	step: fn(c: ref Context): IcUi->Step;
	draw: fn(c: ref Context): int;
	pollresize: fn(c: ref Context, oldw, oldh: int): (int, int, int);
};

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	StepKey: con 1;
	StepTick: con 2;

	init: fn();
	rootid: fn(u: ref IcUi->Ui): int;
	setstatusrows: fn(u: ref IcUi->Ui, helprow, statusrow: int);
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
	textview: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcontent: fn(v: ref IcView->Node, content: string);
	setcode: fn(v: ref IcView->Node, code: string);
	setargs: fn(v: ref IcView->Node, sarg: string, iarg0, iarg1, iarg2: int);
	show: fn(v: ref IcView->Node);
	allocid: fn(t: ref IcView->Tree): int;
};

IcViewGotoMod: module
{
	PATH: con "/dis/ic/viewgoto.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;

	mode: fn(): int;
	input: fn(): string;
};

IcViewSearchMod: module
{
	PATH: con "/dis/ic/viewsearch.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, pattern: string);
	alert: fn(u: ref IcUi->Ui, parentid, w, h: int, text: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	isalert: fn(): int;

	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	options: fn(): IcViewCommon->SearchOptions;
	pattern: fn(): string;
};

IcViewCodepageMod: module
{
	PATH: con "/dis/ic/viewcodepage.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, current: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	selected: fn(): string;
};

IcCodepageMod: module
{
	PATH: con "/dis/ic/codepage.dis";

	init: fn();

	count: fn(): int;
	name: fn(idx: int): string;
	find: fn(enc: string): int;
	defaultname: fn(): string;

	decode: fn(enc: string, buf: array of byte, n: int): string;
};

IcViewSourceMod: module
{
	PATH: con "/dis/ic/viewsource.dis";

	init: fn();

	newsource: fn(path: string): ref IcViewCommon->ViewerSource;
	closefile: fn(s: ref IcViewCommon->ViewerSource);

	ensureindexed: fn(s: ref IcViewCommon->ViewerSource, line: int): int;
	ensureeof: fn(s: ref IcViewCommon->ViewerSource): int;
	ensureoffset: fn(s: ref IcViewCommon->ViewerSource, off: big): int;

	linecount: fn(s: ref IcViewCommon->ViewerSource): int;
	lineforoffset: fn(s: ref IcViewCommon->ViewerSource, off: big): int;

	getline: fn(s: ref IcViewCommon->ViewerSource, line: int): string;

	setencoding: fn(s: ref IcViewCommon->ViewerSource, enc: string);
	encoding: fn(s: ref IcViewCommon->ViewerSource): string;

	wraplines: fn(lines: array of string, width: int): array of string;
	visiblecontent: fn(lines: array of string, top, rows: int): string;
	spaces: fn(n: int): string;
	fittext: fn(s: string, w: int): string;
};

IcViewStatsMod: module
{
	PATH: con "/dis/ic/viewstats.dis";

	init: fn();

	start: fn(path: string, knownbytes: big);
	stop: fn();

	get: fn(): IcViewCommon->ViewerStats;
	cleardirty: fn();
};

IcViewButtonsMod: module
{
	PATH: con "/dis/ic/viewbuttons.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);

	draw: fn(u: ref IcUi->Ui, parentid, bottomid, w, h: int);
	activate: fn(fkey: int);
	handletick: fn(): int;
};

IcViewStatusMod: module
{
	PATH: con "/dis/ic/viewstatus.dis";

	init: fn();

	toptext: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, bodyrows: int): string;
};

IcViewSearchRunMod: module
{
	PATH: con "/dis/ic/viewsearchrun.dis";

	SearchResult: adt
	{
		found: int;
		alert: int;
		alerttext: string;
	};

	init: fn();

	reset: fn();
	lastpattern: fn(): string;

	run: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState,
		opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult;

	searchsarg: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, h: int): string;
};

IcRuntimeTheme: module
{
	PATH: con "/dis/ic/runtheme.dis";

	init: fn();

	loadcfg: fn(): ref IcState->ConfigState;
	loadtheme: fn(): ref IcState->ThemeState;
};

sys: Sys;
appfw: IcursesApp;
ui: IcUiMod;
view: IcViewMod;
gotomod: IcViewGotoMod;
viewsearch: IcViewSearchMod;
viewcodepage: IcViewCodepageMod;
codepagemod: IcCodepageMod;
srcmod: IcViewSourceMod;
statsmod: IcViewStatsMod;
viewbuttons: IcViewButtonsMod;
viewstatus: IcViewStatusMod;
viewsearchrun: IcViewSearchRunMod;
runtheme: IcRuntimeTheme;

source: ref IcViewCommon->ViewerSource;

theme: ref IcState->ThemeState;
viewerbodyrows: int;

DefaultTopCode: con "1;38;2;20;25;30;48;2;225;225;225";
DefaultBodyCode: con "38;2;220;230;255;48;2;20;45;90";
DefaultErrorCode: con "1;38;2;255;120;120;48;2;20;45;90";

InitialPrefetchScreens: con 6;
ScrollPrefetchScreens: con 8;

Kesc: con 27;
Kq: con int 'q';
Kn: con int 'n';
Kp: con int 'p';
Ks: con int 's';

Kup: con 57362;
Kdown: con 57363;
Kpgup: con 57366;
Kpgdown: con 57367;
Khome: con 57360;
Kend: con 57361;
Kf1: con 57409;
Kf2: con 57410;
Kf3: con 57411;
Kf4: con 57412;
Kf5: con 57413;
Kf6: con 57414;
Kf7: con 57415;
Kf8: con 57416;
Kf9: con 57417;
Kf10: con 57418;

Kshiftf7: con 57463;
Kaltf7: con 57479;
Kctrlf7: con 57511;

newsource: fn(path: string): ref IcViewCommon->ViewerSource;
closefile: fn(s: ref IcViewCommon->ViewerSource);
ensuresource: fn(v: ref IcState->ViewerState, rows: int);
prefetch: fn(v: ref IcState->ViewerState, rows: int): int;
refreshwindow: fn(v: ref IcState->ViewerState, rows: int);

appendline: fn(a: array of string, s: string): array of string;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
bodyh: fn(h: int): int;
bodyid: fn(v: ref IcState->ViewerState): int;

topcode: fn(): string;
bodycode: fn(): string;
errorcode: fn(): string;
applytheme: fn(t: ref IcState->ThemeState);

clampview: fn(v: ref IcState->ViewerState, h: int);
ensureids: fn(u: ref IcUi->Ui, v: ref IcState->ViewerState);
setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
setbody: fn(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, v: ref IcState->ViewerState, content, code: string);
drawviewer: fn(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int);

iserrorline: fn(s: string): int;

parsebigdec: fn(s: string): (big, int);
parsebighex: fn(s: string): (big, int);
applygoto: fn(v: ref IcState->ViewerState): int;

showsearchalert: fn(state: ref IcState->AppState, text: string);
runsearch: fn(state: ref IcState->AppState, direction: int, fromcurrent: int): int;

rewrap: fn(v: ref IcState->ViewerState, w: int);
applyencoding: fn(state: ref IcState->AppState, v: ref IcState->ViewerState, enc: string);

closeviewer: fn(state: ref IcState->AppState, fkey: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	appfw = load IcursesApp IcursesApp->PATH;
	if(appfw == nil)
		raise "fail:load icurses/app";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	gotomod = load IcViewGotoMod IcViewGotoMod->PATH;
	if(gotomod == nil)
		raise "fail:load ic/viewgoto";

	viewsearch = load IcViewSearchMod IcViewSearchMod->PATH;
	if(viewsearch == nil)
		raise "fail:load ic/viewsearch";

	viewcodepage = load IcViewCodepageMod IcViewCodepageMod->PATH;
	if(viewcodepage == nil)
		raise "fail:load ic/viewcodepage";

	codepagemod = load IcCodepageMod IcCodepageMod->PATH;
	if(codepagemod == nil)
		raise "fail:load ic/codepage";

	srcmod = load IcViewSourceMod IcViewSourceMod->PATH;
	if(srcmod == nil)
		raise "fail:load ic/viewsource";

	statsmod = load IcViewStatsMod IcViewStatsMod->PATH;
	if(statsmod == nil)
		raise "fail:load ic/viewstats";

	viewbuttons = load IcViewButtonsMod IcViewButtonsMod->PATH;
	if(viewbuttons == nil)
		raise "fail:load ic/viewbuttons";

	viewstatus = load IcViewStatusMod IcViewStatusMod->PATH;
	if(viewstatus == nil)
		raise "fail:load ic/viewstatus";

	viewsearchrun = load IcViewSearchRunMod IcViewSearchRunMod->PATH;
	if(viewsearchrun == nil)
		raise "fail:load ic/viewsearchrun";

	runtheme = load IcRuntimeTheme IcRuntimeTheme->PATH;
	if(runtheme == nil)
		raise "fail:load ic/runtheme";

	appfw->init("icview");
	ui->init();
	view->init();
	gotomod->init();
	viewsearch->init();
	viewcodepage->init();
	codepagemod->init();
	srcmod->init();
	statsmod->init();
	viewbuttons->init();
	viewstatus->init();
	viewsearchrun->init();
	runtheme->init();

	source = nil;
	theme = runtheme->loadtheme();
	viewbuttons->settheme(theme);

	viewerbodyrows = 1;
}

topcode(): string
{
	if(theme != nil && theme.paneltopcode != "")
		return theme.paneltopcode;

	return DefaultTopCode;
}

bodycode(): string
{
	if(theme != nil && theme.panelbodycode != "")
		return theme.panelbodycode;

	return DefaultBodyCode;
}

errorcode(): string
{
	if(theme != nil && theme.panelmarkedcode != "")
		return theme.panelmarkedcode;

	return DefaultErrorCode;
}

applytheme(t: ref IcState->ThemeState)
{
	if(t != nil)
		theme = t;

	viewbuttons->settheme(theme);
}

newstate(): ref IcState->ViewerState
{
	v: ref IcState->ViewerState;

	v = ref IcState->ViewerState;
	v.active = 0;
	v.mode = ModeText;
	v.path = "";
	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.topline = 0;
	v.nlines = 0;
	v.topid = -1;
	v.bottomid = -1;
	v.bodyids = array[0] of int;
	v.lastw = 0;
	v.encoding = codepagemod->defaultname();

	return v;
}

runfile(path: string): int
{
	return runfilemode(path, ModeText);
}

newsource(path: string): ref IcViewCommon->ViewerSource
{
	return srcmod->newsource(path);
}

closefile(s: ref IcViewCommon->ViewerSource)
{
	srcmod->closefile(s);
}

ensuresource(v: ref IcState->ViewerState, rows: int)
{
	if(v == nil)
		return;

	if(v.path == "")
		return;

	if(rows < 1)
		rows = 1;

	if(source != nil && source.path == v.path){
		srcmod->setencoding(source, v.encoding);
		return;
	}

	closefile(source);
	source = newsource(v.path);
	if(source != nil)
		srcmod->setencoding(source, v.encoding);

	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.lastw = 0;

	srcmod->ensureindexed(source, InitialPrefetchScreens * rows + 1);
	v.nlines = srcmod->linecount(source);

	if(source != nil)
		statsmod->start(v.path, source.length);
	else
		statsmod->start(v.path, big 0);
}

prefetch(v: ref IcState->ViewerState, rows: int): int
{
	target, before: int;

	if(v == nil || source == nil)
		return 0;

	if(rows < 1)
		rows = 1;

	before = source.noffsets;
	target = v.topline + rows * ScrollPrefetchScreens;
	srcmod->ensureindexed(source, target);

	v.nlines = srcmod->linecount(source);

	return source.noffsets != before;
}

appendline(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

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

refreshwindow(v: ref IcState->ViewerState, rows: int)
{
	i, need, idx: int;
	lines: array of string;

	if(v == nil)
		return;

	if(source == nil){
		v.lines = array[0] of string;
		v.wrapped = array[0] of string;
		v.nlines = 0;
		v.lastw = 0;
		return;
	}

	if(rows < 1)
		rows = 1;

	prefetch(v, rows);

	need = rows * 2;
	if(need < rows)
		need = rows;

	lines = array[0] of string;
	for(i = 0; i < need; i++){
		idx = v.topline + i;
		if(source.eof && idx >= srcmod->linecount(source))
			break;

		if(!srcmod->ensureindexed(source, idx))
			break;

		lines = appendline(lines, srcmod->getline(source, idx));
	}

	if(len lines == 0)
		lines = appendline(lines, "");

	v.lines = lines;
	v.wrapped = array[0] of string;
	v.nlines = srcmod->linecount(source);
	v.lastw = 0;
}

spaces(n: int): string
{
	return srcmod->spaces(n);
}

fittext(s: string, w: int): string
{
	return srcmod->fittext(s, w);
}

bodyh(h: int): int
{
	n: int;

	n = h - 2;
	if(n < 1)
		n = 1;

	return n;
}

bodyid(v: ref IcState->ViewerState): int
{
	if(v == nil)
		return -1;

	if(v.bodyids == nil || len v.bodyids == 0)
		return -1;

	return v.bodyids[0];
}

clampview(v: ref IcState->ViewerState, h: int)
{
	rows, max: int;

	if(v == nil)
		return;

	rows = bodyh(h);

	ensuresource(v, rows);

	if(source != nil){
		prefetch(v, rows);

		if(source.eof){
			max = srcmod->linecount(source) - 1;
			if(max < 0)
				max = 0;
			if(v.topline > max)
				v.topline = max;
		}else{
			if(v.topline < 0)
				v.topline = 0;
		}

		v.nlines = srcmod->linecount(source);
	}else{
		max = v.nlines - 1;
		if(max < 0)
			max = 0;
		if(v.topline > max)
			v.topline = max;
	}

	if(v.topline < 0)
		v.topline = 0;
}

ensureids(u: ref IcUi->Ui, v: ref IcState->ViewerState)
{
	if(u == nil || u.tree == nil || v == nil)
		return;

	if(v.topid <= 0)
		v.topid = view->allocid(u.tree);

	if(v.bottomid <= 0)
		v.bottomid = view->allocid(u.tree);

	if(v.bodyids == nil || len v.bodyids == 0)
		v.bodyids = array[] of { view->allocid(u.tree) };
}

setlabel(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(view->find(u.tree, id) == nil)
		ui->label(u, parentid, id, x, y, w, text);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

setbody(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, v: ref IcState->ViewerState, content, code: string)
{
	n: ref IcView->Node;
	sarg: string;

	if(u == nil || u.tree == nil)
		return;

	if(view->find(u.tree, id) == nil)
		ui->textview(u, parentid, id, x, y, w, h);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	sarg = viewsearchrun->searchsarg(source, v, h);

	view->setbounds(n, x, y, w, h);
	view->setcontent(n, content);
	view->setcode(n, code);
	view->setargs(n, sarg, 0, 0, 0);
	view->show(n);
}

iserrorline(s: string): int
{
	if(len s >= 17 && s[0:17] == "Cannot open file")
		return 1;

	if(len s >= 17 && s[0:17] == "Cannot read file")
		return 1;

	return 0;
}

drawviewer(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int)
{
	rows, id: int;
	code, content: string;

	if(u == nil || v == nil)
		return;

	rows = bodyh(h);
	viewerbodyrows = rows;

	ensureids(u, v);
	ensuresource(v, rows);

	clampview(v, h);
	refreshwindow(v, rows);

	v.wrapped = v.lines;
	v.lastw = w;

	ui->setstatusrows(u, -1, -1);

	setlabel(u, parentid, v.topid, 0, 0, w, viewstatus->toptext(source, v, viewerbodyrows), topcode());

	code = bodycode();
	if(source != nil && source.error != "")
		code = errorcode();
	if(v.lines != nil && len v.lines > 0 && iserrorline(v.lines[0]))
		code = errorcode();

	id = bodyid(v);
	if(id >= 0){
		content = srcmod->visiblecontent(v.lines, 0, rows);
		setbody(u, parentid, id, 0, 1, w, rows, v, content, code);
	}

	viewbuttons->settheme(theme);
	viewbuttons->draw(u, parentid, v.bottomid, w, h);

	if(gotomod != nil && gotomod->active())
		gotomod->draw(u, parentid, w, h);

	if(viewsearch != nil && viewsearch->active())
		viewsearch->draw(u, parentid, w, h);

	if(viewcodepage != nil && viewcodepage->active())
		viewcodepage->draw(u, parentid, w, h);
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.viewer != nil && state.viewer.active;
}

start(state: ref IcState->AppState, path: string, mode: int): int
{
	if(state == nil || path == "")
		return -1;

	if(state.theme != nil)
		applytheme(state.theme);

	closefile(source);
	source = newsource(path);

	if(state.viewer == nil)
		state.viewer = newstate();

	state.viewer.active = 1;
	state.viewer.mode = mode;
	state.viewer.path = path;
	state.viewer.lines = array[0] of string;
	state.viewer.wrapped = array[0] of string;
	state.viewer.topline = 0;
	state.viewer.lastw = 0;
	if(state.viewer.encoding == "")
		state.viewer.encoding = codepagemod->defaultname();

	viewsearchrun->reset();

	if(source != nil)
		srcmod->setencoding(source, state.viewer.encoding);

	if(source.error != "")
		state.viewer.lines = array[] of { source.error };

	srcmod->ensureindexed(source, InitialPrefetchScreens * bodyh(state.height) + 1);
	state.viewer.nlines = srcmod->linecount(source);

	statsmod->start(path, source.length);

	return 0;
}

build(state: ref IcState->AppState, parentid, w, h: int): int
{
	if(state == nil || state.ui == nil || state.viewer == nil || !state.viewer.active)
		return -1;

	if(state.theme != nil)
		applytheme(state.theme);

	drawviewer(state.ui, parentid, state.viewer, w, h);
	return 0;
}

parsebigdec(s: string): (big, int)
{
	i, ok, c: int;
	v: big;

	v = big 0;
	ok = 0;

	for(i = 0; i < len s; i++){
		c = s[i];
		if(c < '0' || c > '9')
			return (v, 0);

		v = v * big 10 + big (c - '0');
		ok = 1;
	}

	return (v, ok);
}

parsebighex(s: string): (big, int)
{
	i, ok, c, d: int;
	v: big;

	v = big 0;
	ok = 0;

	for(i = 0; i < len s; i++){
		c = s[i];
		d = -1;

		if(c >= '0' && c <= '9')
			d = c - '0';
		else if(c >= 'a' && c <= 'f')
			d = c - 'a' + 10;
		else if(c >= 'A' && c <= 'F')
			d = c - 'A' + 10;

		if(d < 0)
			return (v, 0);

		v = v * big 16 + big d;
		ok = 1;
	}

	return (v, ok);
}

applygoto(v: ref IcState->ViewerState): int
{
	s: string;
	value, off: big;
	ok, mode, target, maxline: int;
	st: IcViewCommon->ViewerStats;

	if(v == nil || source == nil)
		return 0;

	s = gotomod->input();
	mode = gotomod->mode();

	if(mode == IcViewCommon->GotoOffsetHex)
		(value, ok) = parsebighex(s);
	else
		(value, ok) = parsebigdec(s);

	if(!ok)
		return 0;

	case mode {
	IcViewCommon->GotoLine =>
		target = int value - 1;
		if(target < 0)
			target = 0;
		srcmod->ensureindexed(source, target);
		v.topline = target;

	IcViewCommon->GotoPercent =>
		if(value < big 0)
			value = big 0;
		if(value > big 100)
			value = big 100;

		if(source.length > big 0){
			off = (source.length * value) / big 100;
			target = srcmod->lineforoffset(source, off);
			v.topline = target;
		}else{
			st = statsmod->get();
			if(st.ready && st.lines > big 0){
				target = int ((st.lines * value) / big 100);
				if(target < 0)
					target = 0;
				srcmod->ensureindexed(source, target);
				v.topline = target;
			}
		}

	IcViewCommon->GotoOffsetDec or IcViewCommon->GotoOffsetHex =>
		if(value < big 0)
			value = big 0;
		if(source.length > big 0 && value > source.length)
			value = source.length;

		target = srcmod->lineforoffset(source, value);
		v.topline = target;
	}

	if(source.eof){
		maxline = srcmod->linecount(source) - viewerbodyrows;
		if(maxline < 0)
			maxline = 0;
		if(v.topline > maxline)
			v.topline = maxline;
	}

	if(v.topline < 0)
		v.topline = 0;

	v.lastw = 0;
	return 1;
}

showsearchalert(state: ref IcState->AppState, text: string)
{
	if(state == nil || state.ui == nil)
		return;

	viewsearch->alert(state.ui, state.toolid, state.width, state.height, text);
	build(state, state.toolid, state.width, state.height);
}

runsearch(state: ref IcState->AppState, direction: int, fromcurrent: int): int
{
	v: ref IcState->ViewerState;
	opts: IcViewCommon->SearchOptions;
	r: IcViewSearchRunMod->SearchResult;

	if(state == nil || state.viewer == nil || source == nil)
		return 0;

	v = state.viewer;
	opts = viewsearch->options();
	opts.encoding = v.encoding;

	r = viewsearchrun->run(source, v, opts, direction, fromcurrent);

	if(r.alert){
		showsearchalert(state, r.alerttext);
		return 1;
	}

	if(r.found){
		clampview(v, state.height);
		build(state, state.toolid, state.width, state.height);
		return 1;
	}

	return 0;
}

applyencoding(state: ref IcState->AppState, v: ref IcState->ViewerState, enc: string)
{
	if(v == nil || enc == "")
		return;

	if(codepagemod->find(enc) < 0)
		return;

	if(v.encoding == enc)
		return;

	v.encoding = enc;

	if(source != nil)
		srcmod->setencoding(source, enc);

	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.lastw = 0;

	viewsearchrun->reset();

	clampview(v, state.height);
	refreshwindow(v, bodyh(state.height));
	build(state, state.toolid, state.width, state.height);
}

closeviewer(state: ref IcState->AppState, fkey: int): int
{
	v: ref IcState->ViewerState;

	if(state == nil || state.viewer == nil)
		return 2;

	v = state.viewer;

	viewbuttons->activate(fkey);
	v.active = 0;
	closefile(source);
	source = nil;

	if(statsmod != nil)
		statsmod->stop();
	if(gotomod != nil)
		gotomod->close(state.ui);
	if(viewsearch != nil)
		viewsearch->close(state.ui);
	if(viewcodepage != nil)
		viewcodepage->close(state.ui);

	viewsearchrun->reset();
	return 2;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	v: ref IcState->ViewerState;
	rows, r, gr: int;
	enc, lastpattern: string;

	if(state == nil || state.viewer == nil || !state.viewer.active)
		return 0;

	if(state.theme != nil)
		applytheme(state.theme);

	v = state.viewer;
	rows = bodyh(state.height);

	if(viewcodepage != nil && viewcodepage->active()){
		gr = viewcodepage->handlekey(state.ui, state.toolid, state.width, state.height, k);

		if(gr == 2){
			viewcodepage->close(state.ui);
			build(state, state.toolid, state.width, state.height);
			return 1;
		}

		if(gr == 1){
			enc = viewcodepage->selected();
			viewcodepage->close(state.ui);
			applyencoding(state, v, enc);
			return 1;
		}

		build(state, state.toolid, state.width, state.height);
		return 1;
	}

	if(gotomod != nil && gotomod->active()){
		gr = gotomod->handlekey(state.ui, state.toolid, state.width, state.height, k);

		if(gr == IcViewCommon->GotoCancel){
			gotomod->close(state.ui);
			build(state, state.toolid, state.width, state.height);
			return 1;
		}

		if(gr == IcViewCommon->GotoOk){
			applygoto(v);
			gotomod->close(state.ui);
			clampview(v, state.height);
			build(state, state.toolid, state.width, state.height);
			return 1;
		}

		build(state, state.toolid, state.width, state.height);
		return 1;
	}

	if(viewsearch != nil && viewsearch->active()){
		gr = viewsearch->handlekey(state.ui, state.toolid, state.width, state.height, k);

		if(gr == IcViewCommon->SearchCancel || gr == IcViewCommon->SearchAlertClosed){
			viewsearch->close(state.ui);
			build(state, state.toolid, state.width, state.height);
			return 1;
		}

		if(gr == IcViewCommon->SearchForward){
			viewsearch->close(state.ui);
			runsearch(state, IcViewCommon->SearchDirForward, 0);
			return 1;
		}

		if(gr == IcViewCommon->SearchBackward){
			viewsearch->close(state.ui);
			runsearch(state, IcViewCommon->SearchDirBackward, 0);
			return 1;
		}

		build(state, state.toolid, state.width, state.height);
		return 1;
	}

	r = 1;

	case k {
	Kq or Kesc =>
		return closeviewer(state, 10);

	Kf3 =>
		return closeviewer(state, 3);

	Kf5 =>
		viewbuttons->activate(5);
		if(gotomod != nil)
			gotomod->open(state.ui, state.toolid, state.width, state.height);

	Kf7 or Ks =>
		viewbuttons->activate(7);
		if(viewsearch != nil)
			viewsearch->open(state.ui, state.toolid, state.width, state.height, viewsearchrun->lastpattern());

	Kshiftf7 or Kn =>
		viewbuttons->activate(7);
		lastpattern = viewsearchrun->lastpattern();
		if(lastpattern == ""){
			if(viewsearch != nil)
				viewsearch->open(state.ui, state.toolid, state.width, state.height, lastpattern);
		}else
			runsearch(state, IcViewCommon->SearchDirForward, 1);

	Kctrlf7 or Kaltf7 or Kp =>
		viewbuttons->activate(7);
		lastpattern = viewsearchrun->lastpattern();
		if(lastpattern == ""){
			if(viewsearch != nil)
				viewsearch->open(state.ui, state.toolid, state.width, state.height, lastpattern);
		}else
			runsearch(state, IcViewCommon->SearchDirBackward, 1);

	Kf8 =>
		viewbuttons->activate(8);
		if(viewcodepage != nil)
			viewcodepage->open(state.ui, state.toolid, state.width, state.height, v.encoding);

	Kf10 =>
		return closeviewer(state, 10);

	Kf1 or Kf2 or Kf4 or Kf6 or Kf9 =>
		r = 0;

	Kup =>
		v.topline--;

	Kdown =>
		v.topline++;
		if(source != nil)
			srcmod->ensureindexed(source, v.topline + rows * ScrollPrefetchScreens);

	Kpgup =>
		v.topline -= rows;

	Kpgdown =>
		v.topline += rows;
		if(source != nil)
			srcmod->ensureindexed(source, v.topline + rows * ScrollPrefetchScreens);

	Khome =>
		v.topline = 0;

	Kend =>
		if(source != nil){
			srcmod->ensureeof(source);
			v.nlines = srcmod->linecount(source);
			v.topline = v.nlines - rows;
		}else
			v.topline = v.nlines - rows;

	* =>
		r = 0;
	}

	if(r == 0)
		return 0;

	clampview(v, state.height);
	build(state, state.toolid, state.width, state.height);

	return 1;
}

handletick(state: ref IcState->AppState): int
{
	changed: int;
	st: IcViewCommon->ViewerStats;

	if(state == nil || state.viewer == nil || !state.viewer.active)
		return 0;

	if(state.theme != nil)
		applytheme(state.theme);

	changed = 0;

	if(viewbuttons->handletick())
		changed = 1;

	if(gotomod != nil && gotomod->handletick(state.ui, state.toolid, state.width, state.height))
		changed = 1;

	if(viewsearch != nil && viewsearch->handletick(state.ui, state.toolid, state.width, state.height))
		changed = 1;

	if(viewcodepage != nil && viewcodepage->handletick(state.ui, state.toolid, state.width, state.height))
		changed = 1;

	if(statsmod != nil){
		st = statsmod->get();
		if(st.dirty){
			statsmod->cleardirty();
			changed = 1;
		}
	}

	if(changed)
		build(state, state.toolid, state.width, state.height);

	return changed;
}

runfilemode(path: string, mode: int): int
{
	ctx: ref IcursesApp->Context;
	opts: IcursesApp->Options;
	step: IcUi->Step;
	u: ref IcUi->Ui;
	st: ref IcState->AppState;
	v: ref IcState->ViewerState;
	nw, nh, resized: int;
	running, r, changed: int;

	closefile(source);
	source = newsource(path);

	theme = runtheme->loadtheme();
	viewbuttons->settheme(theme);

	v = newstate();
	v.path = path;
	v.mode = mode;
	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.topline = 0;
	v.lastw = 0;

	viewsearchrun->reset();

	if(source != nil)
		srcmod->setencoding(source, v.encoding);

	if(source.error != "")
		v.lines = array[] of { source.error };

	opts = appfw->defaultopts();
	opts.screenmode = IcursesApp->ScreenAlternate;
	opts.mouse = 0;
	opts.tickms = 200;

	ctx = appfw->newctx(sys->fildes(1), opts);
	if(ctx == nil)
		return -1;

	if(appfw->open(ctx) < 0)
		return -1;

	u = appfw->ui(ctx);
	if(u == nil){
		appfw->close(ctx);
		return -1;
	}

	st = ref IcState->AppState;
	st.ui = u;
	st.rootid = ui->rootid(u);
	st.toolid = st.rootid;
	st.width = appfw->width(ctx);
	st.height = appfw->height(ctx);
	st.viewer = v;
	st.theme = theme;

	v.active = 1;

	srcmod->ensureindexed(source, InitialPrefetchScreens * bodyh(st.height) + 1);
	v.nlines = srcmod->linecount(source);

	statsmod->start(path, source.length);

	build(st, st.rootid, st.width, st.height);
	appfw->draw(ctx);

	running = 1;
	while(running){
		step = appfw->step(ctx);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			r = handlekey(st, step.key);
			if(r == 2)
				running = 0;
			else if(r != 0)
				appfw->draw(ctx);
		}

		if(step.kind == IcUi->StepTick){
			changed = prefetch(v, bodyh(st.height));

			if(handletick(st))
				changed = 1;

			(nw, nh, resized) = appfw->pollresize(ctx, st.width, st.height);
			if(resized){
				st.width = nw;
				st.height = nh;
				v.lastw = 0;
				build(st, st.rootid, st.width, st.height);
				appfw->draw(ctx);
			}else if(changed){
				build(st, st.rootid, st.width, st.height);
				appfw->draw(ctx);
			}
		}
	}

	closefile(source);
	source = nil;

	if(statsmod != nil)
		statsmod->stop();

	if(gotomod != nil)
		gotomod->close(u);

	if(viewsearch != nil)
		viewsearch->close(u);

	if(viewcodepage != nil)
		viewcodepage->close(u);

	viewsearchrun->reset();

	appfw->close(ctx);
	return 0;
}

rewrap(v: ref IcState->ViewerState, w: int)
{
	if(v == nil)
		return;

	if(w < 1)
		w = 1;

	if(v.lastw == w && v.wrapped != nil && len v.wrapped > 0)
		return;

	v.wrapped = srcmod->wraplines(v.lines, w);
	v.lastw = w;
}