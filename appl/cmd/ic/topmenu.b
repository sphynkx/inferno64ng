implement IcTopMenu;

include "ic/topmenu.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	group: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
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

Kesc: con 27;
Kenter: con 10;
Kreturn: con 13;
Kleft: con 57364;
Kright: con 57365;

BaseCode: con "1;38;2;20;25;30;48;2;210;235;255";
FocusCode: con "1;38;2;0;0;0;48;2;170;225;255";

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
}

newstate(): ref IcState->TopBarState
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
}

close(bar: ref IcState->TopBarState)
{
	if(bar == nil)
		return;

	bar.active = 0;
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

ensureids(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	i: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(bar.id <= 0)
		bar.id = view->allocid(state.ui.tree);

	if(bar.backgroundid <= 0)
		bar.backgroundid = view->allocid(state.ui.tree);

	if(bar.itemids != nil && len bar.itemids == MenuCount)
		return;

	bar.itemids = array[MenuCount] of int;
	for(i = 0; i < MenuCount; i++)
		bar.itemids[i] = view->allocid(state.ui.tree);
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

	n = view->find(state.ui.tree, bar.id);
	if(n != nil)
		view->hide(n);
}

setlabel(state: ref IcState->AppState, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || id <= 0 || w <= 0)
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

showmenu(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int)
{
	i, x, iw: int;
	n: ref IcView->Node;
	code: string;

	if(w <= 0)
		return;

	ui->group(state.ui, state.mainid, bar.id, 0, 0, w, 1);

	n = view->find(state.ui.tree, bar.id);
	if(n != nil){
		view->setbounds(n, 0, 0, w, 1);
		view->show(n);
	}

	setlabel(state, bar.id, bar.backgroundid, 0, 0, w, spaces(w), BaseCode);

	x = 1;
	for(i = 0; i < MenuCount; i++){
		iw = len itemtext(i);
		if(x + iw > w)
			iw = w - x;
		if(iw <= 0)
			break;

		code = BaseCode;
		if(bar.focus == i)
			code = FocusCode;

		setlabel(state, bar.id, bar.itemids[i], x, 0, iw, itemtext(i), code);
		x += iw + 1;
	}

	view->bringtofront(state.ui.tree, bar.id);
	view->bringtofront(state.ui.tree, bar.backgroundid);

	if(bar.itemids != nil){
		for(i = 0; i < len bar.itemids; i++)
			view->bringtofront(state.ui.tree, bar.itemids[i]);
	}
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

	return 0;
}

handlekey(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int
{
	if(state == nil || bar == nil || !bar.active)
		return 0;

	if(k == Kesc){
		bar.active = 0;
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

	if(k == Kenter || k == Kreturn){
		bar.active = 0;
		return 1;
	}

	return 1;
}