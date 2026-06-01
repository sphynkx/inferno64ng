implement IcViewCodepage;

include "ic/viewcodepage.m";
include "ic/codepage.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	allocid: fn(t: ref IcView->Tree): int;
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
	removetree: fn(t: ref IcView->Tree, id: int): int;
	bringtofront: fn(t: ref IcView->Tree, id: int): int;
};

ui: IcUiMod;
view: IcViewMod;
codepage: IcCodepage;

style: Style;

activeflag: int;
selectedidx: int;

shadowid: int;
windowid: int;
itemids: array of int;

x: int;
y: int;
ww: int;
wh: int;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

animstage: int;
animwait: int;

UpKey: con 57362;
DownKey: con 57363;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;

initstyle: fn();
setstylevalue: fn(cur, next: string): string;
animticks: fn(): int;

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(v: string, w: int): string;
topframe: fn(w: int): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);

ensureids: fn(u: ref IcUi->Ui);
resetwindowids: fn();
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

drawshadow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawwindow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	codepage = load IcCodepage IcCodepage->PATH;
	if(codepage == nil)
		raise "fail:load ic/codepage";

	ui->init();
	view->init();
	codepage->init();

	initstyle();

	activeflag = 0;
	selectedidx = 0;

	shadowid = -1;
	windowid = -1;
	itemids = array[0] of int;

	x = 0;
	y = 0;
	ww = 0;
	wh = 0;

	animstage = StageNone;
	animwait = 0;
}

initstyle()
{
	style.windowcode = "38;2;20;20;20;48;2;210;210;210";
	style.framecode = "1;38;2;35;35;35;48;2;210;210;210";
	style.textcode = "38;2;20;20;20;48;2;210;210;210";
	style.focuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.shadowcode = "";

	style.animticks = 0;

	style.frameh = "─";
	style.framev = "│";
	style.framenw = "┌";
	style.framene = "┐";
	style.framesw = "└";
	style.framese = "┘";
}

setstylevalue(cur, next: string): string
{
	if(next != "")
		return next;
	return cur;
}

setstyle(arg: Style)
{
	style.windowcode = setstylevalue(style.windowcode, arg.windowcode);
	style.framecode = setstylevalue(style.framecode, arg.framecode);
	style.textcode = setstylevalue(style.textcode, arg.textcode);
	style.focuscode = setstylevalue(style.focuscode, arg.focuscode);
	style.shadowcode = setstylevalue(style.shadowcode, arg.shadowcode);

	if(arg.animticks >= 0)
		style.animticks = arg.animticks;

	style.frameh = setstylevalue(style.frameh, arg.frameh);
	style.framev = setstylevalue(style.framev, arg.framev);
	style.framenw = setstylevalue(style.framenw, arg.framenw);
	style.framene = setstylevalue(style.framene, arg.framene);
	style.framesw = setstylevalue(style.framesw, arg.framesw);
	style.framese = setstylevalue(style.framese, arg.framese);
}

animticks(): int
{
	if(style.animticks < 0)
		return 0;

	return style.animticks;
}

active(): int
{
	return activeflag;
}

selected(): string
{
	n: int;

	n = codepage->count();
	if(n <= 0)
		return "";

	if(selectedidx < 0)
		selectedidx = 0;
	if(selectedidx >= n)
		selectedidx = n - 1;

	return codepage->name(selectedidx);
}

open(u: ref IcUi->Ui, parentid, w, h: int, current: string)
{
	idx: int;

	if(u == nil || u.tree == nil)
		return;

	activeflag = 1;

	idx = codepage->find(current);
	if(idx < 0)
		idx = codepage->find(codepage->defaultname());
	if(idx < 0)
		idx = 0;

	selectedidx = idx;

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	ensureids(u);
	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!activeflag)
		return;

	if(animticks() > 0 && animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		animwait = 0;
		return;
	}

	dispose(u);
	activeflag = 0;
	animstage = StageNone;
	animwait = 0;
	resetwindowids();
}

fillstr(n: int, ch: string): string
{
	out: string;
	i: int;

	out = "";
	for(i = 0; i < n; i++)
		out += ch;

	return out;
}

spaces(n: int): string
{
	return fillstr(n, " ");
}

fittext(v: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len v > w)
		return v[0:w];

	if(len v < w)
		return v + spaces(w - len v);

	return v;
}

topframe(w: int): string
{
	prefix: string;
	n: int;

	prefix = style.framenw + " Codepage ";
	n = w - len prefix - len style.framene;
	if(n < 0)
		n = 0;

	return fittext(prefix + fillstr(n, style.frameh) + style.framene, w);
}

bottomframe(w: int): string
{
	if(w < 2)
		return fittext(style.framesw, w);

	return style.framesw + fillstr(w - 2, style.frameh) + style.framese;
}

midframe(w: int): string
{
	if(w < 2)
		return fittext(style.framev, w);

	return style.framev + spaces(w - 2) + style.framev;
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

ensureids(u: ref IcUi->Ui)
{
	i, n: int;

	if(u == nil || u.tree == nil)
		return;

	if(shadowid < 0)
		shadowid = view->allocid(u.tree);
	if(windowid < 0)
		windowid = view->allocid(u.tree);

	n = codepage->count();

	if(itemids != nil && len itemids == n)
		return;

	itemids = array[n] of int;
	for(i = 0; i < n; i++)
		itemids[i] = view->allocid(u.tree);
}

resetwindowids()
{
	windowid = -1;
	itemids = array[0] of int;
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(windowid >= 0)
		view->removetree(u.tree, windowid);
	if(shadowid >= 0)
		view->removetree(u.tree, shadowid);

	shadowid = -1;
	resetwindowids();
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(windowid >= 0)
		view->removetree(u.tree, windowid);

	resetwindowids();
}

drawshadow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(shadowid >= 0)
		view->removetree(u.tree, shadowid);

	shadowid = view->allocid(u.tree);

	if(ui->node(u, parentid, shadowid, "shadow", x + 1, y + 1, w, h) < 0)
		return -1;

	view->bringtofront(u.tree, shadowid);
	return 0;
}

drawwindow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	i, n, bodyw, row, bgid: int;
	name, code: string;
	nn: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(windowid >= 0)
		view->removetree(u.tree, windowid);

	if(shadowid >= 0)
		view->removetree(u.tree, shadowid);

	shadowid = view->allocid(u.tree);
	windowid = view->allocid(u.tree);

	n = codepage->count();
	itemids = array[n] of int;
	for(i = 0; i < n; i++)
		itemids[i] = view->allocid(u.tree);

	if(ui->node(u, parentid, shadowid, "shadow", x + 1, y + 1, w, h) < 0)
		return -1;

	if(ui->node(u, parentid, windowid, "group", x, y, w, h) < 0)
		return -1;

	nn = view->find(u.tree, windowid);
	if(nn != nil && style.windowcode != "")
		view->setcode(nn, style.windowcode);

	setlabel(u, windowid, view->allocid(u.tree), 0, 0, w, topframe(w), style.framecode);

	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}

	setlabel(u, windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), style.framecode);

	bodyw = w - 4;
	if(bodyw < 1)
		bodyw = 1;

	for(i = 0; i < n && i < h - 2; i++){
		name = codepage->name(i);
		if(i == selectedidx)
			code = style.focuscode;
		else
			code = style.textcode;

		setlabel(u, windowid, itemids[i], 2, 1 + i, bodyw, name, code);
	}

	view->bringtofront(u.tree, shadowid);
	view->bringtofront(u.tree, windowid);

	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	iw, ih, n: int;

	if(u == nil || u.tree == nil || !activeflag)
		return -1;

	n = codepage->count();

	iw = 34;
	ih = n + 4;

	if(iw > w - 4)
		iw = w - 4;
	if(iw < 20)
		iw = 20;

	if(ih > h - 2)
		ih = h - 2;
	if(ih < 6)
		ih = 6;

	x = (w - iw) / 2;
	y = (h - ih) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	ww = iw;
	wh = ih;

	if(animstage == StageShadow || animstage == StageClosingShadow){
		drawshadow(u, parentid, x, y, iw, ih);
		return 0;
	}

	if(animstage != StageWindow)
		animstage = StageWindow;

	return drawwindow(u, parentid, x, y, iw, ih);
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	delay: int;

	if(!activeflag)
		return 0;

	delay = animticks();
	if(delay <= 0)
		return 0;

	if(animstage == StageShadow){
		animwait++;
		if(animwait < delay)
			return 0;

		animwait = 0;
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		animwait++;
		if(animwait < delay)
			return 0;

		dispose(u);
		activeflag = 0;
		animstage = StageNone;
		animwait = 0;
		return 1;
	}

	return 0;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	n: int;

	if(!activeflag)
		return 0;

	if(animstage != StageWindow)
		return 0;

	n = codepage->count();

	if(k == EscapeKey)
		return 2;

	if(k == UpKey){
		selectedidx--;
		if(selectedidx < 0)
			selectedidx = 0;
		draw(u, parentid, w, h);
		return 0;
	}

	if(k == DownKey){
		selectedidx++;
		if(selectedidx >= n)
			selectedidx = n - 1;
		draw(u, parentid, w, h);
		return 0;
	}

	if(k == EnterKey || k == ReturnKey)
		return 1;

	return 0;
}