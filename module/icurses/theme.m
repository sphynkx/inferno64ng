include "icurses/icurses.m";

IcTheme: module
{
	PATH: con "/dis/lib/icurses/theme.dis";

	#
	# Core UI attributes.
	#
	AttrNormal: con 0;
	AttrWindow: con 1;
	AttrFrame: con 2;
	AttrTitle: con 3;
	AttrButton: con 4;
	AttrFocus: con 5;
	AttrStatus: con 6;
	AttrScroll: con 7;
	AttrShadow: con 8;
	AttrMarked: con 9;
	AttrMarkedFocus: con 10;

	#
	# Generic effect attributes for demos/games/animation layers.
	# They are intentionally not Matrix-specific.
	#
	AttrEffectHead: con 20;
	AttrEffectBright: con 21;
	AttrEffectMid: con 22;
	AttrEffectDim: con 23;
	AttrEffectDark: con 24;

	init: fn(ci: Icurses->ConsInfo);

	sgr: fn(attr: int): string;

	colors: fn(): int;
	truecolor: fn(): int;
};