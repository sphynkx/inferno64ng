implement IcTopBar;

include "ic/topbar.m";

IcTopMenu: module
{
	PATH: con "/dis/ic/topmenu.dis";

	init: fn();

	newstate: fn(): ref IcState->TopBarState;

	active: fn(bar: ref IcState->TopBarState): int;
	toggle: fn(bar: ref IcState->TopBarState);
	close: fn(bar: ref IcState->TopBarState);

	build: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int;
	handlekey: fn(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int;
};

topmenu: IcTopMenu;

init()
{
	topmenu = load IcTopMenu IcTopMenu->PATH;
	if(topmenu == nil)
		raise "fail:load ic/topmenu";

	topmenu->init();
}

newbar(): ref IcState->TopBarState
{
	return topmenu->newstate();
}

build(state: ref IcState->AppState, bar: ref IcState->TopBarState, rect: IcLayout->Rect): int
{
	return topmenu->build(state, bar, rect);
}

active(bar: ref IcState->TopBarState): int
{
	return topmenu->active(bar);
}

toggle(bar: ref IcState->TopBarState)
{
	topmenu->toggle(bar);
}

close(bar: ref IcState->TopBarState)
{
	topmenu->close(bar);
}

handlekey(state: ref IcState->AppState, bar: ref IcState->TopBarState, k: int): int
{
	return topmenu->handlekey(state, bar, k);
}