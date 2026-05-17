include "ic/state.m";

IcFsModel: module
{
	PATH: con "/dis/ic/fsmodel.dis";

	init: fn();
	readdir: fn(path: string): ref IcState->PanelDir;
	renderitems: fn(d: ref IcState->PanelDir): array of string;
};