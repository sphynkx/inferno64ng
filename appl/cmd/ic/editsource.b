implement IcEditSource;

include "ic/editsource.m";

IcEditCommon: module
{
	PATH: con "/dis/ic/editcommon.dis";

	ModeEdit: con 0;
	SelectionNone: con 0;

	init: fn();
	trim: fn(s: string): string;
	joinpath: fn(base, name: string): string;
	dirname: fn(path: string): string;
	expandtabs: fn(s: string): string;
};

sys: Sys;
common: IcEditCommon;

ScanChunkSize: con 32768;
InitialOffsetCap: con 1024;
MaxRawLineLen: con 8192;

OpSet: con 1;
OpInsert: con 2;
OpDelete: con 3;

MapMissing: con -1;
MapOriginal: con 0;
MapAdd: con 1;

appendoffset: fn(e: ref IcState->EditorState, off: big);
appendop: fn(e: ref IcState->EditorState, op: IcState->EditorOp);
appendaddline: fn(e: ref IcState->EditorState, text: string): int;
appendline: fn(a: array of string, text: string): array of string;

ensureindexed: fn(e: ref IcState->EditorState, line: int): int;
ensureeof: fn(e: ref IcState->EditorState): int;
originallinecount: fn(e: ref IcState->EditorState): int;
opdelta: fn(e: ref IcState->EditorState): int;

mapline: fn(e: ref IcState->EditorState, line: int): (int, int);
getlineoriginal: fn(e: ref IcState->EditorState, line: int): string;

sanitize: fn(text: string): string;
safecell: fn(c: int): string;

writeall: fn(fd: ref Sys->FD, text: string): int;
copyfile: fn(src, dst: string): int;
tmpname: fn(path: string): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	common = load IcEditCommon IcEditCommon->PATH;
	if(common == nil)
		raise "fail:load ic/editcommon";

	common->init();
}

newstate(path, dir: string): ref IcState->EditorState
{
	e: ref IcState->EditorState;
	d: Sys->Dir;
	rc: int;

	e = ref IcState->EditorState;

	e.active = 1;
	e.path = path;
	e.dir = dir;

	e.fd = nil;
	e.length = big 0;

	e.offsetcap = InitialOffsetCap;
	e.offsets = array[e.offsetcap] of big;
	e.offsets[0] = big 0;
	e.noffsets = 1;
	e.scanoff = big 0;
	e.eof = 0;
	e.error = "";

	e.addlines = array[0] of string;
	e.ops = array[0] of IcState->EditorOp;

	e.lines = array[0] of string;

	e.topline = 0;
	e.nlines = 1;
	e.cursorline = 0;
	e.cursorcol = 0;

	e.topid = -1;
	e.bodyid = -1;
	e.bottomid = -1;

	e.buttonids = array[0] of int;
	e.overlayids = array[0] of int;

	e.dirty = 0;
	e.message = "";

	e.mode = IcEditCommon->ModeEdit;
	e.filenameinput = "";
	e.searchinput = "";
	e.lastsearch = "";

	e.activefkey = 0;
	e.activewait = 0;

	e.selectionmode = IcEditCommon->SelectionNone;

	e.modalstage = 0;
	e.modalwait = 0;

	if(e.dir == "" && path != "")
		e.dir = common->dirname(path);

	if(path != ""){
		e.fd = sys->open(path, Sys->OREAD);
		if(e.fd == nil){
			e.eof = 1;
			e.message = "New file: " + path;
		}else{
			(rc, d) = sys->fstat(e.fd);
			if(rc >= 0)
				e.length = d.length;
		}
	}else{
		e.eof = 1;
		e.message = "New file";
	}

	refreshwindow(e, 32);

	return e;
}

close(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.fd = nil;
}

appendoffset(e: ref IcState->EditorState, off: big)
{
	a: array of big;
	i, ncap: int;

	if(e == nil || off < big 0)
		return;

	if(e.length > big 0 && off >= e.length)
		return;

	if(e.noffsets > 0 && e.offsets[e.noffsets - 1] == off)
		return;

	if(e.noffsets >= e.offsetcap){
		ncap = e.offsetcap * 2;
		if(ncap < InitialOffsetCap)
			ncap = InitialOffsetCap;

		a = array[ncap] of big;
		for(i = 0; i < e.noffsets; i++)
			a[i] = e.offsets[i];

		e.offsets = a;
		e.offsetcap = ncap;
	}

	e.offsets[e.noffsets] = off;
	e.noffsets++;
}

ensureindexed(e: ref IcState->EditorState, line: int): int
{
	buf: array of byte;
	n, i: int;
	off: big;

	if(e == nil)
		return 0;

	if(line < 0)
		line = 0;

	if(e.fd == nil)
		return line == 0;

	if(line < e.noffsets)
		return 1;

	if(e.eof)
		return line < e.noffsets;

	buf = array[ScanChunkSize] of byte;

	while(!e.eof && e.noffsets <= line){
		n = sys->pread(e.fd, buf, len buf, e.scanoff);
		if(n < 0){
			e.eof = 1;
			break;
		}

		if(n == 0){
			e.eof = 1;
			e.length = e.scanoff;
			break;
		}

		for(i = 0; i < n; i++){
			if(int buf[i] == '\n'){
				off = e.scanoff + big (i + 1);
				appendoffset(e, off);
			}
		}

		e.scanoff += big n;

		if(e.length > big 0 && e.scanoff >= e.length){
			e.eof = 1;
			e.length = e.scanoff;
		}
	}

	return line < e.noffsets;
}

ensureeof(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	while(!e.eof)
		ensureindexed(e, e.noffsets);

	return 1;
}

originallinecount(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 1;

	if(e.fd == nil)
		return 1;

	return e.noffsets;
}

opdelta(e: ref IcState->EditorState): int
{
	i, d: int;

	d = 0;

	if(e == nil || e.ops == nil)
		return d;

	for(i = 0; i < len e.ops; i++){
		if(e.ops[i].kind == OpInsert)
			d += e.ops[i].count;
		else if(e.ops[i].kind == OpDelete)
			d -= e.ops[i].count;
	}

	return d;
}

linecount(e: ref IcState->EditorState): int
{
	n: int;

	if(e == nil)
		return 1;

	n = originallinecount(e) + opdelta(e);
	if(n < 1)
		n = 1;

	return n;
}

appendop(e: ref IcState->EditorState, op: IcState->EditorOp)
{
	a: array of IcState->EditorOp;
	i, n: int;

	if(e == nil)
		return;

	n = len e.ops;
	a = array[n + 1] of IcState->EditorOp;
	for(i = 0; i < n; i++)
		a[i] = e.ops[i];

	a[n] = op;
	e.ops = a;
	e.dirty = 1;
}

appendaddline(e: ref IcState->EditorState, text: string): int
{
	a: array of string;
	i, n: int;

	if(e == nil)
		return -1;

	n = len e.addlines;
	a = array[n + 1] of string;
	for(i = 0; i < n; i++)
		a[i] = e.addlines[i];

	a[n] = text;
	e.addlines = a;

	return n;
}

mapline(e: ref IcState->EditorState, line: int): (int, int)
{
	i: int;
	op: IcState->EditorOp;

	if(e == nil || line < 0)
		return (MapMissing, -1);

	for(i = len e.ops - 1; i >= 0; i--){
		op = e.ops[i];

		if(op.kind == OpInsert){
			if(line >= op.line && line < op.line + op.count)
				return (MapAdd, op.addstart + line - op.line);

			if(line >= op.line + op.count)
				line -= op.count;
		}else if(op.kind == OpDelete){
			if(line >= op.line)
				line += op.count;
		}else if(op.kind == OpSet){
			if(line == op.line)
				return (MapAdd, op.addstart);
		}
	}

	return (MapOriginal, line);
}

ensureline(e: ref IcState->EditorState, line: int): int
{
	kind, idx: int;

	if(e == nil)
		return line == 0;

	if(line < 0)
		return 0;

	(kind, idx) = mapline(e, line);

	if(kind == MapAdd)
		return idx >= 0 && idx < len e.addlines;

	if(kind == MapOriginal)
		return ensureindexed(e, idx);

	return 0;
}

getline(e: ref IcState->EditorState, line: int): string
{
	kind, idx: int;

	if(e == nil)
		return "";

	if(line < 0)
		return "";

	(kind, idx) = mapline(e, line);

	if(kind == MapAdd){
		if(idx >= 0 && idx < len e.addlines)
			return e.addlines[idx];

		return "";
	}

	if(kind == MapOriginal)
		return getlineoriginal(e, idx);

	return "";
}

getlineoriginal(e: ref IcState->EditorState, line: int): string
{
	start, end, span: big;
	want, n: int;
	buf: array of byte;

	if(e == nil || line < 0)
		return "";

	if(e.fd == nil)
		return "";

	if(!ensureindexed(e, line))
		return "";

	start = e.offsets[line];

	ensureindexed(e, line + 1);

	if(line + 1 < e.noffsets)
		end = e.offsets[line + 1];
	else if(e.eof && e.length > big 0)
		end = e.length;
	else
		end = e.scanoff;

	if(end < start)
		end = start;

	span = end - start;
	if(span > big MaxRawLineLen)
		span = big MaxRawLineLen;

	want = int span;
	if(want <= 0)
		return "";

	buf = array[want] of byte;
	n = sys->pread(e.fd, buf, want, start);
	if(n <= 0)
		return "";

	while(n > 0 && (int buf[n - 1] == '\n' || int buf[n - 1] == '\r'))
		n--;

	if(n <= 0)
		return "";

	return sanitize(common->expandtabs(string buf[0:n]));
}

safecell(c: int): string
{
	if(c == '\t')
		return " ";

	if(c == '\r' || c == '\n')
		return "";

	if(c < 32 || c == 127)
		return ".";

	if(c >= 16r80 && c < 16rA0)
		return ".";

	return sys->sprint("%c", c);
}

sanitize(text: string): string
{
	i, c, need: int;
	out: string;

	if(text == "")
		return "";

	need = 0;
	for(i = 0; i < len text; i++){
		c = text[i];
		if(c < 32 || c == 127 || (c >= 16r80 && c < 16rA0)){
			need = 1;
			break;
		}
	}

	if(!need)
		return text;

	out = "";
	for(i = 0; i < len text; i++)
		out += safecell(text[i]);

	return out;
}

setline(e: ref IcState->EditorState, line: int, text: string): int
{
	op: IcState->EditorOp;
	addidx: int;

	if(e == nil || line < 0)
		return 0;

	addidx = appendaddline(e, text);
	if(addidx < 0)
		return 0;

	op.kind = OpSet;
	op.line = line;
	op.count = 1;
	op.addstart = addidx;

	appendop(e, op);
	return 1;
}

insertlineat(e: ref IcState->EditorState, line: int, text: string): int
{
	op: IcState->EditorOp;
	addidx, n: int;

	if(e == nil)
		return 0;

	n = linecount(e);

	if(line < 0)
		line = 0;
	if(line > n)
		line = n;

	addidx = appendaddline(e, text);
	if(addidx < 0)
		return 0;

	op.kind = OpInsert;
	op.line = line;
	op.count = 1;
	op.addstart = addidx;

	appendop(e, op);
	return 1;
}

deletelineat(e: ref IcState->EditorState, line: int): int
{
	op: IcState->EditorOp;
	n: int;

	if(e == nil)
		return 0;

	n = linecount(e);

	if(n <= 1){
		setline(e, 0, "");
		return 1;
	}

	if(line < 0 || line >= n)
		return 0;

	op.kind = OpDelete;
	op.line = line;
	op.count = 1;
	op.addstart = -1;

	appendop(e, op);
	return 1;
}

writeall(fd: ref Sys->FD, text: string): int
{
	n: int;

	if(fd == nil)
		return -1;

	n = sys->fprint(fd, "%s", text);
	if(n < 0)
		return -1;

	return 0;
}

tmpname(path: string): string
{
	if(path == "")
		return "/tmp/icedit.tmp";

	return path + ".icedit.tmp";
}

copyfile(src, dst: string): int
{
	in, out: ref Sys->FD;
	buf: array of byte;
	n: int;

	in = sys->open(src, Sys->OREAD);
	if(in == nil)
		return -1;

	out = sys->create(dst, Sys->OWRITE, 8r666);
	if(out == nil){
		in = nil;
		return -1;
	}

	buf = array[32768] of byte;

	for(;;){
		n = sys->read(in, buf, len buf);
		if(n < 0){
			in = nil;
			out = nil;
			return -1;
		}

		if(n == 0)
			break;

		if(sys->write(out, buf, n) != n){
			in = nil;
			out = nil;
			return -1;
		}
	}

	in = nil;
	out = nil;

	return 0;
}

savefile(e: ref IcState->EditorState): int
{
	fd: ref Sys->FD;
	tmp, line: string;
	i, n: int;

	if(e == nil)
		return 0;

	if(e.path == ""){
		e.message = "File name required";
		return 0;
	}

	ensureeof(e);

	tmp = tmpname(e.path);
	fd = sys->create(tmp, Sys->OWRITE, 8r666);
	if(fd == nil){
		e.message = "Save failed";
		return 0;
	}

	n = linecount(e);

	for(i = 0; i < n; i++){
		line = getline(e, i);

		if(writeall(fd, line) < 0){
			fd = nil;
			e.message = "Save failed";
			return 0;
		}

		if(i < n - 1){
			if(writeall(fd, "\n") < 0){
				fd = nil;
				e.message = "Save failed";
				return 0;
			}
		}
	}

	fd = nil;

	if(e.fd != nil)
		e.fd = nil;

	if(copyfile(tmp, e.path) < 0){
		e.message = "Save failed";
		return 0;
	}

	sys->remove(tmp);

	e.fd = sys->open(e.path, Sys->OREAD);
	e.length = big 0;
	e.offsetcap = InitialOffsetCap;
	e.offsets = array[e.offsetcap] of big;
	e.offsets[0] = big 0;
	e.noffsets = 1;
	e.scanoff = big 0;
	e.eof = 0;
	e.error = "";
	e.addlines = array[0] of string;
	e.ops = array[0] of IcState->EditorOp;
	e.dirty = 0;

	e.message = "Saved";
	e.nlines = linecount(e);

	return 1;
}

saveas(e: ref IcState->EditorState, name: string): int
{
	path: string;

	if(e == nil)
		return 0;

	name = common->trim(name);
	if(name == ""){
		e.message = "File name is empty";
		return 0;
	}

	path = common->joinpath(e.dir, name);
	e.path = path;

	return savefile(e);
}

appendline(a: array of string, text: string): array of string
{
	b: array of string;
	i, n: int;

	if(a == nil){
		b = array[1] of string;
		b[0] = text;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;
	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = text;
	return b;
}

refreshwindow(e: ref IcState->EditorState, rows: int)
{
	i, idx, n: int;
	lines: array of string;

	if(e == nil)
		return;

	if(rows < 1)
		rows = 1;

	if(e.topline < 0)
		e.topline = 0;

	lines = array[0] of string;

	for(i = 0; i < rows; i++){
		idx = e.topline + i;
		if(!ensureline(e, idx))
			break;

		lines = appendline(lines, getline(e, idx));
	}

	if(len lines == 0)
		lines = appendline(lines, "");

	e.lines = lines;

	n = linecount(e);
	if(n < 1)
		n = 1;

	e.nlines = n;
}