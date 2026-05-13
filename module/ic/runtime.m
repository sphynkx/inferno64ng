include "sys.m";

IcRuntime: module
{
	PATH: con "/dis/ic/runtime.dis";

	init: fn();
	enter: fn(out: ref Sys->FD): int;
	leave: fn(out: ref Sys->FD);
	size: fn(): (int, int);
	pollresize: fn(oldw, oldh: int): (int, int, int);
};