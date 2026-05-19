include "sys.m";
include "ic/viewcommon.m";

IcViewStats: module
{
	PATH: con "/dis/ic/viewstats.dis";

	init: fn();

	start: fn(path: string, knownbytes: big);
	stop: fn();

	get: fn(): IcViewCommon->ViewerStats;
	cleardirty: fn();
};