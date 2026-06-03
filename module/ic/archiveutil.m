IcArchiveUtil: module
{
	PATH: con "/dis/ic/archiveutil.dis";

	init: fn();
	istargz: fn(path: string): int;
	stagedtarpath: fn(path: string): string;
	preparetarpath: fn(path: string): (string, string);
};