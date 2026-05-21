IcCodepage: module
{
	PATH: con "/dis/ic/codepage.dis";

	init: fn();

	count: fn(): int;
	name: fn(idx: int): string;
	find: fn(enc: string): int;
	defaultname: fn(): string;

	decode: fn(enc: string, buf: array of byte, n: int): string;
};