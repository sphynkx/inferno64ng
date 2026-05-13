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

ui: IcUiMod;
panelui: IcPanel;
fsmodel: IcFsModelMod;
view: IcViewMod;

DefaultPath: con ".";
DefaultCommandBarText: con "";
DefaultInfoText: con "";

appenditem: fn(a: array of IcPanel->Item, e: IcPanel->Item): array of IcPanel->Item;
maketitle: fn(p: ref IcState->PanelState): string;
makeinfo: fn(p: ref IcState->PanelState): string;
makeopts: fn(p: ref IcState->PanelState): IcPanel->Options;
buildmodel: fn(d: ref IcState->PanelDir): ref IcPanel->Model;

init()
{
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

	ui->init();
	panelui->init();
	fsmodel->init();
	view->init();
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

maketitle(p: ref IcState->PanelState): string
{
	if(p == nil)
		return "";

	if(p.active)
		return "[" + p.path + "]";

	return " " + p.path + " ";
}

makeinfo(p: ref IcState->PanelState): string
{
	n: int;

	if(p == nil || p.dir == nil || p.dir.items == nil)
		return DefaultInfoText;

	n = len p.dir.items;
	return "Items: " + string n;
}

makeopts(p: ref IcState->PanelState): IcPanel->Options
{
	o: IcPanel->Options;

	o = panelui->defaultopts();
	o.mode = IcPanel->ModeBrief2Col;
	o.cursorstyle = IcPanel->CursorBackground;
	o.showframe = 1;
	o.showcommandbar = 0;
	o.commandbarrows = 1;
	o.showinfobar = 1;
	o.infobarrows = 1;
	o.showparentitem = 0;
	o.hideparentatroot = 1;
	o.directoriesfirst = 1;
	o.showhidden = 1;
	o.sortfield = "name";
	o.sortdirection = IcPanel->SortAsc;
	o.sortsecondary = "";
	o.columncount = 2;
	o.mouseenabled = 0;
	o.wrapnav = 0;
	o.vimnav = 0;
	o.rowstep = 1;
	o.colstep = 0;
	o.pagestep = 0;

	p = p;

	return o;
}

buildmodel(d: ref IcState->PanelDir): ref IcPanel->Model
{
	m: ref IcPanel->Model;
	it: IcPanel->Item;
	i: int;

	m = ref IcPanel->Model;
	m.rootid = 0;
	m.items = array[0] of IcPanel->Item;

	if(d == nil || d.items == nil)
		return m;

	for(i = 0; i < len d.items; i++){
		it.id = i + 1;
		it.parentid = 0;
		it.name = d.items[i].name;

		if(d.items[i].isdir)
			it.kind = "dir";
		else
			it.kind = "file";

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

		m.items = appenditem(m.items, it);
	}

	return m;
}

newpanel(side: int): ref IcState->PanelState
{
	p: ref IcState->PanelState;

	p = ref IcState->PanelState;
	p.id = -1;
	p.side = side;
	p.active = side == IcState->SideLeft;
	p.path = DefaultPath;
	p.dir = nil;
	p.panel = nil;
	p.model = nil;

	return p;
}

build(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int
{
	opts: IcPanel->Options;

	if(state == nil || state.ui == nil || p == nil)
		return -1;

	if(rect.w <= 0 || rect.h <= 0)
		return 0;

	if(p.id <= 0)
		p.id = view->allocid(state.ui.tree);

	if(p.panel == nil){
		opts = makeopts(p);
		p.panel = panelui->new(p.id, maketitle(p), opts);
		if(p.panel == nil)
			return -1;
	}

	panelui->setbounds(p.panel, rect.x, rect.y, rect.w, rect.h);
	panelui->settitle(p.panel, maketitle(p));
	panelui->setcommandbar(p.panel, DefaultCommandBarText);

	p.dir = fsmodel->readdir(p.path);
	p.model = buildmodel(p.dir);

	panelui->setinfo(p.panel, makeinfo(p));
	panelui->setmodel(p.panel, p.model);

	if(panelui->build(state.ui, state.mainid, p.panel) < 0)
		return -1;

	return panelui->render(state.ui, p.panel);
}

refresh(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return -1;

	p.dir = fsmodel->readdir(p.path);
	p.model = buildmodel(p.dir);

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
	return refresh(state, p);
}

handlekey(state: ref IcState->AppState, p: ref IcState->PanelState, k: int): int
{
	if(state == nil || state.ui == nil || p == nil || p.panel == nil)
		return -1;

	panelui->handlekey(state.ui, p.panel, k);

	return panelui->render(state.ui, p.panel);
}