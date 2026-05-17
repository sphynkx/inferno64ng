include "ic/state.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	loadstate: fn(): ref IcState->ConfigState;

	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
	getbool: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};