implement IcAppPanel;

include "ic/appanel.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
};

IcFsModelMod: module
{
	PATH: con "/dis/ic/fsmodel.dis";

	init: fn();
	readdir: fn(path: string): ref IcState->PanelDir;
	renderitems: fn(d: ref IcState->PanelDir): array of string;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	allocid: fn(t: ref IcView->Tree): int;
};

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

sys: Sys;
ui: IcUiMod;
panelui: IcPanel;
fsmodel: IcFsModelMod;
view: IcViewMod;
cfgdata: IcConfigData;

DefaultPath: con ".";
DefaultCommandBarText: con "";
DefaultInfoText: con "";

PanelSection: con "panel";

RootItemId: con 0;
ParentItemId: con 1;
FirstEntryId: con 2;

appenditem: fn(a: array of IcPanel->Item, e: IcPanel->Item): array of IcPanel->Item;
emptyitem: fn(): IcPanel->Item;
maketitle: fn(p: ref IcState->PanelState): string;
makeinfo: fn(p: ref IcState->PanelState): string;
makeopts: fn(state: ref IcState->AppState, p: ref IcState->PanelState): IcPanel->Options;
modevalue: fn(s: string, def: int): int;
cursorvalue: fn(s: string, def: int): int;
sortvalue: fn(s: string, def: int): int;
namefitvalue: fn(s: string, def: int): int;
framevalue: fn(s: string, def: int): int;
cwdpath: fn(): string;
joinpath: fn(base, name: string): string;
parentpath: fn(path: string): string;
normalizepath: fn(path: string): string;
trimdirsuffix: fn(name: string): string;
basename: fn(path: string): string;
selectedpath: fn(base, name: string): string;
findselected: fn(p: ref IcState->PanelState, path: string): int;
appendselected: fn(a: array of IcState->SelectedItem, e: IcState->SelectedItem): array of IcState->SelectedItem;
removeselected: fn(a: array of IcState->SelectedItem, idx: int): array of IcState->SelectedItem;
markitem: fn(p: ref IcState->PanelState, it: IcPanel->Item): IcPanel->Item;
selectparent: fn(state: ref IcState->AppState, p: ref IcState->PanelState);
selectremembered: fn(state: ref IcState->AppState, p: ref IcState->PanelState);
buildmodel: fn(p: ref IcState->PanelState, d: ref IcState->PanelDir): ref IcPanel->Model;
itempath: fn(p: ref IcState->PanelState): string;
navigate: fn(state: ref IcState->AppState, p: ref IcState->PanelState): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	panelui = load IcPanel IcPanel->PATH;
	if(panelui == nil)
		raise "fail:load icurses/panel";

	fsmodel = load IcFsModelMod IcFsModelMod->PATH;
	if(fsmodel == nil)
		raise "fail:load ic/fsmodel";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	ui->init();
	panelui->init();
	fsmodel->init();
	view->init();
	cfgdata->init();
}

appenditem(a: array of IcPanel->Item, e: IcPanel->Item): array of IcPanel->Item
{
	r: array of IcPanel->Item;
	i, n: int;

	if(a == nil){
		r = array[1] of IcPanel->Item;
		r[0] = e;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcPanel->Item;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = e;
	return r;
}

emptyitem(): IcPanel->Item
{
	it: IcPanel->Item;

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

maketitle(p: ref IcState->PanelState): string
{
	if(p == nil)
		return "[]";

	return "[" + p.path + "]";
}

makeinfo(p: ref IcState->PanelState): string
{
	n, s: int;

	if(p == nil || p.dir == nil || p.dir.items == nil)
		return DefaultInfoText;

	n = len p.dir.items;
	s = 0;
	if(p.selected != nil)
		s = len p.selected;

	if(s > 0)
		return "Items: " + string n + "  Selected: " + string s;

	return "Items: " + string n;
}

modevalue(s: string, def: int): int
{
	if(s == "brief2col")
		return IcPanel->ModeBrief2Col;
	if(s == "wide1col")
		return IcPanel->ModeWide1Col;
	if(s == "tree")
		return IcPanel->ModeTree;
	if(s == "customfields")
		return IcPanel->ModeCustomFields;

	return def;
}

cursorvalue(s: string, def: int): int
{
	if(s == "arrow")
		return IcPanel->CursorArrow;
	if(s == "background")
		return IcPanel->CursorBackground;
	if(s == "inverse")
		return IcPanel->CursorInverse;
	if(s == "frame")
		return IcPanel->CursorFrame;
	if(s == "underline")
		return IcPanel->CursorUnderline;

	return def;
}

sortvalue(s: string, def: int): int
{
	if(s == "asc")
		return IcPanel->SortAsc;
	if(s == "desc")
		return IcPanel->SortDesc;

	return def;
}

namefitvalue(s: string, def: int): int
{
	if(s == "middle")
		return IcPanel->NameFitMiddle;
	if(s == "clip")
		return IcPanel->NameFitClip;

	return def;
}

framevalue(s: string, def: int): int
{
	if(s == "ascii")
		return IcPaint->FrameAscii;
	if(s == "single")
		return IcPaint->FrameSingle;
	if(s == "double")
		return IcPaint->FrameDouble;
	if(s == "default")
		return IcView->FrameDefault;

	return def;
}

makeopts(state: ref IcState->AppState, p: ref IcState->PanelState): IcPanel->Options
{
	o: IcPanel->Options;
	s: string;

	o = panelui->defaultopts();

	if(state != nil){
		s = cfgdata->get(state.cfg, PanelSection, "mode", "brief2col");
		o.mode = modevalue(s, o.mode);

		s = cfgdata->get(state.cfg, PanelSection, "cursorstyle", "background");
		o.cursorstyle = cursorvalue(s, o.cursorstyle);

		s = cfgdata->get(state.cfg, PanelSection, "framestyle", "double");
		o.framestyle = framevalue(s, IcPaint->FrameDouble);

		o.showframe = cfgdata->getbool(state.cfg, PanelSection, "showframe", 1);
		o.showcommandbar = cfgdata->getbool(state.cfg, PanelSection, "showcommandbar", 0);
		o.commandbarrows = cfgdata->getint(state.cfg, PanelSection, "commandbarrows", 1);

		o.showinfobar = cfgdata->getbool(state.cfg, PanelSection, "showinfobar", 1);
		o.infobarrows = cfgdata->getint(state.cfg, PanelSection, "infobarrows", 1);

		o.showparentitem = cfgdata->getbool(state.cfg, PanelSection, "showparentitem", 1);
		o.hideparentatroot = cfgdata->getbool(state.cfg, PanelSection, "hideparentatroot", 0);

		o.directoriesfirst = cfgdata->getbool(state.cfg, PanelSection, "directoriesfirst", 1);
		o.showhidden = cfgdata->getbool(state.cfg, PanelSection, "showhidden", 1);

		o.sortfield = cfgdata->get(state.cfg, PanelSection, "sortfield", "name");

		s = cfgdata->get(state.cfg, PanelSection, "sortdirection", "asc");
		o.sortdirection = sortvalue(s, IcPanel->SortAsc);

		o.sortsecondary = cfgdata->get(state.cfg, PanelSection, "sortsecondary", "");

		o.columncount = cfgdata->getint(state.cfg, PanelSection, "columncount", 2);

		s = cfgdata->get(state.cfg, PanelSection, "namefit", "middle");
		o.namefit = namefitvalue(s, IcPanel->NameFitMiddle);

		o.markedcode = cfgdata->get(state.cfg, PanelSection, "markedcode", "");

		o.mouseenabled = cfgdata->getbool(state.cfg, PanelSection, "mouseenabled", 0);
		o.wrapnav = cfgdata->getbool(state.cfg, PanelSection, "wrapnav", 0);
		o.vimnav = cfgdata->getbool(state.cfg, PanelSection, "vimnav", 0);

		o.rowstep = cfgdata->getint(state.cfg, PanelSection, "rowstep", 1);
		o.colstep = cfgdata->getint(state.cfg, PanelSection, "colstep", 0);
		o.pagestep = cfgdata->getint(state.cfg, PanelSection, "pagestep", 0);
	}

	p = p;

	return o;
}

cwdpath(): string
{
	fd: ref Sys->FD;
	path: string;

	fd = sys->open(".", Sys->OREAD);
	if(fd == nil)
		return DefaultPath;

	path = sys->fd2path(fd);
	if(path == nil || path == "")
		return DefaultPath;

	if(len path > 1 && path[len path - 1] == '/')
		path = path[0:len path - 1];

	return path;
}

normalizepath(path: string): string
{
	if(path == "" || path == ".")
		return cwdpath();

	if(path == "./")
		return cwdpath();

	if(len path > 1 && path[len path - 1] == '/')
		return path[0:len path - 1];

	return path;
}

trimdirsuffix(name: string): string
{
	if(len name > 1 && name[len name - 1] == '/')
		return name[0:len name - 1];

	return name;
}

basename(path: string): string
{
	i: int;

	path = normalizepath(path);
	if(path == "/")
		return path;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[i + 1:];
	}

	return path;
}

joinpath(base, name: string): string
{
	base = normalizepath(base);
	name = trimdirsuffix(name);

	if(name == "" || name == ".")
		return base;

	if(name == "..")
		return parentpath(base);

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

parentpath(path: string): string
{
	i: int;

	path = normalizepath(path);

	if(path == "/")
		return path;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/'){
			if(i == 0)
				return "/";
			return path[0:i];
		}
	}

	return "/";
}

selectedpath(base, name: string): string
{
	return joinpath(base, trimdirsuffix(name));
}

findselected(p: ref IcState->PanelState, path: string): int
{
	i: int;

	if(p == nil || p.selected == nil || path == "")
		return -1;

	for(i = 0; i < len p.selected; i++){
		if(p.selected[i].path == path)
			return i;
	}

	return -1;
}

appendselected(a: array of IcState->SelectedItem, e: IcState->SelectedItem): array of IcState->SelectedItem
{
	r: array of IcState->SelectedItem;
	i, n: int;

	if(a == nil){
		r = array[1] of IcState->SelectedItem;
		r[0] = e;
		return r;
	}

	n = len a;
	r = array[n + 1] of IcState->SelectedItem;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = e;
	return r;
}

removeselected(a: array of IcState->SelectedItem, idx: int): array of IcState->SelectedItem
{
	r: array of IcState->SelectedItem;
	i, j, n: int;

	if(a == nil || idx < 0 || idx >= len a)
		return a;

	n = len a - 1;
	if(n <= 0)
		return array[0] of IcState->SelectedItem;

	r = array[n] of IcState->SelectedItem;
	j = 0;

	for(i = 0; i < len a; i++){
		if(i == idx)
			continue;

		r[j] = a[i];
		j++;
	}

	return r;
}

markitem(p: ref IcState->PanelState, it: IcPanel->Item): IcPanel->Item
{
	path: string;

	if(p == nil)
		return it;

	if(it.kind == "root" || it.kind == "parent")
		return it;

	path = selectedpath(p.path, it.name);
	if(findselected(p, path) >= 0)
		it.flags = it.flags | IcPanel->FlagMarked;

	return it;
}

buildmodel(p: ref IcState->PanelState, d: ref IcState->PanelDir): ref IcPanel->Model
{
	m: ref IcPanel->Model;
	it: IcPanel->Item;
	i: int;

	m = ref IcPanel->Model;
	m.rootid = RootItemId;
	m.items = array[0] of IcPanel->Item;

	it = emptyitem();
	it.id = RootItemId;
	it.parentid = -1;
	it.name = "";
	it.kind = "root";

	if(p != nil && normalizepath(p.path) != "/")
		it.parentid = ParentItemId;

	m.items = appenditem(m.items, it);

	if(p != nil && normalizepath(p.path) != "/"){
		it = emptyitem();
		it.id = ParentItemId;
		it.parentid = -1;
		it.name = "..";
		it.kind = "parent";
		m.items = appenditem(m.items, it);
	}

	if(d == nil || d.items == nil)
		return m;

	for(i = 0; i < len d.items; i++){
		it = emptyitem();
		it.id = FirstEntryId + i;
		it.parentid = RootItemId;
		it.name = d.items[i].name;

		if(d.items[i].isdir)
			it.kind = "dir";
		else
			it.kind = "file";

		it = markitem(p, it);
		m.items = appenditem(m.items, it);
	}

	return m;
}

selectparent(state: ref IcState->AppState, p: ref IcState->PanelState)
{
	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return;

	panelui->selectid(state.ui, p.panel, ParentItemId);
}

selectremembered(state: ref IcState->AppState, p: ref IcState->PanelState)
{
	i: int;
	name: string;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil || p.model == nil)
		return;

	name = p.lastchildname;
	if(name == "")
		return;

	for(i = 0; i < len p.model.items; i++){
		if(trimdirsuffix(p.model.items[i].name) == name){
			panelui->selectid(state.ui, p.panel, p.model.items[i].id);
			return;
		}
	}
}

newpanel(side: int): ref IcState->PanelState
{
	p: ref IcState->PanelState;

	p = ref IcState->PanelState;
	p.id = -1;
	p.side = side;
	p.active = side == IcState->SideLeft;
	p.path = cwdpath();
	p.dir = nil;
	p.lastchildname = "";
	p.selected = array[0] of IcState->SelectedItem;
	p.panel = nil;
	p.model = nil;

	return p;
}

itempath(p: ref IcState->PanelState): string
{
	name, kind: string;

	if(p == nil || p.panel == nil)
		return normalizepath(p.path);

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(kind == "parent" || name == "..")
		return parentpath(p.path);

	if(kind == "dir")
		return joinpath(p.path, name);

	return normalizepath(p.path);
}

navigate(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	next, curpath, curbase, kind, name: string;

	if(state == nil || p == nil || p.panel == nil)
		return -1;

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(name == "..")
		kind = "parent";

	if(kind != "dir" && kind != "parent")
		return 0;

	curpath = normalizepath(p.path);
	curbase = basename(curpath);

	if(kind == "parent")
		next = parentpath(curpath);
	else
		next = joinpath(curpath, name);

	next = normalizepath(next);
	if(next == "")
		next = cwdpath();

	if(next == curpath && kind == "parent")
		return panelui->render(state.ui, p.panel);

	if(kind == "parent")
		p.lastchildname = curbase;
	else
		p.lastchildname = "";

	p.selected = array[0] of IcState->SelectedItem;
	p.path = next;

	if(refresh(state, p) < 0)
		return -1;

	if(kind == "parent")
		selectremembered(state, p);
	else
		selectparent(state, p);

	return panelui->render(state.ui, p.panel);
}

build(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int
{
	opts: IcPanel->Options;

	if(state == nil || state.ui == nil || p == nil)
		return -1;

	if(rect.w <= 0 || rect.h <= 0)
		return 0;

	if(p.path == "" || p.path == ".")
		p.path = cwdpath();
	else
		p.path = normalizepath(p.path);

	if(p.selected == nil)
		p.selected = array[0] of IcState->SelectedItem;

	if(p.id <= 0)
		p.id = view->allocid(state.ui.tree);

	if(p.panel == nil){
		opts = makeopts(state, p);
		p.panel = panelui->new(p.id, maketitle(p), opts);
		if(p.panel == nil)
			return -1;
	}else{
		opts = makeopts(state, p);
		panelui->setopts(p.panel, opts);
	}

	panelui->setactive(p.panel, p.active);

	panelui->setbounds(p.panel, rect.x, rect.y, rect.w, rect.h);
	panelui->settitle(p.panel, maketitle(p));
	panelui->setcommandbar(p.panel, DefaultCommandBarText);

	p.dir = fsmodel->readdir(p.path);
	p.model = buildmodel(p, p.dir);

	panelui->setinfo(p.panel, makeinfo(p));
	panelui->setmodel(p.panel, p.model);

	if(panelui->build(state.ui, state.mainid, p.panel) < 0)
		return -1;

	return panelui->render(state.ui, p.panel);
}

refresh(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	opts: IcPanel->Options;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return -1;

	p.path = normalizepath(p.path);

	if(p.selected == nil)
		p.selected = array[0] of IcState->SelectedItem;

	opts = makeopts(state, p);
	panelui->setopts(p.panel, opts);
	panelui->setactive(p.panel, p.active);

	p.dir = fsmodel->readdir(p.path);
	p.model = buildmodel(p, p.dir);

	panelui->settitle(p.panel, maketitle(p));
	panelui->setinfo(p.panel, makeinfo(p));
	panelui->setmodel(p.panel, p.model);

	return panelui->render(state.ui, p.panel);
}

setactive(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int
{
	if(state == nil || p == nil)
		return -1;

	p.active = active != 0;

	if(p.panel != nil)
		panelui->setactive(p.panel, p.active);

	return refresh(state, p);
}

togglemarkadvance(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	name, kind, path: string;
	idx, id: int;
	sel: IcState->SelectedItem;
	m: IcMsg->Msg;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return -1;

	name = panelui->currentname(p.panel);
	kind = panelui->currentkind(p.panel);

	if(kind == "parent" || name == "..")
		return panelui->render(state.ui, p.panel);

	if(kind != "dir" && kind != "file")
		return panelui->render(state.ui, p.panel);

	path = selectedpath(p.path, name);
	idx = findselected(p, path);

	if(idx >= 0){
		p.selected = removeselected(p.selected, idx);
	}else{
		sel.path = path;
		sel.name = trimdirsuffix(name);
		sel.kind = kind;
		p.selected = appendselected(p.selected, sel);
	}

	id = panelui->currentid(p.panel);

	if(refresh(state, p) < 0)
		return -1;

	panelui->selectid(state.ui, p.panel, id);
	m = panelui->down(state.ui, p.panel);
	m = m;

	panelui->setinfo(p.panel, makeinfo(p));

	return panelui->render(state.ui, p.panel);
}

handlekey(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int
{
	m: IcMsg->Msg;

	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return -1;

	m = panelui->handlekey(state.ui, p.panel, k);

	if(m.cmd == "panel.activate")
		return navigate(state, p);

	return panelui->render(state.ui, p.panel);
}

clearselection(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	if(state == nil || p == nil)
		return -1;

	p.selected = array[0] of IcState->SelectedItem;

	if(p.panel == nil)
		return 0;

	return refresh(state, p);
}
