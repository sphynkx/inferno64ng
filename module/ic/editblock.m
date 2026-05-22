include "ic/state.m";

IcEditBlock: module
{
	PATH: con "/dis/ic/editblock.dis";

	SelectionNone: con 0;
	SelectionLine: con 1;
	SelectionBlock: con 2;

	init: fn();

	initstate: fn(e: ref IcState->EditorState);

	active: fn(e: ref IcState->EditorState): int;
	kind: fn(e: ref IcState->EditorState): int;

	startline: fn(e: ref IcState->EditorState);
	startblock: fn(e: ref IcState->EditorState);
	clear: fn(e: ref IcState->EditorState);

	refresh: fn(e: ref IcState->EditorState);

	span: fn(e: ref IcState->EditorState, line, width: int): (int, int, int);

	copyselection: fn(e: ref IcState->EditorState): int;
	paste: fn(e: ref IcState->EditorState): int;
	deleteselection: fn(e: ref IcState->EditorState): int;

	savepersistent: fn(e: ref IcState->EditorState): int;
	loadpersistent: fn(e: ref IcState->EditorState): int;
};