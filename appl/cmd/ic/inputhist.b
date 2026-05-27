implement IcInputHistory;

include "ic/inputhist.m";

IcUserDirMod: module
{
	PATH: con "/dis/ic/userdir.dis";

	init: fn();
	ensurepath: fn(name: string): string;
};

sys: Sys;
userdir: IcUserDirMod;

trim: fn(s: string): string;
readfile: fn(path: string): string;
writefile: fn(path, text: string): int;
escape: fn(s: string): string;
unescape: fn(s: string): string;
appenditem: fn(a: array of string, s: string): array of string;
prependitem: fn(a: array of string, s: string): array of string;
removeitem: fn(a: array of string, s: string): array of string;
truncateitems: fn(a: array of string, maxitems: int): array of string;
parse: fn(text, section: string): array of string;
serialize: fn(section: string, items: array of string): string;
mergesection: fn(text, section: string, items: array of string): string;
histpath: fn(): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	userdir = load IcUserDirMod IcUserDirMod->PATH;
	if(userdir == nil)
		raise "fail:load ic/userdir";

	userdir->init();
}

new(section: string, maxitems: int): ref History
{
	h: ref History;

	if(maxitems <= 0)
		maxitems = DefaultMaxItems;

	h = ref History;
	h.section = section;
	h.items = array[0] of string;
	h.sel = -1;
	h.maxitems = maxitems;

	return h;
}

histpath(): string
{
	return userdir->ensurepath(FileName);
}

trim(s: string): string
{
	a, b: int;

	a = 0;
	b = len s;

	while(a < b && (s[a] == ' ' || s[a] == '\t' || s[a] == '\r' || s[a] == '\n'))
		a++;

	while(b > a && (s[b - 1] == ' ' || s[b - 1] == '\t' || s[b - 1] == '\r' || s[b - 1] == '\n'))
		b--;

	if(a >= b)
		return "";

	return s[a:b];
}

readfile(pathname: string): string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	out: string;

	if(pathname == "")
		return "";

	fd = sys->open(pathname, Sys->OREAD);
	if(fd == nil)
		return "";

	buf = array[4096] of byte;
	out = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		out += string buf[0:n];
	}

	return out;
}

writefile(pathname, text: string): int
{
	fd: ref Sys->FD;

	if(pathname == "")
		return -1;

	fd = sys->create(pathname, Sys->OWRITE, 8r666);
	if(fd == nil)
		return -1;

	sys->fprint(fd, "%s", text);
	return 0;
}

escape(s: string): string
{
	out: string;
	i: int;

	out = "";
	for(i = 0; i < len s; i++){
		if(s[i] == '\\')
			out += "\\\\";
		else if(s[i] == '\n')
			out += "\\n";
		else if(s[i] == '\r')
			out += "\\r";
		else
			out += s[i:i + 1];
	}

	return out;
}

unescape(s: string): string
{
	out: string;
	i: int;

	out = "";
	for(i = 0; i < len s; i++){
		if(s[i] != '\\' || i + 1 >= len s){
			out += s[i:i + 1];
			continue;
		}

		i++;
		if(s[i] == 'n')
			out += "\n";
		else if(s[i] == 'r')
			out += "\r";
		else
			out += s[i:i + 1];
	}

	return out;
}

appenditem(a: array of string, s: string): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		a = array[0] of string;

	n = len a;
	r = array[n + 1] of string;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	r[n] = s;
	return r;
}

prependitem(a: array of string, s: string): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		a = array[0] of string;

	n = len a;
	r = array[n + 1] of string;
	r[0] = s;

	for(i = 0; i < n; i++)
		r[i + 1] = a[i];

	return r;
}

removeitem(a: array of string, s: string): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		return array[0] of string;

	n = 0;
	for(i = 0; i < len a; i++){
		if(a[i] != s)
			n++;
	}

	r = array[n] of string;
	n = 0;

	for(i = 0; i < len a; i++){
		if(a[i] != s){
			r[n] = a[i];
			n++;
		}
	}

	return r;
}

truncateitems(a: array of string, maxitems: int): array of string
{
	r: array of string;
	i, n: int;

	if(a == nil)
		return array[0] of string;

	if(maxitems <= 0)
		maxitems = DefaultMaxItems;

	if(len a <= maxitems)
		return a;

	n = maxitems;
	r = array[n] of string;

	for(i = 0; i < n; i++)
		r[i] = a[i];

	return r;
}

parse(text, section: string): array of string
{
	items: array of string;
	line, cur, key, value: string;
	i, start, eq, active, p: int;

	items = array[0] of string;
	cur = "";
	active = 0;
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = trim(text[start:i]);
		start = i + 1;

		if(line == "")
			continue;

		if(line[0] == '[' && len line > 2 && line[len line - 1] == ']'){
			cur = trim(line[1:len line - 1]);
			active = cur == section;
			continue;
		}

		if(!active)
			continue;

		eq = -1;
		for(p = 0; p < len line; p++){
			if(line[p] == '='){
				eq = p;
				break;
			}
		}

		if(eq < 0)
			continue;

		key = trim(line[0:eq]);
		value = trim(line[eq + 1:]);

		if(key != "")
			items = appenditem(items, unescape(value));
	}

	return items;
}

serialize(section: string, items: array of string): string
{
	out: string;
	i: int;

	out = "[" + section + "]\n";

	if(items != nil){
		for(i = 0; i < len items; i++)
			out += "item" + string i + "=" + escape(items[i]) + "\n";
	}

	return out;
}

mergesection(text, section: string, items: array of string): string
{
	out, line, cur: string;
	i, start, active, replaced: int;

	out = "";
	cur = "";
	active = 0;
	replaced = 0;
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = text[start:i];
		start = i + 1;

		if(trim(line) != "" && trim(line)[0] == '[' && len trim(line) > 2 && trim(line)[len trim(line) - 1] == ']'){
			if(active && !replaced){
				out += serialize(section, items);
				out += "\n";
				replaced = 1;
			}

			cur = trim(trim(line)[1:len trim(line) - 1]);
			active = cur == section;

			if(!active){
				out += line + "\n";
			}

			continue;
		}

		if(!active)
			out += line + "\n";
	}

	if(!replaced){
		if(out != "" && out[len out - 1] != '\n')
			out += "\n";
		if(out != "")
			out += "\n";

		out += serialize(section, items);
	}

	return out;
}

loadhist(h: ref History): int
{
	p, text: string;

	if(h == nil)
		return -1;

	p = histpath();
	if(p == "")
		return -1;

	text = readfile(p);
	h.items = parse(text, h.section);
	h.items = truncateitems(h.items, h.maxitems);
	h.sel = -1;

	return 0;
}

savehist(h: ref History): int
{
	p, text, merged: string;

	if(h == nil)
		return -1;

	p = histpath();
	if(p == "")
		return -1;

	text = readfile(p);
	merged = mergesection(text, h.section, h.items);

	return writefile(p, merged);
}

add(h: ref History, text: string): int
{
	if(h == nil)
		return -1;

	text = trim(text);
	if(text == "")
		return 0;

	h.items = removeitem(h.items, text);
	h.items = prependitem(h.items, text);
	h.items = truncateitems(h.items, h.maxitems);
	h.sel = -1;

	return savehist(h);
}

count(h: ref History): int
{
	if(h == nil || h.items == nil)
		return 0;

	return len h.items;
}

current(h: ref History): string
{
	if(h == nil || h.items == nil)
		return "";

	if(h.sel < 0 || h.sel >= len h.items)
		return "";

	return h.items[h.sel];
}

prev(h: ref History): string
{
	if(h == nil || h.items == nil || len h.items == 0)
		return "";

	if(h.sel < 0)
		h.sel = len h.items - 1;
	else if(h.sel > 0)
		h.sel--;
	else
		h.sel = len h.items - 1;

	return current(h);
}

next(h: ref History): string
{
	if(h == nil || h.items == nil || len h.items == 0)
		return "";

	if(h.sel < 0)
		h.sel = 0;
	else if(h.sel + 1 < len h.items)
		h.sel++;
	else
		h.sel = 0;

	return current(h);
}

hide(h: ref History)
{
	if(h != nil)
		h.sel = -1;
}

visible(h: ref History): int
{
	if(h == nil)
		return 0;

	return h.sel >= 0;
}

show(h: ref History)
{
	if(h == nil)
		return;

	if(h.items != nil && len h.items > 0 && h.sel < 0)
		h.sel = 0;
}