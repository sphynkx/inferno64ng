include "icurses/ui.m";

IcMenu: module
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

	popupmenu: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, title: string, items: array of Item, sel: int): int;
	setpopupmenu: fn(u: ref IcUi->Ui, id: int, items: array of Item, sel: int): int;

	navbar: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of Item, sel: int): int;
	setnavbar: fn(u: ref IcUi->Ui, id: int, items: array of Item, sel: int): int;

	actionbar: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of Item, sel: int): int;
	setactionbar: fn(u: ref IcUi->Ui, id: int, items: array of Item, sel: int): int;
};