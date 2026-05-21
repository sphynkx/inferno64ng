include "ic/state.m";
include "ic/viewcommon.m";

IcViewStatus: module
{
	PATH: con "/dis/ic/viewstatus.dis";

	init: fn();

	toptext: fn(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, bodyrows: int): string;
};