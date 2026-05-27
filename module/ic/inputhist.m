include "ic/state.m";

IcInputHistory: module
{
	PATH: con "/dis/ic/inputhist.dis";

	DefaultMaxItems: con 32;
	FileName: con "history.cfg";

	History: adt
	{
		section: string;
		items: array of string;
		sel: int;
		maxitems: int;
	};

	init: fn();

	new: fn(section: string, maxitems: int): ref History;
	loadhist: fn(h: ref History): int;
	savehist: fn(h: ref History): int;

	add: fn(h: ref History, text: string): int;
	count: fn(h: ref History): int;
	current: fn(h: ref History): string;
	prev: fn(h: ref History): string;
	next: fn(h: ref History): string;

	hide: fn(h: ref History);
	visible: fn(h: ref History): int;
	show: fn(h: ref History);
};