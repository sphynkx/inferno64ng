include "sys.m";
include "ic/viewcommon.m";

IcViewSource: module
{
	PATH: con "/dis/ic/viewsource.dis";

	init: fn();

	newsource: fn(path: string): ref IcViewCommon->ViewerSource;
	closefile: fn(s: ref IcViewCommon->ViewerSource);

	ensureindexed: fn(s: ref IcViewCommon->ViewerSource, line: int): int;
	ensureeof: fn(s: ref IcViewCommon->ViewerSource): int;
	ensureoffset: fn(s: ref IcViewCommon->ViewerSource, off: big): int;

	linecount: fn(s: ref IcViewCommon->ViewerSource): int;
	lineforoffset: fn(s: ref IcViewCommon->ViewerSource, off: big): int;

	getline: fn(s: ref IcViewCommon->ViewerSource, line: int): string;

	wraplines: fn(lines: array of string, width: int): array of string;
	visiblecontent: fn(lines: array of string, top, rows: int): string;
	spaces: fn(n: int): string;
	fittext: fn(s: string, w: int): string;
};