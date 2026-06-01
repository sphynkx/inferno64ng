implement IcSearchDialog;

include "ic/searchdialog.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";
	init: fn();
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	group: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
	window: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, title: string): int;
	shadowwindow: fn(u: ref IcUi->Ui, parentid, shadowid, id: int, x, y, w, h: int, title: string, dx, dy: int): int;
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

s: IcViewCommon->SearchDialogState;
style: Style;
hist: ref IcInputHistoryMod->History;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

animstage: int;
animwait: int;

HistorySection: con "search_dialog";
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

initstyle: fn();
setstylevalue: fn(cur, next: string): string;
animticks: fn(): int;

ensureids: fn(u: ref IcUi->Ui);
resetwindowids: fn();
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(v: string, w: int): string;
trim: fn(v: string): string;
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

	resetstyle();

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

	animstage = StageNone;
	animwait = 0;
}

resetstyle()
{
	initstyle();
}

debugstate(): string
{
	return "SD active=" + string s.active
		+ " alert=" + string s.alert
		+ " stage=" + string animstage
		+ " wait=" + string animwait
		+ " anim=" + string style.animticks
		+ " windowcode=" + style.windowcode
		+ " framecode=" + style.framecode;
}

initstyle()
{
	style.windowcode = "38;2;20;20;20;48;2;210;210;210";
	style.framecode = "1;38;2;35;35;35;48;2;210;210;210";
	style.textcode = "38;2;20;20;20;48;2;210;210;210";
	style.fieldcode = "1;38;2;255;255;255;48;2;55;160;220";
	style.fieldfocuscode = "1;38;2;255;255;255;48;2;35;135;205";
	style.focuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.cursorcode = "1;38;2;255;255;255;48;2;220;80;40";
	style.buttoncode = "1;38;2;20;20;20;48;2;235;235;235";
	style.buttonfocuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.disabledcode = "38;2;120;120;120;48;2;210;210;210";
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
	style.fieldcode = setstylevalue(style.fieldcode, arg.fieldcode);
	style.fieldfocuscode = setstylevalue(style.fieldfocuscode, arg.fieldfocuscode);
	style.focuscode = setstylevalue(style.focuscode, arg.focuscode);
	style.cursorcode = setstylevalue(style.cursorcode, arg.cursorcode);
	style.buttoncode = setstylevalue(style.buttoncode, arg.buttoncode);
	style.buttonfocuscode = setstylevalue(style.buttonfocuscode, arg.buttonfocuscode);
	style.disabledcode = setstylevalue(style.disabledcode, arg.disabledcode);
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

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	loadhistory();

	resetwindowids();
	ensureids(u);
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

	if(animticks() > 0){
		animstage = StageShadow;
		animwait = 0;
	}else{
		animstage = StageWindow;
		animwait = 0;
	}

	resetwindowids();
	ensureids(u);
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

	s.windowid = -1;
	s.inputid = -1;

	if(s.optionids == nil || len s.optionids != 5)
		s.optionids = array[5] of int;

	s.optionids[0] = -1;
	s.optionids[1] = -1;
	s.optionids[2] = -1;
	s.optionids[3] = -1;
	s.optionids[4] = -1;

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	s.buttonids[0] = -1;
	s.buttonids[1] = -1;
	s.buttonids[2] = -1;
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

trim(v: string): string
{
	a, b: int;

	a = 0;
	b = len v;

	while(a < b && (v[a] == ' ' || v[a] == '\t' || v[a] == '\n' || v[a] == '\r'))
		a++;

	while(b > a && (v[b - 1] == ' ' || v[b - 1] == '\t' || v[b - 1] == '\n' || v[b - 1] == '\r'))
		b--;

	if(a >= b)
		return "";

	return v[a:b];
}

topframe(w: int, title: string): string
{
	prefix: string;
	n: int;

	prefix = style.framenw + " " + title + " ";
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
		+ "base=" + style.cursorcode + "\n";
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

	v = trim(s.input);
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
			view->setcode(n, style.focuscode);
		else
			view->setcode(n, style.fieldcode);
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
		return style.focuscode;

	return style.textcode;
}

buttoncode(focus: int): string
{
	if(s.focus == focus)
		return style.buttonfocuscode;

	return style.buttoncode;
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
	if(k < 32)
		return 0;

	if(k >= 57344)
		return 0;

	return 1;
}

focusnext()
{
	s.focus++;
	if(s.focus > IcViewCommon->SearchFocusCancel)
		s.focus = IcViewCommon->SearchFocusInput;
}

focusprev()
{
	s.focus--;
	if(s.focus < IcViewCommon->SearchFocusInput)
		s.focus = IcViewCommon->SearchFocusCancel;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	if(!s.active)
		return IcViewCommon->SearchNone;

	if(s.alert){
		if(k == EscapeKey || k == EnterKey || k == ReturnKey || k == SpaceKey){
			s.result = IcViewCommon->SearchAlertClosed;
			return s.result;
		}

		return IcViewCommon->SearchNone;
	}

	if(k == EscapeKey){
		s.inputhistoryopen = 0;
		s.inputhistorysel = -1;
		hidehistory(u);
		s.result = IcViewCommon->SearchCancel;
		return s.result;
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

		if(k == DownKey && s.inputhistoryopen){
			if(s.inputhistoryitems != nil && len s.inputhistoryitems > 0){
				if(s.inputhistorysel < 0)
					s.inputhistorysel = 0;
				else if(s.inputhistorysel + 1 < len s.inputhistoryitems)
					s.inputhistorysel++;
				else
					s.inputhistorysel = 0;
				draw(u, parentid, w, h);
			}
			return IcViewCommon->SearchNone;
		}

		if(k == UpKey && s.inputhistoryopen){
			if(s.inputhistoryitems != nil && len s.inputhistoryitems > 0){
				if(s.inputhistorysel < 0)
					s.inputhistorysel = len s.inputhistoryitems - 1;
				else if(s.inputhistorysel > 0)
					s.inputhistorysel--;
				else
					s.inputhistorysel = len s.inputhistoryitems - 1;
				draw(u, parentid, w, h);
			}
			return IcViewCommon->SearchNone;
		}
	}

	if(k == TabKey || (k == DownKey && !s.inputhistoryopen)){
		s.inputhistoryopen = 0;
		s.inputhistorysel = -1;
		hidehistory(u);
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == UpKey && !s.inputhistoryopen){
		focusprev();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == LeftKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			hidehistory(u);
			s.inputpos--;
			clampinputpos();
		}else
			focusprev();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == RightKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			hidehistory(u);
			s.inputpos++;
			clampinputpos();
		}else
			focusnext();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == BackspaceKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			hidehistory(u);
			backspacechar();
		}

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == DeleteKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			hidehistory(u);
			deletechar();
		}

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(s.focus == IcViewCommon->SearchFocusInput && printable(k)){
		s.inputhistoryopen = 0;
		s.inputhistorysel = -1;
		hidehistory(u);
		insertchar(k);
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == SpaceKey){
		if(togglefocus()){
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(s.focus == IcViewCommon->SearchFocusForward){
			savehistory();
			s.result = IcViewCommon->SearchForward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusBackwardButton){
			savehistory();
			s.result = IcViewCommon->SearchBackward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusCancel){
			s.result = IcViewCommon->SearchCancel;
			return s.result;
		}
	}

	if(k == EnterKey || k == ReturnKey){
		if(s.focus == IcViewCommon->SearchFocusInput && s.inputhistoryopen){
			if(s.inputhistoryitems != nil && len s.inputhistoryitems > 0 && s.inputhistorysel >= 0 && s.inputhistorysel < len s.inputhistoryitems){
				s.input = s.inputhistoryitems[s.inputhistorysel];
				s.inputpos = len s.input;
			}
			s.inputhistoryopen = 0;
			s.inputhistorysel = -1;
			hidehistory(u);
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(s.focus == IcViewCommon->SearchFocusInput || s.focus == IcViewCommon->SearchFocusForward){
			savehistory();
			s.result = IcViewCommon->SearchForward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusBackwardButton){
			savehistory();
			s.result = IcViewCommon->SearchBackward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusCancel){
			s.result = IcViewCommon->SearchCancel;
			return s.result;
		}

		if(togglefocus()){
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}
	}

	return IcViewCommon->SearchNone;
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
	bodyw, bx, row, bgid, cpos: int;
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

	if(ui->node(u, parentid, s.shadowid, "shadow", x + 2, y + 1, w, h) < 0)
		return -1;

	if(ui->node(u, parentid, s.windowid, "group", x, y, w, h) < 0)
		return -1;

	n = view->find(u.tree, s.windowid);
	if(n != nil && style.windowcode != "")
		view->setcode(n, style.windowcode);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w,
		topframe(w, "Search"), style.framecode);

	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}

	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w,
		bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	setlabel(u, s.windowid, view->allocid(u.tree), 4, 1, bodyw,
		"Find:", style.textcode);

	if(s.focus == IcViewCommon->SearchFocusInput)
		setlabel(u, s.windowid, s.inputid, 4, 2, bodyw,
			fieldtext(bodyw), style.fieldfocuscode);
	else
		setlabel(u, s.windowid, s.inputid, 4, 2, bodyw,
			fieldtext(bodyw), style.fieldcode);

	n = view->find(u.tree, s.inputid);
	if(n != nil){
		n.styles = array[0] of string;

		if(s.focus == IcViewCommon->SearchFocusInput && !s.inputhistoryopen){
			cpos = fieldcursorpos(bodyw);
			n.styles = array[] of {
				"",
				cursoroverlay(cpos)
			};
		}
	}

	setlabel(u, s.windowid, s.optionids[0], 4, 4, bodyw,
		checkbox(s.case_sensitive, "Case sensitive"),
		optioncode(IcViewCommon->SearchFocusCase));

	setlabel(u, s.windowid, s.optionids[1], 4, 5, bodyw,
		checkbox(s.backward, "Backward"),
		optioncode(IcViewCommon->SearchFocusBackward));

	setlabel(u, s.windowid, s.optionids[2], 4, 6, bodyw,
		checkbox(s.wrap, "Wrap search"),
		optioncode(IcViewCommon->SearchFocusWrap));

	setlabel(u, s.windowid, s.optionids[3], 4, 7, bodyw,
		checkbox(s.regex, "Regex"),
		optioncode(IcViewCommon->SearchFocusRegex));

	setlabel(u, s.windowid, s.optionids[4], 4, 8, bodyw,
		checkbox(s.anyencoding, "Any encoding"),
		optioncode(IcViewCommon->SearchFocusAnyEncoding));

	setlabel(u, s.windowid, view->allocid(u.tree), 4, 9, bodyw,
		"Encoding: " + s.encoding,
		style.disabledcode);

	bx = (w - 39) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, s.windowid, s.buttonids[0], bx, 11, 13,
		buttontext(0),
		buttoncode(IcViewCommon->SearchFocusForward));

	setlabel(u, s.windowid, s.buttonids[1], bx + 15, 11, 12,
		buttontext(1),
		buttoncode(IcViewCommon->SearchFocusBackwardButton));

	setlabel(u, s.windowid, s.buttonids[2], bx + 29, 11, 10,
		buttontext(2),
		buttoncode(IcViewCommon->SearchFocusCancel));

	drawhistory(u);

	view->bringtofront(u.tree, s.shadowid);
	view->bringtofront(u.tree, s.windowid);

	return 0;
}

drawalert(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, bx, row, bgid: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);

	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = view->allocid(u.tree);
	s.windowid = view->allocid(u.tree);

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	s.buttonids[0] = view->allocid(u.tree);
	s.buttonids[1] = -1;
	s.buttonids[2] = -1;

	if(ui->node(u, parentid, s.shadowid, "shadow", x + 2, y + 1, w, h) < 0)
		return -1;

	if(ui->node(u, parentid, s.windowid, "group", x, y, w, h) < 0)
		return -1;

	n = view->find(u.tree, s.windowid);
	if(n != nil && style.windowcode != "")
		view->setcode(n, style.windowcode);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w,
		topframe(w, "Search"), style.framecode);

	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}

	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w,
		bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	setlabel(u, s.windowid, view->allocid(u.tree), 4, 2, bodyw,
		s.alerttext, style.textcode);

	bx = (w - 6) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, s.windowid, s.buttonids[0], bx, 4, 6,
		"[ OK ]", style.buttonfocuscode);

	view->bringtofront(u.tree, s.shadowid);
	view->bringtofront(u.tree, s.windowid);

	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	x, y, dw, dh: int;

	if(u == nil || u.tree == nil || !s.active)
		return 0;

	if(s.alert)
		dh = 7;
	else
		dh = 14;

	dw = 58;

	if(dw > w - 4)
		dw = w - 4;
	if(dw < 34)
		dw = 34;

	if(dh > h - 2)
		dh = h - 2;
	if(dh < 5)
		dh = 5;

	x = (w - dw) / 2;
	y = (h - dh) / 2;

	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	s.x = x;
	s.y = y;
	s.w = dw;
	s.h = dh;

	if(animstage == StageShadow || animstage == StageClosingShadow){
		drawshadow(u, parentid, x, y, dw, dh);
		return 1;
	}

	if(animstage != StageWindow)
		animstage = StageWindow;

	if(s.alert)
		return drawalert(u, parentid, x, y, dw, dh);

	return drawwindow(u, parentid, x, y, dw, dh);
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	delay: int;

	if(!s.active)
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
		s.active = 0;
		s.result = IcViewCommon->SearchNone;
		animstage = StageNone;
		animwait = 0;
		resetwindowids();
		return 1;
	}

	return 0;
}
