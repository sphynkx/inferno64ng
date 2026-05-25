implement IcTopBar;

include "ic/topbar.m";

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
};

ui: IcUiMod;
view: IcViewMod;

MenuCount: con 5;
OptionItemCount: con 1;

Kesc: con 27;
Kenter: con 10;
Kreturn: con 13;
Kup: con 57362;
Kdown: con 57363;
Kleft: con 57364;
Kright: con 57365;

DefaultBaseCode: con "1;38;2;20;25;30;48;2;210;235;255";
DefaultFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";

submenuactive: int;
submenushadowid: int;
submenubgid: int;
submenuitemids: array of int;
submenuindex: int;

basecode: fn(state: ref IcState->AppState): string;
focuscode: fn(state: ref IcState->AppState): string;
spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
itemtext: fn(i: int): string;
submenuitemtext: fn(i: int): string;
menuitemx: fn(i: int): int;
ensureids: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
hideall: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
hidesubmenu: fn(state: ref IcState->AppState);
setlabel: fn(state: ref IcState->AppState, id, x, y, w: int, text, code: string);
showshadow: fn(state: ref IcState->AppState, id, x, y, w, h: int);
showmenu: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int);
showsubmenu: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	ui->init();
	view->init();

	submenuactive = 0;
	submenushadowid = -1;
	submenubgid = -1;
	submenuitemids = array[0] of int;
	submenuindex = 0;
}

basecode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.menuwindowcode != "")
		return state.theme.menuwindowcode;

	return DefaultBaseCode;
}

focuscode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.menufocuscode != "")
		return state.theme.menufocuscode;

	return DefaultFocusCode;
}

newbar(): ref IcState->TopBarState
{
	bar: ref IcState->TopBarState;

	bar = ref IcState->TopBarState;
	bar.id = -1;
	bar.backgroundid = -1;
	bar.active = 0;
	bar.focus = 0;
	bar.itemids = array[0] of int;

	return bar;
}

active(bar: ref IcState->TopBarState): int
{
	return bar != nil && bar.active;
}

toggle(bar: ref IcState->TopBarState)
{
	if(bar == nil)
		return;

	bar.active = !bar.active;
	if(bar.active && (bar.focus < 0 || bar.focus >= MenuCount))
		bar.focus = 0;

	submenuactive = 0;
	submenuindex = 0;
}

close(bar: ref IcState->TopBarState)
{
	if(bar == nil)
		return;

	bar.active = 0;
	submenuactive = 0;
	submenuindex = 0;
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

itemtext(i: int): string
{
	case i {
	0 =>
		return " Left ";
	1 =>
		return " File ";
	2 =>
		return " Command ";
	3 =>
		return " Options ";
	4 =>
		return " Right ";
	}

	return " ";
}

submenuitemtext(i: int): string
{
	case i {
	0 =>
		return " Screensavers ";
	}

	return " ";
}

menuitemx(i: int): int
{
	x, k: int;

	x = 1;
	for(k = 0; k < i; k++)
		x += len itemtext(k) + 1;

	return x;
}

ensureids(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	i: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(bar.backgroundid <= 0)
		bar.backgroundid = view->allocid(state.ui.tree);

	if(bar.itemids == nil || len bar.itemids != MenuCount){
		bar.itemids = array[MenuCount] of int;
		for(i = 0; i < MenuCount; i++)
			bar.itemids[i] = view->allocid(state.ui.tree);
	}

	if(submenushadowid <= 0)
		submenushadowid = view->allocid(state.ui.tree);

	if(submenubgid <= 0)
		submenubgid = view->allocid(state.ui.tree);

	if(submenuitemids == nil || len submenuitemids != OptionItemCount){
		submenuitemids = array[OptionItemCount] of int;
		for(i = 0; i < OptionItemCount; i++)
			submenuitemids[i] = view->allocid(state.ui.tree);
	}
}

hideall(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(bar.itemids != nil){
		for(i = 0; i < len bar.itemids; i++){
			n = view->find(state.ui.tree, bar.itemids[i]);
			if(n != nil)
				view->hide(n);
		}
	}

	n = view->find(state.ui.tree, bar.backgroundid);
	if(n != nil)
		view->hide(n);

	hidesubmenu(state);
}

hidesubmenu(state: ref IcState->AppState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	n = view->find(state.ui.tree, submenushadowid);
	if(n != nil)
		view->hide(n);

	n = view->find(state.ui.tree, submenubgid);
	if(n != nil)
		view->hide(n);

	if(submenuitemids != nil){
		for(i = 0; i < len submenuitemids; i++){
			n = view->find(state.ui.tree, submenuitemids[i]);
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

showshadow(state: ref IcState->AppState, id, x, y, w, h: int)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || id <= 0)
		return;

	if(view->find(state.ui.tree, id) == nil)
		ui->node(state.ui, state.mainid, id, "shadow", x, y, w, h);

	n = view->find(state.ui.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, h);
	view->show(n);
	view->bringtofront(state.ui.tree, id);
}

showmenu(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int)
{
	i, x, iw: int;
	code, normal, focusc: string;

	if(w <= 0)
		return;

	normal = basecode(state);
	focusc = focuscode(state);

	setlabel(state, bar.backgroundid, 0, 0, w, spaces(w), normal);

	x = 1;
	for(i = 0; i < MenuCount; i++){
		iw = len itemtext(i);
		if(x + iw > w)
			iw = w - x;
		if(iw <= 0)
			break;

		code = normal;
		if(bar.focus == i)
			code = focusc;

		setlabel(state, bar.itemids[i], x, 0, iw, itemtext(i), code);
		x += iw + 1;
	}
}

showsubmenu(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	x, y, w, h, i: int;
	normal, focusc, code: string;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(bar.focus != 3){
		hidesubmenu(state);
		submenuactive = 0;
		return;
	}

	normal = basecode(state);
	focusc = focuscode(state);

	x = menuitemx(3);
	y = 1;
	w = len submenuitemtext(0);
	h = OptionItemCount;

	showshadow(state, submenushadowid, x + 2, y + 1, w, h);
	setlabel(state, submenubgid, x, y, w, spaces(w), normal);

	for(i = 0; i < OptionItemCount; i++){
		code = normal;
		if(submenuindex == i)
			code = focusc;

		setlabel(state, submenuitemids[i], x, y + i, w, submenuitemtext(i), code);
	}

	submenuactive = 1;
}

build(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int
{
	w: int;

	if(state == nil || state.ui == nil || bar == nil)
		return -1;

	ensureids(state, bar);

	if(!bar.active){
		hideall(state, bar);
		return 0;
	}

	w = rect.w;
	if(w <= 0)
		w = state.width;

	showmenu(state, bar, w);

	if(submenuactive)
		showsubmenu(state, bar);
	else
		hidesubmenu(state);

	return 0;
}

handlekey(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int
{
	if(state == nil || bar == nil || !bar.active)
		return 0;

	if(k == Kesc){
		close(bar);
		return 1;
	}

	if(submenuactive){
		if(k == Kup){
			submenuindex--;
			if(submenuindex < 0)
				submenuindex = OptionItemCount - 1;
			return 1;
		}

		if(k == Kdown){
			submenuindex++;
			if(submenuindex >= OptionItemCount)
				submenuindex = 0;
			return 1;
		}

		if(k == Kleft){
			submenuactive = 0;
			return 1;
		}

		if(k == Kenter || k == Kreturn)
			return 2;

		return 1;
	}

	if(k == Kleft){
		bar.focus--;
		if(bar.focus < 0)
			bar.focus = MenuCount - 1;
		return 1;
	}

	if(k == Kright){
		bar.focus++;
		if(bar.focus >= MenuCount)
			bar.focus = 0;
		return 1;
	}

	if((k == Kenter || k == Kreturn || k == Kdown) && bar.focus == 3){
		submenuactive = 1;
		submenuindex = 0;
		return 1;
	}

	if(k == Kenter || k == Kreturn){
		close(bar);
		return 1;
	}

	return 1;
}