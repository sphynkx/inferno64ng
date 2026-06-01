include "ic/state.m";

IcRunCmd: module
{
	PATH: con "/dis/ic/runcmd.dis";

	init: fn();

	runtemplate: fn(state: ref IcState->AppState, template: string): int;
	buildcommand: fn(state: ref IcState->AppState, template: string): string;
};