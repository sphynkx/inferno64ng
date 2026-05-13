implement IcPanel;

include "icurses/panel.m";

sys: Sys;
msg: IcMsg;
ui: IcUi;
view: IcView;
ic: Icurses;

DefaultTitle: con "Panel";
DefaultStatus: con "";
DefaultCommandBar: con "";
DefaultInfo: con "";

ParentDisplayName: con "..";
ParentKind: con "parent";

PanelCmdSelect: con "panel.select";
PanelCmdActivate: con "panel.activate";

finditem: fn(m: ref IcPanel->Model, itemid: int): int;
getitem: fn(m: ref IcPanel->Model, itemid: int): IcPanel->Item;
sameparent: fn(it: IcPanel->Item, parentid: int): int;
itemhidden: fn(it: IcPanel->Item): int;
itemdisplaykinddir: fn(it: IcPanel->Item): int;
sortvalue: fn(it: IcPanel->Item, key: string): string;
lesstext: fn(a, b: string): int;
lessitem: fn(a, b: IcPanel->Item, opts: IcPanel->Options): int;
sortitems: fn(a: array of IcPanel->Item, opts: IcPanel->Options): array of IcPanel->Item;
childitems: fn(m: ref IcPanel->Model, rootid: int, opts: IcPanel->Options): array of IcPanel->Item;
canparent: fn(p: ref IcPanel->Panel): int;
parentitem: fn(p: ref IcPanel->Panel): IcPanel->Item;
displaymain: fn(p: ref IcPanel->Panel, it: IcPanel->Item, depth, isparent: int): string;
displayaux: fn(p: ref IcPanel->Panel, it: IcPanel->Item): string;
makeline: fn(p: ref IcPanel->Panel, it: IcPanel->Item, depth, isparent: int): IcPanel->Line;
flattenbrief: fn(p: ref IcPanel->Panel): array of IcPanel->Line;
flattenwide: fn(p: ref IcPanel->Panel): array of IcPanel->Line;
flattentree: fn(p: ref IcPanel->Panel): array of IcPanel->Line;
flatten: fn(p: ref IcPanel->Panel): array of IcPanel->Line;
visiblebodyrows: fn(p: ref IcPanel->Panel): int;
visiblecommandrows: fn(p: ref IcPanel->Panel): int;
visibleinforows: fn(p: ref IcPanel->Panel): int;
fixcurrent: fn(p: ref IcPanel->Panel);
fixtop: fn(p: ref IcPanel->Panel);
currentindex: fn(p: ref IcPanel->Panel): int;
linewidths: fn(p: ref IcPanel->Panel): (int, int, int);
briefindexmove: fn(p: ref IcPanel->Panel, delta: int): int;
briefcolstep: fn(p: ref IcPanel->Panel): int;
briefpagestep: fn(p: ref IcPanel->Panel): int;
briefrowcount: fn(p: ref IcPanel->Panel): int;
appendrowid: fn(a: array of int, id: int): array of int;
setlineids: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel, parentid, count: int): int;
makemsg: fn(p: ref IcPanel->Panel, cmd: string): IcMsg->Msg;
lineindexat: fn(p: ref IcPanel->Panel, row: int): int;
clickselect: fn(u: ref IcUi->Ui, p: ref IcPanel->Panel, row: int): IcMsg->Msg;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	msg = load IcMsg IcMsg->PATH;
	if(msg == nil)
		raise "fail:load icmsg";

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icui";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	msg->init();
	ui->init();
	view->init();
	ic->init();
}

defaultopts(): IcPanel->Options
{
	o: IcPanel->Options;

	o.mode = IcPanel->ModeBrief2Col;
	o.cursorstyle = IcPanel->CursorBackground;

	o.showframe = 1;
	o.framestyle = IcView->FrameDefault;

	o.showcommandbar = 0;
	o.commandbarrows = 1;

	o.showinfobar = 1;
	o.infobarrows = 1;

	o.showparentitem = 1;
	o.hideparentatroot = 1;

	o.directoriesfirst = 0;
	o.showhidden = 1;

	o.sortfield = "";
	o.sortdirection = IcPanel->SortAsc;
	o.sortsecondary = "";

	o.columncount = 2;
	o.customfields = array[0] of string;

	o.mouseenabled = 0;
	o.wrapnav = 0;
	o.vimnav = 0;

	o.rowstep = 1;
	o.colstep = 0;
	o.pagestep = 0;

	return o;
}

new(id: int, title: string, opts: IcPanel->Options): ref IcPanel->Panel
{
	p: ref IcPanel->Panel;
	d: IcPanel->Options;

	p = ref IcPanel->Panel;
	d = defaultopts();

	if(opts.columncount != 0 || opts.commandbarrows != 0 || opts.infobarrows != 0 ||
	   opts.mode != 0 || opts.cursorstyle != 0 || opts.showframe != 0 ||
	   opts.showcommandbar != 0 || opts.showinfobar != 0 || opts.showparentitem != 0 ||
	   opts.hideparentatroot != 0 || opts.directoriesfirst != 0 || opts.showhidden != 0 ||
	   opts.sortdirection != 0 || opts.mouseenabled != 0 || opts.wrapnav != 0 ||
	   opts.vimnav != 0 || opts.rowstep != 0 || opts.colstep != 0 ||
	   opts.pagestep != 0 || opts.sortfield != "" || opts.sortsecondary != "" ||
	   opts.customfields != nil)
		d = opts;

	p.id = id;
	p.titleid = -1;
	p.bodyid = -1;
	p.commandbarid = -1;
	p.infobarid = -1;
	p.rowids = array[0] of int;

	p.x = 0;
	p.y = 0;
	p.w = 1;
	p.h = 1;

	if(title == "")
		title = DefaultTitle;

	p.title = title;
	p.status = DefaultStatus;
	p.commandbar = DefaultCommandBar;
	p.info = DefaultInfo;

	p.model = nil;
	p.opts = d;

	p.rootid = -1;
	p.currentid = -1;
	p.top = 0;

	p.lines = array[0] of IcPanel->Line;

	return p;
}

setbounds(p: ref IcPanel->Panel, x, y, w, h: int): int
{
	if(p == nil)
		return -1;

	if(w <= 0)
		w = 1;
	if(h <= 0)
		h = 1;

	p.x = x;
	p.y = y;
	p.w = w;
	p.h = h;

	return 0;
}

settitle(p: ref IcPanel->Panel, title: string): int
{
	if(p == nil)
		return -1;

	p.title = title;
	return 0;
}

setstatus(p: ref IcPanel->Panel, status: string): int
{
	if(p == nil)
		return -1;

	p.status = status;
	return 0;
}

setcommandbar(p: ref IcPanel->Panel, text: string): int
{
	if(p == nil)
		return -1;

	p.commandbar = text;
	return 0;
}

setinfo(p: ref IcPanel->Panel, text: string): int
{
	if(p == nil)
		return -1;

	p.info = text;
	return 0;
}

setmodel(p: ref IcPanel->Panel, model: ref IcPanel->Model): int
{
	if(p == nil)
		return -1;

	p.model = model;

	if(model != nil && p.rootid < 0)
		p.rootid = model.rootid;

	p.lines = flatten(p);
	fixcurrent(p);
	fixtop(p);

	return 0;
}

setopts(p: ref IcPanel->Panel, opts: IcPanel->Options): int
{
	if(p == nil)
		return -1;

	p.opts = opts;
	p.lines = flatten(p);
	fixcurrent(p);
	fixtop(p);

	return 0;
}

setroot(p: ref IcPanel->Panel, rootid: int): int
{
	if(p == nil)
		return -1;

	p.rootid = rootid;
	p.lines = flatten(p);
	fixcurrent(p);
	fixtop(p);

	return 0;
}

currentid(p: ref IcPanel->Panel): int
{
	if(p == nil)
		return -1;

	return p.currentid;
}

currentname(p: ref IcPanel->Panel): string
{
	it: IcPanel->Item;

	if(p == nil || p.model == nil || p.currentid < 0)
		return "";

	it = getitem(p.model, p.currentid);
	return it.name;
}

currentkind(p: ref IcPanel->Panel): string
{
	it: IcPanel->Item;

	if(p == nil || p.model == nil || p.currentid < 0)
		return "";

	it = getitem(p.model, p.currentid);
	return it.kind;
}

finditem(m: ref IcPanel->Model, itemid: int): int
{
	i: int;

	if(m == nil || m.items == nil || itemid < 0)
		return -1;

	for(i = 0; i < len m.items; i++)
		if(m.items[i].id == itemid)
			return i;

	return -1;
}

getitem(m: ref IcPanel->Model, itemid: int): IcPanel->Item
{
	it: IcPanel->Item;
	i: int;

	i = finditem(m, itemid);
	if(i >= 0)
		return m.items[i];

	it.id = -1;
	it.parentid = -1;
	it.name = "";
	it.kind = "";
	it.flags = 0;
	it.sarg = "";
	it.iarg0 = 0;
	it.iarg1 = 0;
	it.iarg2 = 0;
	it.fields = array[0] of string;
	it.sortby = array[0] of string;
	it.hotkey = "";
	it.command = "";
	it.targetid = -1;

	return it;
}

sameparent(it: IcPanel->Item, parentid: int): int
{
	return it.parentid == parentid;
}

itemhidden(it: IcPanel->Item): int
{
	return (it.flags & IcPanel->FlagHidden) != 0;
}

itemdisplaykinddir(it: IcPanel->Item): int
{
	return it.kind == "dir";
}

sortvalue(it: IcPanel->Item, key: string): string
{
	i: int;

	if(key == "" || key == "name")
		return it.name;

	if(key == "kind")
		return it.kind;

	for(i = 0; i + 1 < len it.sortby; i += 2){
		if(it.sortby[i] == key)
			return it.sortby[i + 1];
	}

	for(i = 0; i + 1 < len it.fields; i += 2){
		if(it.fields[i] == key)
			return it.fields[i + 1];
	}

	return "";
}

lesstext(a, b: string): int
{
	return a < b;
}

lessitem(a, b: IcPanel->Item, opts: IcPanel->Options): int
{
	va, vb, sa, sb: string;

	if(opts.directoriesfirst){
		if(itemdisplaykinddir(a) && !itemdisplaykinddir(b))
			return 1;
		if(!itemdisplaykinddir(a) && itemdisplaykinddir(b))
			return 0;
	}

	va = sortvalue(a, opts.sortfield);
	vb = sortvalue(b, opts.sortfield);

	if(va == vb && opts.sortsecondary != ""){
		sa = sortvalue(a, opts.sortsecondary);
		sb = sortvalue(b, opts.sortsecondary);
		if(sa != sb){
			if(opts.sortdirection == IcPanel->SortDesc)
				return sb < sa;
			return sa < sb;
		}
	}

	if(va == vb){
		if(opts.sortdirection == IcPanel->SortDesc)
			return b.name < a.name;
		return a.name < b.name;
	}

	if(opts.sortdirection == IcPanel->SortDesc)
		return vb < va;

	return va < vb;
}

sortitems(a: array of IcPanel->Item, opts: IcPanel->Options): array of IcPanel->Item
{
	r: array of IcPanel->Item;
	i, j: int;
	t: IcPanel->Item;

	if(a == nil)
		return array[0] of IcPanel->Item;

	r = array[len a] of IcPanel->Item;
	for(i = 0; i < len a; i++)
		r[i] = a[i];

	for(i = 0; i < len r; i++){
		for(j = i + 1; j < len r; j++){
			if(!lessitem(r[i], r[j], opts)){
				t = r[i];
				r[i] = r[j];
				r[j] = t;
			}
		}
	}

	return r;
}

childitems(m: ref IcPanel->Model, rootid: int, opts: IcPanel->Options): array of IcPanel->Item
{
	r: array of IcPanel->Item;
	n, i: int;

	r = array[0] of IcPanel->Item;

	if(m == nil || m.items == nil)
		return r;

	n = 0;
	for(i = 0; i < len m.items; i++){
		if(!sameparent(m.items[i], rootid))
			continue;
		if(!opts.showhidden && itemhidden(m.items[i]))
			continue;
		n++;
	}

	r = array[n] of IcPanel->Item;
	n = 0;
	for(i = 0; i < len m.items; i++){
		if(!sameparent(m.items[i], rootid))
			continue;
		if(!opts.showhidden && itemhidden(m.items[i]))
			continue;
		r[n] = m.items[i];
		n++;
	}

	return sortitems(r, opts);
}

canparent(p: ref IcPanel->Panel): int
{
	it: IcPanel->Item;

	if(p == nil || p.model == nil || p.rootid < 0)
		return 0;

	if(!p.opts.showparentitem)
		return 0;

	if(p.opts.hideparentatroot && p.rootid == p.model.rootid)
		return 0;

	it = getitem(p.model, p.rootid);
	if(it.id < 0)
		return 0;

	return it.parentid >= 0;
}

parentitem(p: ref IcPanel->Panel): IcPanel->Item
{
	it, r: IcPanel->Item;

	it = getitem(p.model, p.rootid);

	r.id = it.parentid;
	r.parentid = -1;
	r.name = ParentDisplayName;
	r.kind = ParentKind;
	r.flags = 0;
	r.sarg = "";
	r.iarg0 = 0;
	r.iarg1 = 0;
	r.iarg2 = 0;
	r.fields = array[0] of string;
	r.sortby = array[0] of string;
	r.hotkey = "";
	r.command = "";
	r.targetid = -1;

	return r;
}

displaymain(p: ref IcPanel->Panel, it: IcPanel->Item, depth, isparent: int): string
{
	s: string;
	i: int;

	s = "";

	if(p != nil && p.opts.mode == IcPanel->ModeTree){
		for(i = 0; i < depth; i++)
			s += "  ";
		if(depth > 0)
			s += "`- ";
	}

	if(isparent)
		return s + ParentDisplayName;

	return s + it.name;
}

displayaux(p: ref IcPanel->Panel, it: IcPanel->Item): string
{
	i, j: int;
	key, value, out: string;

	if(p == nil)
		return "";

	if(p.opts.mode != IcPanel->ModeCustomFields || p.opts.customfields == nil)
		return "";

	out = "";

	for(i = 0; i < len p.opts.customfields; i++){
		key = p.opts.customfields[i];
		value = "";

		for(j = 0; j + 1 < len it.fields; j += 2){
			if(it.fields[j] == key){
				value = it.fields[j + 1];
				break;
			}
		}

		if(value == "")
			continue;

		if(out != "")
			out += "  ";
		out += value;
	}

	return out;
}

makeline(p: ref IcPanel->Panel, it: IcPanel->Item, depth, isparent: int): IcPanel->Line
{
	l: IcPanel->Line;

	l.itemid = it.id;
	l.depth = depth;
	l.isparent = isparent;
	l.text = displaymain(p, it, depth, isparent);
	l.aux = displayaux(p, it);
	l.flags = it.flags;

	return l;
}

flattenbrief(p: ref IcPanel->Panel): array of IcPanel->Line
{
	a: array of IcPanel->Item;
	r: array of IcPanel->Line;
	n, i, hasparent: int;
	it: IcPanel->Item;

	a = childitems(p.model, p.rootid, p.opts);
	hasparent = canparent(p);
	n = len a;
	if(hasparent)
		n++;

	r = array[n] of IcPanel->Line;
	i = 0;

	if(hasparent){
		it = parentitem(p);
		r[i] = makeline(p, it, 0, 1);
		i++;
	}

	for(; i < n; i++)
		r[i] = makeline(p, a[i - hasparent], 0, 0);

	return r;
}

flattenwide(p: ref IcPanel->Panel): array of IcPanel->Line
{
	return flattenbrief(p);
}

flattentree(p: ref IcPanel->Panel): array of IcPanel->Line
{
	#
	# First working implementation:
	# use one-level flattening from current root.
	# Tree expansion state can be added later without changing the panel API.
	#
	return flattenbrief(p);
}

flatten(p: ref IcPanel->Panel): array of IcPanel->Line
{
	if(p == nil || p.model == nil)
		return array[0] of IcPanel->Line;

	case p.opts.mode {
	IcPanel->ModeWide1Col =>
		return flattenwide(p);

	IcPanel->ModeTree =>
		return flattentree(p);

	IcPanel->ModeCustomFields =>
		return flattenwide(p);
	}

	return flattenbrief(p);
}

visiblecommandrows(p: ref IcPanel->Panel): int
{
	if(p == nil || !p.opts.showcommandbar)
		return 0;

	if(p.opts.commandbarrows <= 0)
		return 1;

	return p.opts.commandbarrows;
}

visibleinforows(p: ref IcPanel->Panel): int
{
	if(p == nil || !p.opts.showinfobar)
		return 0;

	if(p.opts.infobarrows <= 0)
		return 1;

	return p.opts.infobarrows;
}

visiblebodyrows(p: ref IcPanel->Panel): int
{
	rows: int;

	if(p == nil)
		return 1;

	rows = p.h;

	if(p.opts.showframe)
		rows -= 2;

	rows -= visiblecommandrows(p);
	rows -= visibleinforows(p);

	if(rows < 1)
		rows = 1;

	return rows;
}

currentindex(p: ref IcPanel->Panel): int
{
	i: int;

	if(p == nil || p.lines == nil || p.currentid < 0)
		return -1;

	for(i = 0; i < len p.lines; i++)
		if(p.lines[i].itemid == p.currentid)
			return i;

	return -1;
}

fixcurrent(p: ref IcPanel->Panel)
{
	if(p == nil)
		return;

	if(p.lines == nil || len p.lines == 0){
		p.currentid = -1;
		p.top = 0;
		return;
	}

	if(currentindex(p) >= 0)
		return;

	p.currentid = p.lines[0].itemid;
}

fixtop(p: ref IcPanel->Panel)
{
	rows, idx, maxtop: int;

	if(p == nil)
		return;

	rows = visiblebodyrows(p);
	if(rows <= 0)
		rows = 1;

	idx = currentindex(p);
	if(idx < 0){
		p.top = 0;
		return;
	}

	if(idx < p.top)
		p.top = idx;

	if(idx >= p.top + rows)
		p.top = idx - rows + 1;

	maxtop = len p.lines - rows;
	if(maxtop < 0)
		maxtop = 0;

	if(p.top < 0)
		p.top = 0;
	if(p.top > maxtop)
		p.top = maxtop;
}

linewidths(p: ref IcPanel->Panel): (int, int, int)
{
	bodyw, colw, auxw: int;

	bodyw = p.w;
	if(p.opts.showframe)
		bodyw -= 2;

	if(bodyw < 1)
		bodyw = 1;

	auxw = 0;
	colw = bodyw;

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2)
		colw = (bodyw - 1) / 2;

	if(colw < 1)
		colw = 1;

	return (bodyw, colw, auxw);
}

briefrowcount(p: ref IcPanel->Panel): int
{
	rows: int;

	rows = visiblebodyrows(p);
	if(rows < 1)
		rows = 1;

	return rows;
}

briefcolstep(p: ref IcPanel->Panel): int
{
	step: int;

	if(p.opts.colstep > 0)
		return p.opts.colstep;

	step = briefrowcount(p);
	if(step < 1)
		step = 1;

	return step;
}

briefpagestep(p: ref IcPanel->Panel): int
{
	step: int;

	if(p.opts.pagestep > 0)
		return p.opts.pagestep;

	step = briefcolstep(p) * 2;
	if(step < 1)
		step = 1;

	return step;
}

briefindexmove(p: ref IcPanel->Panel, delta: int): int
{
	idx: int;

	idx = currentindex(p);
	if(idx < 0)
		return 0;

	idx += delta;

	if(idx < 0)
		idx = 0;
	if(idx >= len p.lines)
		idx = len p.lines - 1;

	return idx;
}

appendrowid(a: array of int, id: int): array of int
{
	b: array of int;
	i, n: int;

	if(a == nil){
		b = array[1] of int;
		b[0] = id;
		return b;
	}

	n = len a;
	b = array[n + 1] of int;
	for(i = 0; i < n; i++)
		b[i] = a[i];
	b[n] = id;

	return b;
}

setlineids(u: ref IcUi->Ui, p: ref IcPanel->Panel, parentid, count: int): int
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || p == nil || parentid < 0)
		return -1;

	if(count < 0)
		count = 0;

	if(p.rowids == nil)
		p.rowids = array[0] of int;

	if(len p.rowids >= count)
		return 0;

	for(i = len p.rowids; i < count; i++){
		p.rowids = appendrowid(p.rowids, view->allocid(u.tree));
		if(ui->label(u, parentid, p.rowids[i], 0, 0, 1, "") < 0)
			return -1;

		n = view->find(u.tree, p.rowids[i]);
		if(n != nil)
			view->setfocusable(n, 0);
	}

	return 0;
}

build(u: ref IcUi->Ui, parentid: int, p: ref IcPanel->Panel): int
{
	n: ref IcView->Node;
	cmdrows, inforows, bodyrows: int;
	y0, x0, innerw: int;

	if(u == nil || u.tree == nil || p == nil || parentid < 0)
		return -1;

	if(p.id < 0)
		p.id = view->allocid(u.tree);
	if(p.titleid < 0)
		p.titleid = view->allocid(u.tree);
	if(p.bodyid < 0)
		p.bodyid = view->allocid(u.tree);
	if(p.commandbarid < 0)
		p.commandbarid = view->allocid(u.tree);
	if(p.infobarid < 0)
		p.infobarid = view->allocid(u.tree);

	if(p.opts.showframe){
		if(ui->window(u, parentid, p.id, p.x, p.y, p.w, p.h, p.title) < 0)
			return -1;
	}else{
		if(ui->group(u, parentid, p.id, p.x, p.y, p.w, p.h) < 0)
			return -1;
	}

	n = view->find(u.tree, p.id);
	if(n != nil && p.opts.showframe)
		view->setframe(n, p.opts.framestyle);

	x0 = 0;
	y0 = 0;
	innerw = p.w;
	if(p.opts.showframe){
		x0 = 1;
		y0 = 1;
		innerw = p.w - 2;
	}
	if(innerw < 1)
		innerw = 1;

	cmdrows = visiblecommandrows(p);
	inforows = visibleinforows(p);
	bodyrows = visiblebodyrows(p);

	if(ui->label(u, p.id, p.titleid, x0, y0 - (p.opts.showframe != 0), innerw, p.title) < 0)
		return -1;

	if(ui->group(u, p.id, p.bodyid, x0, y0 + cmdrows, innerw, bodyrows) < 0)
		return -1;

	if(ui->label(u, p.id, p.commandbarid, x0, y0, innerw, p.commandbar) < 0)
		return -1;

	if(ui->label(u, p.id, p.infobarid, x0, y0 + cmdrows + bodyrows, innerw, p.info) < 0)
		return -1;

	if(setlineids(u, p, p.bodyid, bodyrows) < 0)
		return -1;

	return render(u, p);
}

render(u: ref IcUi->Ui, p: ref IcPanel->Panel): int
{
	n, rown: ref IcView->Node;
	bodyw, colw, auxw: int;
	cmdrows, inforows, bodyrows: int;
	start, idx, i, rowcount, colstep: int;
	line, text: string;
	leftidx, rightidx: int;
	leftline, rightline: IcPanel->Line;

	if(u == nil || u.tree == nil || p == nil)
		return -1;

	p.lines = flatten(p);
	fixcurrent(p);
	fixtop(p);

	(bodyw, colw, auxw) = linewidths(p);
	auxw = auxw;

	cmdrows = visiblecommandrows(p);
	inforows = visibleinforows(p);
	bodyrows = visiblebodyrows(p);

	n = view->find(u.tree, p.id);
	if(n != nil){
		view->setbounds(n, p.x, p.y, p.w, p.h);
		view->settext(n, p.title);
		if(p.opts.showframe)
			view->setframe(n, p.opts.framestyle);
	}

	n = view->find(u.tree, p.commandbarid);
	if(n != nil){
		if(cmdrows > 0)
			view->show(n);
		else
			view->hide(n);
		view->settext(n, p.commandbar);
	}

	n = view->find(u.tree, p.infobarid);
	if(n != nil){
		if(inforows > 0)
			view->show(n);
		else
			view->hide(n);
		view->settext(n, p.info);
	}

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2){
		rowcount = briefrowcount(p);
		colstep = briefcolstep(p);
		start = p.top;

		for(i = 0; i < bodyrows; i++){
			rown = view->find(u.tree, p.rowids[i]);
			if(rown == nil)
				continue;

			leftidx = start + i;
			rightidx = start + colstep + i;

			leftline.itemid = -1;
			leftline.text = "";
			rightline.itemid = -1;
			rightline.text = "";

			if(leftidx >= 0 && leftidx < len p.lines)
				leftline = p.lines[leftidx];
			if(rightidx >= 0 && rightidx < len p.lines)
				rightline = p.lines[rightidx];

			line = "";
			if(leftline.itemid >= 0)
				line += leftline.text;
			while(len line < colw)
				line += " ";

			line += "|";

			text = "";
			if(rightline.itemid >= 0)
				text = rightline.text;

			while(len text < colw)
				text += " ";

			line += text;

			view->setbounds(rown, 0, i, bodyw, 1);
			view->settext(rown, line);
			view->show(rown);
		}
	}else{
		start = p.top;

		for(i = 0; i < bodyrows; i++){
			rown = view->find(u.tree, p.rowids[i]);
			if(rown == nil)
				continue;

			idx = start + i;
			if(idx >= 0 && idx < len p.lines)
				line = p.lines[idx].text;
			else
				line = "";

			while(len line < bodyw)
				line += " ";

			if(len line > bodyw)
				line = line[0:bodyw];

			view->setbounds(rown, 0, i, bodyw, 1);
			view->settext(rown, line);
			view->show(rown);
		}
	}

	return 0;
}

makemsg(p: ref IcPanel->Panel, cmd: string): IcMsg->Msg
{
	m: IcMsg->Msg;
	it: IcPanel->Item;

	if(p == nil)
		return msg->none();

	m = msg->newmsg(p.id, p.id, IcMsg->KindCommand, cmd);
	m.iarg0 = p.currentid;
	m.iarg1 = p.top;
	m.iarg2 = len p.lines;

	if(p.model != nil && p.currentid >= 0){
		it = getitem(p.model, p.currentid);
		m.sarg = it.name;
	}

	return m;
}

selectid(u: ref IcUi->Ui, p: ref IcPanel->Panel, itemid: int): IcMsg->Msg
{
	if(p == nil)
		return msg->none();

	p.currentid = itemid;
	fixtop(p);
	render(u, p);

	return makemsg(p, PanelCmdSelect);
}

up(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	step = p.opts.rowstep;
	if(step <= 0)
		step = 1;

	idx = currentindex(p);
	if(idx < 0)
		idx = 0;
	else
		idx -= step;

	if(idx < 0){
		if(p.opts.wrapnav)
			idx = len p.lines - 1;
		else
			idx = 0;
	}

	return selectid(u, p, p.lines[idx].itemid);
}

down(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	step = p.opts.rowstep;
	if(step <= 0)
		step = 1;

	idx = currentindex(p);
	if(idx < 0)
		idx = 0;
	else
		idx += step;

	if(idx >= len p.lines){
		if(p.opts.wrapnav)
			idx = 0;
		else
			idx = len p.lines - 1;
	}

	return selectid(u, p, p.lines[idx].itemid);
}

left(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2){
		step = briefcolstep(p);
		idx = currentindex(p);
		if(idx < 0)
			idx = 0;
		else
			idx -= step;
		if(idx < 0)
			idx = 0;

		return selectid(u, p, p.lines[idx].itemid);
	}

	return up(u, p);
}

right(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2){
		step = briefcolstep(p);
		idx = currentindex(p);
		if(idx < 0)
			idx = 0;
		else
			idx += step;
		if(idx >= len p.lines)
			idx = len p.lines - 1;

		return selectid(u, p, p.lines[idx].itemid);
	}

	return down(u, p);
}

pageup(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2)
		step = briefpagestep(p);
	else{
		step = p.opts.pagestep;
		if(step <= 0)
			step = visiblebodyrows(p);
	}

	idx = currentindex(p);
	if(idx < 0)
		idx = 0;
	else
		idx -= step;

	if(idx < 0)
		idx = 0;

	return selectid(u, p, p.lines[idx].itemid);
}

pagedown(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	idx, step: int;

	if(p == nil || len p.lines == 0)
		return msg->none();

	if(p.opts.mode == IcPanel->ModeBrief2Col && p.opts.columncount >= 2)
		step = briefpagestep(p);
	else{
		step = p.opts.pagestep;
		if(step <= 0)
			step = visiblebodyrows(p);
	}

	idx = currentindex(p);
	if(idx < 0)
		idx = 0;
	else
		idx += step;

	if(idx >= len p.lines)
		idx = len p.lines - 1;

	return selectid(u, p, p.lines[idx].itemid);
}

home(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	if(p == nil || len p.lines == 0)
		return msg->none();

	return selectid(u, p, p.lines[0].itemid);
}

end(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	if(p == nil || len p.lines == 0)
		return msg->none();

	return selectid(u, p, p.lines[len p.lines - 1].itemid);
}

activate(u: ref IcUi->Ui, p: ref IcPanel->Panel): IcMsg->Msg
{
	m: IcMsg->Msg;
	it: IcPanel->Item;

	if(p == nil)
		return msg->none();

	m = makemsg(p, PanelCmdActivate);

	if(p.model != nil && p.currentid >= 0){
		it = getitem(p.model, p.currentid);
		if(it.command != "")
			m.cmd = it.command;
		if(it.targetid >= 0)
			m.dst = it.targetid;
		if(it.name != "")
			m.sarg = it.name;
	}

	return m;
}

handlekey(u: ref IcUi->Ui, p: ref IcPanel->Panel, k: int): IcMsg->Msg
{
	if(p == nil)
		return msg->none();

	if(p.opts.vimnav){
		if(k == 'k')
			return up(u, p);
		if(k == 'j')
			return down(u, p);
		if(k == 'h')
			return left(u, p);
		if(k == 'l')
			return right(u, p);
	}

	if(k == Icurses->Kup)
		return up(u, p);

	if(k == Icurses->Kdown)
		return down(u, p);

	if(k == Icurses->Kleft)
		return left(u, p);

	if(k == Icurses->Kright)
		return right(u, p);

	if(k == Icurses->Kpgup)
		return pageup(u, p);

	if(k == Icurses->Kpgdown)
		return pagedown(u, p);

	if(k == Icurses->Khome)
		return home(u, p);

	if(k == Icurses->Kend)
		return end(u, p);

	if(ic->isconfirm(k))
		return activate(u, p);

	return msg->none();
}

lineindexat(p: ref IcPanel->Panel, row: int): int
{
	idx: int;

	if(p == nil)
		return -1;

	if(row < 0)
		return -1;

	idx = p.top + row;
	if(idx >= 0 && idx < len p.lines)
		return idx;

	return -1;
}

clickselect(u: ref IcUi->Ui, p: ref IcPanel->Panel, row: int): IcMsg->Msg
{
	idx: int;

	idx = lineindexat(p, row);
	if(idx < 0)
		return msg->none();

	return selectid(u, p, p.lines[idx].itemid);
}

handlemouse(u: ref IcUi->Ui, p: ref IcPanel->Panel, mouse: string): IcMsg->Msg
{
	u = u;
	p = p;
	mouse = mouse;

	#
	# Mouse support is intentionally left minimal in the first implementation.
	# The module API already reserves a dedicated entry point.
	#
	return msg->none();
}