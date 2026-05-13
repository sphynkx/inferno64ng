implement IcBottomBar;

include "ic/bottombar.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
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

ui: IcUiMod;
view: IcViewMod;

BarText: con " F1 Help  F2 Menu  F3 View  F4 Edit  F5 Copy  F6 Move  F7 MkDir  F8 Delete  F9 Menu  F10 Exit ";

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

newbar(): ref IcState->BottomBarState
{
	return ref IcState->BottomBarState;
}

build(state: ref IcState->AppState, bar: ref IcState->BottomBarState, rect: IcLayout->Rect): int
{
	n: ref IcView->Node;

	if(state == nil || state.ui == nil || bar == nil)
		return -1;

	if(bar.id <= 0)
		bar.id = view->allocid(state.ui.tree);

	ui->label(state.ui, state.mainid, bar.id, rect.x, rect.y, rect.w, BarText);

	n = view->find(state.ui.tree, bar.id);
	if(n != nil){
		view->setbounds(n, rect.x, rect.y, rect.w, 1);
		view->settext(n, BarText);
		view->show(n);
	}

	return 0;
}