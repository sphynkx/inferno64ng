implement IcViewer;

include "ic/viewer.m";

IcursesApp: module
{
	PATH: con "/dis/lib/icurses/app.dis";

	ScreenNormal: con 0;
	ScreenAlternate: con 1;

	Options: adt
	{
		screenmode: int;
		mouse: int;
		tickms: int;
	};

	Context: adt
	{
		out: ref Sys->FD;
		ui: ref IcUi->Ui;

		w: int;
		h: int;

		screenmode: int;
		mouse: int;
		tickms: int;

		appscreen: int;
		opened: int;
		started: int;
	};

	init: fn(name: string);
	defaultopts: fn(): Options;
	newctx: fn(out: ref Sys->FD, opts: Options): ref Context;

	open: fn(c: ref Context): int;
	close: fn(c: ref Context);

	ui: fn(c: ref Context): ref IcUi->Ui;
	width: fn(c: ref Context): int;
	height: fn(c: ref Context): int;

	step: fn(c: ref Context): IcUi->Step;
	draw: fn(c: ref Context): int;
	pollresize: fn(c: ref Context, oldw, oldh: int): (int, int, int);
};

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	StepKey: con 1;
	StepTick: con 2;

	init: fn();
	rootid: fn(u: ref IcUi->Ui): int;
	setstatusrows: fn(u: ref IcUi->Ui, helprow, statusrow: int);
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
	textview: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcontent: fn(v: ref IcView->Node, content: string);
	setcode: fn(v: ref IcView->Node, code: string);
	setargs: fn(v: ref IcView->Node, sarg: string, iarg0, iarg1, iarg2: int);
	show: fn(v: ref IcView->Node);
	hide: fn(v: ref IcView->Node);
	allocid: fn(t: ref IcView->Tree): int;
};

ViewerSource: adt
{
	path: string;
	fd: ref Sys->FD;
	length: big;

	offsets: array of big;
	noffsets: int;
	offsetcap: int;

	scanoff: big;
	eof: int;
	error: string;
};

ViewerButton: adt
{
	labelid: int;
	fkey: int;
	text: string;
	enabled: int;
};

sys: Sys;
appfw: IcursesApp;
ui: IcUiMod;
view: IcViewMod;

source: ref ViewerSource;

viewerbuttons: array of ViewerButton;
vieweractivefkey: int;
vieweractivewait: int;
viewerbodyrows: int;

statstoken: int;
statspath: string;
statsready: int;
statsdirty: int;
statsbytes: big;
statslines: big;
statschars: big;

TopCode: con "1;38;2;20;25;30;48;2;225;225;225";
BodyCode: con "38;2;220;230;255;48;2;20;45;90";
BottomCode: con "1;38;2;20;25;30;48;2;170;225;255";
BottomActiveCode: con "1;38;2;255;120;210;48;2;170;225;255";
BottomDisabledCode: con "38;2;120;120;120;48;2;170;225;255";
ErrorCode: con "1;38;2;255;120;120;48;2;20;45;90";

ScanChunkSize: con 32768;
InitialOffsetCap: con 1024;
InitialPrefetchScreens: con 6;
ScrollPrefetchScreens: con 8;
MaxRawLineLen: con 4096;
ReplacementChar: con 16rFFFD;

ViewerButtonCount: con 10;
ViewerButtonGap: con 1;
ViewerFlashTicks: con 2;

Kesc: con 27;
Kq: con int 'q';

Kup: con 57362;
Kdown: con 57363;
Kpgup: con 57366;
Kpgdown: con 57367;
Khome: con 57360;
Kend: con 57361;
Kf1: con 57409;
Kf2: con 57410;
Kf3: con 57411;
Kf4: con 57412;
Kf5: con 57413;
Kf6: con 57414;
Kf7: con 57415;
Kf8: con 57416;
Kf9: con 57417;
Kf10: con 57418;

newsource: fn(path: string): ref ViewerSource;
ensuresource: fn(v: ref IcState->ViewerState, rows: int);
closefile: fn(s: ref ViewerSource);
appendoffset: fn(s: ref ViewerSource, off: big);
ensureindexed: fn(s: ref ViewerSource, line: int): int;
ensureeof: fn(s: ref ViewerSource): int;
linecount: fn(s: ref ViewerSource): int;
getline: fn(s: ref ViewerSource, line: int): string;
readlinebytes: fn(s: ref ViewerSource, line: int): (array of byte, int);
prefetch: fn(v: ref IcState->ViewerState, rows: int): int;
refreshwindow: fn(v: ref IcState->ViewerState, rows: int);

decodechunk: fn(buf: array of byte, n: int): string;
sanitizechunk: fn(text: string): string;
needsanitize: fn(text: string): int;
safecell: fn(c: int): string;

appendline: fn(a: array of string, s: string): array of string;
wraplines: fn(lines: array of string, width: int): array of string;
wrapline: fn(line: string, width: int): array of string;
appendarray: fn(dst, src: array of string): array of string;
visiblecontent: fn(lines: array of string, top, rows: int): string;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
bodyh: fn(h: int): int;
bodyid: fn(v: ref IcState->ViewerState): int;

clampview: fn(v: ref IcState->ViewerState, h: int);
ensureids: fn(u: ref IcUi->Ui, v: ref IcState->ViewerState);
setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
setbody: fn(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, content, code: string);
drawviewer: fn(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int);

toptext: fn(v: ref IcState->ViewerState): string;
iserrorline: fn(s: string): int;

humanbytes: fn(n: big): string;
knownoffset: fn(v: ref IcState->ViewerState): big;
viewpercent: fn(v: ref IcState->ViewerState): string;
linestat: fn(): string;
charstat: fn(): string;

startstats: fn(path: string);
stopstats: fn();
statworker: fn(path: string, token: int);

initbuttons: fn(u: ref IcUi->Ui);
buttonx: fn(w, idx: int): int;
buttonw: fn(w, idx: int): int;
buttontext: fn(fkey: int, text: string, w: int): string;
buttoncode: fn(b: ViewerButton): string;
drawbuttonbar: fn(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int);
activatebutton: fn(fkey: int);
viewerhandletick: fn(): int;

rewrap: fn(v: ref IcState->ViewerState, w: int);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	appfw = load IcursesApp IcursesApp->PATH;
	if(appfw == nil)
		raise "fail:load icurses/app";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	source = nil;
	viewerbuttons = array[0] of ViewerButton;
	vieweractivefkey = 0;
	vieweractivewait = 0;
	viewerbodyrows = 1;

	statstoken = 0;
	statspath = "";
	statsready = 0;
	statsdirty = 0;
	statsbytes = big 0;
	statslines = big 0;
	statschars = big 0;

	appfw->init("icview");
	ui->init();
	view->init();
}

newstate(): ref IcState->ViewerState
{
	v: ref IcState->ViewerState;

	v = ref IcState->ViewerState;
	v.active = 0;
	v.mode = ModeText;
	v.path = "";
	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.topline = 0;
	v.nlines = 0;
	v.topid = -1;
	v.bottomid = -1;
	v.bodyids = array[0] of int;
	v.lastw = 0;

	return v;
}

runfile(path: string): int
{
	return runfilemode(path, ModeText);
}

newsource(path: string): ref ViewerSource
{
	s: ref ViewerSource;
	rc: int;
	d: Sys->Dir;

	s = ref ViewerSource;
	s.path = path;
	s.fd = sys->open(path, Sys->OREAD);
	s.length = big 0;
	s.offsetcap = InitialOffsetCap;
	s.offsets = array[s.offsetcap] of big;
	s.noffsets = 1;
	s.offsets[0] = big 0;
	s.scanoff = big 0;
	s.eof = 0;
	s.error = "";

	if(s.fd == nil){
		s.error = "Cannot open file: " + path;
		s.eof = 1;
		return s;
	}

	(rc, d) = sys->fstat(s.fd);
	if(rc >= 0)
		s.length = d.length;

	return s;
}

ensuresource(v: ref IcState->ViewerState, rows: int)
{
	if(v == nil)
		return;

	if(v.path == "")
		return;

	if(rows < 1)
		rows = 1;

	if(source != nil && source.path == v.path)
		return;

	closefile(source);
	source = newsource(v.path);

	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.lastw = 0;

	ensureindexed(source, InitialPrefetchScreens * rows + 1);
	v.nlines = linecount(source);
	startstats(v.path);
}

closefile(s: ref ViewerSource)
{
	if(s == nil)
		return;

	s.fd = nil;
}

appendoffset(s: ref ViewerSource, off: big)
{
	a: array of big;
	i, ncap: int;

	if(s == nil)
		return;

	if(off < big 0)
		return;

	if(s.length > big 0 && off >= s.length)
		return;

	if(s.noffsets > 0 && s.offsets[s.noffsets - 1] == off)
		return;

	if(s.noffsets >= s.offsetcap){
		ncap = s.offsetcap * 2;
		if(ncap < InitialOffsetCap)
			ncap = InitialOffsetCap;

		a = array[ncap] of big;
		for(i = 0; i < s.noffsets; i++)
			a[i] = s.offsets[i];

		s.offsets = a;
		s.offsetcap = ncap;
	}

	s.offsets[s.noffsets] = off;
	s.noffsets++;
}

ensureindexed(s: ref ViewerSource, line: int): int
{
	buf: array of byte;
	n, i: int;
	off: big;

	if(s == nil)
		return 0;

	if(line < 0)
		line = 0;

	if(s.error != "")
		return 0;

	if(line < s.noffsets)
		return 1;

	if(s.eof)
		return line < s.noffsets;

	buf = array[ScanChunkSize] of byte;

	while(!s.eof && s.noffsets <= line){
		n = sys->pread(s.fd, buf, len buf, s.scanoff);
		if(n < 0){
			s.error = "Cannot read file: " + s.path;
			s.eof = 1;
			break;
		}

		if(n == 0){
			s.eof = 1;
			s.length = s.scanoff;
			break;
		}

		for(i = 0; i < n; i++){
			if(int buf[i] == '\n'){
				off = s.scanoff + big (i + 1);
				appendoffset(s, off);
			}
		}

		s.scanoff += big n;

		if(s.length > big 0 && s.scanoff >= s.length){
			s.eof = 1;
			s.length = s.scanoff;
		}
	}

	return line < s.noffsets;
}

ensureeof(s: ref ViewerSource): int
{
	if(s == nil)
		return 0;

	while(!s.eof)
		ensureindexed(s, s.noffsets);

	return s.eof;
}

linecount(s: ref ViewerSource): int
{
	if(s == nil)
		return 0;

	if(s.error != "")
		return 1;

	if(s.noffsets <= 0)
		return 0;

	return s.noffsets;
}

readlinebytes(s: ref ViewerSource, line: int): (array of byte, int)
{
	start, end, span: big;
	n, want: int;
	buf: array of byte;

	if(s == nil || s.fd == nil || line < 0)
		return (array[0] of byte, 0);

	if(!ensureindexed(s, line))
		return (array[0] of byte, 0);

	start = s.offsets[line];

	#
	# Ensure the next line offset if possible. Do not scan the whole file here:
	# visible rendering must stay bounded and lazy.
	#
	ensureindexed(s, line + 1);

	if(line + 1 < s.noffsets)
		end = s.offsets[line + 1];
	else if(s.eof && s.length > big 0)
		end = s.length;
	else
		end = s.scanoff;

	if(end < start)
		end = start;

	span = end - start;
	if(span > big MaxRawLineLen)
		span = big MaxRawLineLen;

	want = int span;
	if(want < 0)
		want = 0;

	buf = array[want] of byte;
	if(want == 0)
		return (buf, 0);

	n = sys->pread(s.fd, buf, want, start);
	if(n < 0)
		return (array[0] of byte, 0);

	while(n > 0 && (int buf[n - 1] == '\n' || int buf[n - 1] == '\r'))
		n--;

	return (buf, n);
}

getline(s: ref ViewerSource, line: int): string
{
	buf: array of byte;
	n: int;

	if(s == nil)
		return "";

	if(s.error != "")
		return s.error;

	(buf, n) = readlinebytes(s, line);
	if(n <= 0)
		return "";

	return sanitizechunk(decodechunk(buf, n));
}

prefetch(v: ref IcState->ViewerState, rows: int): int
{
	target, before: int;

	if(v == nil || source == nil)
		return 0;

	if(rows < 1)
		rows = 1;

	before = source.noffsets;
	target = v.topline + rows * ScrollPrefetchScreens;
	ensureindexed(source, target);

	v.nlines = linecount(source);

	return source.noffsets != before;
}

refreshwindow(v: ref IcState->ViewerState, rows: int)
{
	i, need, idx: int;
	lines: array of string;

	if(v == nil)
		return;

	if(source == nil){
		v.lines = array[0] of string;
		v.wrapped = array[0] of string;
		v.nlines = 0;
		v.lastw = 0;
		return;
	}

	if(rows < 1)
		rows = 1;

	prefetch(v, rows);

	need = rows * 2;
	if(need < rows)
		need = rows;

	lines = array[0] of string;
	for(i = 0; i < need; i++){
		idx = v.topline + i;
		if(source.eof && idx >= linecount(source))
			break;

		if(!ensureindexed(source, idx))
			break;

		lines = appendline(lines, getline(source, idx));
	}

	if(len lines == 0)
		lines = appendline(lines, "");

	v.lines = lines;
	v.wrapped = array[0] of string;
	v.nlines = linecount(source);
	v.lastw = 0;
}

decodechunk(buf: array of byte, n: int): string
{
	i, b0, b1, b2, b3, c: int;
	out: string;

	out = "";
	i = 0;

	while(i < n){
		b0 = int buf[i] & 16rFF;

		if(b0 < 16r80){
			out += sys->sprint("%c", b0);
			i++;
			continue;
		}

		if((b0 & 16rE0) == 16rC0 && i + 1 < n){
			b1 = int buf[i + 1] & 16rFF;
			if((b1 & 16rC0) == 16r80){
				c = ((b0 & 16r1F) << 6) | (b1 & 16r3F);
				if(c >= 16r80){
					out += sys->sprint("%c", c);
					i += 2;
					continue;
				}
			}
		}

		if((b0 & 16rF0) == 16rE0 && i + 2 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80){
				c = ((b0 & 16r0F) << 12) | ((b1 & 16r3F) << 6) | (b2 & 16r3F);
				if(c >= 16r800 && (c < 16rD800 || c > 16rDFFF)){
					out += sys->sprint("%c", c);
					i += 3;
					continue;
				}
			}
		}

		if((b0 & 16rF8) == 16rF0 && i + 3 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			b3 = int buf[i + 3] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80 && (b3 & 16rC0) == 16r80){
				c = ((b0 & 16r07) << 18) | ((b1 & 16r3F) << 12) | ((b2 & 16r3F) << 6) | (b3 & 16r3F);
				if(c >= 16r10000 && c <= 16r10FFFF){
					out += sys->sprint("%c", c);
					i += 4;
					continue;
				}
			}
		}

		out += sys->sprint("%c", ReplacementChar);
		i++;
	}

	return out;
}

safecell(c: int): string
{
	if(c == '\t')
		return " ";

	if(c == '\r')
		return "\r";

	if(c == '\n')
		return "\n";

	if(c < 32 || c == 127)
		return ".";

	if(c >= 16r80 && c < 16rA0)
		return ".";

	if(c == ReplacementChar)
		return ".";

	return sys->sprint("%c", c);
}

needsanitize(text: string): int
{
	i, c: int;

	for(i = 0; i < len text; i++){
		c = text[i];

		if(c == '\t')
			return 1;

		if(c < 32 && c != '\n' && c != '\r')
			return 1;

		if(c == 127)
			return 1;

		if(c >= 16r80 && c < 16rA0)
			return 1;

		if(c == ReplacementChar)
			return 1;
	}

	return 0;
}

sanitizechunk(text: string): string
{
	i: int;
	out: string;

	if(text == "")
		return "";

	if(!needsanitize(text))
		return text;

	out = "";
	for(i = 0; i < len text; i++)
		out += safecell(text[i]);

	return out;
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

appendarray(dst, src: array of string): array of string
{
	i: int;

	if(src == nil)
		return dst;

	for(i = 0; i < len src; i++)
		dst = appendline(dst, src[i]);

	return dst;
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

fittext(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s > w)
		return s[0:w];

	if(len s < w)
		return s + spaces(w - len s);

	return s;
}

wrapline(line: string, width: int): array of string
{
	out: array of string;
	current, word: string;
	i, start, cut: int;

	if(width < 1)
		width = 1;

	out = array[0] of string;
	current = "";

	for(i = 0; i < len line; i++){
		if(line[i] == ' ' || line[i] == '\t' || line[i] == '\r')
			continue;

		start = i;
		while(i < len line && line[i] != ' ' && line[i] != '\t' && line[i] != '\r')
			i++;

		word = line[start:i];
		i--;

		if(len word > width){
			if(current != ""){
				out = appendline(out, current);
				current = "";
			}

			start = 0;
			while(start < len word){
				cut = start + width;
				if(cut > len word)
					cut = len word;
				out = appendline(out, word[start:cut]);
				start = cut;
			}

			continue;
		}

		if(current == "")
			current = word;
		else if(len current + 1 + len word <= width)
			current += " " + word;
		else{
			out = appendline(out, current);
			current = word;
		}
	}

	if(current != "")
		out = appendline(out, current);

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

wraplines(lines: array of string, width: int): array of string
{
	out: array of string;
	i: int;

	out = array[0] of string;

	if(lines == nil)
		return appendline(out, "");

	for(i = 0; i < len lines; i++)
		out = appendarray(out, wrapline(lines[i], width));

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

visiblecontent(lines: array of string, top, rows: int): string
{
	i, idx: int;
	s: string;

	if(lines == nil || rows <= 0)
		return "";

	s = "";

	for(i = 0; i < rows; i++){
		idx = top + i;
		if(idx >= 0 && idx < len lines)
			s += lines[idx];

		if(i < rows - 1)
			s += "\n";
	}

	return s;
}

bodyh(h: int): int
{
	n: int;

	n = h - 2;
	if(n < 1)
		n = 1;

	return n;
}

bodyid(v: ref IcState->ViewerState): int
{
	if(v == nil)
		return -1;

	if(v.bodyids == nil || len v.bodyids == 0)
		return -1;

	return v.bodyids[0];
}

clampview(v: ref IcState->ViewerState, h: int)
{
	rows, max: int;

	if(v == nil)
		return;

	rows = bodyh(h);

	ensuresource(v, rows);

	if(source != nil){
		prefetch(v, rows);

		if(source.eof){
			max = linecount(source) - 1;
			if(max < 0)
				max = 0;
			if(v.topline > max)
				v.topline = max;
		}else{
			if(v.topline < 0)
				v.topline = 0;
		}

		v.nlines = linecount(source);
	}else{
		max = v.nlines - 1;
		if(max < 0)
			max = 0;
		if(v.topline > max)
			v.topline = max;
	}

	if(v.topline < 0)
		v.topline = 0;
}

ensureids(u: ref IcUi->Ui, v: ref IcState->ViewerState)
{
	if(u == nil || u.tree == nil || v == nil)
		return;

	if(v.topid <= 0)
		v.topid = view->allocid(u.tree);

	if(v.bottomid <= 0)
		v.bottomid = view->allocid(u.tree);

	if(v.bodyids == nil || len v.bodyids == 0)
		v.bodyids = array[] of { view->allocid(u.tree) };

	initbuttons(u);
}

setlabel(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(view->find(u.tree, id) == nil)
		ui->label(u, parentid, id, x, y, w, text);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

setbody(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, content, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(view->find(u.tree, id) == nil)
		ui->textview(u, parentid, id, x, y, w, h);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, h);
	view->setcontent(n, content);
	view->setcode(n, code);
	view->setargs(n, "", 0, 0, 0);
	view->show(n);
}

humanbytes(n: big): string
{
	if(n < big 0)
		n = big 0;

	if(n >= big 1073741824)
		return string int (n / big 1073741824) + "G";

	if(n >= big 1048576)
		return string int (n / big 1048576) + "M";

	if(n >= big 1024)
		return string int (n / big 1024) + "K";

	return string n + "B";
}

knownoffset(v: ref IcState->ViewerState): big
{
	if(v == nil || source == nil)
		return big 0;

	if(v.topline < 0)
		return big 0;

	if(v.topline < source.noffsets)
		return source.offsets[v.topline];

	return source.scanoff;
}

viewpercent(v: ref IcState->ViewerState): string
{
	off: big;
	p: int;

	if(v == nil || source == nil)
		return "?%";

	if(source.length <= big 0)
		return "?%";

	if(source.eof && viewerbodyrows > 0 && v.topline + viewerbodyrows >= linecount(source))
		return "100%";

	off = knownoffset(v);
	if(off < big 0)
		off = big 0;
	if(off > source.length)
		off = source.length;

	p = int (((off * big 100) + (source.length / big 2)) / source.length);
	if(p < 0)
		p = 0;
	if(p > 100)
		p = 100;

	return string p + "%";
}

linestat(): string
{
	if(statsready)
		return string statslines;

	if(source == nil)
		return "0";

	if(source.eof)
		return string linecount(source);

	return "~" + string linecount(source);
}

charstat(): string
{
	n: big;

	if(statsready)
		return "~" + string statschars;

	if(source == nil)
		return "~0";

	n = source.length;
	if(n <= big 0)
		n = source.scanoff;

	return "~" + string n;
}

toptext(v: ref IcState->ViewerState): string
{
	size, lines, chars, pos: string;

	if(v == nil)
		return "";

	if(source == nil)
		return " " + v.path + "  size:? lines:? chars:? pos:? enc:?";

	if(statsready && statsbytes > big 0)
		size = humanbytes(statsbytes);
	else if(source.length > big 0)
		size = humanbytes(source.length);
	else
		size = "~" + humanbytes(source.scanoff);

	lines = linestat();
	chars = charstat();
	pos = viewpercent(v);

	return " " + v.path
		+ "  size:" + size
		+ "  lines:" + lines
		+ "  chars:" + chars
		+ "  pos:" + pos
		+ "  enc:?";
}

iserrorline(s: string): int
{
	if(len s >= 17 && s[0:17] == "Cannot open file")
		return 1;

	if(len s >= 17 && s[0:17] == "Cannot read file")
		return 1;

	return 0;
}

startstats(path: string)
{
	statstoken++;
	statspath = path;
	statsready = 0;
	statsdirty = 1;
	statsbytes = big 0;
	statslines = big 0;
	statschars = big 0;

	if(path == "")
		return;

	if(source != nil && source.length > big 0){
		statsbytes = source.length;
		statschars = source.length;
	}

	spawn statworker(path, statstoken);
}

stopstats()
{
	statstoken++;
	statspath = "";
	statsready = 0;
	statsdirty = 0;
	statsbytes = big 0;
	statslines = big 0;
	statschars = big 0;
}

statworker(path: string, token: int)
{
	fd: ref Sys->FD;
	buf: array of byte;
	n, i: int;
	bytes, lines, chars: big;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return;

	buf = array[ScanChunkSize] of byte;
	bytes = big 0;
	lines = big 0;
	chars = big 0;

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		bytes += big n;
		chars += big n;

		for(i = 0; i < n; i++){
			if(int buf[i] == '\n')
				lines++;
		}
	}

	fd = nil;

	if(token != statstoken)
		return;

	if(path != statspath)
		return;

	statsbytes = bytes;
	statslines = lines;
	statschars = chars;
	statsready = 1;
	statsdirty = 1;
}

initbuttons(u: ref IcUi->Ui)
{
	i: int;
	b: ViewerButton;

	if(u == nil || u.tree == nil)
		return;

	if(viewerbuttons != nil && len viewerbuttons == ViewerButtonCount)
		return;

	viewerbuttons = array[ViewerButtonCount] of ViewerButton;

	for(i = 0; i < ViewerButtonCount; i++){
		b.labelid = view->allocid(u.tree);
		b.fkey = i + 1;
		b.text = "";
		b.enabled = 0;

		case i {
		0 =>
			b.text = "Help";
		1 =>
			b.text = "Wrap";
		2 =>
			b.text = "Quit";
			b.enabled = 1;
		3 =>
			b.text = "Edit";
		4 =>
			b.text = "GoTo";
		5 =>
			b.text = "Hex";
		6 =>
			b.text = "Search";
		7 =>
			b.text = "Codepage";
		8 =>
			b.text = "Menu";
		9 =>
			b.text = "Quit";
			b.enabled = 1;
		}

		viewerbuttons[i] = b;
	}
}

buttonx(w, idx: int): int
{
	return (w * idx) / ViewerButtonCount;
}

buttonw(w, idx: int): int
{
	x0, x1, bw: int;

	x0 = buttonx(w, idx);
	x1 = (w * (idx + 1)) / ViewerButtonCount;

	bw = x1 - x0;
	if(idx < ViewerButtonCount - 1)
		bw -= ViewerButtonGap;

	if(bw < 1)
		bw = 1;

	return bw;
}

buttontext(fkey: int, text: string, w: int): string
{
	if(text == "")
		return fittext("F" + string fkey, w);

	return fittext("F" + string fkey + " " + text, w);
}

buttoncode(b: ViewerButton): string
{
	if(!b.enabled)
		return BottomDisabledCode;

	if(vieweractivewait > 0 && b.fkey == vieweractivefkey)
		return BottomActiveCode;

	return BottomCode;
}

drawbuttonbar(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int)
{
	i, x, bw: int;

	if(u == nil || v == nil)
		return;

	setlabel(u, parentid, v.bottomid, 0, h - 1, w, spaces(w), BottomCode);

	if(viewerbuttons == nil || len viewerbuttons != ViewerButtonCount)
		initbuttons(u);

	for(i = 0; i < len viewerbuttons; i++){
		x = buttonx(w, i);
		bw = buttonw(w, i);

		setlabel(
			u,
			parentid,
			viewerbuttons[i].labelid,
			x,
			h - 1,
			bw,
			buttontext(viewerbuttons[i].fkey, viewerbuttons[i].text, bw),
			buttoncode(viewerbuttons[i])
		);
	}
}

activatebutton(fkey: int)
{
	vieweractivefkey = fkey;
	vieweractivewait = ViewerFlashTicks;
}

viewerhandletick(): int
{
	if(vieweractivewait <= 0)
		return 0;

	vieweractivewait--;
	if(vieweractivewait > 0)
		return 0;

	vieweractivefkey = 0;
	return 1;
}

drawviewer(u: ref IcUi->Ui, parentid: int, v: ref IcState->ViewerState, w, h: int)
{
	rows, id: int;
	bodycode, content: string;

	if(u == nil || v == nil)
		return;

	rows = bodyh(h);
	viewerbodyrows = rows;

	ensureids(u, v);
	ensuresource(v, rows);

	clampview(v, h);
	refreshwindow(v, rows);
	rewrap(v, w);

	ui->setstatusrows(u, -1, -1);

	setlabel(u, parentid, v.topid, 0, 0, w, toptext(v), TopCode);

	bodycode = BodyCode;
	if(source != nil && source.error != "")
		bodycode = ErrorCode;
	if(v.lines != nil && len v.lines > 0 && iserrorline(v.lines[0]))
		bodycode = ErrorCode;

	id = bodyid(v);
	if(id >= 0){
		content = visiblecontent(v.wrapped, 0, rows);
		setbody(u, parentid, id, 0, 1, w, rows, content, bodycode);
	}

	drawbuttonbar(u, parentid, v, w, h);
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.viewer != nil && state.viewer.active;
}

start(state: ref IcState->AppState, path: string, mode: int): int
{
	if(state == nil || path == "")
		return -1;

	closefile(source);
	source = newsource(path);

	if(state.viewer == nil)
		state.viewer = newstate();

	state.viewer.active = 1;
	state.viewer.mode = mode;
	state.viewer.path = path;
	state.viewer.lines = array[0] of string;
	state.viewer.wrapped = array[0] of string;
	state.viewer.topline = 0;
	state.viewer.lastw = 0;

	vieweractivefkey = 0;
	vieweractivewait = 0;

	if(source.error != "")
		state.viewer.lines = array[] of { source.error };

	ensureindexed(source, InitialPrefetchScreens * bodyh(state.height) + 1);
	state.viewer.nlines = linecount(source);

	startstats(path);

	return 0;
}

build(state: ref IcState->AppState, parentid, w, h: int): int
{
	if(state == nil || state.ui == nil || state.viewer == nil || !state.viewer.active)
		return -1;

	drawviewer(state.ui, parentid, state.viewer, w, h);
	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	v: ref IcState->ViewerState;
	rows, r: int;

	if(state == nil || state.viewer == nil || !state.viewer.active)
		return 0;

	v = state.viewer;
	rows = bodyh(state.height);
	r = 1;

	case k {
	Kq or Kesc =>
		activatebutton(10);
		v.active = 0;
		closefile(source);
		source = nil;
		stopstats();
		return 2;

	Kf3 =>
		activatebutton(3);
		v.active = 0;
		closefile(source);
		source = nil;
		stopstats();
		return 2;

	Kf10 =>
		activatebutton(10);
		v.active = 0;
		closefile(source);
		source = nil;
		stopstats();
		return 2;

	Kf1 or Kf2 or Kf4 or Kf5 or Kf6 or Kf7 or Kf8 or Kf9 =>
		r = 0;

	Kup =>
		v.topline--;

	Kdown =>
		v.topline++;
		if(source != nil)
			ensureindexed(source, v.topline + rows * ScrollPrefetchScreens);

	Kpgup =>
		v.topline -= rows;

	Kpgdown =>
		v.topline += rows;
		if(source != nil)
			ensureindexed(source, v.topline + rows * ScrollPrefetchScreens);

	Khome =>
		v.topline = 0;

	Kend =>
		if(source != nil){
			ensureeof(source);
			v.nlines = linecount(source);
			v.topline = v.nlines - rows;
		}else
			v.topline = v.nlines - rows;

	* =>
		r = 0;
	}

	if(r == 0)
		return 0;

	clampview(v, state.height);
	build(state, state.toolid, state.width, state.height);

	return 1;
}

handletick(state: ref IcState->AppState): int
{
	changed: int;

	if(state == nil || state.viewer == nil || !state.viewer.active)
		return 0;

	changed = 0;

	if(viewerhandletick())
		changed = 1;

	if(statsdirty){
		statsdirty = 0;
		changed = 1;
	}

	if(changed)
		build(state, state.toolid, state.width, state.height);

	return changed;
}

runfilemode(path: string, mode: int): int
{
	ctx: ref IcursesApp->Context;
	opts: IcursesApp->Options;
	step: IcUi->Step;
	u: ref IcUi->Ui;
	st: ref IcState->AppState;
	v: ref IcState->ViewerState;
	nw, nh, resized: int;
	running, r, changed: int;

	closefile(source);
	source = newsource(path);

	v = newstate();
	v.path = path;
	v.mode = mode;
	v.lines = array[0] of string;
	v.wrapped = array[0] of string;
	v.topline = 0;
	v.lastw = 0;

	viewerbuttons = array[0] of ViewerButton;
	vieweractivefkey = 0;
	vieweractivewait = 0;

	if(source.error != "")
		v.lines = array[] of { source.error };

	opts = appfw->defaultopts();
	opts.screenmode = IcursesApp->ScreenAlternate;
	opts.mouse = 0;
	opts.tickms = 200;

	ctx = appfw->newctx(sys->fildes(1), opts);
	if(ctx == nil)
		return -1;

	if(appfw->open(ctx) < 0)
		return -1;

	u = appfw->ui(ctx);
	if(u == nil){
		appfw->close(ctx);
		return -1;
	}

	st = ref IcState->AppState;
	st.ui = u;
	st.rootid = ui->rootid(u);
	st.toolid = st.rootid;
	st.width = appfw->width(ctx);
	st.height = appfw->height(ctx);
	st.viewer = v;

	v.active = 1;

	ensureindexed(source, InitialPrefetchScreens * bodyh(st.height) + 1);
	v.nlines = linecount(source);

	startstats(path);

	build(st, st.rootid, st.width, st.height);
	appfw->draw(ctx);

	running = 1;
	while(running){
		step = appfw->step(ctx);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			r = handlekey(st, step.key);
			if(r == 2)
				running = 0;
			else if(r != 0)
				appfw->draw(ctx);
		}

		if(step.kind == IcUi->StepTick){
			changed = prefetch(v, bodyh(st.height));

			if(handletick(st))
				changed = 1;

			(nw, nh, resized) = appfw->pollresize(ctx, st.width, st.height);
			if(resized){
				st.width = nw;
				st.height = nh;
				v.lastw = 0;
				build(st, st.rootid, st.width, st.height);
				appfw->draw(ctx);
			}else if(changed){
				build(st, st.rootid, st.width, st.height);
				appfw->draw(ctx);
			}
		}
	}

	closefile(source);
	source = nil;
	stopstats();

	appfw->close(ctx);
	return 0;
}

rewrap(v: ref IcState->ViewerState, w: int)
{
	if(v == nil)
		return;

	if(w < 1)
		w = 1;

	if(v.lastw == w && v.wrapped != nil && len v.wrapped > 0)
		return;

	v.wrapped = wraplines(v.lines, w);
	v.lastw = w;
}