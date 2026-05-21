include "ic/state.m";
include "ic/viewcommon.m";

IcViewSearchRun: module
{
	PATH: con "/dis/ic/viewsearchrun.dis";

	SearchResult: adt
	{
		found: int;
		alert: int;
		alerttext: string;
	};

	init: fn();

	reset: fn();
	lastpattern: fn(): string;

	run: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState,
		opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult;

	searchsarg: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, h: int): string;
};