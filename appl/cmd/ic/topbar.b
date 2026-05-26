implement IcTopBar;

include "ic/topbar.m";

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

IcMenuMod: module
{
	PATH: con "/dis/lib/icurses/menu.dis";

	KindCommand:   con 0;
	KindSeparator: con 1;
	KindSubmenu:   con 2;

	FlagDisabled: con 1;
	FlagChecked:  con 2;
	FlagRadio:    con 4;

	PopupNone:    con 0;
	PopupHandled: con 1;
	PopupAccept:  con 2;
	PopupCancel:  con 3;

	PopupStageNone:   con 0;
	PopupStageShadow: con 1;
	PopupStageMenu:   con 2;

	Item: adt
	{
		kind:      int;
		flags:     int;

		label:     string;
		hotkey:    string;

		targetid:  int;
		command:   string;

		submenuid: int;
		status:    string;
	};

	Popup: adt
	{
		active:    int;
		stage:     int;
		wait:      int;

		parentid:  int;
		shadowid: int;
		id:        int;

		x:         int;
		y:         int;
		w:         int;
		h:         int;

		dx:        int;
		dy:        int;

		items:     array of Item;
		sel:       int;

		itemids:   array of int;

		basecode:     string;
		focuscode:    string;
		disabledcode: string;
		shadowcode:   string;
	};

	init: fn();

	newitem: fn(label, hotkey: string, targetid: int, command: string): Item;
	newseparator: fn(): Item;
	newsubmenu: fn(label, hotkey: string, submenuid: int): Item;

	setdisabled: fn(it: Item, disabled: int): Item;
	setchecked: fn(it: Item, checked: int): Item;
	setradio: fn(it: Item, radio: int): Item;
	setstatus: fn(it: Item, status: string): Item;

	enabled: fn(it: Item): int;
	checked: fn(it: Item): int;
	radio: fn(it: Item): int;
	separator: fn(it: Item): int;
	submenu: fn(it: Item): int;

	popupwidth: fn(items: array of Item): int;

	newpopup: fn(parentid, shadowid, id: int): ref Popup;
	setpopupstyle: fn(p: ref Popup, basecode, focuscode, disabledcode, shadowcode: string): int;
	openpopup: fn(u: ref IcUi->Ui, p: ref Popup, x, y, w: int, title: string, items: array of Item, sel, animticks: int): int;
	buildpopup: fn(u: ref IcUi->Ui, p: ref Popup): int;
	tickpopup: fn(u: ref IcUi->Ui, p: ref Popup, delay: int): int;
	closepopup: fn(u: ref IcUi->Ui, p: ref Popup): int;
	handlepopupkey: fn(u: ref IcUi->Ui, p: ref Popup, k: int): int;
	selectedpopupitem: fn(p: ref Popup): Item;
};

ui: IcUiMod;
view: IcViewMod;
icmenu: IcMenuMod;

MenuCount: con 5;

MenuLeft: con 0;
MenuFile: con 1;
MenuCommand: con 2;
MenuOptions: con 3;
MenuRight: con 4;

Kesc: con 27;
Kenter: con 10;
Kreturn: con 13;
Kup: con 57362;
Kdown: con 57363;
Kleft: con 57364;
Kright: con 57365;

DefaultBaseCode: con "1;38;2;20;25;30;48;2;210;235;255";
DefaultFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";
DefaultDisabledCode: con "1;38;2;110;110;110;48;2;210;235;255";

CommandOptionsScreensavers: con "options.screensavers";

popup: ref IcMenuMod->Popup;

basecode: fn(state: ref IcState->AppState): string;
focuscode: fn(state: ref IcState->AppState): string;
disabledcode: fn(state: ref IcState->AppState): string;
shadowcode: fn(state: ref IcState->AppState): string;
animticks: fn(state: ref IcState->AppState): int;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
itemtext: fn(i: int): string;
menuitemx: fn(i: int): int;

ensureids: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
ensurepopup: fn(state: ref IcState->AppState);
hideall: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
setlabel: fn(state: ref IcState->AppState, parentid, id, x, y, w: int, text, code: string);

showbar: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int);
popupitems: fn(menuindex: int): array of IcMenuMod->Item;
openpopupfor: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState): int;
closepopup: fn(state: ref IcState->AppState);
movefocus: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, delta: int);
commandforitem: fn(it: IcMenuMod->Item): int;

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	icmenu = load IcMenuMod IcMenuMod->PATH;
	if(icmenu == nil)
		raise "fail:load icurses/menu";

	ui->init();
	view->init();
	icmenu->init();

	popup = nil;
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

disabledcode(state: ref IcState->AppState): string
{
	state = state;
	return DefaultDisabledCode;
}

shadowcode(state: ref IcState->AppState): string
{
	if(state != nil && state.theme != nil && state.theme.modalshadowcode != "")
		return state.theme.modalshadowcode;

	return "";
}

animticks(state: ref IcState->AppState): int
{
	if(state != nil && state.theme != nil && state.theme.modalanimticks > 0)
		return state.theme.modalanimticks;

	return 0;
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

	if(popup != nil)
		popup.active = 0;
}

close(bar: ref IcState->TopBarState)
{
	if(bar == nil)
		return;

	bar.active = 0;

	if(popup != nil)
		popup.active = 0;
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
	MenuLeft =>
		return " Left ";
	MenuFile =>
		return " File ";
	MenuCommand =>
		return " Command ";
	MenuOptions =>
		return " Options ";
	MenuRight =>
		return " Right ";
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

	if(bar.id <= 0)
		bar.id = view->allocid(state.ui.tree);

	if(bar.backgroundid <= 0)
		bar.backgroundid = view->allocid(state.ui.tree);

	if(bar.itemids == nil || len bar.itemids != MenuCount){
		bar.itemids = array[MenuCount] of int;
		for(i = 0; i < MenuCount; i++)
			bar.itemids[i] = view->allocid(state.ui.tree);
	}
}

ensurepopup(state: ref IcState->AppState)
{
	shadowid, popupid: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	if(popup != nil){
		popup.parentid = state.mainid;
		return;
	}

	shadowid = view->allocid(state.ui.tree);
	popupid = view->allocid(state.ui.tree);

	popup = icmenu->newpopup(state.mainid, shadowid, popupid);
}

hideall(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(popup != nil)
		icmenu->closepopup(state.ui, popup);

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

showbar(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int)
{
	i, x, iw: int;
	n: ref IcView->Node;
	code, normal, focusc: string;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(w <= 0)
		return;

	normal = basecode(state);
	focusc = focuscode(state);

	if(view->find(state.ui.tree, bar.id) == nil)
		ui->group(state.ui, state.mainid, bar.id, 0, 0, w, 1);

	n = view->find(state.ui.tree, bar.id);
	if(n != nil){
		view->setbounds(n, 0, 0, w, 1);
		view->show(n);
	}

	setlabel(state, bar.id, bar.backgroundid, 0, 0, w, spaces(w), normal);

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

popupitems(menuindex: int): array of IcMenuMod->Item
{
	a: array of IcMenuMod->Item;
	it: IcMenuMod->Item;

	case menuindex {
	MenuOptions =>
		a = array[1] of IcMenuMod->Item;
		a[0] = icmenu->newitem("Screensavers", "", IcView->NoId, CommandOptionsScreensavers);
		return a;

	MenuLeft =>
		a = array[1] of IcMenuMod->Item;
		it = icmenu->newitem("No left commands yet", "", IcView->NoId, "");
		a[0] = icmenu->setdisabled(it, 1);
		return a;

	MenuFile =>
		a = array[1] of IcMenuMod->Item;
		it = icmenu->newitem("No file commands yet", "", IcView->NoId, "");
		a[0] = icmenu->setdisabled(it, 1);
		return a;

	MenuCommand =>
		a = array[1] of IcMenuMod->Item;
		it = icmenu->newitem("No command items yet", "", IcView->NoId, "");
		a[0] = icmenu->setdisabled(it, 1);
		return a;

	MenuRight =>
		a = array[1] of IcMenuMod->Item;
		it = icmenu->newitem("No right commands yet", "", IcView->NoId, "");
		a[0] = icmenu->setdisabled(it, 1);
		return a;
	}

	return array[0] of IcMenuMod->Item;
}

openpopupfor(state: ref IcState->AppState, bar: ref IcState->TopBarState): int
{
	items: array of IcMenuMod->Item;
	x, y, w: int;

	if(state == nil || state.ui == nil || bar == nil)
		return -1;

	ensurepopup(state);
	if(popup == nil)
		return -1;

	items = popupitems(bar.focus);

	x = menuitemx(bar.focus);
	y = 1;
	w = icmenu->popupwidth(items);

	if(x + w > state.width)
		x = state.width - w;
	if(x < 0)
		x = 0;

	icmenu->setpopupstyle(popup, basecode(state), focuscode(state), disabledcode(state), shadowcode(state));

	if(icmenu->openpopup(state.ui, popup, x, y, w, "", items, 0, animticks(state)) < 0)
		return -1;

	return 0;
}

closepopup(state: ref IcState->AppState)
{
	if(state != nil && state.ui != nil && popup != nil)
		icmenu->closepopup(state.ui, popup);
	else if(popup != nil)
		popup.active = 0;
}

movefocus(state: ref IcState->AppState, bar: ref IcState->TopBarState, delta: int)
{
	if(bar == nil)
		return;

	bar.focus += delta;

	while(bar.focus < 0)
		bar.focus += MenuCount;

	while(bar.focus >= MenuCount)
		bar.focus -= MenuCount;

	if(popup != nil && popup.active)
		openpopupfor(state, bar);
}

commandforitem(it: IcMenuMod->Item): int
{
	if(it.command == CommandOptionsScreensavers)
		return IcTopBar->CmdOptionsScreensavers;

	return IcTopBar->CmdHandled;
}

build(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int
{
	w: int;

	if(state == nil || state.ui == nil || bar == nil)
		return -1;

	ensureids(state, bar);
	ensurepopup(state);

	if(!bar.active){
		hideall(state, bar);
		return 0;
	}

	w = rect.w;
	if(w <= 0)
		w = state.width;

	showbar(state, bar, w);

	if(popup != nil && popup.active)
		icmenu->buildpopup(state.ui, popup);

	return 0;
}

handlekey(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int
{
	r: int;
	it: IcMenuMod->Item;

	if(state == nil || bar == nil || !bar.active)
		return IcTopBar->CmdNone;

	ensurepopup(state);

	if(k == Kesc){
		closepopup(state);
		bar.active = 0;
		return IcTopBar->CmdHandled;
	}

	if(popup != nil && popup.active){
		if(k == Kleft){
			closepopup(state);
			movefocus(state, bar, -1);
			return IcTopBar->CmdHandled;
		}

		if(k == Kright){
			closepopup(state);
			movefocus(state, bar, 1);
			return IcTopBar->CmdHandled;
		}

		r = icmenu->handlepopupkey(state.ui, popup, k);

		if(r == IcMenuMod->PopupAccept){
			it = icmenu->selectedpopupitem(popup);
			closepopup(state);
			return commandforitem(it);
		}

		if(r == IcMenuMod->PopupCancel){
			closepopup(state);
			return IcTopBar->CmdHandled;
		}

		if(r != IcMenuMod->PopupNone)
			return IcTopBar->CmdHandled;
	}

	if(k == Kleft){
		movefocus(state, bar, -1);
		return IcTopBar->CmdHandled;
	}

	if(k == Kright){
		movefocus(state, bar, 1);
		return IcTopBar->CmdHandled;
	}

	if(k == Kenter || k == Kreturn || k == Kup || k == Kdown){
		openpopupfor(state, bar);
		return IcTopBar->CmdHandled;
	}

	return IcTopBar->CmdHandled;
}

handletick(state: ref IcState->AppState, bar: ref IcState->TopBarState): int
{
	if(state == nil || state.ui == nil || bar == nil || !bar.active)
		return 0;

	if(popup == nil || !popup.active)
		return 0;

	return icmenu->tickpopup(state.ui, popup, animticks(state));
}