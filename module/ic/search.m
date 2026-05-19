include "sys.m";
include "ic/viewcommon.m";

IcSearch: module
{
	PATH: con "/dis/ic/search.dis";

	init: fn();

	defaultopts: fn(): IcViewCommon->SearchOptions;
	newsession: fn(path: string, opts: IcViewCommon->SearchOptions): ref IcViewCommon->SearchSession;
	reset: fn(s: ref IcViewCommon->SearchSession, path: string, opts: IcViewCommon->SearchOptions);

	addmatch: fn(s: ref IcViewCommon->SearchSession, m: IcViewCommon->SearchMatch): int;

	findplain: fn(text, pattern: string, casefold, startcol, backward: int): (int, int);
	matchline: fn(text, pattern: string, casefold, regex, startcol, backward: int): (int, int, string);

	lowerstr: fn(s: string): string;
};