include "ic/state.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	loadstate: fn(): ref IcState->ConfigState;
	settheme: fn(c: ref IcState->ConfigState, name: string): int;

	hasuserdir: fn(c: ref IcState->ConfigState): int;
	userpath: fn(c: ref IcState->ConfigState, name: string): string;
	ensureuserpath: fn(c: ref IcState->ConfigState, name: string): string;

	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;

	set: fn(c: ref IcState->ConfigState, section, key, value: string): int;
	setint: fn(c: ref IcState->ConfigState, section, key: string, value: int): int;
	setbool: fn(c: ref IcState->ConfigState, section, key: string, value: int): int;
};