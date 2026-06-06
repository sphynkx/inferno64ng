IcArchiveUtil: module
{
	PATH: con "/dis/ic/archiveutil.dis";

	init: fn();
	istargz: fn(path: string): int;
	istarbz2: fn(path: string): int;
	iscpiogz: fn(path: string): int;
	iscpiobz2: fn(path: string): int;
	stagedtarpath: fn(path: string): string;
	stagedcpiopath: fn(path: string): string;
	preparetarpath: fn(path: string): (string, string);
	preparecpiopath: fn(path: string): (string, string);
};