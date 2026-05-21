implement IcEditor;

include "ic/editor.m";

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
	allocid: fn(t: ref IcView->Tree): int;
};

sys: Sys;
appfw: IcursesApp;
ui: IcUiMod;
view: IcViewMod;

TopCode: con "1;38;2;20;25;30;48;2;225;225;225";
BodyCode: con "38;2;220;230;255;48;2;20;45;90";
BottomCode: con "1;38;2;20;25;30;48;2;170;225;255";

DefaultCursorCode: con "1;38;2;0;0;0;48;2;255;235;80";
CursorCode: string;

ModeEdit: con 0;
ModeConfirmQuit: con 1;
ModeFilename: con 2;

TabSpaces: con 4;

Kesc: con 27;

Ky: con int 'y';
KY: con int 'Y';
Kn: con int 'n';
KN: con int 'N';

Kenter: con 10;
Kreturn: con 13;
Kbackspace: con 8;
Kdelete: con 127;

Kup: con 57362;
Kdown: con 57363;
Kleft: con 57364;
Kright: con 57365;
Kpgup: con 57366;
Kpgdown: con 57367;
Khome: con 57360;
Kend: con 57361;

Kf2: con 57410;
Kf3: con 57411;
Kf10: con 57418;

initstate: fn(path, dir: string): ref IcState->EditorState;

readfile: fn(path: string): (string, int);
savefile: fn(e: ref IcState->EditorState): int;
saveas: fn(e: ref IcState->EditorState, name: string): int;
textlines: fn(text: string): array of string;
joinlines: fn(lines: array of string): string;

appendline: fn(a: array of string, s: string): array of string;
insertline: fn(a: array of string, idx: int, s: string): array of string;
deleteline: fn(a: array of string, idx: int): array of string;

expandtabs: fn(s: string): string;
joinpath: fn(base, name: string): string;
basename: fn(path: string): string;
dirname: fn(path: string): string;

spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;

bodyh: fn(h: int): int;
ensureids: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
clampcursor: fn(e: ref IcState->EditorState);
ensurecursorvisible: fn(e: ref IcState->EditorState, rows: int);

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
setbody: fn(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, e: ref IcState->EditorState, content, code: string);

toptext: fn(e: ref IcState->EditorState): string;
bottomtext: fn(e: ref IcState->EditorState, w: int): string;
visiblecontent: fn(e: ref IcState->EditorState, rows, w: int): string;
cursorarg: fn(e: ref IcState->EditorState, rows: int): string;

draweditor: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int);

printable: fn(k: int): int;
insertchar: fn(e: ref IcState->EditorState, k: int);
newline: fn(e: ref IcState->EditorState);
backspace: fn(e: ref IcState->EditorState);
deletechar: fn(e: ref IcState->EditorState);
moveleft: fn(e: ref IcState->EditorState);
moveright: fn(e: ref IcState->EditorState);
moveup: fn(e: ref IcState->EditorState);
movedown: fn(e: ref IcState->EditorState);

startfilename: fn(e: ref IcState->EditorState);
requestquit: fn(e: ref IcState->EditorState): int;
closeeditor: fn(e: ref IcState->EditorState): int;

handleeditkey: fn(e: ref IcState->EditorState, k, h: int): int;
handleconfirmkey: fn(e: ref IcState->EditorState, k: int): int;
handlefilenamekey: fn(e: ref IcState->EditorState, k: int): int;
handleeditor: fn(e: ref IcState->EditorState, k, h: int): int;

readthemefile: fn(path, key, def: string): string;
loadthemevalue: fn(key, def: string): string;
trim: fn(s: string): string;
username: fn(): string;

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

	appfw->init("icedit");
	ui->init();
	view->init();

	CursorCode = loadthemevalue("editor_cursor_code", DefaultCursorCode);
}

initstate(path, dir: string): ref IcState->EditorState
{
	e: ref IcState->EditorState;
	text: string;
	ok: int;

	e = ref IcState->EditorState;
	e.active = 1;
	e.path = path;
	e.dir = dir;
	e.topline = 0;
	e.cursorline = 0;
	e.cursorcol = 0;
	e.topid = -1;
	e.bodyid = -1;
	e.bottomid = -1;
	e.dirty = 0;
	e.message = "";
	e.mode = ModeEdit;
	e.filenameinput = "";

	if(e.dir == "" && path != "")
		e.dir = dirname(path);

	(text, ok) = readfile(path);
	if(ok)
		e.lines = textlines(text);
	else{
		e.lines = array[] of { "" };
		if(path == "")
			e.message = "New file";
		else
			e.message = "New file: " + path;
	}

	if(e.lines == nil || len e.lines == 0)
		e.lines = array[] of { "" };

	return e;
}

readfile(path: string): (string, int)
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	text: string;

	if(path == "")
		return ("", 0);

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return ("", 0);

	buf = array[4096] of byte;
	text = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		text += string buf[0:n];
	}

	fd = nil;
	return (text, 1);
}

savefile(e: ref IcState->EditorState): int
{
	fd: ref Sys->FD;
	text: string;
	n: int;

	if(e == nil)
		return 0;

	if(e.path == ""){
		startfilename(e);
		return 0;
	}

	fd = sys->create(e.path, Sys->OWRITE, 8r666);
	if(fd == nil){
		e.message = "Save failed";
		return 0;
	}

	text = joinlines(e.lines);
	n = sys->fprint(fd, "%s", text);
	fd = nil;

	if(n < 0){
		e.message = "Save failed";
		return 0;
	}

	e.dirty = 0;
	e.message = "Saved";
	return 1;
}

saveas(e: ref IcState->EditorState, name: string): int
{
	path: string;

	name = trim(name);
	if(name == ""){
		e.message = "File name is empty";
		return 0;
	}

	path = joinpath(e.dir, name);
	e.path = path;

	return savefile(e);
}

textlines(text: string): array of string
{
	lines: array of string;
	i, start, end: int;
	line: string;

	lines = array[0] of string;
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		end = i;
		if(end > start && text[end - 1] == '\r')
			end--;

		line = expandtabs(text[start:end]);
		lines = appendline(lines, line);

		start = i + 1;
	}

	if(len lines == 0)
		lines = appendline(lines, "");

	return lines;
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

insertline(a: array of string, idx: int, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(a == nil)
		return appendline(nil, s);

	n = len a;
	if(idx < 0)
		idx = 0;
	if(idx > n)
		idx = n;

	b = array[n + 1] of string;
	for(i = 0; i < idx; i++)
		b[i] = a[i];

	b[idx] = s;

	for(i = idx; i < n; i++)
		b[i + 1] = a[i];

	return b;
}

deleteline(a: array of string, idx: int): array of string
{
	b: array of string;
	i, j, n: int;

	if(a == nil || len a <= 1)
		return array[] of { "" };

	n = len a;
	if(idx < 0 || idx >= n)
		return a;

	b = array[n - 1] of string;
	j = 0;
	for(i = 0; i < n; i++){
		if(i == idx)
			continue;

		b[j] = a[i];
		j++;
	}

	return b;
}

expandtabs(s: string): string
{
	i, j: int;
	out: string;

	out = "";

	for(i = 0; i < len s; i++){
		if(s[i] == '\t'){
			for(j = 0; j < TabSpaces; j++)
				out += " ";
		}else
			out += s[i:i + 1];
	}

	return out;
}

joinpath(base, name: string): string
{
	if(name == "")
		return base;

	if(len name > 0 && name[0] == '/')
		return name;

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

basename(path: string): string
{
	i: int;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[i + 1:];
	}

	return path;
}

dirname(path: string): string
{
	i: int;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/'){
			if(i == 0)
				return "/";
			return path[0:i];
		}
	}

	return "";
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

bodyh(h: int): int
{
	rows: int;

	rows = h - 2;
	if(rows < 1)
		rows = 1;

	return rows;
}

ensureids(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	if(u == nil || u.tree == nil || e == nil)
		return;

	if(e.topid <= 0)
		e.topid = view->allocid(u.tree);

	if(e.bodyid <= 0)
		e.bodyid = view->allocid(u.tree);

	if(e.bottomid <= 0)
		e.bottomid = view->allocid(u.tree);
}

clampcursor(e: ref IcState->EditorState)
{
	line: string;

	if(e == nil)
		return;

	if(e.lines == nil || len e.lines == 0)
		e.lines = array[] of { "" };

	if(e.cursorline < 0)
		e.cursorline = 0;
	if(e.cursorline >= len e.lines)
		e.cursorline = len e.lines - 1;

	line = e.lines[e.cursorline];

	if(e.cursorcol < 0)
		e.cursorcol = 0;
	if(e.cursorcol > len line)
		e.cursorcol = len line;
}

ensurecursorvisible(e: ref IcState->EditorState, rows: int)
{
	if(e == nil)
		return;

	if(rows < 1)
		rows = 1;

	clampcursor(e);

	if(e.topline < 0)
		e.topline = 0;

	if(e.cursorline < e.topline)
		e.topline = e.cursorline;

	if(e.cursorline >= e.topline + rows)
		e.topline = e.cursorline - rows + 1;

	if(e.topline < 0)
		e.topline = 0;
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

setbody(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, e: ref IcState->EditorState, content, code: string)
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
	view->setargs(n, cursorarg(e, h), 0, 0, 0);
	view->show(n);
}

toptext(e: ref IcState->EditorState): string
{
	mark, name: string;

	if(e == nil)
		return "";

	if(e.dirty)
		mark = "*";
	else
		mark = "";

	if(e.path == "")
		name = "<new>";
	else
		name = e.path;

	if(e.message != "")
		return " " + name
			+ mark
			+ "  line:" + string (e.cursorline + 1)
			+ "  col:" + string (e.cursorcol + 1)
			+ "  lines:" + string len e.lines
			+ "  " + e.message;

	return " " + name
		+ mark
		+ "  line:" + string (e.cursorline + 1)
		+ "  col:" + string (e.cursorcol + 1)
		+ "  lines:" + string len e.lines;
}

bottomtext(e: ref IcState->EditorState, w: int): string
{
	text: string;

	if(e == nil)
		return fittext("", w);

	if(e.mode == ModeConfirmQuit)
		text = "Save changes?  Y Yes  N No  Esc Cancel";
	else if(e.mode == ModeFilename)
		text = "Save as: " + e.filenameinput + "  Enter OK  Esc Cancel";
	else
		text = "F2 Save  F3 Quit  F10 Quit";

	return fittext(text, w);
}

visiblecontent(e: ref IcState->EditorState, rows, w: int): string
{
	i, idx: int;
	line, text: string;

	text = "";

	for(i = 0; i < rows; i++){
		idx = e.topline + i;

		if(idx >= 0 && idx < len e.lines){
			line = e.lines[idx];

			if(idx == e.cursorline && e.cursorcol >= len line)
				line += " ";

			text += fittext(line, w);
		}else
			text += spaces(w);

		if(i < rows - 1)
			text += "\n";
	}

	return text;
}

cursorarg(e: ref IcState->EditorState, rows: int): string
{
	row, start, end: int;

	if(e == nil)
		return "";

	if(e.mode != ModeEdit)
		return "";

	row = e.cursorline - e.topline;
	if(row < 0 || row >= rows)
		return "";

	start = e.cursorcol;
	if(start < 0)
		start = 0;

	end = start + 1;

	return "search_line=" + string row + "\n"
		+ "search_start=" + string start + "\n"
		+ "search_end=" + string end + "\n"
		+ "search_code=" + CursorCode + "\n";
}

draweditor(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int)
{
	rows: int;
	content: string;

	if(u == nil || e == nil)
		return;

	rows = bodyh(h);

	ensureids(u, e);
	ensurecursorvisible(e, rows);

	ui->setstatusrows(u, -1, -1);

	setlabel(u, parentid, e.topid, 0, 0, w, toptext(e), TopCode);

	content = visiblecontent(e, rows, w);
	setbody(u, parentid, e.bodyid, 0, 1, w, rows, e, content, BodyCode);

	setlabel(u, parentid, e.bottomid, 0, h - 1, w, bottomtext(e, w), BottomCode);
}

printable(k: int): int
{
	if(k < 32)
		return 0;

	if(k >= 57344)
		return 0;

	return 1;
}

insertchar(e: ref IcState->EditorState, k: int)
{
	line, c: string;

	clampcursor(e);

	line = e.lines[e.cursorline];
	c = sys->sprint("%c", k);

	e.lines[e.cursorline] = line[0:e.cursorcol] + c + line[e.cursorcol:];
	e.cursorcol++;
	e.dirty = 1;
	e.message = "";
}

newline(e: ref IcState->EditorState)
{
	line, left, right: string;

	clampcursor(e);

	line = e.lines[e.cursorline];
	left = line[0:e.cursorcol];
	right = line[e.cursorcol:];

	e.lines[e.cursorline] = left;
	e.lines = insertline(e.lines, e.cursorline + 1, right);

	e.cursorline++;
	e.cursorcol = 0;
	e.dirty = 1;
	e.message = "";
}

backspace(e: ref IcState->EditorState)
{
	line, prev: string;
	prevlen: int;

	clampcursor(e);

	line = e.lines[e.cursorline];

	if(e.cursorcol > 0){
		e.lines[e.cursorline] = line[0:e.cursorcol - 1] + line[e.cursorcol:];
		e.cursorcol--;
		e.dirty = 1;
		e.message = "";
		return;
	}

	if(e.cursorline <= 0)
		return;

	prev = e.lines[e.cursorline - 1];
	prevlen = len prev;

	e.lines[e.cursorline - 1] = prev + line;
	e.lines = deleteline(e.lines, e.cursorline);

	e.cursorline--;
	e.cursorcol = prevlen;
	e.dirty = 1;
	e.message = "";
}

deletechar(e: ref IcState->EditorState)
{
	line, next: string;

	clampcursor(e);

	line = e.lines[e.cursorline];

	if(e.cursorcol < len line){
		e.lines[e.cursorline] = line[0:e.cursorcol] + line[e.cursorcol + 1:];
		e.dirty = 1;
		e.message = "";
		return;
	}

	if(e.cursorline + 1 >= len e.lines)
		return;

	next = e.lines[e.cursorline + 1];
	e.lines[e.cursorline] = line + next;
	e.lines = deleteline(e.lines, e.cursorline + 1);
	e.dirty = 1;
	e.message = "";
}

moveleft(e: ref IcState->EditorState)
{
	clampcursor(e);

	if(e.cursorcol > 0){
		e.cursorcol--;
		return;
	}

	if(e.cursorline > 0){
		e.cursorline--;
		e.cursorcol = len e.lines[e.cursorline];
	}
}

moveright(e: ref IcState->EditorState)
{
	clampcursor(e);

	if(e.cursorcol < len e.lines[e.cursorline]){
		e.cursorcol++;
		return;
	}

	if(e.cursorline + 1 < len e.lines){
		e.cursorline++;
		e.cursorcol = 0;
	}
}

moveup(e: ref IcState->EditorState)
{
	e.cursorline--;
	clampcursor(e);
}

movedown(e: ref IcState->EditorState)
{
	e.cursorline++;
	clampcursor(e);
}

startfilename(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	e.mode = ModeFilename;
	e.filenameinput = basename(e.path);
	if(e.filenameinput == "")
		e.filenameinput = "";
	e.message = "";
}

requestquit(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 2;

	if(e.dirty){
		e.mode = ModeConfirmQuit;
		e.message = "";
		return 1;
	}

	return closeeditor(e);
}

closeeditor(e: ref IcState->EditorState): int
{
	if(e != nil)
		e.active = 0;

	return 2;
}

handleeditkey(e: ref IcState->EditorState, k, h: int): int
{
	rows: int;

	rows = bodyh(h);

	case k {
	Kesc or Kf3 or Kf10 =>
		return requestquit(e);

	Kf2 =>
		savefile(e);

	Kenter or Kreturn =>
		newline(e);

	Kbackspace =>
		backspace(e);

	Kdelete =>
		deletechar(e);

	Kleft =>
		moveleft(e);

	Kright =>
		moveright(e);

	Kup =>
		moveup(e);

	Kdown =>
		movedown(e);

	Kpgup =>
		e.cursorline -= rows;
		clampcursor(e);

	Kpgdown =>
		e.cursorline += rows;
		clampcursor(e);

	Khome =>
		e.cursorcol = 0;
		clampcursor(e);

	Kend =>
		clampcursor(e);
		e.cursorcol = len e.lines[e.cursorline];

	* =>
		if(printable(k))
			insertchar(e, k);
		else
			return 0;
	}

	ensurecursorvisible(e, rows);
	return 1;
}

handleconfirmkey(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc){
		e.mode = ModeEdit;
		return 1;
	}

	if(k == Ky || k == KY){
		if(e.path == ""){
			startfilename(e);
			return 1;
		}

		if(savefile(e))
			return closeeditor(e);

		e.mode = ModeEdit;
		return 1;
	}

	if(k == Kn || k == KN)
		return closeeditor(e);

	return 0;
}

handlefilenamekey(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc){
		e.mode = ModeEdit;
		e.filenameinput = "";
		return 1;
	}

	if(k == Kenter || k == Kreturn){
		if(saveas(e, e.filenameinput)){
			e.mode = ModeEdit;
			e.filenameinput = "";
		}
		return 1;
	}

	if(k == Kbackspace){
		if(len e.filenameinput > 0)
			e.filenameinput = e.filenameinput[0:len e.filenameinput - 1];
		return 1;
	}

	if(printable(k)){
		e.filenameinput += sys->sprint("%c", k);
		return 1;
	}

	return 0;
}

handleeditor(e: ref IcState->EditorState, k, h: int): int
{
	if(e == nil || !e.active)
		return 0;

	if(e.mode == ModeConfirmQuit)
		return handleconfirmkey(e, k);

	if(e.mode == ModeFilename)
		return handlefilenamekey(e, k);

	return handleeditkey(e, k, h);
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.editor != nil && state.editor.active;
}

start(state: ref IcState->AppState, path: string): int
{
	dir: string;

	if(path == "")
		return -1;

	if(state == nil)
		return -1;

	dir = dirname(path);
	state.editor = initstate(path, dir);

	return 0;
}

startnew(state: ref IcState->AppState, dir: string): int
{
	if(state == nil)
		return -1;

	state.editor = initstate("", dir);

	if(state.editor != nil)
		startfilename(state.editor);

	return 0;
}

build(state: ref IcState->AppState, parentid, w, h: int): int
{
	if(state == nil || state.ui == nil || state.editor == nil || !state.editor.active)
		return -1;

	draweditor(state.ui, parentid, state.editor, w, h);
	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;

	if(state == nil || state.editor == nil)
		return 0;

	r = handleeditor(state.editor, k, state.height);

	if(r == 2)
		return 2;

	return r;
}

handletick(state: ref IcState->AppState): int
{
	state = state;
	return 0;
}

runfile(path: string): int
{
	ctx: ref IcursesApp->Context;
	opts: IcursesApp->Options;
	step: IcUi->Step;
	u: ref IcUi->Ui;
	e: ref IcState->EditorState;
	rootid: int;
	w, h, nw, nh, resized: int;
	running, r: int;

	if(path == "")
		return -1;

	e = initstate(path, dirname(path));

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

	rootid = ui->rootid(u);
	w = appfw->width(ctx);
	h = appfw->height(ctx);

	draweditor(u, rootid, e, w, h);
	appfw->draw(ctx);

	running = 1;
	while(running){
		step = appfw->step(ctx);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			r = handleeditor(e, step.key, h);
			if(r == 2)
				running = 0;
			else if(r != 0){
				draweditor(u, rootid, e, w, h);
				appfw->draw(ctx);
			}
		}

		if(step.kind == IcUi->StepTick){
			(nw, nh, resized) = appfw->pollresize(ctx, w, h);
			if(resized){
				w = nw;
				h = nh;
				draweditor(u, rootid, e, w, h);
				appfw->draw(ctx);
			}
		}
	}

	appfw->close(ctx);
	return 0;
}

trim(s: string): string
{
	a, b: int;

	a = 0;
	b = len s;

	while(a < b && (s[a] == ' ' || s[a] == '\t' || s[a] == '\n' || s[a] == '\r'))
		a++;

	while(b > a && (s[b - 1] == ' ' || s[b - 1] == '\t' || s[b - 1] == '\n' || s[b - 1] == '\r'))
		b--;

	if(a >= b)
		return "";

	return s[a:b];
}

username(): string
{
	fd: ref Sys->FD;
	buf: array of byte;
	n: int;
	name: string;

	fd = sys->open("/env/user", Sys->OREAD);
	if(fd == nil)
		return "inferno";

	buf = array[128] of byte;
	n = sys->read(fd, buf, len buf);
	fd = nil;

	if(n <= 0)
		return "inferno";

	name = trim(string buf[0:n]);
	if(name == "")
		return "inferno";

	return name;
}

readthemefile(path, key, def: string): string
{
	text, line, prefix: string;
	fd: ref Sys->FD;
	buf: array of byte;
	n, i, start: int;

	fd = sys->open(path, Sys->OREAD);
	if(fd == nil)
		return def;

	buf = array[4096] of byte;
	text = "";

	for(;;){
		n = sys->read(fd, buf, len buf);
		if(n <= 0)
			break;

		text += string buf[0:n];
	}

	fd = nil;

	prefix = key + "=";
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = trim(text[start:i]);
		start = i + 1;

		if(line == "")
			continue;

		if(line[0] == '#')
			continue;

		if(len line >= len prefix && line[0:len prefix] == prefix)
			return trim(line[len prefix:]);
	}

	return def;
}

loadthemevalue(key, def: string): string
{
	v: string;

	v = readthemefile("/lib/ic/theme.cfg", key, def);
	v = readthemefile("/usr/" + username() + "/ic/theme.cfg", key, v);

	return v;
}