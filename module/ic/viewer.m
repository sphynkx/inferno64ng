IcViewer: module
{
	PATH: con "/dis/ic/viewer.dis";

	ModeText: con 0;
	ModeHex: con 1;

	init: fn();
	runfile: fn(path: string): int;
	runfilemode: fn(path: string, mode: int): int;
};