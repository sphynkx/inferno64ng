include "ic/state.m";
include "ic/viewcommon.m";

IcEditSearchRun: module
{
	PATH: con "/dis/ic/editsearchrun.dis";

	SearchResult: adt
	{
		found: int;
		alert: int;
		alerttext: string;
	};

	init: fn();

	reset: fn();
	lastpattern: fn(): string;

	run: fn(e: ref IcState->EditorState, opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult;
	searchsarg: fn(e: ref IcState->EditorState, h: int): string;
};