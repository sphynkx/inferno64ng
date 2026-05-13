implement IcPanel;

include "ic/panel.m";

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
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	show: fn(v: ref IcView->Node);
	allocid: fn(t: ref IcView->Tree): int;
};

IcListMod: module
{
	PATH: con "/dis/lib/icurses/list.dis";

	init: fn();
	new: fn(id: int, rows: int): ref IcList->List;
	setrows: fn(l: ref IcList->List, rows: int): int;
	setitems: fn(l: ref IcList->List, items: array of string): int;
	render: fn(u: ref IcUi->Ui, l: ref IcList->List): int;
	handlekey: fn(u: ref IcUi->Ui, l: ref IcList->List, k: int): IcMsg->Msg;
};

IcFsModelMod: module
{
	PATH: con "/dis/ic/fsmodel.dis";

	init: fn();
	readdir: fn(path: string): ref IcState->PanelDir;
	renderitems: fn(d: ref IcState->PanelDir): array of string;
};

ui: IcUiMod;
view: IcViewMod;
listmod: IcListMod;
fsmodel: IcFsModelMod;

DefaultPath: con ".";

maketitle: fn(p: ref IcState->PanelState): string;

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	listmod = load IcListMod IcListMod->PATH;
	if(listmod == nil)
		raise "fail:load icurses/list";

	fsmodel = load IcFsModelMod IcFsModelMod->PATH;
	if(fsmodel == nil)
		raise "fail:load ic/fsmodel";

	ui->init();
	view->init();
	listmod->init();
	fsmodel->init();
}

maketitle(p: ref IcState->PanelState): string
{
	if(p == nil)
		return "";

	if(p.active)
		return "[" + p.path + "]";

	return " " + p.path + " ";
}

newpanel(side: int): ref IcState->PanelState
{
	p: ref IcState->PanelState;

	p = ref IcState->PanelState;
	p.side = side;
	p.active = side == IcState->SideLeft;
	p.path = DefaultPath;

	return p;
}

build(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int
{
	n: ref IcView->Node;
	rows, i, rowid: int;

	if(state == nil || state.ui == nil || p == nil)
		return -1;

	if(rect.w <= 0 || rect.h <= 0)
		return 0;

	if(p.id <= 0)
		p.id = view->allocid(state.ui.tree);
	if(p.titleid <= 0)
		p.titleid = view->allocid(state.ui.tree);
	if(p.listboxid <= 0)
		p.listboxid = view->allocid(state.ui.tree);

	ui->window(state.ui, state.mainid, p.id, rect.x, rect.y, rect.w, rect.h, maketitle(p));
	ui->label(state.ui, p.id, p.titleid, 1, 0, rect.w - 2, maketitle(p));
	ui->window(state.ui, p.id, p.listboxid, 0, 0, rect.w, rect.h, "");

	rows = rect.h - 2;
	if(rows < 1)
		rows = 1;

	if(p.liststate == nil)
		p.liststate = listmod->new(p.listboxid, rows);
	else
		listmod->setrows(p.liststate, rows);

	n = view->find(state.ui.tree, p.listboxid);
	if(n != nil)
		view->setbounds(n, 0, 0, rect.w, rect.h);

	for(i = 0; i < rows; i++){
		rowid = view->allocid(state.ui.tree);
		ui->label(state.ui, p.listboxid, rowid, 1, 1 + i, rect.w - 2, "");
	}

	return refresh(state, p);
}

refresh(state: ref IcState->AppState, p: ref IcState->PanelState): int
{
	items: array of string;
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || p == nil)
		return -1;

	p.dir = fsmodel->readdir(p.path);
	items = fsmodel->renderitems(p.dir);

	if(p.liststate != nil){
		listmod->setitems(p.liststate, items);
		listmod->render(state.ui, p.liststate);
	}

	n = view->find(state.ui.tree, p.id);
	if(n != nil)
		view->settext(n, maketitle(p));

	n = view->find(state.ui.tree, p.titleid);
	if(n != nil)
		view->settext(n, maketitle(p));

	return 0;
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
	if(state == nil || state.ui == nil || p == nil || p.liststate == nil)
		return -1;

	listmod->handlekey(state.ui, p.liststate, k);
	return 0;
}