implement IcMenu;

include "icurses/menu.m";

sys: Sys;
ui: IcUi;
view: IcView;

Kesc: con 27;
Kenter: con 10;
Kreturn: con 13;
Kup: con 57362;
Kdown: con 57363;
Kleft: con 57364;
Kright: con 57365;

DefaultPopupBaseCode: con "1;38;2;20;25;30;48;2;210;235;255";
DefaultPopupFocusCode: con "1;38;2;0;0;0;48;2;170;225;255";
DefaultPopupDisabledCode: con "1;38;2;110;110;110;48;2;210;235;255";

DefaultShadowDx: con 2;
DefaultShadowDy: con 1;
MinPopupWidth: con 12;

emptyitem: IcMenu->Item;

setflag: fn(it: IcMenu->Item, flag, on: int): IcMenu->Item;
hasflag: fn(it: IcMenu->Item, flag: int): int;

spaces: fn(n: int): string;
repeat: fn(ch: string, n: int): string;
clip: fn(s: string, w: int): string;
padright: fn(s: string, w: int): string;
clamp: fn(v, lo, hi: int): int;

itemcount: fn(items: array of IcMenu->Item): int;
itemwidth: fn(it: IcMenu->Item): int;
popupitemline: fn(it: IcMenu->Item, w, selected: int): string;
popuprowline: fn(it: IcMenu->Item, w: int): string;
baritemtext: fn(it: IcMenu->Item, selected: int): string;

ensurelabel: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
ensurelabelcode: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text, code: string): int;
ensurenode: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
hidelabel: fn(u: ref IcUi->Ui, id: int);
drawbar: fn(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int, action: int): int;

popupcode: fn(p: ref IcMenu->Popup, it: IcMenu->Item, selected: int): string;
popupitemids: fn(u: ref IcUi->Ui, p: ref IcMenu->Popup, count: int): int;
popupfixsel: fn(p: ref IcMenu->Popup);
popupfirstenabled: fn(items: array of IcMenu->Item): int;
popupmove: fn(p: ref IcMenu->Popup, delta: int);
popupshowshadow: fn(u: ref IcUi->Ui, p: ref IcMenu->Popup): int;
popupshowbody: fn(u: ref IcUi->Ui, p: ref IcMenu->Popup): int;
popuphidebody: fn(u: ref IcUi->Ui, p: ref IcMenu->Popup);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	ui->init();
	view->init();

	emptyitem = newitem("", "", IcView->NoId, "");
	emptyitem.flags = IcMenu->FlagDisabled;
}

newitem(label, hotkey: string, targetid: int, command: string): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindCommand;
	it.flags = 0;

	it.label = label;
	it.hotkey = hotkey;

	it.targetid = targetid;
	it.command = command;

	it.submenuid = IcView->NoId;
	it.status = "";

	return it;
}

newseparator(): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindSeparator;
	it.flags = IcMenu->FlagDisabled;

	it.label = "";
	it.hotkey = "";

	it.targetid = IcView->NoId;
	it.command = "";

	it.submenuid = IcView->NoId;
	it.status = "";

	return it;
}

newsubmenu(label, hotkey: string, submenuid: int): IcMenu->Item
{
	it: IcMenu->Item;

	it.kind = IcMenu->KindSubmenu;
	it.flags = 0;

	it.label = label;
	it.hotkey = hotkey;

	it.targetid = IcView->NoId;
	it.command = "";

	it.submenuid = submenuid;
	it.status = "";

	return it;
}

setflag(it: IcMenu->Item, flag, on: int): IcMenu->Item
{
	if(on)
		it.flags |= flag;
	else
		it.flags &= ~flag;

	return it;
}

hasflag(it: IcMenu->Item, flag: int): int
{
	return (it.flags & flag) != 0;
}

setdisabled(it: IcMenu->Item, disabled: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagDisabled, disabled);
}

setchecked(it: IcMenu->Item, checked: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagChecked, checked);
}

setradio(it: IcMenu->Item, radio: int): IcMenu->Item
{
	return setflag(it, IcMenu->FlagRadio, radio);
}

setstatus(it: IcMenu->Item, status: string): IcMenu->Item
{
	it.status = status;
	return it;
}

enabled(it: IcMenu->Item): int
{
	if(separator(it))
		return 0;

	if(hasflag(it, IcMenu->FlagDisabled))
		return 0;

	return 1;
}

checked(it: IcMenu->Item): int
{
	return hasflag(it, IcMenu->FlagChecked);
}

radio(it: IcMenu->Item): int
{
	return hasflag(it, IcMenu->FlagRadio);
}

separator(it: IcMenu->Item): int
{
	return it.kind == IcMenu->KindSeparator;
}

submenu(it: IcMenu->Item): int
{
	return it.kind == IcMenu->KindSubmenu;
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

repeat(ch: string, n: int): string
{
	s: string;
	i: int;

	s = "";

	if(ch == "")
		ch = " ";

	for(i = 0; i < n; i++)
		s += ch;

	return s;
}

clip(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s <= w)
		return s;

	return s[0:w];
}

padright(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s >= w)
		return s[0:w];

	return s + spaces(w - len s);
}

clamp(v, lo, hi: int): int
{
	if(hi < lo)
		hi = lo;

	if(v < lo)
		return lo;

	if(v > hi)
		return hi;

	return v;
}

itemcount(items: array of IcMenu->Item): int
{
	if(items == nil)
		return 0;

	return len items;
}

itemwidth(it: IcMenu->Item): int
{
	n: int;

	if(separator(it))
		return 3;

	n = 4;
	n += len it.label;

	if(it.hotkey != "")
		n += 1 + len it.hotkey;

	if(submenu(it))
		n += 2;

	return n;
}

popupwidth(items: array of IcMenu->Item): int
{
	i, n, w: int;

	w = MinPopupWidth;
	n = itemcount(items);

	for(i = 0; i < n; i++){
		if(itemwidth(items[i]) + 2 > w)
			w = itemwidth(items[i]) + 2;
	}

	return w;
}

popupitemline(it: IcMenu->Item, w, selected: int): string
{
	prefix, s: string;

	if(selected)
		prefix = "> ";
	else
		prefix = "  ";

	if(w <= len prefix)
		return clip(prefix, w);

	s = prefix + popuprowline(it, w - len prefix);
	return clip(s, w);
}

popuprowline(it: IcMenu->Item, w: int): string
{
	mark, tail, s: string;
	bodyw: int;

	if(w <= 0)
		return "";

	if(separator(it))
		return repeat("-", w);

	if(checked(it)){
		if(radio(it))
			mark = "(*) ";
		else
			mark = "[x] ";
	}else{
		if(radio(it))
			mark = "( ) ";
		else
			mark = "    ";
	}

	tail = "";
	if(submenu(it))
		tail = " >";
	else if(it.hotkey != "")
		tail = " " + it.hotkey;

	bodyw = w - len mark - len tail;
	if(bodyw < 0)
		bodyw = 0;

	if(!enabled(it))
		s = mark + padright("(" + it.label + ")", bodyw) + tail;
	else
		s = mark + padright(it.label, bodyw) + tail;

	return clip(s, w);
}

baritemtext(it: IcMenu->Item, selected: int): string
{
	s: string;

	if(it.hotkey != "")
		s = it.hotkey + " " + it.label;
	else
		s = it.label;

	if(selected)
		return ">" + s + "<";

	return " " + s + " ";
}

ensurelabel(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int
{
	return ensurelabelcode(u, parentid, id, x, y, w, text, "");
}

ensurelabelcode(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text, code: string): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return -1;

	if(w <= 0)
		w = 1;

	n = view->find(u.tree, id);
	if(n == nil){
		if(ui->label(u, parentid, id, x, y, w, text) < 0)
			return -1;

		n = view->find(u.tree, id);
		if(n == nil)
			return -1;
	}

	view->settext(n, padright(text, w));
	view->setbounds(n, x, y, w, 1);

	if(code != "")
		view->setcode(n, code);

	view->show(n);

	return 0;
}

ensurenode(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || id < 0)
		return -1;

	if(w <= 0)
		w = 1;
	if(h <= 0)
		h = 1;

	n = view->find(u.tree, id);
	if(n == nil){
		if(ui->node(u, parentid, id, kind, x, y, w, h) < 0)
			return -1;

		n = view->find(u.tree, id);
		if(n == nil)
			return -1;
	}

	view->setbounds(n, x, y, w, h);
	view->show(n);

	return 0;
}

hidelabel(u: ref IcUi->Ui, id: int)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->settext(n, "");
	view->hide(n);
}

newpopup(parentid, shadowid, id: int): ref IcMenu->Popup
{
	p: ref IcMenu->Popup;

	p = ref IcMenu->Popup;

	p.active = 0;
	p.stage = IcMenu->PopupStageNone;
	p.wait = 0;

	p.parentid = parentid;
	p.shadowid = shadowid;
	p.id = id;

	p.x = 0;
	p.y = 0;
	p.w = MinPopupWidth;
	p.h = 1;

	p.dx = DefaultShadowDx;
	p.dy = DefaultShadowDy;

	p.items = array[0] of IcMenu->Item;
	p.sel = 0;

	p.itemids = array[0] of int;

	p.basecode = DefaultPopupBaseCode;
	p.focuscode = DefaultPopupFocusCode;
	p.disabledcode = DefaultPopupDisabledCode;
	p.shadowcode = "";

	return p;
}

setpopupstyle(p: ref IcMenu->Popup, basecode, focuscode, disabledcode, shadowcode: string): int
{
	if(p == nil)
		return -1;

	if(basecode != "")
		p.basecode = basecode;
	if(focuscode != "")
		p.focuscode = focuscode;
	if(disabledcode != "")
		p.disabledcode = disabledcode;

	shadowcode = shadowcode;
	p.shadowcode = "";

	return 0;
}

popupfirstenabled(items: array of IcMenu->Item): int
{
	i: int;

	if(items == nil)
		return 0;

	for(i = 0; i < len items; i++){
		if(enabled(items[i]))
			return i;
	}

	return 0;
}

popupfixsel(p: ref IcMenu->Popup)
{
	n: int;

	if(p == nil)
		return;

	n = itemcount(p.items);
	if(n <= 0){
		p.sel = 0;
		return;
	}

	p.sel = clamp(p.sel, 0, n - 1);

	if(!enabled(p.items[p.sel]))
		p.sel = popupfirstenabled(p.items);
}

popupitemids(u: ref IcUi->Ui, p: ref IcMenu->Popup, count: int): int
{
	old: array of int;
	i: int;

	if(u == nil || u.tree == nil || p == nil)
		return -1;

	if(count < 1)
		count = 1;

	if(p.itemids != nil && len p.itemids >= count)
		return 0;

	old = p.itemids;
	p.itemids = array[count] of int;

	for(i = 0; i < count; i++){
		if(old != nil && i < len old && old[i] > 0)
			p.itemids[i] = old[i];
		else
			p.itemids[i] = view->allocid(u.tree);
	}

	return 0;
}

openpopup(u: ref IcUi->Ui, p: ref IcMenu->Popup, x, y, w: int, title: string, items: array of IcMenu->Item, sel, animticks: int): int
{
	title = title;

	if(u == nil || u.tree == nil || p == nil)
		return -1;

	if(items == nil)
		items = array[0] of IcMenu->Item;

	if(p.parentid < 0)
		return -1;

	if(p.shadowid <= 0)
		p.shadowid = view->allocid(u.tree);
	if(p.id <= 0)
		p.id = view->allocid(u.tree);

	if(w <= 0)
		w = popupwidth(items);
	if(w < MinPopupWidth)
		w = MinPopupWidth;

	p.x = x;
	p.y = y;
	p.w = w;
	p.h = itemcount(items);
	if(p.h <= 0)
		p.h = 1;

	p.items = items;
	p.sel = sel;
	popupfixsel(p);

	p.active = 1;
	p.wait = 0;

	if(animticks > 0)
		p.stage = IcMenu->PopupStageShadow;
	else
		p.stage = IcMenu->PopupStageMenu;

	return buildpopup(u, p);
}

popupcode(p: ref IcMenu->Popup, it: IcMenu->Item, selected: int): string
{
	if(p == nil)
		return DefaultPopupBaseCode;

	if(selected)
		return p.focuscode;

	if(!enabled(it))
		return p.disabledcode;

	return p.basecode;
}

popupshowshadow(u: ref IcUi->Ui, p: ref IcMenu->Popup): int
{
	if(u == nil || u.tree == nil || p == nil)
		return -1;

	if(p.shadowid <= 0)
		return -1;

	if(ensurenode(u, p.parentid, p.shadowid, "shadow", p.x + p.dx, p.y, p.w, p.h + p.dy) < 0)
		return -1;

	view->bringtofront(u.tree, p.shadowid);

	return 0;
}

popuphidebody(u: ref IcUi->Ui, p: ref IcMenu->Popup)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || p == nil)
		return;

	n = view->find(u.tree, p.id);
	if(n != nil)
		view->hide(n);

	if(p.itemids != nil){
		for(i = 0; i < len p.itemids; i++){
			n = view->find(u.tree, p.itemids[i]);
			if(n != nil)
				view->hide(n);
		}
	}
}

popupshowbody(u: ref IcUi->Ui, p: ref IcMenu->Popup): int
{
	i, rows: int;
	text, code: string;
	n: ref IcView->Node;
	it: IcMenu->Item;

	if(u == nil || u.tree == nil || p == nil)
		return -1;

	rows = itemcount(p.items);
	if(rows <= 0)
		rows = 1;

	if(popupitemids(u, p, rows) < 0)
		return -1;

	if(ensurenode(u, p.parentid, p.id, "group", p.x, p.y, p.w, rows) < 0)
		return -1;

	n = view->find(u.tree, p.id);
	if(n == nil)
		return -1;

	view->bringtofront(u.tree, p.id);

	if(itemcount(p.items) <= 0){
		ensurelabelcode(u, p.id, p.itemids[0], 0, 0, p.w, "(empty)", p.disabledcode);
		return 0;
	}

	for(i = 0; i < rows; i++){
		it = p.items[i];
		text = popuprowline(it, p.w);
		code = popupcode(p, it, i == p.sel);

		if(ensurelabelcode(u, p.id, p.itemids[i], 0, i, p.w, text, code) < 0)
			return -1;
	}

	for(i = rows; i < len p.itemids; i++)
		hidelabel(u, p.itemids[i]);

	return 0;
}

buildpopup(u: ref IcUi->Ui, p: ref IcMenu->Popup): int
{
	if(u == nil || u.tree == nil || p == nil)
		return -1;

	if(!p.active){
		closepopup(u, p);
		return 0;
	}

	if(popupshowshadow(u, p) < 0)
		return -1;

	if(p.stage == IcMenu->PopupStageShadow){
		popuphidebody(u, p);
		return 0;
	}

	return popupshowbody(u, p);
}

tickpopup(u: ref IcUi->Ui, p: ref IcMenu->Popup, delay: int): int
{
	if(u == nil || p == nil || !p.active)
		return 0;

	if(p.stage != IcMenu->PopupStageShadow)
		return 0;

	if(delay <= 0)
		delay = 1;

	p.wait++;
	if(p.wait < delay)
		return 0;

	p.wait = 0;
	p.stage = IcMenu->PopupStageMenu;
	buildpopup(u, p);

	return 1;
}

closepopup(u: ref IcUi->Ui, p: ref IcMenu->Popup): int
{
	n: ref IcView->Node;

	if(p == nil)
		return -1;

	if(u != nil && u.tree != nil){
		n = view->find(u.tree, p.shadowid);
		if(n != nil)
			view->hide(n);

		n = view->find(u.tree, p.id);
		if(n != nil)
			view->hidetree(u.tree, p.id);
	}

	p.active = 0;
	p.stage = IcMenu->PopupStageNone;
	p.wait = 0;

	return 0;
}

popupmove(p: ref IcMenu->Popup, delta: int)
{
	n, old: int;

	if(p == nil || p.items == nil)
		return;

	n = len p.items;
	if(n <= 0)
		return;

	old = p.sel;

	for(;;){
		p.sel += delta;

		while(p.sel < 0)
			p.sel += n;

		while(p.sel >= n)
			p.sel -= n;

		if(enabled(p.items[p.sel]))
			break;

		if(p.sel == old)
			break;
	}
}

handlepopupkey(u: ref IcUi->Ui, p: ref IcMenu->Popup, k: int): int
{
	if(u == nil || p == nil || !p.active)
		return IcMenu->PopupNone;

	if(k == Kesc){
		closepopup(u, p);
		return IcMenu->PopupCancel;
	}

	if(p.stage != IcMenu->PopupStageMenu)
		return IcMenu->PopupHandled;

	if(k == Kup){
		popupmove(p, -1);
		buildpopup(u, p);
		return IcMenu->PopupHandled;
	}

	if(k == Kdown){
		popupmove(p, 1);
		buildpopup(u, p);
		return IcMenu->PopupHandled;
	}

	if(k == Kleft || k == Kright)
		return IcMenu->PopupCancel;

	if(k == Kenter || k == Kreturn){
		if(itemcount(p.items) <= 0)
			return IcMenu->PopupHandled;

		if(!enabled(p.items[p.sel]))
			return IcMenu->PopupHandled;

		return IcMenu->PopupAccept;
	}

	return IcMenu->PopupHandled;
}

selectedpopupitem(p: ref IcMenu->Popup): IcMenu->Item
{
	if(p == nil || p.items == nil)
		return emptyitem;

	if(p.sel < 0 || p.sel >= len p.items)
		return emptyitem;

	return p.items[p.sel];
}

popupmenu(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, title: string, items: array of IcMenu->Item, sel: int): int
{
	p: ref IcMenu->Popup;

	p = newpopup(parentid, IcView->NoId, id);
	if(p == nil)
		return -1;

	return openpopup(u, p, x, y, w, title, items, sel, 0);
}

setpopupmenu(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	n: ref IcView->Node;
	p: ref IcMenu->Popup;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	p = newpopup(n.parentid, IcView->NoId, id);
	if(p == nil)
		return -1;

	return openpopup(u, p, n.x, n.y, n.w, "", items, sel, 0);
}

navbar(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of IcMenu->Item, sel: int): int
{
	if(u == nil)
		return -1;

	if(w <= 0)
		w = 1;

	if(ui->group(u, parentid, id, x, y, w, 1) < 0)
		return -1;

	return setnavbar(u, id, items, sel);
}

setnavbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	return drawbar(u, id, items, sel, 0);
}

actionbar(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, items: array of IcMenu->Item, sel: int): int
{
	if(u == nil)
		return -1;

	if(w <= 0)
		w = 1;

	if(ui->group(u, parentid, id, x, y, w, 1) < 0)
		return -1;

	return setactionbar(u, id, items, sel);
}

setactionbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int): int
{
	return drawbar(u, id, items, sel, 1);
}

drawbar(u: ref IcUi->Ui, id: int, items: array of IcMenu->Item, sel: int, action: int): int
{
	n: ref IcView->Node;
	i, x, w, count, oldcount, maxold, itemid: int;
	s: string;

	action = action;

	if(u == nil || u.tree == nil)
		return -1;

	n = view->find(u.tree, id);
	if(n == nil)
		return -1;

	w = n.w;
	if(w <= 0)
		return -1;

	count = itemcount(items);
	oldcount = n.iarg2;
	maxold = oldcount;
	if(maxold < count)
		maxold = count;

	for(i = 0; i < maxold; i++){
		if(i < view->childcount(n))
			itemid = view->childat(n, i);
		else
			itemid = IcView->NoId;

		if(itemid == IcView->NoId)
			continue;

		if(i >= count)
			hidelabel(u, itemid);
	}

	if(count <= 0){
		view->setargs(n, "", sel, action, 0);
		return 0;
	}

	if(sel < 0)
		sel = 0;
	if(sel >= count)
		sel = count - 1;

	x = 0;

	for(i = 0; i < count; i++){
		if(i < view->childcount(n))
			itemid = view->childat(n, i);
		else{
			itemid = view->allocid(u.tree);
			if(ui->label(u, id, itemid, 0, 0, 1, "") < 0)
				return -1;
		}

		if(separator(items[i])){
			hidelabel(u, itemid);
			continue;
		}

		s = baritemtext(items[i], i == sel);

		if(x >= w){
			hidelabel(u, itemid);
			continue;
		}

		if(x + len s > w)
			s = clip(s, w - x);

		ensurelabel(u, id, itemid, x, 0, len s, s);
		x += len s;
	}

	view->setargs(n, "", sel, action, count);
	return 0;
}