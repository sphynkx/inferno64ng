implement IcViewStatus;

include "ic/viewstatus.m";

IcViewSourceMod: module
{
	PATH: con "/dis/ic/viewsource.dis";

	init: fn();

	linecount: fn(s: ref IcViewCommon->ViewerSource): int;
	encoding: fn(s: ref IcViewCommon->ViewerSource): string;
};

IcViewStatsMod: module
{
	PATH: con "/dis/ic/viewstats.dis";

	init: fn();

	get: fn(): IcViewCommon->ViewerStats;
};

srcmod: IcViewSourceMod;
statsmod: IcViewStatsMod;

humanbytes: fn(n: big): string;
knownoffset: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState): big;
viewpercent: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, bodyrows: int): string;
linestat: fn(source: ref IcViewCommon->ViewerSource): string;
charstat: fn(source: ref IcViewCommon->ViewerSource): string;

init()
{
	srcmod = load IcViewSourceMod IcViewSourceMod->PATH;
	if(srcmod == nil)
		raise "fail:load ic/viewsource";

	statsmod = load IcViewStatsMod IcViewStatsMod->PATH;
	if(statsmod == nil)
		raise "fail:load ic/viewstats";

	srcmod->init();
	statsmod->init();
}

humanbytes(n: big): string
{
	if(n < big 0)
		n = big 0;

	if(n >= big 1073741824)
		return string int (n / big 1073741824) + "G";

	if(n >= big 1048576)
		return string int (n / big 1048576) + "M";

	if(n >= big 1024)
		return string int (n / big 1024) + "K";

	return string n + "B";
}

knownoffset(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState): big
{
	if(v == nil || source == nil)
		return big 0;

	if(v.topline < 0)
		return big 0;

	if(v.topline < source.noffsets)
		return source.offsets[v.topline];

	return source.scanoff;
}

viewpercent(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, bodyrows: int): string
{
	off: big;
	p: int;

	if(v == nil || source == nil)
		return "?%";

	if(source.length <= big 0)
		return "?%";

	if(source.eof && bodyrows > 0 && v.topline + bodyrows >= srcmod->linecount(source))
		return "100%";

	off = knownoffset(source, v);
	if(off < big 0)
		off = big 0;
	if(off > source.length)
		off = source.length;

	p = int (((off * big 100) + (source.length / big 2)) / source.length);
	if(p < 0)
		p = 0;
	if(p > 100)
		p = 100;

	return string p + "%";
}

linestat(source: ref IcViewCommon->ViewerSource): string
{
	st: IcViewCommon->ViewerStats;

	st = statsmod->get();
	if(st.ready)
		return string st.lines;

	if(source == nil)
		return "0";

	if(source.eof)
		return string srcmod->linecount(source);

	return "~" + string srcmod->linecount(source);
}

charstat(source: ref IcViewCommon->ViewerSource): string
{
	n: big;
	st: IcViewCommon->ViewerStats;

	st = statsmod->get();
	if(st.ready)
		return "~" + string st.chars;

	if(source == nil)
		return "~0";

	n = source.length;
	if(n <= big 0)
		n = source.scanoff;

	return "~" + string n;
}

toptext(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, bodyrows: int): string
{
	size, lines, chars, pos, enc: string;
	st: IcViewCommon->ViewerStats;

	if(v == nil)
		return "";

	if(source == nil)
		return " " + v.path + "  size:? lines:? chars:? pos:? enc:" + v.encoding;

	st = statsmod->get();

	if(st.ready && st.bytes > big 0)
		size = humanbytes(st.bytes);
	else if(source.length > big 0)
		size = humanbytes(source.length);
	else
		size = "~" + humanbytes(source.scanoff);

	lines = linestat(source);
	chars = charstat(source);
	pos = viewpercent(source, v, bodyrows);
	enc = srcmod->encoding(source);

	return " " + v.path
		+ "  size:" + size
		+ "  lines:" + lines
		+ "  chars:" + chars
		+ "  pos:" + pos
		+ "  enc:" + enc;
}