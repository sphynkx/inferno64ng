implement IcSsSetup;

include "ic/sssetup.m";

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
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
	bringtofront: fn(t: ref IcView->Tree, id: int): int;
	allocid: fn(t: ref IcView->Tree): int;
	removetree: fn(t: ref IcView->Tree, id: int): int;
};

IcScreenSaver: module
{
	PATH: con "/dis/ic/screensaver.dis";

	init: fn();

	available: fn(): array of string;
	titleof: fn(name: string): string;

	selected: fn(cfg: ref IcState->ConfigState): string;
	isenabled: fn(cfg: ref IcState->ConfigState): int;
	idlelimit: fn(cfg: ref IcState->ConfigState): int;

	setselected: fn(state: ref IcState->AppState, name: string): int;
	setenabled: fn(state: ref IcState->AppState, on: int): int;
	setidlelimit: fn(state: ref IcState->AppState, seconds: int): int;
	reload: fn(state: ref IcState->AppState): int;
};

IcScreenMod: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	rebuild: fn(state: ref IcState->AppState): int;
};

IcUserState: module
{
	PATH: con "/dis/ic/userstate.dis";

	init: fn();
	save: fn(state: ref IcState->AppState): int;
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;
screensaver: IcScreenSaver;
screen: IcScreenMod;
userstate: IcUserState;

DefaultBaseCode: con "38;2;20;20;20;48;2;210;210;210";
DefaultFrameCode: con "38;2;20;20;20;48;2;210;210;210";
DefaultFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";
DefaultFieldCode: con "38;2;20;20;20;48;2;245;245;245";
DefaultCursorCode: con "1;38;2;255;255;255;48;2;30;90;150";
DefaultButtonCode: con "1;38;2;20;20;20;48;2;235;235;235";

Kesc: con 27;
Kenter: con 10;
Kreturn: con 13;
Ktab: con 9;
Kup: con 57362;
Kdown: con 57363;
Kleft: con 57364;
Kright: con 57365;
Kbackspace: con 8;
Kdelete: con 127;
Kspace: con 32;

FocusEnabled: con 0;
FocusIdle: con 1;
FocusList: con 2;
FocusOk: con 3;
FocusCancel: con 4;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;

SetupBoxW: con 46;
SetupBoxMinH: con 12;

activeflag: int;
animstage: int;
animwait: int;

shadowid: int;
itemids: array of int;

availablelist: array of string;
selectedindex: int;
enabledvalue: int;
idleinput: string;
idlecursor: int;
focus: int;

basecode: fn(state: ref IcState->AppState): string;
framecode: fn(state: ref IcState->AppState): string;
focuscode: fn(state: ref IcState->AppState): string;
fieldcode: fn(state: ref IcState->AppState): string;
cursorcode: fn(state: ref IcState->AppState): string;
buttoncode: fn(state: ref IcState->AppState): string;
animticks: fn(state: ref IcState->AppState): int;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
ensureids: fn(state: ref IcState->AppState, count: int);
hideall: fn(state: ref IcState->AppState);
setlabel: fn(state: ref IcState->AppState, id, x, y, w: int, text, code: string);
showshadow: fn(state: ref IcState->AppState, x, y, w, h: int);
boxline: fn(w: int, left, mid, right: string): string;
fillline: fn(w: int): string;

geometry: fn(state: ref IcState->AppState): (int, int, int, int);
drawshadow: fn(state: ref IcState->AppState): int;
drawwindow: fn(state: ref IcState->AppState): int;
drawidlefield: fn(state: ref IcState->AppState, x, y, w: int);

syncfromconfig: fn(state: ref IcState->AppState);
applychanges: fn(state: ref IcState->AppState): int;
findselectedindex: fn(name: string): int;
isdigit: fn(c: int): int;
focusnext: fn();
focusprev: fn();
idleinsert: fn(ch: int);
idlebackspace: fn();
idledelete: fn();

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

	screensaver = load IcScreenSaver IcScreenSaver->PATH;
	if(screensaver == nil)
		raise "fail:load ic/screensaver";

	screen = load IcScreenMod IcScreenMod->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	userstate = load IcUserState IcUserState->PATH;
	if(userstate == nil)
		raise "fail:load ic/userstate";

	ui->init();
	view->init();
	screensaver->init();
	screen->init();
	userstate->init();

	activeflag = 0;
	animstage = StageNone;
	animwait = 0;

	shadowid = -1;
	itemids = array[0] of int;

	availablelist = array[0] of string;
	selectedindex = 0;
	enabledvalue = 1;
	idleinput = "30";
	idlecursor = len idleinput;
	focus = FocusEnabled;
}

basecode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modaltextcode != "")
		return state.theme.modaltextcode;
	return DefaultBaseCode;
}

framecode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modalframecode != "")
		return state.theme.modalframecode;
	return DefaultFrameCode;
}

focuscode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modalfocuscode != "")
		return state.theme.modalfocuscode;
	return DefaultFocusCode;
}

fieldcode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modalfieldcode != "")
		return state.theme.modalfieldcode;
	return DefaultFieldCode;
}

cursorcode(state: ref IcState->AppState): string
{
	return DefaultCursorCode;
}

buttoncode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modalbuttoncode != "")
		return state.theme.modalbuttoncode;
	return DefaultButtonCode;
}

animticks(state: ref IcState->AppState): int
{
	if(state != nil && state.theme != nil && state.theme.modalanimticks >= 0)
		return state.theme.modalanimticks;

	return 0;
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

boxline(w: int, left, mid, right: string): string
{
	if(w < 2)
		return left + right;

	return left + fittext(mid, w - 2) + right;
}

fillline(w: int): string
{
	return boxline(w, "│", "", "│");
}

ensureids(state: ref IcState->AppState, count: int)
{
	i: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	if(shadowid <= 0)
		shadowid = view->allocid(state.ui.tree);

	if(itemids != nil && len itemids >= count)
		return;

	itemids = array[count] of int;
	for(i = 0; i < count; i++)
		itemids[i] = view->allocid(state.ui.tree);
}

hideall(state: ref IcState->AppState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	n = view->find(state.ui.tree, shadowid);
	if(n != nil)
		view->hide(n);

	if(itemids != nil){
		for(i = 0; i < len itemids; i++){
			n = view->find(state.ui.tree, itemids[i]);
			if(n != nil)
				view->hide(n);
		}
	}
}

setlabel(state: ref IcState->AppState, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || id <= 0 || w <= 0)
		return;

	if(view->find(state.ui.tree, id) == nil)
		ui->label(state.ui, state.mainid, id, x, y, w, text);

	n = view->find(state.ui.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
	view->bringtofront(state.ui.tree, id);
}

showshadow(state: ref IcState->AppState, x, y, w, h: int)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || shadowid <= 0)
		return;

	if(view->find(state.ui.tree, shadowid) == nil)
		ui->node(state.ui, state.mainid, shadowid, "shadow", x, y, w, h);

	n = view->find(state.ui.tree, shadowid);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, h);
	view->show(n);
	view->bringtofront(state.ui.tree, shadowid);
}

geometry(state: ref IcState->AppState): (int, int, int, int)
{
	w, h, x, y, need: int;

	need = 11 + len availablelist;
	if(need < SetupBoxMinH)
		need = SetupBoxMinH;

	w = SetupBoxW;
	if(state != nil && w > state.width - 4)
		w = state.width - 4;
	if(w < 30)
		w = 30;

	h = need;
	if(state != nil && h > state.height - 2)
		h = state.height - 2;
	if(h < 10)
		h = 10;

	x = 0;
	y = 0;

	if(state != nil){
		x = (state.width - w) / 2;
		y = (state.height - h) / 2;
	}

	return (x, y, w, h);
}

findselectedindex(name: string): int
{
	i: int;

	for(i = 0; i < len availablelist; i++){
		if(availablelist[i] == name)
			return i;
	}

	return 0;
}

syncfromconfig(state: ref IcState->AppState)
{
	if(state == nil || state.cfg == nil)
		return;

	availablelist = screensaver->available();
	selectedindex = findselectedindex(screensaver->selected(state.cfg));
	enabledvalue = screensaver->isenabled(state.cfg);
	idleinput = string screensaver->idlelimit(state.cfg);
	idlecursor = len idleinput;

	if(idleinput == ""){
		idleinput = "30";
		idlecursor = len idleinput;
	}
}

active(state: ref IcState->AppState): int
{
	state = state;
	return activeflag;
}

open(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	syncfromconfig(state);
	activeflag = 1;
	animwait = 0;
	focus = FocusEnabled;

	if(animticks(state) > 0)
		animstage = StageShadow;
	else
		animstage = StageWindow;

	return build(state);
}

close(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	activeflag = 0;
	animstage = StageNone;
	animwait = 0;
	hideall(state);
	return 0;
}

isdigit(c: int): int
{
	return c >= '0' && c <= '9';
}

focusnext()
{
	focus++;
	if(focus > FocusCancel)
		focus = FocusEnabled;
}

focusprev()
{
	focus--;
	if(focus < FocusEnabled)
		focus = FocusCancel;
}

idleinsert(ch: int)
{
	s: string;

	s = sys->sprint("%c", ch);
	idleinput = idleinput[0:idlecursor] + s + idleinput[idlecursor:];
	idlecursor++;
}

idlebackspace()
{
	if(idlecursor <= 0)
		return;

	idleinput = idleinput[0:idlecursor - 1] + idleinput[idlecursor:];
	idlecursor--;

	if(idleinput == ""){
		idleinput = "0";
		idlecursor = 1;
	}
}

idledelete()
{
	if(idlecursor >= len idleinput)
		return;

	idleinput = idleinput[0:idlecursor] + idleinput[idlecursor + 1:];

	if(idleinput == ""){
		idleinput = "0";
		idlecursor = 1;
	}
}

applychanges(state: ref IcState->AppState): int
{
	seconds: int;

	if(state == nil || state.cfg == nil)
		return -1;

	seconds = int idleinput;
	if(seconds < 0)
		seconds = 0;

	screensaver->setenabled(state, enabledvalue);
	screensaver->setidlelimit(state, seconds);

	if(selectedindex >= 0 && selectedindex < len availablelist)
		screensaver->setselected(state, availablelist[selectedindex]);

	screensaver->reload(state);
	userstate->save(state);
	screen->rebuild(state);

	return 0;
}

drawshadow(state: ref IcState->AppState): int
{
	x, y, w, h: int;

	if(state == nil || state.ui == nil || !activeflag)
		return 0;

	(x, y, w, h) = geometry(state);
	ensureids(state, 128 + len availablelist);
	hideall(state);

	showshadow(state, x + 2, y + 1, w, h);
	return 0;
}

drawidlefield(state: ref IcState->AppState, x, y, w: int)
{
	prefix, before, cursorch, after: string;
	px, fieldx, fieldw: int;

	prefix = "Idle seconds: ";
	fieldw = w - 4 - len prefix;
	if(fieldw < 1)
		fieldw = 1;

	px = x + 2;
	fieldx = px + len prefix;

	setlabel(state, itemids[80], px, y, len prefix, prefix, basecode(state));
	setlabel(state, itemids[81], fieldx, y, fieldw, spaces(fieldw), fieldcode(state));

	before = idleinput[0:idlecursor];
	after = idleinput[idlecursor:];

	if(before != "")
		setlabel(state, itemids[82], fieldx, y, len before, before, fieldcode(state));

	if(idlecursor < len idleinput)
		cursorch = idleinput[idlecursor:idlecursor + 1];
	else
		cursorch = " ";

	setlabel(state, itemids[83], fieldx + idlecursor, y, 1, cursorch, cursorcode(state));

	if(after != "" && idlecursor + 1 < len idleinput)
		setlabel(state, itemids[84], fieldx + idlecursor + 1, y, len idleinput - idlecursor - 1, idleinput[idlecursor + 1:], fieldcode(state));
}

drawwindow(state: ref IcState->AppState): int
{
	x, y, w, h, i, line: int;
	normal, focusc, buttonc, framec: string;
	s, mark: string;

	if(state == nil || state.ui == nil || !activeflag)
		return 0;

	(x, y, w, h) = geometry(state);
	ensureids(state, 128 + len availablelist);
	hideall(state);

	showshadow(state, x + 2, y + 1, w, h);

	normal = basecode(state);
	focusc = focuscode(state);
	buttonc = buttoncode(state);
	framec = framecode(state);

	setlabel(state, itemids[0], x, y, w, boxline(w, "┌", " Screensavers ", "┐"), framec);

	line = 1;
	while(line < h - 1){
		setlabel(state, itemids[line], x, y + line, w, fillline(w), normal);
		line++;
	}

	setlabel(state, itemids[h - 1], x, y + h - 1, w, boxline(w, "└", "", "┘"), framec);

	line = y + 2;

	s = "[ ] Enable screensavers";
	if(enabledvalue)
		s = "[x] Enable screensavers";
	if(focus == FocusEnabled)
		setlabel(state, itemids[32], x + 2, line, w - 4, s, focusc);
	else
		setlabel(state, itemids[32], x + 2, line, w - 4, s, normal);

	line++;

	if(focus == FocusIdle)
		drawidlefield(state, x, line, w);
	else
		setlabel(state, itemids[33], x + 2, line, w - 4, "Idle seconds: " + idleinput, normal);

	line += 2;

	setlabel(state, itemids[34], x + 2, line, w - 4, "Available screensavers:", normal);
	line++;

	for(i = 0; i < len availablelist && line < y + h - 3; i++){
		mark = "( ) ";
		if(i == selectedindex)
			mark = "(o) ";

		s = mark + screensaver->titleof(availablelist[i]);

		if(focus == FocusList && i == selectedindex)
			setlabel(state, itemids[35 + i], x + 4, line, w - 8, s, focusc);
		else
			setlabel(state, itemids[35 + i], x + 4, line, w - 8, s, normal);

		line++;
	}

	if(focus == FocusOk)
		setlabel(state, itemids[64], x + 2, y + h - 2, 8, "[ OK ]", focusc);
	else
		setlabel(state, itemids[64], x + 2, y + h - 2, 8, "[ OK ]", buttonc);

	if(focus == FocusCancel)
		setlabel(state, itemids[65], x + 12, y + h - 2, 12, "[ Cancel ]", focusc);
	else
		setlabel(state, itemids[65], x + 12, y + h - 2, 12, "[ Cancel ]", buttonc);

	return 0;
}

build(state: ref IcState->AppState): int
{
	if(state == nil || state.ui == nil || !activeflag)
		return 0;

	if(animstage == StageShadow)
		return drawshadow(state);

	return drawwindow(state);
}

handletick(state: ref IcState->AppState): int
{
	delay: int;

	if(state == nil || !activeflag)
		return 0;

	if(animstage != StageShadow)
		return 0;

	delay = animticks(state);
	if(delay <= 0)
		delay = 1;

	animwait++;
	if(animwait < delay)
		return 0;

	animwait = 0;
	animstage = StageWindow;
	build(state);

	return 1;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	if(state == nil || !activeflag)
		return 0;

	if(animstage != StageWindow)
		return 1;

	if(k == Kesc){
		close(state);
		return 1;
	}

	if(focus == FocusList){
		if(k == Kup){
			selectedindex--;
			if(selectedindex < 0)
				selectedindex = len availablelist - 1;
			build(state);
			return 1;
		}

		if(k == Kdown){
			selectedindex++;
			if(selectedindex >= len availablelist)
				selectedindex = 0;
			build(state);
			return 1;
		}
	}

	if(focus == FocusIdle){
		if(k == Kleft){
			if(idlecursor > 0)
				idlecursor--;
			build(state);
			return 1;
		}

		if(k == Kright){
			if(idlecursor < len idleinput)
				idlecursor++;
			build(state);
			return 1;
		}
	}else{
		if(k == Kleft){
			focusprev();
			build(state);
			return 1;
		}

		if(k == Kright){
			focusnext();
			build(state);
			return 1;
		}
	}

	if(k == Ktab){
		focusnext();
		build(state);
		return 1;
	}

	if(k == Kup && focus != FocusList){
		focusprev();
		build(state);
		return 1;
	}

	if(k == Kdown && focus != FocusList){
		focusnext();
		build(state);
		return 1;
	}

	if(focus == FocusEnabled && k == Kspace){
		enabledvalue = !enabledvalue;
		build(state);
		return 1;
	}

	if(focus == FocusIdle){
		if(k == Kbackspace){
			idlebackspace();
			build(state);
			return 1;
		}

		if(k == Kdelete){
			idledelete();
			build(state);
			return 1;
		}

		if(isdigit(k)){
			if(idleinput == "0"){
				idleinput = "";
				idlecursor = 0;
			}
			idleinsert(k);
			build(state);
			return 1;
		}
	}

	if(k == Kenter || k == Kreturn){
		if(focus == FocusCancel){
			close(state);
			return 1;
		}

		if(focus == FocusOk){
			applychanges(state);
			close(state);
			return 1;
		}

		if(focus == FocusEnabled){
			enabledvalue = !enabledvalue;
			build(state);
			return 1;
		}

		focusnext();
		build(state);
		return 1;
	}

	return 1;
}