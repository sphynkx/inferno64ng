include "ic/state.m";

IcEditCommon: module
{
	PATH: con "/dis/ic/editcommon.dis";

	ModeEdit: con 0;
	ModeConfirmQuit: con 1;
	ModeFilename: con 2;
	ModeHelp: con 3;
	ModeSearch: con 4;
	ModeMenu: con 5;

	SelectionNone: con 0;
	SelectionLine: con 1;
	SelectionBlock: con 2;

	TabSpaces: con 4;
	ButtonCount: con 10;
	ButtonGap: con 1;
	FlashTicks: con 2;
	ModalStageMax: con 3;

	EditorButton: adt
	{
		fkey: int;
		text: string;
		enabled: int;
	};

	init: fn();

	spaces: fn(n: int): string;
	repeat: fn(s: string, n: int): string;
	fittext: fn(s: string, w: int): string;
	trim: fn(s: string): string;

	joinpath: fn(base, name: string): string;
	basename: fn(path: string): string;
	dirname: fn(path: string): string;
	expandtabs: fn(s: string): string;

	bodyh: fn(h: int): int;
	buttondef: fn(idx: int): EditorButton;
};