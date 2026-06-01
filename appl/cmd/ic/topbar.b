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

sys: Sys;
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

StdThemeDir: con "/lib/ic";
ThemeSuffix: con ".theme";

CommandOptionsScreensavers: con "options.screensavers";
CommandOptionsThemes: con "options.themes";

popup: ref IcMenuMod->Popup;
themepopup: ref IcMenuMod->Popup;
selectedthemename: string;

basecode: fn(state: ref IcState->AppState): string;
focuscode: fn(state: ref IcState->AppState): string;
disabledcode: fn(state: ref IcState->AppState): string;
shadowcode: fn(state: ref IcState->AppState): string;
animticks: fn(state: ref IcState->AppState): int;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
itemtext: fn(i: int): string;
menuitemx: fn(i: int): int;

startswith: fn(s, prefix: string): int;
endswith: fn(s, suffix: string): int;
themefromfile: fn(file: string): string;
appendstr: fn(a: array of string, s: string): array of string;
sortstrings: fn(a: array of string): array of string;
readthemes: fn(path: string): array of string;
appendthemeitems: fn(a: array of IcMenuMod->Item, names: array of string): array of IcMenuMod->Item;

ensureids: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
ensurepopup: fn(state: ref IcState->AppState);
hideall: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState);
setlabel: fn(state: ref IcState->AppState, parentid, id, x, y, w: int, text, code: string);

showbar: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, w: int);
popupitems: fn(menuindex: int): array of IcMenuMod->Item;
themeitems: fn(state: ref IcState->AppState): array of IcMenuMod->Item;
openpopupfor: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState): int;
openthemepopup: fn(state: ref IcState->AppState): int;
closepopup: fn(state: ref IcState->AppState);
closethemepopup: fn(state: ref IcState->AppState);
closeallpopups: fn(state: ref IcState->AppState);
movefocus: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, delta: int);
commandforitem: fn(it: IcMenuMod->Item): int;
selectedmainitem: fn(): IcMenuMod->Item;
isthemesitem: fn(it: IcMenuMod->Item): int;

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

	icmenu = load IcMenuMod IcMenuMod->PATH;
	if(icmenu == nil)
		raise "fail:load icurses/menu";

	ui->init();
	view->init();
	icmenu->init();

	popup = nil;
	themepopup = nil;
	selectedthemename = "";
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
	if(state != nil && state.theme != nil && state.theme.dialogshadowcode != "")
		return state.theme.dialogshadowcode;

	return "";
}

animticks(state: ref IcState->AppState): int
{
	if(state != nil && state.theme != nil && state.theme.dialoganimticks > 0)
		return state.theme.dialoganimticks;

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
	if(themepopup != nil)
		themepopup.active = 0;
}

close(bar: ref IcState->TopBarState)
{
	if(bar == nil)
		return;

	bar.active = 0;

	if(popup != nil)
		popup.active = 0;
	if(themepopup != nil)
		themepopup.active = 0;
}

selectedtheme(): string
{
	return selectedthemename;
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

startswith(s, prefix: string): int
{
	if(len prefix > len s)
		return 0;

	return s[0:len prefix] == prefix;
}

endswith(s, suffix: string): int
{
	if(len suffix > len s)
		return 0;

	return s[len s - len suffix:] == suffix;
}

themefromfile(file: string): string
{
	if(!endswith(file, ThemeSuffix))
		return "";

	return file[0:len file - len ThemeSuffix];
}

appendstr(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(s == "")
		return a;

	if(a == nil){
		b = array[1] of string;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;

	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = s;
	return b;
}

sortstrings(a: array of string): array of string
{
	i, j: int;
	t: string;

	if(a == nil)
		return array[0] of string;

	for(i = 0; i < len a; i++){
		for(j = i + 1; j < len a; j++){
			if(a[j] < a[i]){
				t = a[i];
				a[i] = a[j];
				a[j] = t;
			}
		}
	}

	return a;
}

readthemes(path: string): array of string
{
	fd: ref Sys->FD;
	n, i: int;
	dirs: array of Sys->Dir;
	names: array of string;
	name: string;

	names = array[0] of string;

	if(path == "")
		return names;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return names;

	for(;;){
		(n, dirs) = sys->dirread(fd);
		if(n <= 0)
			break;

		for(i = 0; i < n; i++){
			if((dirs[i].mode & Sys->DMDIR) != 0)
				continue;

			name = themefromfile(dirs[i].name);
			if(name != "")
				names = appendstr(names, name);
		}
	}

	return sortstrings(names);
}

appendthemeitems(a: array of IcMenuMod->Item, names: array of string): array of IcMenuMod->Item
{
	b: array of IcMenuMod->Item;
	i, n, old: int;

	if(names == nil || len names == 0)
		return a;

	old = 0;
	if(a != nil)
		old = len a;

	n = old + len names;
	b = array[n] of IcMenuMod->Item;

	for(i = 0; i < old; i++)
		b[i] = a[i];

	for(i = 0; i < len names; i++)
		b[old + i] = icmenu->newitem(names[i], "", IcView->NoId, names[i]);

	return b;
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
	shadowid, popupid, themeshadowid, themepopupid: int;

	if(state == nil || state.ui == nil || state.ui.tree == nil)
		return;

	if(popup == nil){
		shadowid = view->allocid(state.ui.tree);
		popupid = view->allocid(state.ui.tree);
		popup = icmenu->newpopup(state.mainid, shadowid, popupid);
	}else
		popup.parentid = state.mainid;

	if(themepopup == nil){
		themeshadowid = view->allocid(state.ui.tree);
		themepopupid = view->allocid(state.ui.tree);
		themepopup = icmenu->newpopup(state.mainid, themeshadowid, themepopupid);
	}else
		themepopup.parentid = state.mainid;
}

hideall(state: ref IcState->AppState, bar: ref IcState->TopBarState)
{
	i: int;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	closeallpopups(state);

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
		a = array[2] of IcMenuMod->Item;
		a[0] = icmenu->newitem("Screensavers", "", IcView->NoId, CommandOptionsScreensavers);
		a[1] = icmenu->newsubmenu("Themes", "", IcView->NoId);
		a[1].command = CommandOptionsThemes;
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

themeitems(state: ref IcState->AppState): array of IcMenuMod->Item
{
	stdnames, usernames: array of string;
	items: array of IcMenuMod->Item;
	it: IcMenuMod->Item;
	userdir: string;

	stdnames = readthemes(StdThemeDir);

	userdir = "";
	if(state != nil && state.cfg != nil && state.cfg.userdir != "")
		userdir = state.cfg.userdir;

	usernames = readthemes(userdir);

	items = array[0] of IcMenuMod->Item;
	items = appendthemeitems(items, stdnames);

	if(usernames != nil && len usernames > 0){
		if(items != nil && len items > 0){
			a := array[len items + 1] of IcMenuMod->Item;
			for(i := 0; i < len items; i++)
				a[i] = items[i];
			a[len items] = icmenu->newseparator();
			items = a;
		}

		items = appendthemeitems(items, usernames);
	}

	if(items == nil || len items == 0){
		items = array[1] of IcMenuMod->Item;
		it = icmenu->newitem("No themes found", "", IcView->NoId, "");
		items[0] = icmenu->setdisabled(it, 1);
	}

	return items;
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

	closethemepopup(state);

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

openthemepopup(state: ref IcState->AppState): int
{
	items: array of IcMenuMod->Item;
	x, y, w, h: int;

	if(state == nil || state.ui == nil)
		return -1;

	ensurepopup(state);
	if(popup == nil || themepopup == nil || !popup.active)
		return -1;

	items = themeitems(state);

	w = icmenu->popupwidth(items);
	x = popup.x + popup.w;
	y = popup.y + popup.sel;
	h = len items;
	if(h <= 0)
		h = 1;

	if(x + w > state.width)
		x = popup.x - w;
	if(x < 0)
		x = 0;

	if(y + h > state.height)
		y = state.height - h;
	if(y < 1)
		y = 1;

	icmenu->setpopupstyle(themepopup, basecode(state), focuscode(state), disabledcode(state), shadowcode(state));

	if(icmenu->openpopup(state.ui, themepopup, x, y, w, "", items, 0, animticks(state)) < 0)
		return -1;

	return 0;
}

closepopup(state: ref IcState->AppState)
{
	closethemepopup(state);

	if(state != nil && state.ui != nil && popup != nil)
		icmenu->closepopup(state.ui, popup);
	else if(popup != nil)
		popup.active = 0;
}

closethemepopup(state: ref IcState->AppState)
{
	if(state != nil && state.ui != nil && themepopup != nil)
		icmenu->closepopup(state.ui, themepopup);
	else if(themepopup != nil)
		themepopup.active = 0;
}

closeallpopups(state: ref IcState->AppState)
{
	closethemepopup(state);
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

selectedmainitem(): IcMenuMod->Item
{
	return icmenu->selectedpopupitem(popup);
}

isthemesitem(it: IcMenuMod->Item): int
{
	return it.command == CommandOptionsThemes;
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

	if(themepopup != nil && themepopup.active)
		icmenu->buildpopup(state.ui, themepopup);

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
		closeallpopups(state);
		bar.active = 0;
		return IcTopBar->CmdHandled;
	}

	if(themepopup != nil && themepopup.active){
		if(k == Kleft){
			closethemepopup(state);
			return IcTopBar->CmdHandled;
		}

		r = icmenu->handlepopupkey(state.ui, themepopup, k);

		if(r == IcMenuMod->PopupAccept){
			it = icmenu->selectedpopupitem(themepopup);
			selectedthemename = it.command;
			closeallpopups(state);
			return IcTopBar->CmdOptionsTheme;
		}

		if(r == IcMenuMod->PopupCancel){
			closethemepopup(state);
			return IcTopBar->CmdHandled;
		}

		if(r != IcMenuMod->PopupNone)
			return IcTopBar->CmdHandled;
	}

	if(popup != nil && popup.active){
		it = selectedmainitem();

		if(k == Kright && isthemesitem(it)){
			openthemepopup(state);
			return IcTopBar->CmdHandled;
		}

		if((k == Kenter || k == Kreturn) && isthemesitem(it)){
			openthemepopup(state);
			return IcTopBar->CmdHandled;
		}

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
	redraw: int;

	if(state == nil || state.ui == nil || bar == nil || !bar.active)
		return 0;

	redraw = 0;

	if(popup != nil && popup.active){
		if(icmenu->tickpopup(state.ui, popup, animticks(state)))
			redraw = 1;
	}

	if(themepopup != nil && themepopup.active){
		if(icmenu->tickpopup(state.ui, themepopup, animticks(state)))
			redraw = 1;
	}

	return redraw;
}