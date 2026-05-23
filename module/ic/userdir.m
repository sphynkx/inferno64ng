IcUserDir: module
{
	PATH: con "/dis/ic/userdir.dis";

	init: fn();

	home: fn(): string;
	dir: fn(): string;
	enabled: fn(): int;

	ensure: fn(): int;
	path: fn(name: string): string;
	ensurepath: fn(name: string): string;
};