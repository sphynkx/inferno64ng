include "ic/state.m";

IcEditSource: module
{
	PATH: con "/dis/ic/editsource.dis";

	init: fn();

	newstate: fn(path, dir: string): ref IcState->EditorState;
	close: fn(e: ref IcState->EditorState);

	linecount: fn(e: ref IcState->EditorState): int;
	ensureline: fn(e: ref IcState->EditorState, line: int): int;
	getline: fn(e: ref IcState->EditorState, line: int): string;

	setline: fn(e: ref IcState->EditorState, line: int, text: string): int;
	insertlineat: fn(e: ref IcState->EditorState, line: int, text: string): int;
	deletelineat: fn(e: ref IcState->EditorState, line: int): int;

	savefile: fn(e: ref IcState->EditorState): int;
	saveas: fn(e: ref IcState->EditorState, name: string): int;

	refreshwindow: fn(e: ref IcState->EditorState, rows: int);
};