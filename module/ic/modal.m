include "ic/state.m";

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	KindNone: con 0;
	KindCopyConfirm: con 1;
	KindOverwrite: con 2;

	ResultNone: con 0;
	ResultOk: con 1;
	ResultCancel: con 2;
	ResultOverwrite: con 3;
	ResultSkip: con 4;

	FocusCheckbox: con 0;
	FocusButton0: con 1;
	FocusButton1: con 2;
	FocusButton2: con 3;

	init: fn();

	active: fn(state: ref IcState->AppState): int;
	close: fn(state: ref IcState->AppState): int;

	showcopyconfirm: fn(state: ref IcState->AppState, count: int, dst: string): int;
	showoverwrite: fn(state: ref IcState->AppState, path: string): int;

	handlekey: fn(state: ref IcState->AppState, k: int): int;
};