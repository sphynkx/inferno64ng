implement IcEditSearch;

include "ic/editsearch.m";

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
	showtree: fn(t: ref IcView->Tree, id: int);
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

s: IcViewCommon->SearchDialogState;
hist: ref IcInputHistoryMod->History;
style: IcEditSearch->Style;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

animstage: int;
animwait: int;

HistorySection: con "search_edit";
HistoryMaxItems: con 32;

TabKey: con 9;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;
BackspaceKey: con 8;
DeleteKey: con 127;
UpKey: con 57362;
DownKey: con 57363;
LeftKey: con 57364;
RightKey: con 57365;
CtrlDownKey: con 57811;

ensureids: fn(u: ref IcUi->Ui);
resetwindowids: fn();
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(v: string, w: int): string;
topframe: fn(w: int, title: string): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
checkbox: fn(checked: int, label: string): string;
fieldtext: fn(w: int): string;
fieldcursorpos: fn(w: int): int;
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
optioncode: fn(focus: int): string;
buttoncode: fn(focus: int): string;
togglefocus: fn(): int;

clampinputpos: fn();
insertchar: fn(k: int);
backspacechar: fn();
deletechar: fn();

drawshadow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawwindow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawalert: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;

windowcode: fn(): string;
framecode: fn(): string;
textcode: fn(): string;
fieldcode: fn(): string;
fieldfocuscode: fn(): string;
focuscode: fn(): string;
cursorcode: fn(): string;
buttonbasecode: fn(): string;
buttonfocusbasecode: fn(): string;
disabledcode: fn(): string;
shadowcode: fn(): string;
animticks: fn(): int;

#debugstate: fn(): string;

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

	s.active = 0;
	s.alert = 0;
	s.alerttext = "";
	s.shadowid = -1;
	s.windowid = -1;
	s.inputid = -1;
	s.optionids = array[5] of int;
	s.buttonids = array[3] of int;
	s.historyids = array[0] of int;
	s.inputhistoryopen = 0;
	s.inputhistorysel = -1;
	s.inputhistoryitems = array[0] of string;

	resetwindowids();

	s.x = 0;
	s.y = 0;
	s.w = 0;
	s.h = 0;
	s.input = "";
	s.inputpos = 0;
	s.focus = IcViewCommon->SearchFocusInput;
	s.case_sensitive = 1;
	s.backward = 0;
	s.wrap = 1;
	s.regex = 0;
	s.anyencoding = 0;
	s.encoding = "utf-8";
	s.result = IcViewCommon->SearchNone;

	hist = nil;
	style.animticks = -1;

	animstage = StageNone;
	animwait = 0;
}

setstyle(sv: Style)
{
	style = sv;
}

windowcode(): string
{
	if(style.windowcode != "")
		return style.windowcode;
	return "38;2;20;20;20;48;2;210;210;210";
}

framecode(): string
{
	if(style.framecode != "")
		return style.framecode;
	return "1;38;2;35;35;35;48;2;210;210;210";
}

textcode(): string
{
	if(style.textcode != "")
		return style.textcode;
	return "38;2;20;20;20;48;2;210;210;210";
}

fieldcode(): string
{
	if(style.fieldcode != "")
		return style.fieldcode;
	return "1;38;2;255;255;255;48;2;55;160;220";
}

fieldfocuscode(): string
{
	if(style.fieldfocuscode != "")
		return style.fieldfocuscode;
	return "1;38;2;255;255;255;48;2;35;135;205";
}

focuscode(): string
{
	if(style.focuscode != "")
		return style.focuscode;
	return "1;38;2;0;0;0;48;2;170;225;255";
}

cursorcode(): string
{
	if(style.cursorcode != "")
		return style.cursorcode;
	return "1;38;2;255;255;255;48;2;220;80;40";
}

buttonbasecode(): string
{
	if(style.buttoncode != "")
		return style.buttoncode;
	return "1;38;2;20;20;20;48;2;235;235;235";
}

buttonfocusbasecode(): string
{
	if(style.buttonfocuscode != "")
		return style.buttonfocuscode;
	return "1;38;2;0;0;0;48;2;170;225;255";
}

disabledcode(): string
{
	if(style.disabledcode != "")
		return style.disabledcode;
	return "38;2;120;120;120;48;2;210;210;210";
}

shadowcode(): string
{
	return style.shadowcode;
}

animticks(): int
{
	if(style.animticks >= 0)
		return style.animticks;
	return 0;
}

animticks_DUMMY(): int
{
	return 0;
}

open(u: ref IcUi->Ui, parentid, w, h: int, pattern: string)
{
	if(u == nil || u.tree == nil)
		return;

	s.active = 1;
	s.alert = 0;
	s.alerttext = "";
	s.result = IcViewCommon->SearchNone;

	s.input = pattern;
	s.inputpos = len s.input;
	s.focus = IcViewCommon->SearchFocusInput;
	s.inputhistoryopen = 0;
	s.inputhistorysel = -1;
	s.inputhistoryitems = array[0] of string;

	if(s.encoding == "")
		s.encoding = "utf-8";

	loadhistory();

	resetwindowids();
	ensureids(u);

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	draw(u, parentid, w, h);
}

alert(u: ref IcUi->Ui, parentid, w, h: int, text: string)
{
	if(u == nil || u.tree == nil)
		return;

	s.active = 1;
	s.alert = 1;
	s.alerttext = text;
	s.result = IcViewCommon->SearchNone;
	s.focus = IcViewCommon->SearchFocusForward;
	s.inputhistoryopen = 0;
	s.inputhistorysel = -1;
	s.inputhistoryitems = array[0] of string;

	resetwindowids();
	ensureids(u);

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!s.active)
		return;

	s.inputhistoryopen = 0;
	s.inputhistorysel = -1;
	hidehistory(u);

	if(animticks() > 0 && animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		animwait = 0;
		return;
	}

	dispose(u);
	s.active = 0;
	s.result = IcViewCommon->SearchNone;
	animstage = StageNone;
	animwait = 0;
	resetwindowids();
}

active(): int
{
	return s.active;
}

isalert(): int
{
	return s.active && s.alert;
}

pattern(): string
{
	return s.input;
}

options(): IcViewCommon->SearchOptions
{
	o: IcViewCommon->SearchOptions;

	o.pattern = s.input;
	o.backward = s.backward;
	o.casefold = !s.case_sensitive;
	o.wrap = s.wrap;
	o.regex = s.regex;
	o.encoding = s.encoding;
	o.anyencoding = s.anyencoding;

	return o;
}

resetwindowids()
{
	i: int;

	s.windowid = -1;
	s.inputid = -1;

	if(s.optionids == nil || len s.optionids != 5)
		s.optionids = array[5] of int;

	for(i = 0; i < len s.optionids; i++)
		s.optionids[i] = -1;

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	for(i = 0; i < len s.buttonids; i++)
		s.buttonids[i] = -1;
}

ensureids(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil)
		return;

	if(s.shadowid < 0)
		s.shadowid = view->allocid(u.tree);
	if(s.windowid < 0)
		s.windowid = view->allocid(u.tree);
	if(s.inputid < 0)
		s.inputid = view->allocid(u.tree);

	if(s.optionids == nil || len s.optionids != 5)
		s.optionids = array[5] of int;

	for(i = 0; i < 5; i++){
		if(s.optionids[i] <= 0)
			s.optionids[i] = view->allocid(u.tree);
	}

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	for(i = 0; i < 3; i++){
		if(s.buttonids[i] <= 0)
			s.buttonids[i] = view->allocid(u.tree);
	}
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	removehistory(u);

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);
	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = -1;
	resetwindowids();
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	hidehistory(u);

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);

	resetwindowids();
}

fillstr(n: int, ch: string): string
{
	v: string;
	i: int;

	v = "";
	for(i = 0; i < n; i++)
		v += ch;

	return v;
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

topframe(w: int, title: string): string
{
	prefix: string;
	n: int;

	prefix = "┌ " + title + " ";
	n = w - len prefix - len "┐";
	if(n < 0)
		n = 0;

	return fittext(prefix + fillstr(n, "─") + "┐", w);
}

bottomframe(w: int): string
{
	if(w < 2)
		return fittext("└", w);

	return "└" + fillstr(w - 2, "─") + "┘";
}

midframe(w: int): string
{
	if(w < 2)
		return fittext("│", w);

	return "│" + spaces(w - 2) + "│";
}

setlabel(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || id <= 0)
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

checkbox(checked: int, label: string): string
{
	if(checked)
		return "[x] " + label;

	return "[ ] " + label;
}

fieldtext(w: int): string
{
	v, trigger: string;
	textw, start, cursor: int;

	trigger = "[v]";
	if(w < len trigger + 2)
		return fittext(trigger, w);

	textw = w - len trigger - 1;
	if(textw < 1)
		textw = 1;

	clampinputpos();

	v = s.input;
	cursor = s.inputpos;
	start = 0;

	if(cursor >= textw)
		start = cursor - textw + 1;

	if(start < 0)
		start = 0;
	if(start > len v)
		start = len v;

	if(len v[start:] > textw)
		v = v[start:start + textw];
	else
		v = v[start:];

	while(len v < textw)
		v += " ";

	return v + " " + trigger;
}

fieldcursorpos(w: int): int
{
	textw, start, cursor: int;

	textw = w - len "[v]" - 1;
	if(textw < 1)
		textw = 1;

	clampinputpos();

	cursor = s.inputpos;
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

cursoroverlay(pos: int): string
{
	return "cursor=1\n"
		+ "pos=" + string pos + "\n"
		+ "base=" + cursorcode() + "\n";
}

loadhistory()
{
	if(hist == nil)
		hist = histmod->new(HistorySection, HistoryMaxItems);
	if(hist == nil)
		return;

	s.inputhistoryopen = 0;
	s.inputhistorysel = -1;
	s.inputhistoryitems = array[0] of string;

	histmod->loadhist(hist);
	if(hist.items != nil)
		s.inputhistoryitems = hist.items;
}

savehistory()
{
	v: string;

	if(hist == nil)
		hist = histmod->new(HistorySection, HistoryMaxItems);
	if(hist == nil)
		return;

	v = s.input;
	if(v == "")
		return;

	histmod->loadhist(hist);
	histmod->add(hist, v);
}

ensurehistoryids(u: ref IcUi->Ui, rows: int)
{
	i, n: int;
	a: array of int;

	if(u == nil || u.tree == nil)
		return;

	if(rows < 0)
		rows = 0;

	if(s.historyids != nil && len s.historyids >= rows)
		return;

	n = 0;
	if(s.historyids != nil)
		n = len s.historyids;

	a = array[rows] of int;

	for(i = 0; i < n && i < rows; i++)
		a[i] = s.historyids[i];

	for(; i < rows; i++)
		a[i] = view->allocid(u.tree);

	s.historyids = a;
}

hidehistory(u: ref IcUi->Ui)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || s.historyids == nil)
		return;

	for(i = 0; i < len s.historyids; i++){
		n = view->find(u.tree, s.historyids[i]);
		if(n != nil)
			view->hide(n);
	}
}

removehistory(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil || s.historyids == nil)
		return;

	for(i = 0; i < len s.historyids; i++){
		if(s.historyids[i] >= 0)
			view->removetree(u.tree, s.historyids[i]);
	}

	s.historyids = array[0] of int;
}

drawhistory(u: ref IcUi->Ui)
{
	i, rows, x, y, w: int;
	text: string;
	id: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(!s.inputhistoryopen || s.inputhistoryitems == nil || len s.inputhistoryitems == 0){
		hidehistory(u);
		return;
	}

	rows = len s.inputhistoryitems;
	if(rows > 5)
		rows = 5;

	ensurehistoryids(u, rows);

	x = s.x + 4;
	y = s.y + 3;
	w = s.w - 8;
	if(w < 10)
		w = 10;

	for(i = 0; i < rows; i++){
		id = s.historyids[i];
		if(i == s.inputhistorysel)
			text = "> " + s.inputhistoryitems[i];
		else
			text = "  " + s.inputhistoryitems[i];

		if(view->find(u.tree, id) == nil)
			ui->label(u, u.tree.rootid, id, x, y + i, w, text);

		n = view->find(u.tree, id);
		if(n == nil)
			continue;

		view->setbounds(n, x, y + i, w, 1);
		view->settext(n, fittext(text, w));
		if(i == s.inputhistorysel)
			view->setcode(n, focuscode());
		else
			view->setcode(n, fieldcode());
		view->show(n);
		view->bringtofront(u.tree, id);
	}
}

buttontext(kind: int): string
{
	case kind {
	0 =>
		return "[< Forward >]";
	1 =>
		return "[ Backward ]";
	}

	return "[ Cancel ]";
}

optioncode(focus: int): string
{
	if(s.focus == focus)
		return focuscode();

	return textcode();
}

buttoncode(focus: int): string
{
	if(s.focus == focus)
		return buttonfocusbasecode();

	return buttonbasecode();
}

togglefocus(): int
{
	case s.focus {
	IcViewCommon->SearchFocusCase =>
		s.case_sensitive = !s.case_sensitive;
		return 1;

	IcViewCommon->SearchFocusBackward =>
		s.backward = !s.backward;
		return 1;

	IcViewCommon->SearchFocusWrap =>
		s.wrap = !s.wrap;
		return 1;

	IcViewCommon->SearchFocusRegex =>
		s.regex = !s.regex;
		return 1;

	IcViewCommon->SearchFocusAnyEncoding =>
		s.anyencoding = !s.anyencoding;
		return 1;
	}

	return 0;
}

clampinputpos()
{
	if(s.inputpos < 0)
		s.inputpos = 0;

	if(s.inputpos > len s.input)
		s.inputpos = len s.input;
}

insertchar(k: int)
{
	c: string;

	clampinputpos();

	c = sys->sprint("%c", k);
	s.input = s.input[0:s.inputpos] + c + s.input[s.inputpos:];
	s.inputpos++;
}

backspacechar()
{
	clampinputpos();

	if(s.inputpos <= 0)
		return;

	s.input = s.input[0:s.inputpos - 1] + s.input[s.inputpos:];
	s.inputpos--;
}

deletechar()
{
	clampinputpos();

	if(s.inputpos >= len s.input)
		return;

	s.input = s.input[0:s.inputpos] + s.input[s.inputpos + 1:];
}

printable(k: int): int
{
	return k >= 32 && k < 127;
}

drawshadow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	if(u == nil || u.tree == nil)
		return -1;

	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = view->allocid(u.tree);

	if(ui->node(u, parentid, s.shadowid, "shadow", x + 2, y + 1, w, h) < 0)
		return -1;

	view->bringtofront(u.tree, s.shadowid);
	return 0;
}

drawwindow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, row, bgid: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);

	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = view->allocid(u.tree);
	s.windowid = view->allocid(u.tree);
	s.inputid = view->allocid(u.tree);
	s.optionids = array[] of {
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree)
	};
	s.buttonids = array[] of {
		view->allocid(u.tree),
		view->allocid(u.tree),
		view->allocid(u.tree)
	};

	ui->node(u, parentid, s.shadowid, "shadow", x + 2, y + 1, w, h);
	ui->node(u, parentid, s.windowid, "group", x, y, w, h);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w, topframe(w, "Search"), framecode());
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), windowcode());
	}
	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), framecode());

	bodyw = w - 4;
	if(bodyw < 1)
		bodyw = 1;

	setlabel(u, s.windowid, view->allocid(u.tree), 2, 1, bodyw, "Find:", textcode());

	if(s.focus == IcViewCommon->SearchFocusInput)
		setlabel(u, s.windowid, s.inputid, 2, 2, bodyw, fieldtext(bodyw), fieldfocuscode());
	else
		setlabel(u, s.windowid, s.inputid, 2, 2, bodyw, fieldtext(bodyw), fieldcode());

	n = view->find(u.tree, s.inputid);
	if(n != nil){
		n.styles = array[0] of string;

		if(s.focus == IcViewCommon->SearchFocusInput && !s.inputhistoryopen){
			n.styles = array[] of {
				"",
				cursoroverlay(fieldcursorpos(bodyw))
			};
		}
	}

	setlabel(u, s.windowid, s.optionids[0], 2, 4, bodyw, checkbox(s.case_sensitive, "Case sensitive"), optioncode(IcViewCommon->SearchFocusCase));
	setlabel(u, s.windowid, s.optionids[1], 2, 5, bodyw, checkbox(s.backward, "Backward"), optioncode(IcViewCommon->SearchFocusBackward));
	setlabel(u, s.windowid, s.optionids[2], 2, 6, bodyw, checkbox(s.wrap, "Wrap search"), optioncode(IcViewCommon->SearchFocusWrap));
	setlabel(u, s.windowid, s.optionids[3], 2, 7, bodyw, checkbox(s.regex, "Regex"), optioncode(IcViewCommon->SearchFocusRegex));
	setlabel(u, s.windowid, s.optionids[4], 2, 8, bodyw, checkbox(s.anyencoding, "Any encoding"), optioncode(IcViewCommon->SearchFocusAnyEncoding));

	if(s.anyencoding)
		setlabel(u, s.windowid, view->allocid(u.tree), 2, 9, bodyw, "Encoding: auto", disabledcode());
	else
		setlabel(u, s.windowid, view->allocid(u.tree), 2, 9, bodyw, "Encoding: " + s.encoding, disabledcode());

	setlabel(u, s.windowid, s.buttonids[0], 6, 11, len buttontext(0), buttontext(0), buttoncode(IcViewCommon->SearchFocusForward));
	setlabel(u, s.windowid, s.buttonids[1], 6 + len buttontext(0) + 2, 11, len buttontext(1), buttontext(1), buttoncode(IcViewCommon->SearchFocusBackward));
	setlabel(u, s.windowid, s.buttonids[2], 6 + len buttontext(0) + 2 + len buttontext(1) + 2, 11, len buttontext(2), buttontext(2), buttoncode(IcViewCommon->SearchFocusCancel));

	drawhistory(u);

	view->showtree(u.tree, s.windowid);
	view->bringtofront(u.tree, s.windowid);

	animstage = StageWindow;
	return 0;
}

drawalert(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, row, bgid: int;

	if(u == nil || u.tree == nil)
		return -1;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);

	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = view->allocid(u.tree);
	s.windowid = view->allocid(u.tree);

	ui->node(u, parentid, s.shadowid, "shadow", x + 2, y + 1, w, h);
	n: ref IcView->Node;
	n = view->find(u.tree, s.shadowid);
	if(n != nil && shadowcode() != "")
		view->setcode(n, shadowcode());

	ui->node(u, parentid, s.windowid, "group", x, y, w, h);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w, topframe(w, "Search"), framecode());
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), windowcode());
	}
	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), framecode());

	bodyw = w - 4;
	if(bodyw < 1)
		bodyw = 1;

	setlabel(u, s.windowid, view->allocid(u.tree), 2, 2, bodyw, s.alerttext, textcode());
	setlabel(u, s.windowid, s.buttonids[0], (w - len "[ OK ]") / 2, h - 2, len "[ OK ]", "[ OK ]", buttoncode(IcViewCommon->SearchFocusForward));

	view->showtree(u.tree, s.windowid);
	view->bringtofront(u.tree, s.windowid);

	animstage = StageWindow;
	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	dw, dh, x, y: int;

	if(u == nil || u.tree == nil)
		return -1;

	dw = 48;
	dh = 13;

	if(s.alert){
		dw = len s.alerttext + 8;
		if(dw < 24)
			dw = 24;
		dh = 7;
	}

	if(dw > w - 4)
		dw = w - 4;
	if(dh > h - 4)
		dh = h - 4;

	x = (w - dw) / 2;
	y = (h - dh) / 2;

	s.x = x;
	s.y = y;
	s.w = dw;
	s.h = dh;

	if(animticks() > 0 && animstage == StageShadow)
		return drawshadow(u, parentid, x, y, dw, dh);

	if(s.alert)
		return drawalert(u, parentid, x, y, dw, dh);

	return drawwindow(u, parentid, x, y, dw, dh);
}

handletick_ISX(u: ref IcUi->Ui, parentid, w, h: int): int
{
	delay: int;

	if(!s.active)
		return 0;

	if(animstage == StageNone || animstage == StageWindow)
		return 0;

	delay = animticks();
	if(delay <= 0)
		delay = 1;

	animwait++;
	if(animwait < delay)
		return 0;

	animwait = 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		s.active = 0;
		s.result = IcViewCommon->SearchNone;
		animstage = StageNone;
		return 1;
	}

	return 0;
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	if(!s.active)
		return 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		animwait = 0;

		if(s.alert)
			return drawalert(u, parentid, s.x, s.y, s.w, s.h) >= 0;

		return drawwindow(u, parentid, s.x, s.y, s.w, s.h) >= 0;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		s.active = 0;
		s.result = IcViewCommon->SearchNone;
		animstage = StageNone;
		animwait = 0;
		return 1;
	}

	return 0;
}

focusnext()
{
	s.focus++;
	if(s.alert){
		if(s.focus > IcViewCommon->SearchFocusForward)
			s.focus = IcViewCommon->SearchFocusForward;
		return;
	}

	if(s.focus > IcViewCommon->SearchFocusCancel)
		s.focus = IcViewCommon->SearchFocusInput;
}

focusprev()
{
	s.focus--;
	if(s.alert){
		if(s.focus < IcViewCommon->SearchFocusForward)
			s.focus = IcViewCommon->SearchFocusForward;
		return;
	}

	if(s.focus < IcViewCommon->SearchFocusInput)
		s.focus = IcViewCommon->SearchFocusCancel;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	r: int;

	if(!s.active)
		return IcViewCommon->SearchNone;

	if(animstage != StageWindow)
		return IcViewCommon->SearchNone;

	if(s.alert){
		if(k == EscapeKey || k == EnterKey || k == ReturnKey || k == SpaceKey){
			close(u);
			return IcViewCommon->SearchAlertClosed;
		}
		return IcViewCommon->SearchNone;
	}

	if(s.inputhistoryopen){
		if(k == EscapeKey){
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == UpKey){
			if(s.inputhistorysel > 0)
				s.inputhistorysel--;
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == DownKey){
			if(s.inputhistorysel + 1 < len s.inputhistoryitems)
				s.inputhistorysel++;
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == EnterKey || k == ReturnKey){
			if(s.inputhistorysel >= 0 && s.inputhistorysel < len s.inputhistoryitems){
				s.input = s.inputhistoryitems[s.inputhistorysel];
				s.inputpos = len s.input;
			}
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}
	}

	if(k == EscapeKey){
		close(u);
		return IcViewCommon->SearchCancel;
	}

	if(k == TabKey){
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == LeftKey && s.focus != IcViewCommon->SearchFocusInput){
		focusprev();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == RightKey && s.focus != IcViewCommon->SearchFocusInput){
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(s.focus == IcViewCommon->SearchFocusInput){
		if(k == CtrlDownKey){
			if(s.inputhistoryitems != nil && len s.inputhistoryitems > 0){
				s.inputhistoryopen = 1;
				if(s.inputhistorysel < 0)
					s.inputhistorysel = 0;
				draw(u, parentid, w, h);
			}
			return IcViewCommon->SearchNone;
		}

		if(k == LeftKey){
			s.inputpos--;
			clampinputpos();
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == RightKey){
			s.inputpos++;
			clampinputpos();
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == BackspaceKey){
			backspacechar();
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == DeleteKey){
			deletechar();
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(printable(k)){
			insertchar(k);
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(k == EnterKey || k == ReturnKey){
			savehistory();
			close(u);
			return IcViewCommon->SearchForward;
		}
	}

	if(k == SpaceKey){
		r = togglefocus();
		if(r){
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(s.focus == IcViewCommon->SearchFocusForward){
			savehistory();
			close(u);
			return IcViewCommon->SearchForward;
		}
		if(s.focus == IcViewCommon->SearchFocusBackward){
			savehistory();
			close(u);
			return IcViewCommon->SearchBackward;
		}
		if(s.focus == IcViewCommon->SearchFocusCancel){
			close(u);
			return IcViewCommon->SearchCancel;
		}
	}

	if(k == EnterKey || k == ReturnKey){
		if(s.focus == IcViewCommon->SearchFocusCase ||
		   s.focus == IcViewCommon->SearchFocusBackward ||
		   s.focus == IcViewCommon->SearchFocusWrap ||
		   s.focus == IcViewCommon->SearchFocusRegex ||
		   s.focus == IcViewCommon->SearchFocusAnyEncoding){
			togglefocus();
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(s.focus == IcViewCommon->SearchFocusForward){
			savehistory();
			close(u);
			return IcViewCommon->SearchForward;
		}
		if(s.focus == IcViewCommon->SearchFocusBackward){
			savehistory();
			close(u);
			return IcViewCommon->SearchBackward;
		}
		if(s.focus == IcViewCommon->SearchFocusCancel){
			close(u);
			return IcViewCommon->SearchCancel;
		}
	}

	return IcViewCommon->SearchNone;
}


debugstate(): string
{
	return "ES active=" + string s.active
		+ " stage=" + string animstage
		+ " wait=" + string animwait;
}
