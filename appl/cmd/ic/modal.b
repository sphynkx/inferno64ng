implement IcModal;

include "ic/modal.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
	modal: fn(u: ref IcUi->Ui, parentid, shadowid, id: int, x, y, w, h: int, title, message, inputlabel, input, checkbox: string, checked, focus, kind: int, button0, button1, button2: string, buttoncount, dx, dy: int, styles: array of string): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	allocid: fn(t: ref IcView->Tree): int;
	removetree: fn(t: ref IcView->Tree, id: int): int;
	showtree: fn(t: ref IcView->Tree, id: int);
	hidetree: fn(t: ref IcView->Tree, id: int);
	bringtofront: fn(t: ref IcView->Tree, id: int): int;
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
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
	savehist: fn(h: ref History): int;
	add: fn(h: ref History, text: string): int;
	count: fn(h: ref History): int;
	current: fn(h: ref History): string;
	prev: fn(h: ref History): string;
	next: fn(h: ref History): string;
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;

histmod: IcInputHistoryMod;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

TabKey: con 9;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;
BackspaceKey: con 8;
DeleteKey: con 127;
LeftKey: con 57364;
RightKey: con 57365;
HomeKey: con 57360;
EndKey: con 57361;
UpKey: con 57362;
DownKey: con 57363;
CtrlDownKey: con 57811;

initstate: fn(state: ref IcState->AppState);
disposewindow: fn(state: ref IcState->AppState);
resetids: fn(m: ref IcState->ModalState);
maxint: fn(a, b: int): int;
fitw: fn(state: ref IcState->AppState, w: int): int;
animticks: fn(state: ref IcState->AppState): int;
checkboxtext: fn(m: ref IcState->ModalState): string;
buttonlabel: fn(s: string): string;
buttonw: fn(s: string): int;
buttonstotalw: fn(m: ref IcState->ModalState): int;
measure: fn(state: ref IcState->AppState);
stylecodes: fn(state: ref IcState->AppState): array of string;
draw: fn(state: ref IcState->AppState): int;
drawshadow: fn(state: ref IcState->AppState): int;
drawwindow: fn(state: ref IcState->AppState): int;
drawframe: fn(state: ref IcState->AppState, id, w, h: int, title: string);
drawlabel: fn(state: ref IcState->AppState, parentid, id, x, y, w: int, text, code: string);
fieldbasecode: fn(state: ref IcState->AppState, focused: int): string;
fieldtextwidth: fn(m: ref IcState->ModalState): int;
fieldcursorpos: fn(m: ref IcState->ModalState): int;
cursoroverlay: fn(state: ref IcState->AppState, pos: int): string;
buttoncode: fn(state: ref IcState->AppState, focused: int): string;
checkboxcode: fn(state: ref IcState->AppState, focused: int): string;
focusmin: fn(m: ref IcState->ModalState): int;
focusmax: fn(m: ref IcState->ModalState): int;
focusnext: fn(m: ref IcState->ModalState);
focusprev: fn(m: ref IcState->ModalState);
activatefocus: fn(m: ref IcState->ModalState): int;
hotkey: fn(k: int, h: string): int;
printable: fn(k: int): int;
clampinputpos: fn(m: ref IcState->ModalState);
inputhistorysection: fn(m: ref IcState->ModalState): string;
loadinputhistory: fn(m: ref IcState->ModalState);
saveinputhistory: fn(m: ref IcState->ModalState);
inputfieldtext: fn(m: ref IcState->ModalState): string;
inputhistorytext: fn(m: ref IcState->ModalState): string;
resetinputhistory: fn(m: ref IcState->ModalState);
ensureinputhistoryids: fn(state: ref IcState->AppState, rows: int): int;
hideinputhistory: fn(state: ref IcState->AppState);
drawinputhistory: fn(state: ref IcState->AppState);
sethistorylabel: fn(state: ref IcState->AppState, id, x, y, w: int, text, code: string);
inputmovehistory: fn(m: ref IcState->ModalState, dir: int);
setresult: fn(m: ref IcState->ModalState, r: int): int;
topframe: fn(w: int, title: string): string;
midframe: fn(w: int): string;
bottomframe: fn(w: int): string;
fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;

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
}

initstate(state: ref IcState->AppState)
{
	if(state == nil)
		return;

	if(state.modal != nil)
		return;

	state.modal = ref IcState->ModalState;
	state.modal.active = 0;
	state.modal.animating = 0;
	state.modal.animstage = StageNone;
	state.modal.animwait = 0;

	state.modal.kind = IcModal->KindNone;
	state.modal.title = "";
	state.modal.message = "";
	state.modal.inputlabel = "";
	state.modal.input = "";
	state.modal.inputpos = 0;
	state.modal.inputhistorysection = "";
	state.modal.inputhistoryopen = 0;
	state.modal.inputhistorysel = -1;
	state.modal.inputhistoryitems = array[0] of string;
	state.modal.inputhistoryids = array[0] of int;
	state.modal.checkbox = "";
	state.modal.checked = 0;

	state.modal.focus = IcModal->FocusButton0;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 0;
	state.modal.button0 = "";
	state.modal.button1 = "";
	state.modal.button2 = "";

	state.modal.hotkey0 = "";
	state.modal.hotkey1 = "";
	state.modal.hotkey2 = "";

	state.modal.x = 0;
	state.modal.y = 0;
	state.modal.w = 0;
	state.modal.h = 0;

	state.modal.shadowid = -1;
	state.modal.canvasid = -1;
}

resetids(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	m.shadowid = -1;
	m.canvasid = -1;
}

active(state: ref IcState->AppState): int
{
	if(state == nil || state.modal == nil)
		return 0;

	return state.modal.active != 0;
}

disposewindow(state: ref IcState->AppState)
{
	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return;

	if(state.modal.canvasid >= 0)
		view->removetree(state.ui.tree, state.modal.canvasid);

	if(state.modal.shadowid >= 0)
		view->removetree(state.ui.tree, state.modal.shadowid);

	resetids(state.modal);
}

close(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	initstate(state);

	if(animticks(state) > 0 && state.modal.animstage == StageWindow){
		if(state.ui != nil && state.ui.tree != nil && state.modal.canvasid >= 0)
			view->removetree(state.ui.tree, state.modal.canvasid);

		state.modal.canvasid = -1;
		state.modal.active = 0;
		state.modal.animating = 1;
		state.modal.animstage = StageClosingShadow;
		state.modal.animwait = 0;
		return 0;
	}

	disposewindow(state);

	state.modal.active = 0;
	state.modal.animating = 0;
	state.modal.animstage = StageNone;
	state.modal.kind = IcModal->KindNone;
	state.modal.result = IcModal->ResultNone;

	if(state.ui != nil && state.ui.tree != nil)
		view->hidetree(state.ui.tree, state.modalid);

	return 0;
}

maxint(a, b: int): int
{
	if(a > b)
		return a;
	return b;
}

fitw(state: ref IcState->AppState, w: int): int
{
	maxw: int;

	if(state == nil)
		return w;

	maxw = state.width - 4;
	if(maxw < 20)
		maxw = 20;

	if(w > maxw)
		w = maxw;

	if(w < 38)
		w = 38;

	return w;
}

animticks(state: ref IcState->AppState): int
{
	if(state != nil && state.theme != nil && state.theme.modalanimticks >= 0)
		return state.theme.modalanimticks;

	return 0;
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

midframe(w: int): string
{
	if(w < 2)
		return fittext("│", w);

	return "│" + spaces(w - 2) + "│";
}

bottomframe(w: int): string
{
	if(w < 2)
		return fittext("└", w);

	return "└" + fillstr(w - 2, "─") + "┘";
}

drawlabel(state: ref IcState->AppState, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || id < 0)
		return;

	if(view->find(state.ui.tree, id) == nil)
		ui->label(state.ui, parentid, id, x, y, w, text);

	n = view->find(state.ui.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

drawframe(state: ref IcState->AppState, id, w, h: int, title: string)
{
	row, lid: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	lid = view->allocid(state.ui.tree);
	drawlabel(state, id, lid, 0, 0, w, topframe(w, title), state.theme.modalframecode);

	for(row = 1; row < h - 1; row++){
		lid = view->allocid(state.ui.tree);
		drawlabel(state, id, lid, 0, row, w, midframe(w), state.theme.modalframecode);
	}

	lid = view->allocid(state.ui.tree);
	drawlabel(state, id, lid, 0, h - 1, w, bottomframe(w), state.theme.modalframecode);
}

fieldbasecode(state: ref IcState->AppState, focused: int): string
{
	if(state == nil || state.theme == nil)
		return "";

	focused = focused;
	return state.theme.modalfieldcode;
}

fieldtextwidth(m: ref IcState->ModalState): int
{
	fieldw, textw: int;

	if(m == nil)
		return 4;

	fieldw = m.w - 6;
	if(fieldw < 12)
		fieldw = 12;

	textw = fieldw - len "[v]" - 1;
	if(textw < 4)
		textw = 4;

	return textw;
}

fieldcursorpos(m: ref IcState->ModalState): int
{
	textw, start, cursor: int;

	if(m == nil)
		return 0;

	textw = fieldtextwidth(m);

	clampinputpos(m);

	cursor = m.inputpos;
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

cursoroverlay(state: ref IcState->AppState, pos: int): string
{
	base: string;

	base = "";
	if(state != nil && state.theme != nil)
		base = state.theme.modalcursorcode;

	return "cursor=1\n"
		+ "pos=" + string pos + "\n"
		+ "base=" + base + "\n";
}

buttoncode(state: ref IcState->AppState, focused: int): string
{
	if(state == nil || state.theme == nil)
		return "";

	if(focused)
		return state.theme.modalbuttonfocuscode;

	return state.theme.modalbuttoncode;
}

checkboxcode(state: ref IcState->AppState, focused: int): string
{
	if(state == nil || state.theme == nil)
		return "";

	if(focused)
		return state.theme.modalfocuscode;

	return state.theme.modaltextcode;
}

checkboxtext(m: ref IcState->ModalState): string
{
	if(m == nil || m.checkbox == "")
		return "";

	if(m.checked)
		return "[x] " + m.checkbox;

	return "[ ] " + m.checkbox;
}

buttonlabel(s: string): string
{
	return "[" + s + "]";
}

buttonw(s: string): int
{
	return len buttonlabel(s) + 2;
}

buttonstotalw(m: ref IcState->ModalState): int
{
	w: int;

	if(m == nil)
		return 0;

	w = 0;

	if(m.buttoncount > 0)
		w += buttonw(m.button0);
	if(m.buttoncount > 1)
		w += 2 + buttonw(m.button1);
	if(m.buttoncount > 2)
		w += 2 + buttonw(m.button2);

	return w;
}

measure(state: ref IcState->AppState)
{
	m: ref IcState->ModalState;
	w, h, fieldw: int;

	m = state.modal;

	w = len m.title + 8;
	w = maxint(w, len m.message + 6);

	fieldw = len m.inputlabel + len m.input + len "[v]" + 7;
	w = maxint(w, fieldw);

	w = maxint(w, len checkboxtext(m) + 6);
	w = maxint(w, buttonstotalw(m) + 6);
	w = fitw(state, w);

	h = 7;
	if(m.inputlabel != "")
		h += 2;
	if(m.checkbox != "")
		h += 2;

	m.w = w;
	m.h = h;
	m.x = (state.width - w) / 2;
	m.y = (state.height - h) / 2;

	if(m.x < 0)
		m.x = 0;
	if(m.y < 0)
		m.y = 0;
}

stylecodes(state: ref IcState->AppState): array of string
{
	a: array of string;

	a = array[9] of string;

	if(state == nil || state.theme == nil)
		return a;

	a[0] = state.theme.modalcopycode;
	a[1] = state.theme.modaloverwritecode;
	a[2] = state.theme.modalframecode;
	a[3] = state.theme.modaltextcode;
	a[4] = state.theme.modalfieldcode;
	a[5] = state.theme.modalfocuscode;
	a[6] = state.theme.modalbuttoncode;
	a[7] = state.theme.modalbuttonfocuscode;

	a[8] = "";

	return a;
}

drawshadow(state: ref IcState->AppState): int
{
	m: ref IcState->ModalState;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return -1;

	m = state.modal;

	if(m.shadowid >= 0)
		view->removetree(state.ui.tree, m.shadowid);

	m.shadowid = view->allocid(state.ui.tree);
	if(ui->node(state.ui, state.modalid, m.shadowid, "shadow", m.x + 2, m.y + 1, m.w, m.h) < 0)
		return -1;

	view->showtree(state.ui.tree, state.modalid);
	view->bringtofront(state.ui.tree, state.modalid);

	return 0;
}

drawwindow(state: ref IcState->AppState): int
{
	m: ref IcState->ModalState;
	bodyw, row, inputid, msgid, labelid, checkid, b0id, b1id, b2id: int;
	bx, y: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return -1;

	m = state.modal;

	if(m.canvasid >= 0)
		view->removetree(state.ui.tree, m.canvasid);

	if(m.shadowid >= 0)
		view->removetree(state.ui.tree, m.shadowid);

	m.shadowid = view->allocid(state.ui.tree);
	m.canvasid = view->allocid(state.ui.tree);

	if(ui->node(state.ui, state.modalid, m.shadowid, "shadow", m.x + 2, m.y + 1, m.w, m.h) < 0)
		return -1;

	if(ui->node(state.ui, state.modalid, m.canvasid, "group", m.x, m.y, m.w, m.h) < 0)
		return -1;

	drawframe(state, m.canvasid, m.w, m.h, m.title);

	bodyw = m.w - 4;
	if(bodyw < 1)
		bodyw = 1;

	row = 2;

	msgid = view->allocid(state.ui.tree);
	drawlabel(state, m.canvasid, msgid, 2, row, bodyw, m.message, state.theme.modaltextcode);
	row++;

	if(m.inputlabel != ""){
		labelid = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, labelid, 2, row, bodyw, m.inputlabel, state.theme.modaltextcode);
		row++;

		inputid = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, inputid, 2, row, bodyw, inputfieldtext(m),
			fieldbasecode(state, m.focus == IcModal->FocusInput));

		n = view->find(state.ui.tree, inputid);
		if(n != nil){
			n.styles = array[0] of string;

			if(m.focus == IcModal->FocusInput && !m.inputhistoryopen){
				n.styles = array[] of {
					"",
					cursoroverlay(state, fieldcursorpos(m))
				};
			}
		}

		row++;
	}

	if(m.checkbox != ""){
		checkid = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, checkid, 2, row, bodyw, checkboxtext(m),
			checkboxcode(state, m.focus == IcModal->FocusCheckbox));
		row += 2;
	}else
		row++;

	bx = (m.w - buttonstotalw(m)) / 2;
	if(bx < 2)
		bx = 2;

	y = m.h - 2;

	if(m.buttoncount > 0){
		b0id = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, b0id, bx, y, buttonw(m.button0),
			buttonlabel(m.button0),
			buttoncode(state, m.focus == IcModal->FocusButton0));
		bx += buttonw(m.button0) + 2;
	}

	if(m.buttoncount > 1){
		b1id = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, b1id, bx, y, buttonw(m.button1),
			buttonlabel(m.button1),
			buttoncode(state, m.focus == IcModal->FocusButton1));
		bx += buttonw(m.button1) + 2;
	}

	if(m.buttoncount > 2){
		b2id = view->allocid(state.ui.tree);
		drawlabel(state, m.canvasid, b2id, bx, y, buttonw(m.button2),
			buttonlabel(m.button2),
			buttoncode(state, m.focus == IcModal->FocusButton2));
	}

	drawinputhistory(state);

	view->showtree(state.ui.tree, state.modalid);
	view->bringtofront(state.ui.tree, state.modalid);

	m.animstage = StageWindow;
	return 0;
}

draw(state: ref IcState->AppState): int
{
	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return -1;

	initstate(state);
	measure(state);
	disposewindow(state);

	if(animticks(state) > 0){
		state.modal.animating = 1;
		state.modal.animstage = StageShadow;
		state.modal.animwait = 0;
		drawshadow(state);
		return 0;
	}

	state.modal.animating = 0;
	state.modal.animstage = StageWindow;
	return drawwindow(state);
}

showcopyconfirm(state: ref IcState->AppState, count: int, direction, target: string): int
{
	initstate(state);
	resetinputhistory(state.modal);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindCopyConfirm;
	state.modal.title = "Copy";
	state.modal.message = "Copy " + string count + " item(s)  " + direction;
	state.modal.inputlabel = "Copy to:";
	state.modal.input = target;
	state.modal.inputpos = len state.modal.input;
	loadinputhistory(state.modal);
	state.modal.checkbox = "Overwrite all";
	state.modal.checked = 0;
	state.modal.focus = IcModal->FocusInput;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 2;
	state.modal.button0 = "OK";
	state.modal.button1 = "Cancel";
	state.modal.button2 = "";

	state.modal.hotkey0 = "O";
	state.modal.hotkey1 = "C";
	state.modal.hotkey2 = "";

	return draw(state);
}

showmoveconfirm(state: ref IcState->AppState, count: int, direction, target: string): int
{
	initstate(state);
	resetinputhistory(state.modal);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindMoveConfirm;
	state.modal.title = "Move";
	state.modal.message = "Move " + string count + " item(s)  " + direction;
	state.modal.inputlabel = "Move to:";
	state.modal.input = target;
	state.modal.inputpos = len state.modal.input;
	loadinputhistory(state.modal);
	state.modal.checkbox = "Overwrite all";
	state.modal.checked = 0;
	state.modal.focus = IcModal->FocusInput;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 2;
	state.modal.button0 = "OK";
	state.modal.button1 = "Cancel";
	state.modal.button2 = "";

	state.modal.hotkey0 = "O";
	state.modal.hotkey1 = "C";
	state.modal.hotkey2 = "";

	return draw(state);
}

showdeleteconfirm(state: ref IcState->AppState, count: int, target: string): int
{
	initstate(state);
	resetinputhistory(state.modal);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindDeleteConfirm;
	state.modal.title = "Delete";
	state.modal.message = "Delete " + string count + " item(s)?";
	state.modal.inputlabel = "";
	state.modal.input = "";
	state.modal.inputpos = 0;
	state.modal.checkbox = "";
	state.modal.checked = 0;
	state.modal.focus = IcModal->FocusButton0;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 2;
	state.modal.button0 = "OK";
	state.modal.button1 = "Cancel";
	state.modal.button2 = "";

	state.modal.hotkey0 = "O";
	state.modal.hotkey1 = "C";
	state.modal.hotkey2 = "";

	target = target;
	return draw(state);
}

showmkdirconfirm(state: ref IcState->AppState, basepath: string): int
{
	initstate(state);
	resetinputhistory(state.modal);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindMkdirConfirm;
	state.modal.title = "Create directory";
	state.modal.message = "Create new directory";
	state.modal.inputlabel = "Name:";
	state.modal.input = "";
	state.modal.inputpos = 0;
	loadinputhistory(state.modal);
	state.modal.checkbox = "";
	state.modal.checked = 0;
	state.modal.focus = IcModal->FocusInput;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 2;
	state.modal.button0 = "OK";
	state.modal.button1 = "Cancel";
	state.modal.button2 = "";

	state.modal.hotkey0 = "O";
	state.modal.hotkey1 = "C";
	state.modal.hotkey2 = "";

	basepath = basepath;
	return draw(state);
}

showoverwrite(state: ref IcState->AppState, path: string): int
{
	initstate(state);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindOverwrite;
	state.modal.title = "Overwrite";
	state.modal.message = "Overwrite " + path + "?";
	state.modal.inputlabel = "";
	state.modal.input = "";
	state.modal.checkbox = "";
	state.modal.checked = 0;
	state.modal.focus = IcModal->FocusButton0;
	state.modal.result = IcModal->ResultNone;

	state.modal.buttoncount = 3;
	state.modal.button0 = "Overwrite";
	state.modal.button1 = "Skip";
	state.modal.button2 = "Cancel";

	state.modal.hotkey0 = "O";
	state.modal.hotkey1 = "S";
	state.modal.hotkey2 = "C";

	return draw(state);
}

focusmin(m: ref IcState->ModalState): int
{
	if(m != nil && m.inputlabel != "" &&
		(m.kind == IcModal->KindCopyConfirm ||
		 m.kind == IcModal->KindMoveConfirm ||
		 m.kind == IcModal->KindMkdirConfirm))
		return IcModal->FocusInput;

	if(m != nil && m.checkbox != "")
		return IcModal->FocusCheckbox;

	return IcModal->FocusButton0;
}

focusmax(m: ref IcState->ModalState): int
{
	if(m == nil)
		return IcModal->FocusButton0;

	if(m.buttoncount >= 3)
		return IcModal->FocusButton2;

	if(m.buttoncount >= 2)
		return IcModal->FocusButton1;

	return IcModal->FocusButton0;
}

focusnext(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	if(m.focus == IcModal->FocusInput){
		if(m.checkbox != "")
			m.focus = IcModal->FocusCheckbox;
		else
			m.focus = IcModal->FocusButton0;
		return;
	}

	if(m.focus == IcModal->FocusCheckbox){
		m.focus = IcModal->FocusButton0;
		return;
	}

	m.focus++;
	if(m.focus > focusmax(m))
		m.focus = focusmin(m);
}

focusprev(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	if(m.focus == IcModal->FocusInput){
		m.focus = focusmax(m);
		return;
	}

	if(m.focus == IcModal->FocusCheckbox){
		if(m.inputlabel != "")
			m.focus = IcModal->FocusInput;
		else
			m.focus = focusmax(m);
		return;
	}

	m.focus--;
	if(m.focus < IcModal->FocusButton0){
		if(m.checkbox != "")
			m.focus = IcModal->FocusCheckbox;
		else if(m.inputlabel != "" &&
			(m.kind == IcModal->KindCopyConfirm ||
			 m.kind == IcModal->KindMoveConfirm ||
			 m.kind == IcModal->KindMkdirConfirm))
			m.focus = IcModal->FocusInput;
		else
			m.focus = focusmax(m);
	}
}

activatefocus(m: ref IcState->ModalState): int
{
	if(m == nil)
		return IcModal->ResultCancel;

	if(m.focus == IcModal->FocusCheckbox){
		m.checked = !m.checked;
		return IcModal->ResultNone;
	}

	if(m.focus == IcModal->FocusInput)
		return IcModal->ResultOk;

	if(m.kind == IcModal->KindCopyConfirm ||
	   m.kind == IcModal->KindMoveConfirm ||
	   m.kind == IcModal->KindDeleteConfirm ||
	   m.kind == IcModal->KindMkdirConfirm){
		if(m.focus == IcModal->FocusButton0)
			return IcModal->ResultOk;
		return IcModal->ResultCancel;
	}

	if(m.kind == IcModal->KindOverwrite){
		if(m.focus == IcModal->FocusButton0)
			return IcModal->ResultOverwrite;
		if(m.focus == IcModal->FocusButton1)
			return IcModal->ResultSkip;
		return IcModal->ResultCancel;
	}

	return IcModal->ResultNone;
}

hotkey(k: int, h: string): int
{
	if(h == "")
		return 0;

	if(len h == 1){
		if(k == h[0])
			return 1;
		if(k >= 'a' && k <= 'z' && k - 32 == h[0])
			return 1;
	}

	return 0;
}

printable(k: int): int
{
	return k >= 32 && k < 127;
}

setresult(m: ref IcState->ModalState, r: int): int
{
	if(m == nil)
		return IcModal->ResultCancel;

	m.result = r;
	return r;
}

clampinputpos(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	if(m.inputpos < 0)
		m.inputpos = 0;

	if(m.inputpos > len m.input)
		m.inputpos = len m.input;
}

inputhistorysection(m: ref IcState->ModalState): string
{
	if(m == nil)
		return "";

	case m.kind {
	IcModal->KindCopyConfirm =>
		return "copy";
	IcModal->KindMoveConfirm =>
		return "move";
	IcModal->KindMkdirConfirm =>
		return "mkdir";
	}

	return "";
}

loadinputhistory(m: ref IcState->ModalState)
{
	h: ref IcInputHistoryMod->History;

	if(m == nil || histmod == nil)
		return;

	m.inputhistorysection = inputhistorysection(m);
	m.inputhistoryopen = 0;
	m.inputhistorysel = -1;
	m.inputhistoryitems = array[0] of string;

	if(m.inputhistorysection == "")
		return;

	h = histmod->new(m.inputhistorysection, 32);
	if(h == nil)
		return;

	histmod->loadhist(h);

	if(h.items != nil)
		m.inputhistoryitems = h.items;
}

resetinputhistory(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	m.inputhistorysection = "";
	m.inputhistoryopen = 0;
	m.inputhistorysel = -1;
	m.inputhistoryitems = array[0] of string;
}

saveinputhistory(m: ref IcState->ModalState)
{
	h: ref IcInputHistoryMod->History;

	if(m == nil || histmod == nil)
		return;

	case m.kind {
	IcModal->KindCopyConfirm or
	IcModal->KindMoveConfirm or
	IcModal->KindMkdirConfirm =>
		;
	* =>
		return;
	}

	if(m.inputhistorysection == "")
		m.inputhistorysection = inputhistorysection(m);

	if(m.inputhistorysection == "")
		return;

	h = histmod->new(m.inputhistorysection, 32);
	if(h == nil)
		return;

	histmod->loadhist(h);
	histmod->add(h, m.input);
}

inputfieldtext(m: ref IcState->ModalState): string
{
	s, trigger: string;
	textw, start, cursor: int;

	if(m == nil)
		return "";

	trigger = "[v]";
	textw = fieldtextwidth(m);

	clampinputpos(m);

	s = m.input;
	cursor = m.inputpos;
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

inputhistorytext(m: ref IcState->ModalState): string
{
	out: string;
	i: int;

	if(m == nil || !m.inputhistoryopen || m.inputhistoryitems == nil)
		return "";

	out = "";

	for(i = 0; i < len m.inputhistoryitems && i < 5; i++){
		if(i == m.inputhistorysel)
			out += "> ";
		else
			out += "  ";

		out += m.inputhistoryitems[i];

		if(i + 1 < len m.inputhistoryitems && i + 1 < 5)
			out += "\n";
	}

	return out;
}

inputmovehistory(m: ref IcState->ModalState, dir: int)
{
	if(m == nil || m.inputhistoryitems == nil || len m.inputhistoryitems == 0)
		return;

	if(!m.inputhistoryopen){
		m.inputhistoryopen = 1;
		m.inputhistorysel = 0;
		return;
	}

	m.inputhistorysel += dir;

	if(m.inputhistorysel < 0)
		m.inputhistorysel = len m.inputhistoryitems - 1;
	if(m.inputhistorysel >= len m.inputhistoryitems)
		m.inputhistorysel = 0;
}

ensureinputhistoryids(state: ref IcState->AppState, rows: int): int
{
	i, n: int;
	a: array of int;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return -1;

	if(rows < 0)
		rows = 0;

	if(state.modal.inputhistoryids != nil && len state.modal.inputhistoryids >= rows)
		return 0;

	n = 0;
	if(state.modal.inputhistoryids != nil)
		n = len state.modal.inputhistoryids;

	a = array[rows] of int;

	for(i = 0; i < n && i < rows; i++)
		a[i] = state.modal.inputhistoryids[i];

	for(; i < rows; i++)
		a[i] = view->allocid(state.ui.tree);

	state.modal.inputhistoryids = a;
	return 0;
}

sethistorylabel(state: ref IcState->AppState, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return;

	if(state.modal.canvasid < 0 || id < 0)
		return;

	if(view->find(state.ui.tree, id) == nil)
		ui->label(state.ui, state.modal.canvasid, id, x, y, w, text);

	n = view->find(state.ui.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

hideinputhistory(state: ref IcState->AppState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return;

	if(state.modal.inputhistoryids == nil)
		return;

	for(i = 0; i < len state.modal.inputhistoryids; i++){
		n = view->find(state.ui.tree, state.modal.inputhistoryids[i]);
		if(n != nil)
			view->hide(n);
	}
}

drawinputhistory(state: ref IcState->AppState)
{
	m: ref IcState->ModalState;
	i, rows, w, x, y: int;
	text, code, focuscode: string;

	if(state == nil || state.modal == nil)
		return;

	m = state.modal;

	if(!m.inputhistoryopen || m.inputhistoryitems == nil || len m.inputhistoryitems == 0){
		hideinputhistory(state);
		return;
	}

	if(m.canvasid < 0){
		hideinputhistory(state);
		return;
	}

	rows = len m.inputhistoryitems;
	if(rows > 5)
		rows = 5;

	if(rows <= 0){
		hideinputhistory(state);
		return;
	}

	if(ensureinputhistoryids(state, rows) < 0)
		return;

	x = 2;
	y = 5;
	w = m.w - 4;

	if(w < 12)
		w = 12;

	code = "";
	focuscode = "";
	if(state.theme != nil){
		code = state.theme.modalfieldcode;
		focuscode = state.theme.modalfocuscode;
	}

	for(i = 0; i < rows; i++){
		if(i == m.inputhistorysel)
			text = "> " + m.inputhistoryitems[i];
		else
			text = "  " + m.inputhistoryitems[i];

		if(i == m.inputhistorysel)
			sethistorylabel(state, m.inputhistoryids[i], x, y + i, w, text, focuscode);
		else
			sethistorylabel(state, m.inputhistoryids[i], x, y + i, w, text, code);
	}
}

handlekey(state: ref IcState->AppState, k: int): int
{
	m: ref IcState->ModalState;
	r: int;

	if(state == nil || state.modal == nil || !state.modal.active)
		return IcModal->ResultNone;

	m = state.modal;

	if(m.animstage != StageWindow)
		return IcModal->ResultNone;

	if(m.inputhistoryopen){
		if(k == EscapeKey){
			m.inputhistoryopen = 0;
			m.inputhistorysel = -1;
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == UpKey){
			inputmovehistory(m, -1);
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == DownKey){
			inputmovehistory(m, 1);
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == EnterKey || k == ReturnKey){
			if(m.inputhistorysel >= 0 && m.inputhistorysel < len m.inputhistoryitems){
				m.input = m.inputhistoryitems[m.inputhistorysel];
				m.inputpos = len m.input;
			}

			m.inputhistoryopen = 0;
			m.inputhistorysel = -1;
			drawwindow(state);
			return IcModal->ResultNone;
		}
	}

	if(k == EscapeKey)
		return setresult(m, IcModal->ResultCancel);

	if(m.focus != IcModal->FocusInput){
		if(hotkey(k, m.hotkey0)){
			if(m.kind == IcModal->KindOverwrite)
				return setresult(m, IcModal->ResultOverwrite);

			saveinputhistory(m);
			return setresult(m, IcModal->ResultOk);
		}

		if(hotkey(k, m.hotkey1)){
			if(m.kind == IcModal->KindOverwrite)
				return setresult(m, IcModal->ResultSkip);
			return setresult(m, IcModal->ResultCancel);
		}

		if(hotkey(k, m.hotkey2))
			return setresult(m, IcModal->ResultCancel);
	}

	if(m.focus == IcModal->FocusInput){
		if(k == CtrlDownKey){
			if(m.inputhistoryitems != nil && len m.inputhistoryitems > 0){
				m.inputhistoryopen = 1;
				if(m.inputhistorysel < 0)
					m.inputhistorysel = 0;
				drawwindow(state);
			}
			return IcModal->ResultNone;
		}

		if(k == LeftKey){
			m.inputpos--;
			clampinputpos(m);
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == RightKey){
			m.inputpos++;
			clampinputpos(m);
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == HomeKey){
			m.inputpos = 0;
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == EndKey){
			m.inputpos = len m.input;
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == BackspaceKey){
			clampinputpos(m);
			if(m.inputpos > 0){
				m.input = m.input[0:m.inputpos - 1] + m.input[m.inputpos:];
				m.inputpos--;
			}
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == DeleteKey){
			clampinputpos(m);
			if(m.inputpos < len m.input)
				m.input = m.input[0:m.inputpos] + m.input[m.inputpos + 1:];

			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(printable(k)){
			clampinputpos(m);
			m.input = m.input[0:m.inputpos] + sys->sprint("%c", k) + m.input[m.inputpos:];
			m.inputpos++;
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(k == EnterKey || k == ReturnKey){
			saveinputhistory(m);
			return setresult(m, IcModal->ResultOk);
		}
	}

	if(k == TabKey || k == RightKey){
		focusnext(m);
		drawwindow(state);
		return IcModal->ResultNone;
	}

	if(k == LeftKey){
		focusprev(m);
		drawwindow(state);
		return IcModal->ResultNone;
	}

	if(k == SpaceKey && m.focus == IcModal->FocusCheckbox){
		m.checked = !m.checked;
		drawwindow(state);
		return IcModal->ResultNone;
	}

	if(k == SpaceKey){
		r = activatefocus(m);
		if(r == IcModal->ResultOk)
			saveinputhistory(m);
		if(r == IcModal->ResultNone)
			drawwindow(state);
		return setresult(m, r);
	}

	if(k == EnterKey || k == ReturnKey){
		r = activatefocus(m);
		if(r == IcModal->ResultOk)
			saveinputhistory(m);
		if(r == IcModal->ResultNone)
			drawwindow(state);
		return setresult(m, r);
	}

	return IcModal->ResultNone;
}

handletick(state: ref IcState->AppState): int
{
	m: ref IcState->ModalState;
	delay: int;

	if(state == nil || state.modal == nil)
		return 0;

	m = state.modal;

	if(!m.animating)
		return 0;

	delay = animticks(state);
	if(delay <= 0)
		delay = 1;

	m.animwait++;
	if(m.animwait < delay)
		return 0;

	m.animwait = 0;

	if(m.animstage == StageShadow){
		m.animstage = StageWindow;
		drawwindow(state);
		return 1;
	}

	if(m.animstage == StageClosingShadow){
		disposewindow(state);
		m.animating = 0;
		m.animstage = StageNone;
		m.kind = IcModal->KindNone;
		m.result = IcModal->ResultNone;

		if(state.ui != nil && state.ui.tree != nil)
			view->hidetree(state.ui.tree, state.modalid);

		return 1;
	}

	return 0;
}