implement IcModal;

include "ic/modal.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	modal: fn(u: ref IcUi->Ui, parentid, shadowid, id: int, x, y, w, h: int, title, message, inputlabel, input, checkbox: string, checked, focus, kind: int, button0, button1, button2: string, buttoncount: int, dx, dy: int, styles: array of string): int;
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
	setcode: fn(v: ref IcView->Node, code: string);
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;

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
focusmin: fn(m: ref IcState->ModalState): int;
focusmax: fn(m: ref IcState->ModalState): int;
focusnext: fn(m: ref IcState->ModalState);
focusprev: fn(m: ref IcState->ModalState);
activatefocus: fn(m: ref IcState->ModalState): int;
hotkey: fn(k: int, h: string): int;
printable: fn(k: int): int;
setresult: fn(m: ref IcState->ModalState, r: int): int;

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

	ui->init();
	view->init();
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
	w, h: int;

	m = state.modal;

	w = len m.title + 8;
	w = maxint(w, len m.message + 6);
	w = maxint(w, len m.inputlabel + len m.input + 8);
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

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return -1;

	m = state.modal;

	if(m.canvasid >= 0)
		view->removetree(state.ui.tree, m.canvasid);

	if(m.shadowid >= 0)
		view->removetree(state.ui.tree, m.shadowid);

	m.shadowid = view->allocid(state.ui.tree);
	m.canvasid = view->allocid(state.ui.tree);

	if(ui->modal(state.ui, state.modalid, m.shadowid, m.canvasid, m.x, m.y, m.w, m.h,
		m.title, m.message, m.inputlabel, m.input, m.checkbox,
		m.checked, m.focus, m.kind,
		m.button0, m.button1, m.button2, m.buttoncount, 2, 1, stylecodes(state)) < 0)
		return -1;

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

	drawshadow(state);
	return drawwindow(state);
}

showcopyconfirm(state: ref IcState->AppState, count: int, direction, target: string): int
{
	initstate(state);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindCopyConfirm;
	state.modal.title = "Copy";
	state.modal.message = "Copy " + string count + " item(s)  " + direction;
	state.modal.inputlabel = "Copy to:";
	state.modal.input = target;
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

	state.modal.active = 1;
	state.modal.kind = IcModal->KindMoveConfirm;
	state.modal.title = "Move";
	state.modal.message = "Move " + string count + " item(s)  " + direction;
	state.modal.inputlabel = "Move to:";
	state.modal.input = target;
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

	state.modal.active = 1;
	state.modal.kind = IcModal->KindDeleteConfirm;
	state.modal.title = "Delete";
	state.modal.message = "Delete " + string count + " item(s)?";
	state.modal.inputlabel = "Delete:";
	state.modal.input = target;
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

	return draw(state);
}

showmkdirconfirm(state: ref IcState->AppState, basepath: string): int
{
	initstate(state);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindMkdirConfirm;
	state.modal.title = "Create directory";
	state.modal.message = "Create new directory";
	state.modal.inputlabel = "Name:";
	state.modal.input = "";
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

handlekey(state: ref IcState->AppState, k: int): int
{
	m: ref IcState->ModalState;
	r: int;

	if(state == nil || state.modal == nil || !state.modal.active)
		return IcModal->ResultNone;

	m = state.modal;

	if(m.animstage != StageWindow)
		return IcModal->ResultNone;

	if(k == EscapeKey)
		return setresult(m, IcModal->ResultCancel);

	if(m.focus != IcModal->FocusInput){
		if(hotkey(k, m.hotkey0)){
			if(m.kind == IcModal->KindOverwrite)
				return setresult(m, IcModal->ResultOverwrite);
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

	if(m.focus == IcModal->FocusInput){
		if(k == BackspaceKey || k == DeleteKey){
			if(len m.input > 0)
				m.input = m.input[0:len m.input - 1];
			drawwindow(state);
			return IcModal->ResultNone;
		}

		if(printable(k)){
			m.input += sys->sprint("%c", k);
			drawwindow(state);
			return IcModal->ResultNone;
		}
	}

	if(k == SpaceKey){
		r = activatefocus(m);
		if(r == IcModal->ResultNone)
			drawwindow(state);
		return setresult(m, r);
	}

	if(k == EnterKey || k == ReturnKey){
		r = activatefocus(m);
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