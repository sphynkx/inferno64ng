IcZipMount: module
{
	PATH: con "/dis/ic/zipmount.dis";

	init: fn();
	mount: fn(zipfile, mountpoint: string): int;
};