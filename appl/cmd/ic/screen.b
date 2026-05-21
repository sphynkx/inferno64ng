implement IcScreen;

include "ic/screen.m";
include "ic/layout.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	group: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
	setframestyle: fn(u: ref IcUi->Ui, style: int);
	setstatusrows: fn(u: ref IcUi->Ui, helprow, statusrow: int);
	draw: fn(u: ref IcUi->Ui);
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	root: fn(t: ref IcView->Tree): ref IcView->Node;
	allocid: fn(t: ref IcView->Tree): int;
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
};

IcLayoutMod: module
{
	PATH: con "/dis/ic/layout.dis";

	init: fn();
	compute: fn(w, h, panelshidden: int): IcLayout->LayoutState;
};

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	build: fn(state: ref IcState->AppState, p: ref IcState->PanelState, rect: IcLayout->Rect): int;
	setactive: fn(state: ref IcState->AppState, p: ref IcState->PanelState, active: int): int;
};

IcTopBarMod: module
{
	PATH: con "/dis/ic/topbar.dis";

	init: fn();
	build: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int;
};

IcBottomBarMod: module
{
	PATH: con "/dis/ic/bottombar.dis";

	init: fn();
	build: fn(state: ref IcState->AppState, bar: ref IcState->BottomBarState, rect: IcLayout->Rect): int;
};

IcViewerMod: module
{
	PATH: con "/dis/ic/viewer.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	build: fn(state: ref IcState->AppState, parentid, w, h: int): int;
};

IcEditorMod: module
{
	PATH: con "/dis/ic/editor.dis";

	init: fn();
	active: fn(state: ref IcState->AppState): int;
	build: fn(state: ref IcState->AppState, parentid, w, h: int): int;
};

ui: IcUiMod;
view: IcViewMod;
layout: IcLayoutMod;
appanel: IcAppPanel;
topbar: IcTopBarMod;
bottombar: IcBottomBarMod;
viewer: IcViewerMod;
editor: IcEditorMod;

ensurelayer: fn(state: ref IcState->AppState, id: int): int;
showpanelnode: fn(state: ref IcState->AppState, p: ref IcState->PanelState);
hidepanelnode: fn(state: ref IcState->AppState, p: ref IcState->PanelState);

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	layout = load IcLayoutMod IcLayoutMod->PATH;
	if(layout == nil)
		raise "fail:load ic/layout";

	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	topbar = load IcTopBarMod IcTopBarMod->PATH;
	if(topbar == nil)
		raise "fail:load ic/topbar";

	bottombar = load IcBottomBarMod IcBottomBarMod->PATH;
	if(bottombar == nil)
		raise "fail:load ic/bottombar";

	viewer = load IcViewerMod IcViewerMod->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	editor = load IcEditorMod IcEditorMod->PATH;
	if(editor == nil)
		raise "fail:load ic/editor";

	ui->init();
	view->init();
	layout->init();
	appanel->init();
	topbar->init();
	bottombar->init();
	viewer->init();
	editor->init();
}

ensurelayer(state: ref IcState->AppState, id: int): int
{
	if(state == nil || state.ui == nil)
		return -1;

	return ui->group(state.ui, state.rootid, id, 0, 0, state.width, state.height);
}

showpanelnode(state: ref IcState->AppState, p: ref IcState->PanelState)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || p == nil)
		return;

	if(p.id <= 0)
		return;

	n = view->find(state.ui.tree, p.id);
	if(n != nil)
		view->show(n);
}

hidepanelnode(state: ref IcState->AppState, p: ref IcState->PanelState)
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || state.ui.tree == nil || p == nil)
		return;

	if(p.id <= 0)
		return;

	n = view->find(state.ui.tree, p.id);
	if(n != nil)
		view->hide(n);
}

build(state: ref IcState->AppState): int
{
	root: ref IcView->Node;
	ls: IcLayout->LayoutState;

	if(state == nil || state.ui == nil)
		return -1;

	root = view->root(state.ui.tree);
	if(root == nil)
		return -1;

	state.rootid = root.id;

	ui->setstatusrows(state.ui, -1, -1);

	if(state.theme != nil)
		ui->setframestyle(state.ui, state.theme.frame);

	if(state.screensaverid <= 0)
		state.screensaverid = view->allocid(state.ui.tree);
	if(state.toolid <= 0)
		state.toolid = view->allocid(state.ui.tree);
	if(state.mainid <= 0)
		state.mainid = view->allocid(state.ui.tree);
	if(state.modalid <= 0)
		state.modalid = view->allocid(state.ui.tree);

	ensurelayer(state, state.screensaverid);
	ensurelayer(state, state.toolid);
	ensurelayer(state, state.mainid);
	ensurelayer(state, state.modalid);

	view->hide(view->find(state.ui.tree, state.screensaverid));
	view->hide(view->find(state.ui.tree, state.toolid));
	view->hide(view->find(state.ui.tree, state.modalid));

	if(editor->active(state)){
		view->hide(view->find(state.ui.tree, state.mainid));
		view->show(view->find(state.ui.tree, state.toolid));
		editor->build(state, state.toolid, state.width, state.height);
		return 0;
	}

	if(viewer->active(state)){
		view->hide(view->find(state.ui.tree, state.mainid));
		view->show(view->find(state.ui.tree, state.toolid));
		viewer->build(state, state.toolid, state.width, state.height);
		return 0;
	}

	view->show(view->find(state.ui.tree, state.mainid));

	ls = layout->compute(state.width, state.height, state.panelshidden);

	topbar->build(state, state.topbar, ls.topbar);
	bottombar->build(state, state.bottombar, ls.bottombar);

	if(!state.panelshidden){
		showpanelnode(state, state.left);
		showpanelnode(state, state.right);

		appanel->build(state, state.left, ls.leftpanel);
		appanel->build(state, state.right, ls.rightpanel);
		appanel->setactive(state, state.left, state.activepanel == IcState->PanelLeft);
		appanel->setactive(state, state.right, state.activepanel == IcState->PanelRight);
	}else{
		hidepanelnode(state, state.left);
		hidepanelnode(state, state.right);
	}

	return 0;
}

rebuild(state: ref IcState->AppState): int
{
	return build(state);
}

redraw(state: ref IcState->AppState): int
{
	if(state == nil || state.ui == nil)
		return -1;

	ui->draw(state.ui);
	return 0;
}