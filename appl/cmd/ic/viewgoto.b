implement IcViewGoto;

include "ic/viewgoto.m";

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

IcInputHistoryMod: module
{
	PATH: con "/dis/ic/inputhist.dis";

	History: adt
	{
		section: string;
		items: array of string;
		sel: int;
		maxitems: int;
	};

	init: fn();
	new: fn(section: string, maxitems: int): ref History;
	loadhist: fn(h: ref History): int;
	add: fn(h: ref History, text: string): int;
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;
histmod: IcInputHistoryMod;

style: Style;

g: IcViewCommon->GotoState;
inputpos: int;
inputcursorid: int;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

animstage: int;
animwait: int;

TabKey: con 9;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;
BackspaceKey: con 8;
DeleteKey: con 127;
HomeKey: con 57360;
EndKey: con 57361;
UpKey: con 57362;
DownKey: con 57363;
LeftKey: con 57364;
RightKey: con 57365;
CtrlDownKey: con 57811;

initstyle: fn();
setstylevalue: fn(dst: string, src: string): string;
animticks: fn(): int;

ensureids: fn(u: ref IcUi->Ui);
resetids: fn();
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);
disposeshadow: fn(u: ref IcUi->Ui);

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
topframe: fn(w: int): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
radiotext: fn(mode: int, label: string): string;
fieldtext: fn(w: int): string;
fieldcursorpos: fn(w: int): int;
fieldcursorchar: fn(w: int): string;
cursoroverlay: fn(pos: int): string;

loadhistory: fn();
savehistory: fn();
ensurehistoryids: fn(u: ref IcUi->Ui, rows: int);
hidehistory: fn(u: ref IcUi->Ui);
removehistory: fn(u: ref IcUi->Ui);
drawhistory: fn(u: ref IcUi->Ui);

buttontext: fn(kind: int): string;
focusnext: fn();
focusprev: fn();
printable: fn(k: int): int;
typecode: fn(focus: int): string;
buttonstyle: fn(focus: int): string;
setfocusmode: fn(focus: int): int;

clampinputpos: fn();
insertchar: fn(k: int);
backspacechar: fn();
deletechar: fn();
normalizedinput: fn(): string;
autochoosemode: fn(k: int);
ishexmark: fn(k: int): int;
ispercentmark: fn(k: int): int;

drawshadow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawwindow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	histmod = load IcInputHistoryMod IcInputHistoryMod->PATH;
	if(histmod == nil)
		raise "fail:load ic/inputhist";

	ui->init();
	view->init();
	histmod->init();

	initstyle();

	g.active = 0;
	g.shadowid = -1;
	g.windowid = -1;
	g.inputid = -1;
	g.typeids = array[4] of int;
	g.buttonids = array[2] of int;
	g.historyids = array[0] of int;
	g.input = "";
	g.inputpos = 0;
	g.inputhistoryopen = 0;
	g.inputhistorysel = -1;
	g.inputhistoryitems = array[0] of string;
	g.mode = IcViewCommon->GotoLine;
	g.focus = IcViewCommon->GotoFocusInput;
	g.result = IcViewCommon->GotoNone;
	inputpos = 0;
	inputcursorid = -1;

	animstage = StageNone;
	animwait = 0;
}

initstyle()
{
	style.windowcode = "38;2;20;20;20;48;2;210;210;210";
	style.framecode = "1;38;2;35;35;35;48;2;210;210;210";
	style.textcode = "38;2;20;20;20;48;2;210;210;210";
	style.fieldcode = "1;38;2;255;255;255;48;2;55;160;220";
	style.fieldfocuscode = "1;38;2;255;255;255;48;2;35;135;205";
	style.focuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.buttoncode = "1;38;2;20;20;20;48;2;235;235;235";
	style.buttonfocuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.shadowcode = "";

	style.animticks = 0;

	style.frameh = "─";
	style.framev = "│";
	style.framenw = "┌";
	style.framene = "┐";
	style.framesw = "└";
	style.framese = "┘";
}

setstylevalue(dst: string, src: string): string
{
	if(src != "")
		return src;

	return dst;
}

setstyle(s: Style)
{
	style.windowcode = setstylevalue(style.windowcode, s.windowcode);
	style.framecode = setstylevalue(style.framecode, s.framecode);
	style.textcode = setstylevalue(style.textcode, s.textcode);
	style.fieldcode = setstylevalue(style.fieldcode, s.fieldcode);
	style.fieldfocuscode = setstylevalue(style.fieldfocuscode, s.fieldfocuscode);
	style.focuscode = setstylevalue(style.focuscode, s.focuscode);
	style.buttoncode = setstylevalue(style.buttoncode, s.buttoncode);
	style.buttonfocuscode = setstylevalue(style.buttonfocuscode, s.buttonfocuscode);
	style.shadowcode = setstylevalue(style.shadowcode, s.shadowcode);

	if(s.animticks >= 0)
		style.animticks = s.animticks;

	style.frameh = setstylevalue(style.frameh, s.frameh);
	style.framev = setstylevalue(style.framev, s.framev);
	style.framenw = setstylevalue(style.framenw, s.framenw);
	style.framene = setstylevalue(style.framene, s.framene);
	style.framesw = setstylevalue(style.framesw, s.framesw);
	style.framese = setstylevalue(style.framese, s.framese);
}

animticks(): int
{
	if(style.animticks < 0)
		return 0;

	return style.animticks;
}

open(u: ref IcUi->Ui, parentid, w, h: int)
{
	if(u == nil || u.tree == nil)
		return;

	g.active = 1;
	g.input = "";
	g.inputpos = 0;
	g.inputhistoryopen = 0;
	g.inputhistorysel = -1;
	g.inputhistoryitems = array[0] of string;
	g.mode = IcViewCommon->GotoLine;
	g.focus = IcViewCommon->GotoFocusInput;
	g.result = IcViewCommon->GotoNone;
	inputpos = 0;

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	loadhistory();

	ensureids(u);
	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!g.active)
		return;

	g.inputhistoryopen = 0;
	g.inputhistorysel = -1;
	hidehistory(u);

	if(animticks() > 0 && animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		animwait = 0;
		return;
	}

	dispose(u);
	g.active = 0;
	g.result = IcViewCommon->GotoNone;
	animstage = StageNone;
	animwait = 0;
}

active(): int
{
	return g.active;
}

mode(): int
{
	return g.mode;
}

input(): string
{
	return normalizedinput();
}

ensureids(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil)
		return;

	if(g.shadowid < 0)
		g.shadowid = view->allocid(u.tree);
	if(g.windowid < 0)
		g.windowid = view->allocid(u.tree);
	if(g.inputid < 0)
		g.inputid = view->allocid(u.tree);
	if(inputcursorid < 0)
		inputcursorid = view->allocid(u.tree);

	if(g.typeids == nil || len g.typeids != 4)
		g.typeids = array[4] of int;

	for(i = 0; i < 4; i++){
		if(g.typeids[i] <= 0)
			g.typeids[i] = view->allocid(u.tree);
	}

	if(g.buttonids == nil || len g.buttonids != 2)
		g.buttonids = array[2] of int;

	for(i = 0; i < 2; i++){
		if(g.buttonids[i] <= 0)
			g.buttonids[i] = view->allocid(u.tree);
	}
}

resetids()
{
	g.shadowid = -1;
	g.windowid = -1;
	g.inputid = -1;
	inputcursorid = -1;
	g.typeids = array[4] of int;
	g.buttonids = array[2] of int;
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	removehistory(u);

	if(g.windowid >= 0)
		view->removetree(u.tree, g.windowid);
	if(g.shadowid >= 0)
		view->removetree(u.tree, g.shadowid);

	resetids();
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	hidehistory(u);

	if(g.windowid >= 0)
		view->removetree(u.tree, g.windowid);

	g.windowid = -1;
	g.inputid = -1;
	inputcursorid = -1;
	g.typeids = array[4] of int;
	g.buttonids = array[2] of int;
}

disposeshadow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(g.shadowid >= 0)
		view->removetree(u.tree, g.shadowid);

	g.shadowid = -1;
}

fillstr(n: int, ch: string): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += ch;

	return s;
}

spaces(n: int): string
{
	return fillstr(n, " ");
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

topframe(w: int): string
{
	prefix, title: string;
	n: int;

	title = " GoTo ";
	prefix = style.framenw + title;
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

radiotext(mode: int, label: string): string
{
	if(g.mode == mode)
		return "(*) " + label;

	return "( ) " + label;
}

fieldtext(w: int): string
{
	s, trigger: string;
	textw, start, cursor: int;

	trigger = "[v]";
	if(w < len trigger + 2)
		return fittext(trigger, w);

	textw = w - len trigger - 1;
	if(textw < 1)
		textw = 1;

	clampinputpos();

	s = g.input;
	cursor = inputpos;
	start = 0;

	if(cursor >= textw)
		start = cursor - textw + 1;

	if(start < 0)
		start = 0;
	if(start > len s)
		start = len s;

	if(len s[start:] > textw)
		s = s[start:start + textw];
	else
		s = s[start:];

	while(len s < textw)
		s += " ";

	return s + " " + trigger;
}

cursoroverlay(pos: int): string
{
	return "cursor=1;base=" + style.focuscode + ";pos=" + string pos + ";ch=";
}

fieldcursorpos(w: int): int
{
	textw, start, cursor: int;

	textw = w - len "[v]" - 1;
	if(textw < 1)
		textw = 1;

	clampinputpos();

	cursor = inputpos;
	start = 0;

	if(cursor >= textw)
		start = cursor - textw + 1;

	cursor -= start;

	if(cursor < 0)
		cursor = 0;
	if(cursor >= textw)
		cursor = textw - 1;

	return cursor;
}

fieldcursorchar(w: int): string
{
	textw, start, cursor, idx: int;

	textw = w - len "[v]" - 1;
	if(textw < 1)
		textw = 1;

	clampinputpos();

	cursor = inputpos;
	start = 0;

	if(cursor >= textw)
		start = cursor - textw + 1;

	idx = start + fieldcursorpos(w);

	if(idx >= 0 && idx < len g.input)
		return g.input[idx:idx + 1];

	return " ";
}

loadhistory()
{
	h: ref IcInputHistoryMod->History;

	g.inputhistoryopen = 0;
	g.inputhistorysel = -1;
	g.inputhistoryitems = array[0] of string;

	h = histmod->new("goto_view", 32);
	if(h == nil)
		return;

	histmod->loadhist(h);
	if(h.items != nil)
		g.inputhistoryitems = h.items;
}

savehistory()
{
	h: ref IcInputHistoryMod->History;
	v: string;

	v = normalizedinput();
	if(v == "")
		return;

	h = histmod->new("goto_view", 32);
	if(h == nil)
		return;

	histmod->loadhist(h);
	histmod->add(h, v);
}

ensurehistoryids(u: ref IcUi->Ui, rows: int)
{
	i, n: int;
	a: array of int;

	if(u == nil || u.tree == nil)
		return;

	if(rows < 0)
		rows = 0;

	if(g.historyids != nil && len g.historyids >= rows)
		return;

	n = 0;
	if(g.historyids != nil)
		n = len g.historyids;

	a = array[rows] of int;

	for(i = 0; i < n && i < rows; i++)
		a[i] = g.historyids[i];

	for(; i < rows; i++)
		a[i] = view->allocid(u.tree);

	g.historyids = a;
}

hidehistory(u: ref IcUi->Ui)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || g.historyids == nil)
		return;

	for(i = 0; i < len g.historyids; i++){
		n = view->find(u.tree, g.historyids[i]);
		if(n != nil)
			view->hide(n);
	}
}

removehistory(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil || g.historyids == nil)
		return;

	for(i = 0; i < len g.historyids; i++){
		if(g.historyids[i] >= 0)
			view->removetree(u.tree, g.historyids[i]);
	}

	g.historyids = array[0] of int;
}

drawhistory(u: ref IcUi->Ui)
{
	i, rows, x, y, w: int;
	text: string;
	id: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(!g.inputhistoryopen || g.inputhistoryitems == nil || len g.inputhistoryitems == 0){
		hidehistory(u);
		return;
	}

	rows = len g.inputhistoryitems;
	if(rows > 5)
		rows = 5;

	ensurehistoryids(u, rows);

	x = g.x + 4;
	y = g.y + 3;
	w = g.w - 8;
	if(w < 10)
		w = 10;

	for(i = 0; i < rows; i++){
		id = g.historyids[i];
		if(i == g.inputhistorysel)
			text = "> " + g.inputhistoryitems[i];
		else
			text = "  " + g.inputhistoryitems[i];

		if(view->find(u.tree, id) == nil)
			ui->label(u, u.tree.rootid, id, x, y + i, w, text);

		n = view->find(u.tree, id);
		if(n == nil)
			continue;

		view->setbounds(n, x, y + i, w, 1);
		view->settext(n, fittext(text, w));
		if(i == g.inputhistorysel)
			view->setcode(n, style.focuscode);
		else
			view->setcode(n, style.fieldcode);
		view->show(n);
		view->bringtofront(u.tree, id);
	}
}

buttontext(kind: int): string
{
	if(kind == 0)
		return "[< OK >]";

	return "[ Cancel ]";
}

focusnext()
{
	g.focus++;
	if(g.focus > IcViewCommon->GotoFocusCancel)
		g.focus = IcViewCommon->GotoFocusInput;
}

focusprev()
{
	g.focus--;
	if(g.focus < IcViewCommon->GotoFocusInput)
		g.focus = IcViewCommon->GotoFocusCancel;
}

printable(k: int): int
{
	if(k >= '0' && k <= '9')
		return 1;

	if(k == '%')
		return 1;

	if(k >= 'a' && k <= 'f')
		return 1;

	if(k >= 'A' && k <= 'F')
		return 1;

	if(k == 'x' || k == 'X')
		return 1;

	if(k == 'h' || k == 'H')
		return 1;

	return 0;
}

typecode(focus: int): string
{
	if(g.focus == focus)
		return style.focuscode;

	return style.textcode;
}

buttonstyle(focus: int): string
{
	if(g.focus == focus)
		return style.buttonfocuscode;

	return style.buttoncode;
}

setfocusmode(focus: int): int
{
	case focus {
	IcViewCommon->GotoFocusLine =>
		g.mode = IcViewCommon->GotoLine;
		return 1;

	IcViewCommon->GotoFocusPercent =>
		g.mode = IcViewCommon->GotoPercent;
		return 1;

	IcViewCommon->GotoFocusOffsetDec =>
		g.mode = IcViewCommon->GotoOffsetDec;
		return 1;

	IcViewCommon->GotoFocusOffsetHex =>
		g.mode = IcViewCommon->GotoOffsetHex;
		return 1;
	}

	return 0;
}

clampinputpos()
{
	if(inputpos < 0)
		inputpos = 0;

	if(inputpos > len g.input)
		inputpos = len g.input;

	g.inputpos = inputpos;
}

insertchar(k: int)
{
	c: string;

	clampinputpos();
	autochoosemode(k);

	c = sys->sprint("%c", k);
	g.input = g.input[0:inputpos] + c + g.input[inputpos:];
	inputpos++;
	g.inputpos = inputpos;
}

backspacechar()
{
	clampinputpos();

	if(inputpos <= 0)
		return;

	g.input = g.input[0:inputpos - 1] + g.input[inputpos:];
	inputpos--;
	g.inputpos = inputpos;
}

deletechar()
{
	clampinputpos();

	if(inputpos >= len g.input)
		return;

	g.input = g.input[0:inputpos] + g.input[inputpos + 1:];
	g.inputpos = inputpos;
}

ishexmark(k: int): int
{
	if(k >= 'a' && k <= 'f')
		return 1;
	if(k >= 'A' && k <= 'F')
		return 1;
	if(k == 'x' || k == 'X')
		return 1;
	if(k == 'h' || k == 'H')
		return 1;

	return 0;
}

ispercentmark(k: int): int
{
	return k == '%';
}

autochoosemode(k: int)
{
	if(ispercentmark(k)){
		g.mode = IcViewCommon->GotoPercent;
		return;
	}

	if(ishexmark(k))
		g.mode = IcViewCommon->GotoOffsetHex;
}

normalizedinput(): string
{
	s: string;

	s = g.input;

	if(g.mode == IcViewCommon->GotoPercent){
		if(len s > 0 && s[len s - 1] == '%')
			s = s[0:len s - 1];

		return s;
	}

	if(g.mode != IcViewCommon->GotoOffsetHex)
		return s;

	if(len s >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
		s = s[2:];

	if(len s > 0 && (s[len s - 1] == 'h' || s[len s - 1] == 'H'))
		s = s[0:len s - 1];

	return s;
}

drawshadow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(g.shadowid >= 0)
		view->removetree(u.tree, g.shadowid);

	g.shadowid = view->allocid(u.tree);

	if(ui->node(u, parentid, g.shadowid, "shadow", x + 2, y + 1, w, h) < 0)
		return -1;

	view->bringtofront(u.tree, g.shadowid);
	return 0;
}

drawwindow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, bx, row, bgid, textw, start, cursor: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(g.windowid >= 0)
		view->removetree(u.tree, g.windowid);

	if(g.shadowid >= 0)
		view->removetree(u.tree, g.shadowid);

	g.shadowid = view->allocid(u.tree);
	g.windowid = view->allocid(u.tree);
	g.inputid = view->allocid(u.tree);
	g.typeids = array[] of {
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree)
	};
	g.buttonids = array[] of {
		view->allocid(u.tree),
		view->allocid(u.tree)
	};

	ui->node(u, parentid, g.shadowid, "shadow", x + 2, y + 1, w, h);
	ui->node(u, parentid, g.windowid, "group", x, y, w, h);

	setlabel(u, g.windowid, view->allocid(u.tree), 0, 0, w, topframe(w), style.framecode);
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, g.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}
	setlabel(u, g.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	if(g.focus == IcViewCommon->GotoFocusInput)
		setlabel(u, g.windowid, g.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldfocuscode);
	else
		setlabel(u, g.windowid, g.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldcode);

	n = view->find(u.tree, g.inputid);
	if(n != nil){
		n.styles = array[0] of string;

		if(g.focus == IcViewCommon->GotoFocusInput && !g.inputhistoryopen){
			textw = bodyw - len "[v]" - 1;
			if(textw < 1)
				textw = 1;

			cursor = inputpos;
			start = 0;

			if(cursor >= textw)
				start = cursor - textw + 1;

			cursor -= start;
			if(cursor < 0)
				cursor = 0;
			if(cursor >= textw)
				cursor = textw - 1;

			n.styles = array[] of {
				"",
				cursoroverlay(cursor)
			};
		}
	}

	setlabel(u, g.windowid, g.typeids[0], 4, 4, bodyw,
		radiotext(IcViewCommon->GotoLine, "Line number"),
		typecode(IcViewCommon->GotoFocusLine));

	setlabel(u, g.windowid, g.typeids[1], 4, 5, bodyw,
		radiotext(IcViewCommon->GotoPercent, "Percent"),
		typecode(IcViewCommon->GotoFocusPercent));

	setlabel(u, g.windowid, g.typeids[2], 4, 6, bodyw,
		radiotext(IcViewCommon->GotoOffsetDec, "Offset (decimal)"),
		typecode(IcViewCommon->GotoFocusOffsetDec));

	setlabel(u, g.windowid, g.typeids[3], 4, 7, bodyw,
		radiotext(IcViewCommon->GotoOffsetHex, "Offset (hex)"),
		typecode(IcViewCommon->GotoFocusOffsetHex));

	bx = (w - 23) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, g.windowid, g.buttonids[0], bx, 10, 9,
		buttontext(0),
		buttonstyle(IcViewCommon->GotoFocusOk));

	setlabel(u, g.windowid, g.buttonids[1], bx + 12, 10, 10,
		buttontext(1),
		buttonstyle(IcViewCommon->GotoFocusCancel));

	drawhistory(u);

	view->bringtofront(u.tree, g.windowid);
	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	iw, wh, x, y: int;

	if(u == nil || u.tree == nil || !g.active)
		return -1;

	ensureids(u);

	iw = 52;
	wh = 13;

	if(iw > w - 4)
		iw = w - 4;
	if(iw < 38)
		iw = 38;

	if(wh > h - 2)
		wh = h - 2;
	if(wh < 12)
		wh = 12;

	x = (w - iw) / 2;
	y = (h - wh) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	g.x = x;
	g.y = y;
	g.w = iw;
	g.h = wh;

	if(animstage == StageShadow || animstage == StageClosingShadow)
		return drawshadow(u, parentid, x, y, iw, wh);

	return drawwindow(u, parentid, x, y, iw, wh);
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	if(!g.active)
		return 0;

	if(animticks() <= 0)
		return 0;

	animwait++;
	if(animwait < animticks())
		return 0;

	animwait = 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		g.active = 0;
		g.result = IcViewCommon->GotoNone;
		animstage = StageNone;
		return 1;
	}

	return 0;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	if(!g.active)
		return IcViewCommon->GotoNone;

	if(animstage != StageWindow)
		return IcViewCommon->GotoNone;

	if(g.inputhistoryopen){
		if(k == EscapeKey){
			g.inputhistoryopen = 0;
			g.inputhistorysel = -1;
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}

		if(k == UpKey){
			if(g.inputhistoryitems != nil && len g.inputhistoryitems > 0){
				if(g.inputhistorysel < 0)
					g.inputhistorysel = 0;
				else if(g.inputhistorysel > 0)
					g.inputhistorysel--;
				else
					g.inputhistorysel = len g.inputhistoryitems - 1;
			}
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}

		if(k == DownKey){
			if(g.inputhistoryitems != nil && len g.inputhistoryitems > 0){
				if(g.inputhistorysel < 0)
					g.inputhistorysel = 0;
				else if(g.inputhistorysel + 1 < len g.inputhistoryitems)
					g.inputhistorysel++;
				else
					g.inputhistorysel = 0;
			}
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}

		if(k == EnterKey || k == ReturnKey){
			if(g.inputhistorysel >= 0 && g.inputhistorysel < len g.inputhistoryitems){
				g.input = g.inputhistoryitems[g.inputhistorysel];
				inputpos = len g.input;
				g.inputpos = inputpos;
			}
			g.inputhistoryopen = 0;
			g.inputhistorysel = -1;
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}
	}

	if(k == EscapeKey){
		g.result = IcViewCommon->GotoCancel;
		return g.result;
	}

	if(k == CtrlDownKey && g.focus == IcViewCommon->GotoFocusInput){
		if(g.inputhistoryitems != nil && len g.inputhistoryitems > 0){
			g.inputhistoryopen = 1;
			if(g.inputhistorysel < 0)
				g.inputhistorysel = 0;
			draw(u, parentid, w, h);
		}
		return IcViewCommon->GotoNone;
	}

	if(k == TabKey || k == DownKey){
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == UpKey){
		focusprev();
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == LeftKey){
		if(g.focus == IcViewCommon->GotoFocusInput){
			inputpos--;
			clampinputpos();
		}else
			focusprev();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == RightKey){
		if(g.focus == IcViewCommon->GotoFocusInput){
			inputpos++;
			clampinputpos();
		}else
			focusnext();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == HomeKey && g.focus == IcViewCommon->GotoFocusInput){
		inputpos = 0;
		g.inputpos = 0;
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == EndKey && g.focus == IcViewCommon->GotoFocusInput){
		inputpos = len g.input;
		g.inputpos = inputpos;
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == BackspaceKey){
		if(g.focus == IcViewCommon->GotoFocusInput)
			backspacechar();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == DeleteKey){
		if(g.focus == IcViewCommon->GotoFocusInput)
			deletechar();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(g.focus == IcViewCommon->GotoFocusInput && printable(k)){
		insertchar(k);
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == SpaceKey){
		if(setfocusmode(g.focus)){
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}

		if(g.focus == IcViewCommon->GotoFocusOk || g.focus == IcViewCommon->GotoFocusInput){
			savehistory();
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusCancel){
			g.result = IcViewCommon->GotoCancel;
			return g.result;
		}
	}

	if(k == EnterKey || k == ReturnKey){
		if(setfocusmode(g.focus)){
			savehistory();
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusOk || g.focus == IcViewCommon->GotoFocusInput){
			savehistory();
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusCancel){
			g.result = IcViewCommon->GotoCancel;
			return g.result;
		}
	}

	return IcViewCommon->GotoNone;
}