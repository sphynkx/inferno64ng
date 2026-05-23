implement IcUserDir;

include "sys.m";
include "ic/userdir.m";

sys: Sys;

HomeEnvFile: con "/env/home";
UserDirName: con "ic";

cleanpath: fn(path: string): string;
readtextfile: fn(path: string): string;
firstline: fn(s: string): string;
isdir: fn(path: string): int;
joinpath: fn(base, name: string): string;
createdir: fn(path: string): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

cleanpath(path: string): string
{
	if(path == nil)
		return "";

	if(path == "")
		return "";

	while(len path > 0
	&& (path[len path - 1] == '\n'
	|| path[len path - 1] == '\r'
	|| path[len path - 1] == ' '
	|| path[len path - 1] == '\t'))
		path = path[0:len path - 1];

	while(len path > 0
	&& (path[0] == ' ' || path[0] == '\t'))
		path = path[1:];

	if(len path > 1 && path[len path - 1] == '/')
		return path[0:len path - 1];

	return path;
}

readtextfile(path: string): string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return "";

	buf = array[4096] of byte;
	n = sys->read(fd, buf, len buf);
	fd = nil;

	if(n <= 0)
		return "";

	return string buf[0:n];
}

firstline(s: string): string
{
	i: int;

	for(i = 0; i < len s; i++){
		if(s[i] == '\n' || s[i] == '\r')
			return s[0:i];
	}

	return s;
}

isdir(path: string): int
{
	rc: int;
	d: Sys->Dir;

	if(path == "")
		return 0;

	(rc, d) = sys->stat(path);
	if(rc < 0)
		return 0;

	return (d.mode & Sys->DMDIR) != 0;
}

joinpath(base, name: string): string
{
	base = cleanpath(base);

	if(base == "")
		return "";

	if(name == "")
		return base;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

createdir(path: string): int
{
	fd: ref Sys->FD;

	if(path == "")
		return 0;

	if(isdir(path))
		return 1;

	fd = sys->create(path, Sys->OREAD, Sys->DMDIR | 8r777);
	if(fd == nil)
		return 0;

	fd = nil;
	return isdir(path);
}

home(): string
{
	h: string;

	h = readtextfile(HomeEnvFile);
	h = cleanpath(firstline(h));

	if(!isdir(h))
		return "";

	return h;
}

dir(): string
{
	h: string;

	h = home();
	if(h == "")
		return "";

	return joinpath(h, UserDirName);
}

enabled(): int
{
	return home() != "";
}

ensure(): int
{
	d: string;

	d = dir();
	if(d == "")
		return 0;

	return createdir(d);
}

path(name: string): string
{
	d: string;

	d = dir();
	if(d == "")
		return "";

	return joinpath(d, name);
}

ensurepath(name: string): string
{
	if(!ensure())
		return "";

	return path(name);
}