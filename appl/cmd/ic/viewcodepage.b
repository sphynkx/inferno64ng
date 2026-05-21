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
	removetree: fn(t: ref IcView->Tree, id: int): int;
	bringtofront: fn(t: ref IcView->Tree, id: int): int;
};

CodepageStyle: adt
{
	windowcode: string;
	framecode: string;
	textcode: string;
	focuscode: string;
	shadowcode: string;

	frameh: string;
	framev: string;
	framenw: string;
	framene: string;
	framesw: string;
	framese: string;
};

State: adt
{
	active: int;
	shadowid: int;
	windowid: int;
	itemids: array of int;
	x: int;
	y: int;
	w: int;
	h: int;
	selected: int;
	result: int;
};

ui: IcUiMod;
view: IcViewMod;
codepage: IcCodepage;

style: CodepageStyle;
s: State;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

ResultNone: con 0;
ResultOk: con 1;
ResultCancel: con 2;

animstage: int;

UpKey: con 57362;
DownKey: con 57363;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(v: string, w: int): string;
topframe: fn(w: int): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;
setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
ensureids: fn(u: ref IcUi->Ui);
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

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

	style.windowcode = "38;2;20;20;20;48;2;210;210;210";
	style.framecode = "1;38;2;35;35;35;48;2;210;210;210";
	style.textcode = "38;2;20;20;20;48;2;210;210;210";
	style.focuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.shadowcode = "38;2;120;120;120;48;2;0;0;0";

	style.frameh = "─";
	style.framev = "│";
	style.framenw = "┌";
	style.framene = "┐";
	style.framesw = "└";
	style.framese = "┘";

	s.active = 0;
	s.shadowid = -1;
	s.windowid = -1;
	s.itemids = array[0] of int;
	s.selected = 0;
	s.result = ResultNone;

	animstage = StageNone;
}

active(): int
{
	return s.active;
}

selected(): string
{
	if(!s.active)
		return "";

	return codepage->name(s.selected);
}

open(u: ref IcUi->Ui, parentid, w, h: int, current: string)
{
	idx: int;

	if(u == nil || u.tree == nil)
		return;

	s.active = 1;
	s.result = ResultNone;

	idx = codepage->find(current);
	if(idx < 0)
		idx = codepage->find(codepage->defaultname());
	if(idx < 0)
		idx = 0;

	s.selected = idx;
	animstage = StageShadow;

	ensureids(u);
	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!s.active)
		return;

	if(animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		return;
	}

	dispose(u);
	s.active = 0;
	s.result = ResultNone;
	animstage = StageNone;
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
	a: array of int;

	if(u == nil || u.tree == nil)
		return;

	if(s.shadowid < 0)
		s.shadowid = view->allocid(u.tree);
	if(s.windowid < 0)
		s.windowid = view->allocid(u.tree);

	n = codepage->count();

	if(s.itemids != nil && len s.itemids == n)
		return;

	a = array[n] of int;
	for(i = 0; i < n; i++)
		a[i] = view->allocid(u.tree);

	s.itemids = a;
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);
	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	iw, wh, x, y: int;
	i, n, bodyw, row, bgid: int;
	name, code: string;
	shadow: ref IcView->Node;

	if(u == nil || u.tree == nil || !s.active)
		return -1;

	ensureids(u);
	dispose(u);

	n = codepage->count();
	iw = 34;
	wh = n + 4;

	if(iw > w - 4)
		iw = w - 4;
	if(iw < 20)
		iw = 20;

	if(wh > h - 2)
		wh = h - 2;
	if(wh < 6)
		wh = 6;

	x = (w - iw) / 2;
	y = (h - wh) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	s.x = x;
	s.y = y;
	s.w = iw;
	s.h = wh;

	ui->node(u, parentid, s.shadowid, "shadow", x + 1, y + 1, iw, wh);
	shadow = view->find(u.tree, s.shadowid);
	if(shadow != nil)
		view->setcode(shadow, style.shadowcode);

	if(animstage == StageShadow || animstage == StageClosingShadow){
		view->bringtofront(u.tree, s.shadowid);
		return 0;
	}

	ui->node(u, parentid, s.windowid, "group", x, y, iw, wh);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, iw, topframe(iw), style.framecode);
	for(row = 1; row < wh - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, iw, midframe(iw), style.framecode);
	}
	setlabel(u, s.windowid, view->allocid(u.tree), 0, wh - 1, iw, bottomframe(iw), style.framecode);

	bodyw = iw - 4;
	if(bodyw < 1)
		bodyw = 1;

	for(i = 0; i < n && i < wh - 2; i++){
		name = codepage->name(i);
		if(i == s.selected)
			code = style.focuscode;
		else
			code = style.textcode;

		setlabel(u, s.windowid, s.itemids[i], 2, 1 + i, bodyw, name, code);
	}

	view->bringtofront(u.tree, s.windowid);
	return 0;
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	if(!s.active)
		return 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		s.active = 0;
		s.result = ResultNone;
		animstage = StageNone;
		return 1;
	}

	return 0;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	n: int;

	if(!s.active)
		return ResultNone;

	if(animstage != StageWindow)
		return ResultNone;

	n = codepage->count();

	if(k == EscapeKey){
		s.result = ResultCancel;
		return s.result;
	}

	if(k == UpKey){
		s.selected--;
		if(s.selected < 0)
			s.selected = 0;
		draw(u, parentid, w, h);
		return ResultNone;
	}

	if(k == DownKey){
		s.selected++;
		if(s.selected >= n)
			s.selected = n - 1;
		draw(u, parentid, w, h);
		return ResultNone;
	}

	if(k == EnterKey || k == ReturnKey){
		s.result = ResultOk;
		return s.result;
	}

	return ResultNone;
}