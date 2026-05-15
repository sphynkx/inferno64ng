implement IcModal;

include "ic/modal.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	window: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int, title: string): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
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
	settext: fn(v: ref IcView->Node, text: string);
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;

TabKey: con 9;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;
LeftKey: con 57364;
RightKey: con 57365;

initstate: fn(state: ref IcState->AppState);
disposewindow: fn(state: ref IcState->AppState);
maxint: fn(a, b: int): int;
fitw: fn(state: ref IcState->AppState, w: int): int;
draw: fn(state: ref IcState->AppState): int;
checkboxtext: fn(m: ref IcState->ModalState): string;
buttonstext: fn(m: ref IcState->ModalState): string;
refresh: fn(state: ref IcState->AppState);
focusmin: fn(m: ref IcState->ModalState): int;
focusmax: fn(m: ref IcState->ModalState): int;
focusnext: fn(m: ref IcState->ModalState);
focusprev: fn(m: ref IcState->ModalState);
activatefocus: fn(m: ref IcState->ModalState): int;
hotkey: fn(k: int, h: string): int;

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
	state.modal.kind = IcModal->KindNone;
	state.modal.title = "";
	state.modal.message = "";
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
	state.modal.windowid = -1;
	state.modal.messageid = -1;
	state.modal.checkboxid = -1;
	state.modal.buttonsid = -1;
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

	if(state.modal.windowid >= 0)
		view->removetree(state.ui.tree, state.modal.windowid);

	state.modal.windowid = -1;
	state.modal.messageid = -1;
	state.modal.checkboxid = -1;
	state.modal.buttonsid = -1;
}

close(state: ref IcState->AppState): int
{
	if(state == nil)
		return -1;

	initstate(state);
	disposewindow(state);

	state.modal.active = 0;
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

	if(w < 34)
		w = 34;

	return w;
}

checkboxtext(m: ref IcState->ModalState): string
{
	if(m == nil || m.checkbox == "")
		return "";

	if(m.checked)
		return "[x] " + m.checkbox;

	return "[ ] " + m.checkbox;
}

buttonstext(m: ref IcState->ModalState): string
{
	s: string;

	if(m == nil)
		return "";

	s = "";

	if(m.buttoncount > 0){
		if(m.focus == IcModal->FocusButton0)
			s += "[" + m.button0 + "]";
		else
			s += " " + m.button0 + " ";
	}

	if(m.buttoncount > 1){
		s += "  ";
		if(m.focus == IcModal->FocusButton1)
			s += "[" + m.button1 + "]";
		else
			s += " " + m.button1 + " ";
	}

	if(m.buttoncount > 2){
		s += "  ";
		if(m.focus == IcModal->FocusButton2)
			s += "[" + m.button2 + "]";
		else
			s += " " + m.button2 + " ";
	}

	return s;
}

draw(state: ref IcState->AppState): int
{
	m: ref IcState->ModalState;
	w, h, x, y, bw: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return -1;

	initstate(state);
	m = state.modal;

	disposewindow(state);

	w = len m.title + 8;
	w = maxint(w, len m.message + 6);
	w = maxint(w, len checkboxtext(m) + 6);
	w = maxint(w, len buttonstext(m) + 6);
	w = fitw(state, w);

	h = 7;
	if(m.checkbox != "")
		h = 8;

	x = (state.width - w) / 2;
	y = (state.height - h) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	m.windowid = view->allocid(state.ui.tree);
	m.messageid = view->allocid(state.ui.tree);
	m.checkboxid = view->allocid(state.ui.tree);
	m.buttonsid = view->allocid(state.ui.tree);

	if(ui->window(state.ui, state.modalid, m.windowid, x, y, w, h, m.title) < 0)
		return -1;

	ui->label(state.ui, m.windowid, m.messageid, 2, 2, w - 4, m.message);

	if(m.checkbox != "")
		ui->label(state.ui, m.windowid, m.checkboxid, 2, 4, w - 4, checkboxtext(m));

	bw = len buttonstext(m);
	if(bw > w - 4)
		bw = w - 4;
	if(bw < 1)
		bw = 1;

	ui->label(state.ui, m.windowid, m.buttonsid, (w - bw) / 2, h - 2, bw, buttonstext(m));

	view->showtree(state.ui.tree, state.modalid);
	view->bringtofront(state.ui.tree, state.modalid);

	return 0;
}

refresh(state: ref IcState->AppState)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || state.modal == nil)
		return;

	n = view->find(state.ui.tree, state.modal.checkboxid);
	if(n != nil)
		view->settext(n, checkboxtext(state.modal));

	n = view->find(state.ui.tree, state.modal.buttonsid);
	if(n != nil)
		view->settext(n, buttonstext(state.modal));
}

showcopyconfirm(state: ref IcState->AppState, count: int, dst: string): int
{
	initstate(state);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindCopyConfirm;
	state.modal.title = "Copy";
	state.modal.message = "Copy " + string count + " item(s) to " + dst;
	state.modal.checkbox = "Overwrite all";
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

showoverwrite(state: ref IcState->AppState, path: string): int
{
	initstate(state);

	state.modal.active = 1;
	state.modal.kind = IcModal->KindOverwrite;
	state.modal.title = "Overwrite";
	state.modal.message = "Overwrite " + path + "?";
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

	m.focus++;
	if(m.focus > focusmax(m))
		m.focus = focusmin(m);
}

focusprev(m: ref IcState->ModalState)
{
	if(m == nil)
		return;

	m.focus--;
	if(m.focus < focusmin(m))
		m.focus = focusmax(m);
}

activatefocus(m: ref IcState->ModalState): int
{
	if(m == nil)
		return IcModal->ResultCancel;

	if(m.focus == IcModal->FocusCheckbox){
		m.checked = !m.checked;
		return IcModal->ResultNone;
	}

	if(m.kind == IcModal->KindCopyConfirm){
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

handlekey(state: ref IcState->AppState, k: int): int
{
	m: ref IcState->ModalState;
	r: int;

	if(state == nil || state.modal == nil || !state.modal.active)
		return IcModal->ResultNone;

	m = state.modal;

	if(k == EscapeKey){
		m.result = IcModal->ResultCancel;
		return m.result;
	}

	if(hotkey(k, m.hotkey0)){
		if(m.kind == IcModal->KindOverwrite)
			m.result = IcModal->ResultOverwrite;
		else
			m.result = IcModal->ResultOk;
		return m.result;
	}

	if(hotkey(k, m.hotkey1)){
		if(m.kind == IcModal->KindOverwrite)
			m.result = IcModal->ResultSkip;
		else
			m.result = IcModal->ResultCancel;
		return m.result;
	}

	if(hotkey(k, m.hotkey2)){
		m.result = IcModal->ResultCancel;
		return m.result;
	}

	if(k == TabKey || k == RightKey){
		focusnext(m);
		refresh(state);
		return IcModal->ResultNone;
	}

	if(k == LeftKey){
		focusprev(m);
		refresh(state);
		return IcModal->ResultNone;
	}

	if(k == SpaceKey){
		if(m.focus == IcModal->FocusCheckbox)
			m.checked = !m.checked;
		else{
			r = activatefocus(m);
			m.result = r;
			return r;
		}

		refresh(state);
		return IcModal->ResultNone;
	}

	if(k == EnterKey || k == ReturnKey){
		r = activatefocus(m);
		m.result = r;
		if(r == IcModal->ResultNone)
			refresh(state);
		return r;
	}

	return IcModal->ResultNone;
}