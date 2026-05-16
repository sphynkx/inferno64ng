implement IcViewer;

include "ic/viewer.m";

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
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
	allocid: fn(t: ref IcView->Tree): int;
};

sys: Sys;
appfw: IcursesApp;
ui: IcUiMod;
view: IcViewMod;

TopCode: con "1;38;2;20;25;30;48;2;225;225;225";
BodyCode: con "38;2;220;230;255;48;2;20;45;90";
BottomCode: con "1;38;2;20;25;30;48;2;170;225;255";

Kesc: con 27;
Kq: con int 'q';

Kup: con 57362;
Kdown: con 57363;
Kpgup: con 57366;
Kpgdown: con 57367;
Khome: con 57360;
Kend: con 57361;
Kf10: con 57418;

loadlines: fn(path: string): array of string;
splitlines: fn(text: string): array of string;
appendline: fn(a: array of string, s: string): array of string;
wraplines: fn(lines: array of string, width: int): array of string;
wrapline: fn(line: string, width: int): array of string;
appendarray: fn(dst, src: array of string): array of string;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
bodyh: fn(h: int): int;

rewrap: fn(v: ref IcState->ViewerState, w: int);
clampview: fn(v: ref IcState->ViewerState, h: int);
ensureids: fn(u: ref IcUi->Ui, v: ref IcState->ViewerState, rows: int);
setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
drawviewer: fn(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int);

toptext: fn(v: ref IcState->ViewerState): string;
bottomtext: fn(w: int): string;

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

	appfw->init("icview");
	ui->init();
	view->init();
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

	return v;
}

runfile(path: string): int
{
	return runfilemode(path, ModeText);
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

appendarray(dst, src: array of string): array of string
{
	i: int;

	if(src == nil)
		return dst;

	for(i = 0; i < len src; i++)
		dst = appendline(dst, src[i]);

	return dst;
}

splitlines(text: string): array of string
{
	lines: array of string;
	i, start: int;
	line: string;

	lines = array[0] of string;
	start = 0;

	for(i = 0; i < len text; i++){
		if(text[i] == '\n'){
			line = text[start:i];
			if(len line > 0 && line[len line - 1] == '\r')
				line = line[0:len line - 1];
			lines = appendline(lines, line);
			start = i + 1;
		}
	}

	if(start < len text){
		line = text[start:];
		if(len line > 0 && line[len line - 1] == '\r')
			line = line[0:len line - 1];
		lines = appendline(lines, line);
	}

	if(lines == nil || len lines == 0)
		lines = appendline(lines, "");

	return lines;
}

loadlines(path: string): array of string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	text: string;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return nil;

	buf = array[Sys->ATOMICIO] of byte;
	text = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n < 0)
			return nil;
		if(n == 0)
			break;

		text += string buf[0:n];
	}

	return splitlines(text);
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

wrapline(line: string, width: int): array of string
{
	out: array of string;
	current, word: string;
	i, start, cut: int;

	if(width < 1)
		width = 1;

	out = array[0] of string;
	current = "";

	for(i = 0; i < len line; i++){
		if(line[i] == ' ' || line[i] == '\t' || line[i] == '\r')
			continue;

		start = i;
		while(i < len line && line[i] != ' ' && line[i] != '\t' && line[i] != '\r')
			i++;

		word = line[start:i];
		i--;

		if(len word > width){
			if(current != ""){
				out = appendline(out, current);
				current = "";
			}

			start = 0;
			while(start < len word){
				cut = start + width;
				if(cut > len word)
					cut = len word;
				out = appendline(out, word[start:cut]);
				start = cut;
			}

			continue;
		}

		if(current == "")
			current = word;
		else if(len current + 1 + len word <= width)
			current += " " + word;
		else{
			out = appendline(out, current);
			current = word;
		}
	}

	if(current != "")
		out = appendline(out, current);

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

wraplines(lines: array of string, width: int): array of string
{
	out: array of string;
	i: int;

	out = array[0] of string;

	if(lines == nil)
		return appendline(out, "");

	for(i = 0; i < len lines; i++)
		out = appendarray(out, wrapline(lines[i], width));

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

bodyh(h: int): int
{
	n: int;

	n = h - 2;
	if(n < 1)
		n = 1;

	return n;
}

rewrap(v: ref IcState->ViewerState, w: int)
{
	if(v == nil)
		return;

	if(w < 1)
		w = 1;

	if(v.lastw == w && v.wrapped != nil && len v.wrapped > 0)
		return;

	v.wrapped = wraplines(v.lines, w);
	v.nlines = len v.wrapped;
	v.lastw = w;
}

clampview(v: ref IcState->ViewerState, h: int)
{
	max: int;

	if(v == nil)
		return;

	max = v.nlines - bodyh(h);
	if(max < 0)
		max = 0;

	if(v.topline < 0)
		v.topline = 0;
	if(v.topline > max)
		v.topline = max;
}

ensureids(u: ref IcUi->Ui, v: ref IcState->ViewerState, rows: int)
{
	i: int;
	body: array of int;

	if(u == nil || u.tree == nil || v == nil)
		return;

	if(v.topid <= 0)
		v.topid = view->allocid(u.tree);

	if(v.bottomid <= 0)
		v.bottomid = view->allocid(u.tree);

	if(v.bodyids != nil && len v.bodyids == rows)
		return;

	body = array[rows] of int;
	for(i = 0; i < rows; i++){
		if(v.bodyids != nil && i < len v.bodyids && v.bodyids[i] > 0)
			body[i] = v.bodyids[i];
		else
			body[i] = view->allocid(u.tree);
	}

	v.bodyids = body;
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

toptext(v: ref IcState->ViewerState): string
{
	if(v == nil)
		return "";

	return " " + v.path + "  [" + string (v.topline + 1) + "/" + string v.nlines + "]";
}

bottomtext(w: int): string
{
	return fittext(" F1 Help  F2 Wrap  F3 Hex  F7 Search  F10 Quit ", w);
}

drawviewer(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int)
{
	i, rows, idx: int;
	text: string;

	if(u == nil || v == nil)
		return;

	rows = bodyh(h);
	ensureids(u, v, rows);

	rewrap(v, w);
	clampview(v, h);

	ui->setstatusrows(u, -1, -1);

	setlabel(u, parentid, v.topid, 0, 0, w, toptext(v), TopCode);

	for(i = 0; i < rows; i++){
		idx = v.topline + i;
		if(idx >= 0 && idx < v.nlines)
			text = v.wrapped[idx];
		else
			text = "";

		setlabel(u, parentid, v.bodyids[i], 0, 1 + i, w, text, BodyCode);
	}

	setlabel(u, parentid, v.bottomid, 0, h - 1, w, bottomtext(w), BottomCode);
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.viewer != nil && state.viewer.active;
}

start(state: ref IcState->AppState, path: string, mode: int): int
{
	lines: array of string;

	if(state == nil || path == "")
		return -1;

	lines = loadlines(path);
	if(lines == nil)
		return -1;

	if(state.viewer == nil)
		state.viewer = newstate();

	state.viewer.active = 1;
	state.viewer.mode = mode;
	state.viewer.path = path;
	state.viewer.lines = lines;
	state.viewer.wrapped = array[0] of string;
	state.viewer.topline = 0;
	state.viewer.nlines = 0;
	state.viewer.lastw = 0;

	return 0;
}

build(state: ref IcState->AppState, parentid, w, h: int): int
{
	if(state == nil || state.ui == nil || state.viewer == nil || !state.viewer.active)
		return -1;

	drawviewer(state.ui, parentid, state.viewer, w, h);
	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	v: ref IcState->ViewerState;

	if(state == nil || state.viewer == nil || !state.viewer.active)
		return 0;

	v = state.viewer;

	case k {
	Kq or Kesc or Kf10 =>
		v.active = 0;
		return 2;

	Kup =>
		v.topline--;

	Kdown =>
		v.topline++;

	Kpgup =>
		v.topline -= bodyh(state.height);

	Kpgdown =>
		v.topline += bodyh(state.height);

	Khome =>
		v.topline = 0;

	Kend =>
		v.topline = v.nlines - bodyh(state.height);

	* =>
		return 0;
	}

	clampview(v, state.height);
	build(state, state.toolid, state.width, state.height);

	return 1;
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
	running, r: int;

	v = newstate();
	v.path = path;
	v.mode = mode;
	v.lines = loadlines(path);
	if(v.lines == nil)
		return -1;

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

	v.active = 1;

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
			(nw, nh, resized) = appfw->pollresize(ctx, st.width, st.height);
			if(resized){
				st.width = nw;
				st.height = nh;
				v.lastw = 0;
				build(st, st.rootid, st.width, st.height);
				appfw->draw(ctx);
			}
		}
	}

	appfw->close(ctx);
	return 0;
}