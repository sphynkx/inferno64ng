implement IcEditBlock;

include "ic/editblock.m";

IcEditSource: module
{
	PATH: con "/dis/ic/editsource.dis";

	init: fn();

	linecount: fn(e: ref IcState->EditorState): int;
	ensureline: fn(e: ref IcState->EditorState, line: int): int;
	getline: fn(e: ref IcState->EditorState, line: int): string;

	setline: fn(e: ref IcState->EditorState, line: int, text: string): int;
	insertlineat: fn(e: ref IcState->EditorState, line: int, text: string): int;
	deletelineat: fn(e: ref IcState->EditorState, line: int): int;
};

sys: Sys;
source: IcEditSource;

BufferDir: con "/tmp/ic";
BufferFile: con "/tmp/ic/edit-buffer";

PersistentLine: con "kind=line";
PersistentBlock: con "kind=block";
PersistentSep: con "--";

min: fn(a, b: int): int;
max: fn(a, b: int): int;
spaces: fn(n: int): string;
padto: fn(s: string, col: int): string;

appendline: fn(a: array of string, s: string): array of string;
splitlines: fn(text: string): array of string;
joinlines: fn(lines: array of string): string;

normalized: fn(e: ref IcState->EditorState): (int, int, int, int);
linepart: fn(s: string, a, b: int): string;

buildlinebuffer: fn(e: ref IcState->EditorState): array of string;
buildblockbuffer: fn(e: ref IcState->EditorState): array of string;

pasteline: fn(e: ref IcState->EditorState): int;
pasteblock: fn(e: ref IcState->EditorState): int;

deletefullines: fn(e: ref IcState->EditorState, a, b: int): int;
deleteblock: fn(e: ref IcState->EditorState, a, b, c0, c1: int): int;

ensurelineexists: fn(e: ref IcState->EditorState, line: int);
makedir: fn(path: string): int;
writefile: fn(path, text: string): int;
readfile: fn(path: string): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	source = load IcEditSource IcEditSource->PATH;
	if(source == nil)
		raise "fail:load ic/editsource";

	source->init();
}

initstate(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.selectionactive = 0;
	e.selectionkind = SelectionNone;
	e.selectionanchorline = 0;
	e.selectionanchorcol = 0;

	e.clipkind = SelectionNone;
	e.cliplines = array[0] of string;

	if(e.selectionids == nil)
		e.selectionids = array[0] of int;
}

active(e: ref IcState->EditorState): int
{
	return e != nil && e.selectionactive;
}

kind(e: ref IcState->EditorState): int
{
	if(e == nil)
		return SelectionNone;

	return e.selectionkind;
}

startline(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.selectionactive = 1;
	e.selectionkind = SelectionLine;
	e.selectionmode = SelectionLine;
	e.selectionanchorline = e.cursorline;
	e.selectionanchorcol = e.cursorcol;

	refresh(e);
	e.message = "Line selection";
}

startblock(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.selectionactive = 1;
	e.selectionkind = SelectionBlock;
	e.selectionmode = SelectionBlock;
	e.selectionanchorline = e.cursorline;
	e.selectionanchorcol = e.cursorcol;

	refresh(e);
	e.message = "Block selection";
}

clear(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.selectionactive = 0;
	e.selectionkind = SelectionNone;
	e.selectionmode = SelectionNone;
	e.message = "";
}

refresh(e: ref IcState->EditorState)
{
	if(e == nil || !e.selectionactive)
		return;

	if(e.selectionkind == SelectionBlock){
		e.cliplines = buildblockbuffer(e);
		e.clipkind = SelectionBlock;
	}else{
		e.cliplines = buildlinebuffer(e);
		e.clipkind = SelectionLine;
	}
}

min(a, b: int): int
{
	if(a < b)
		return a;

	return b;
}

max(a, b: int): int
{
	if(a > b)
		return a;

	return b;
}

spaces(n: int): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += " ";

	return s;
}

padto(s: string, col: int): string
{
	if(col <= len s)
		return s;

	return s + spaces(col - len s);
}

appendline(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(a == nil){
		b = array[1] of string;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;
	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = s;
	return b;
}

splitlines(text: string): array of string
{
	a: array of string;
	i, start: int;

	a = array[0] of string;
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		a = appendline(a, text[start:i]);
		start = i + 1;
	}

	if(len a == 0)
		a = appendline(a, "");

	return a;
}

joinlines(lines: array of string): string
{
	i: int;
	text: string;

	text = "";

	if(lines == nil)
		return text;

	for(i = 0; i < len lines; i++){
		text += lines[i];
		if(i < len lines - 1)
			text += "\n";
	}

	return text;
}

normalized(e: ref IcState->EditorState): (int, int, int, int)
{
	l0, l1, c0, c1: int;

	l0 = min(e.selectionanchorline, e.cursorline);
	l1 = max(e.selectionanchorline, e.cursorline);
	c0 = min(e.selectionanchorcol, e.cursorcol);
	c1 = max(e.selectionanchorcol, e.cursorcol);

	return (l0, l1, c0, c1);
}

linepart(s: string, a, b: int): string
{
	if(a < 0)
		a = 0;
	if(b < a)
		b = a;

	if(a > len s)
		return "";

	if(b > len s)
		b = len s;

	return s[a:b];
}

buildlinebuffer(e: ref IcState->EditorState): array of string
{
	a: array of string;
	l0, l1, c0, c1, i: int;

	a = array[0] of string;

	if(e == nil)
		return a;

	(l0, l1, c0, c1) = normalized(e);
	c0 = c0;
	c1 = c1;

	for(i = l0; i <= l1; i++)
		a = appendline(a, source->getline(e, i));

	return a;
}

buildblockbuffer(e: ref IcState->EditorState): array of string
{
	a: array of string;
	line: string;
	l0, l1, c0, c1, i, width: int;

	a = array[0] of string;

	if(e == nil)
		return a;

	(l0, l1, c0, c1) = normalized(e);
	width = c1 - c0 + 1;

	for(i = l0; i <= l1; i++){
		line = source->getline(e, i);
		line = padto(line, c1 + 1);
		a = appendline(a, linepart(line, c0, c0 + width));
	}

	return a;
}

span(e: ref IcState->EditorState, line, width: int): (int, int, int)
{
	l0, l1, c0, c1: int;

	if(e == nil || !e.selectionactive)
		return (0, 0, 0);

	(l0, l1, c0, c1) = normalized(e);

	if(line < l0 || line > l1)
		return (0, 0, 0);

	if(e.selectionkind == SelectionBlock){
		if(c1 < c0)
			return (0, 0, 0);

		return (c0, c1 + 1, 1);
	}

	return (0, width, 1);
}

copyselection(e: ref IcState->EditorState): int
{
	if(e == nil || !e.selectionactive)
		return 0;

	refresh(e);

	if(e.cliplines == nil || len e.cliplines == 0){
		e.message = "No selection";
		return 0;
	}

	e.message = "Selection copied";
	return 1;
}

ensurelineexists(e: ref IcState->EditorState, line: int)
{
	n: int;

	if(e == nil)
		return;

	n = source->linecount(e);

	while(n <= line){
		source->insertlineat(e, n, "");
		n++;
	}
}

pasteline(e: ref IcState->EditorState): int
{
	i, line: int;

	if(e == nil || e.cliplines == nil || len e.cliplines == 0)
		return 0;

	line = e.cursorline;
	if(line < 0)
		line = 0;

	for(i = 0; i < len e.cliplines; i++)
		source->insertlineat(e, line + i, e.cliplines[i]);

	e.cursorline = line + len e.cliplines - 1;
	if(e.cursorline < 0)
		e.cursorline = 0;
	e.cursorcol = 0;
	e.dirty = 1;
	e.message = "Buffer inserted";

	return 1;
}

pasteblock(e: ref IcState->EditorState): int
{
	i, line, col: int;
	text, part: string;

	if(e == nil || e.cliplines == nil || len e.cliplines == 0)
		return 0;

	line = e.cursorline;
	col = e.cursorcol;

	if(line < 0)
		line = 0;
	if(col < 0)
		col = 0;

	for(i = 0; i < len e.cliplines; i++){
		ensurelineexists(e, line + i);

		text = source->getline(e, line + i);
		text = padto(text, col);

		part = e.cliplines[i];
		text = text[0:col] + part + text[col:];

		source->setline(e, line + i, text);
	}

	e.dirty = 1;
	e.message = "Buffer inserted";
	return 1;
}

paste(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	if(e.cliplines == nil || len e.cliplines == 0){
		e.message = "Clipboard is empty";
		return 0;
	}

	if(e.clipkind == SelectionBlock)
		return pasteblock(e);

	return pasteline(e);
}

deletefullines(e: ref IcState->EditorState, a, b: int): int
{
	i: int;

	if(e == nil)
		return 0;

	for(i = b; i >= a; i--)
		source->deletelineat(e, i);

	e.cursorline = a;
	if(e.cursorline >= source->linecount(e))
		e.cursorline = source->linecount(e) - 1;
	if(e.cursorline < 0)
		e.cursorline = 0;

	e.cursorcol = 0;
	e.dirty = 1;
	return 1;
}

deleteblock(e: ref IcState->EditorState, a, b, c0, c1: int): int
{
	i: int;
	line: string;

	if(e == nil)
		return 0;

	for(i = a; i <= b; i++){
		line = source->getline(e, i);

		if(c0 >= len line)
			continue;

		if(c1 + 1 > len line)
			line = line[0:c0];
		else
			line = line[0:c0] + line[c1 + 1:];

		source->setline(e, i, line);
	}

	e.cursorline = a;
	e.cursorcol = c0;
	e.dirty = 1;
	return 1;
}

deleteselection(e: ref IcState->EditorState): int
{
	l0, l1, c0, c1: int;

	if(e == nil || !e.selectionactive)
		return 0;

	refresh(e);

	(l0, l1, c0, c1) = normalized(e);

	if(e.selectionkind == SelectionBlock)
		deleteblock(e, l0, l1, c0, c1);
	else
		deletefullines(e, l0, l1);

	clear(e);
	e.message = "Selection deleted";
	return 1;
}

makedir(path: string): int
{
	fd: ref Sys->FD;
	d: Sys->Dir;
	rc: int;

	(rc, d) = sys->stat(path);
	if(rc >= 0){
		if((d.mode & Sys->DMDIR) != 0)
			return 0;

		return -1;
	}

	fd = sys->create(path, Sys->OREAD, Sys->DMDIR | 8r777);
	if(fd == nil)
		return -1;

	fd = nil;
	return 0;
}

writefile(path, text: string): int
{
	fd: ref Sys->FD;

	fd = sys->create(path, Sys->OWRITE, 8r666);
	if(fd == nil)
		return -1;

	if(sys->fprint(fd, "%s", text) < 0){
		fd = nil;
		return -1;
	}

	fd = nil;
	return 0;
}

readfile(path: string): string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	text: string;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return "";

	buf = array[4096] of byte;
	text = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		text += string buf[0:n];
	}

	fd = nil;
	return text;
}

savepersistent(e: ref IcState->EditorState): int
{
	header, text: string;

	if(e == nil)
		return 0;

	if(e.selectionactive)
		refresh(e);

	if(e.cliplines == nil || len e.cliplines == 0){
		e.message = "Clipboard is empty";
		return 0;
	}

	if(makedir(BufferDir) < 0){
		e.message = "Cannot create clipboard directory";
		return 0;
	}

	if(e.clipkind == SelectionLine)
		header = PersistentLine;
	else if(e.clipkind == SelectionBlock)
		header = PersistentBlock;
	else{
		e.message = "Clipboard is empty";
		return 0;
	}

	text = header + "\n" + PersistentSep + "\n" + joinlines(e.cliplines);

	if(writefile(BufferFile, text) < 0){
		e.message = "Cannot save clipboard";
		return 0;
	}

	e.message = "Clipboard saved";
	return 1;
}

loadpersistent(e: ref IcState->EditorState): int
{
	text, body: string;
	lines: array of string;
	i, start: int;

	if(e == nil)
		return 0;

	text = readfile(BufferFile);
	if(text == "")
		return 0;

	lines = splitlines(text);
	if(lines == nil || len lines < 3)
		return 0;

	if(lines[0] == PersistentBlock)
		e.clipkind = SelectionBlock;
	else if(lines[0] == PersistentLine)
		e.clipkind = SelectionLine;
	else
		return 0;

	start = -1;
	for(i = 1; i < len lines; i++){
		if(lines[i] == PersistentSep){
			start = i + 1;
			break;
		}
	}

	if(start < 0 || start >= len lines)
		return 0;

	body = "";
	for(i = start; i < len lines; i++){
		body += lines[i];
		if(i < len lines - 1)
			body += "\n";
	}

	e.cliplines = splitlines(body);
	return e.cliplines != nil && len e.cliplines > 0;
}