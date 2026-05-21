implement IcEditKeys;

include "ic/editkeys.m";

IcEditCommon: module
{
	PATH: con "/dis/ic/editcommon.dis";

	ModeEdit: con 0;
	ModeConfirmQuit: con 1;
	ModeFilename: con 2;
	ModeHelp: con 3;
	ModeSearch: con 4;
	ModeMenu: con 5;

	SelectionNone: con 0;
	SelectionLine: con 1;
	SelectionBlock: con 2;

	FlashTicks: con 2;

	init: fn();
	bodyh: fn(h: int): int;
	basename: fn(path: string): string;
	trim: fn(s: string): string;
};

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

	savefile: fn(e: ref IcState->EditorState): int;
	saveas: fn(e: ref IcState->EditorState, name: string): int;
	refreshwindow: fn(e: ref IcState->EditorState, rows: int);
};

IcViewerMod: module
{
	PATH: con "/dis/ic/viewer.dis";

	ModeText: con 0;

	init: fn();
	start: fn(state: ref IcState->AppState, path: string, mode: int): int;
};

sys: Sys;
common: IcEditCommon;
source: IcEditSource;
viewer: IcViewerMod;

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

Kshiftf2: con 57458;
Kshiftf3: con 57459;
Kshiftf7: con 57463;

printable: fn(k: int): int;
activatebutton: fn(e: ref IcState->EditorState, fkey: int);
modalstart: fn(e: ref IcState->EditorState, mode: int);

clampcursor: fn(e: ref IcState->EditorState);
insertchar: fn(e: ref IcState->EditorState, k: int);
newline: fn(e: ref IcState->EditorState);
backspace: fn(e: ref IcState->EditorState);
deletechar: fn(e: ref IcState->EditorState);
moveleft: fn(e: ref IcState->EditorState);
moveright: fn(e: ref IcState->EditorState);
moveup: fn(e: ref IcState->EditorState);
movedown: fn(e: ref IcState->EditorState);

findplain: fn(text, pattern: string, start: int): int;
runsearch: fn(e: ref IcState->EditorState): int;
switchtoviewer: fn(state: ref IcState->AppState, e: ref IcState->EditorState): int;

handleedit: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int;
handleconfirm: fn(e: ref IcState->EditorState, k: int): int;
handlefilename: fn(e: ref IcState->EditorState, k: int): int;
handlesearch: fn(e: ref IcState->EditorState, k: int): int;
handlehelp: fn(e: ref IcState->EditorState, k: int): int;
handlemenu: fn(e: ref IcState->EditorState, k: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	common = load IcEditCommon IcEditCommon->PATH;
	if(common == nil)
		raise "fail:load ic/editcommon";

	source = load IcEditSource IcEditSource->PATH;
	if(source == nil)
		raise "fail:load ic/editsource";

	viewer = load IcViewerMod IcViewerMod->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	common->init();
	source->init();
	viewer->init();
}

printable(k: int): int
{
	if(k < 32)
		return 0;
	if(k >= 57344)
		return 0;
	return 1;
}

activatebutton(e: ref IcState->EditorState, fkey: int)
{
	if(e == nil)
		return;

	e.activefkey = fkey;
	e.activewait = IcEditCommon->FlashTicks;
}

modalstart(e: ref IcState->EditorState, mode: int)
{
	if(e == nil)
		return;

	e.mode = mode;
	e.modalstage = 0;
	e.modalwait = 0;
}

clampcursor(e: ref IcState->EditorState)
{
	line: string;
	n: int;

	if(e == nil)
		return;

	n = source->linecount(e);
	if(n < 1)
		n = 1;

	e.nlines = n;

	if(e.cursorline < 0)
		e.cursorline = 0;
	if(e.cursorline >= n)
		e.cursorline = n - 1;

	line = source->getline(e, e.cursorline);

	if(e.cursorcol < 0)
		e.cursorcol = 0;
	if(e.cursorcol > len line)
		e.cursorcol = len line;
}

insertchar(e: ref IcState->EditorState, k: int)
{
	line, c: string;

	clampcursor(e);

	line = source->getline(e, e.cursorline);
	c = sys->sprint("%c", k);
	line = line[0:e.cursorcol] + c + line[e.cursorcol:];

	source->setline(e, e.cursorline, line);

	e.cursorcol++;
	e.dirty = 1;
	e.message = "";
}

newline(e: ref IcState->EditorState)
{
	line, left, right: string;

	clampcursor(e);

	line = source->getline(e, e.cursorline);
	left = line[0:e.cursorcol];
	right = line[e.cursorcol:];

	source->setline(e, e.cursorline, left);
	source->insertlineat(e, e.cursorline + 1, right);

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

	line = source->getline(e, e.cursorline);

	if(e.cursorcol > 0){
		line = line[0:e.cursorcol - 1] + line[e.cursorcol:];
		source->setline(e, e.cursorline, line);

		e.cursorcol--;
		e.dirty = 1;
		e.message = "";
		return;
	}

	if(e.cursorline <= 0)
		return;

	prev = source->getline(e, e.cursorline - 1);
	prevlen = len prev;

	source->setline(e, e.cursorline - 1, prev + line);
	source->deletelineat(e, e.cursorline);

	e.cursorline--;
	e.cursorcol = prevlen;
	e.dirty = 1;
	e.message = "";
}

deletechar(e: ref IcState->EditorState)
{
	line, next: string;
	n: int;

	clampcursor(e);

	line = source->getline(e, e.cursorline);

	if(e.cursorcol < len line){
		line = line[0:e.cursorcol] + line[e.cursorcol + 1:];
		source->setline(e, e.cursorline, line);

		e.dirty = 1;
		e.message = "";
		return;
	}

	n = source->linecount(e);
	if(e.cursorline + 1 >= n)
		return;

	next = source->getline(e, e.cursorline + 1);

	source->setline(e, e.cursorline, line + next);
	source->deletelineat(e, e.cursorline + 1);

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
		e.cursorcol = len source->getline(e, e.cursorline);
	}
}

moveright(e: ref IcState->EditorState)
{
	line: string;
	n: int;

	clampcursor(e);

	line = source->getline(e, e.cursorline);

	if(e.cursorcol < len line){
		e.cursorcol++;
		return;
	}

	n = source->linecount(e);
	if(e.cursorline + 1 < n){
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

findplain(text, pattern: string, start: int): int
{
	i, j, ok: int;

	if(pattern == "")
		return -1;

	if(start < 0)
		start = 0;

	for(i = start; i + len pattern <= len text; i++){
		ok = 1;
		for(j = 0; j < len pattern; j++){
			if(text[i + j] != pattern[j]){
				ok = 0;
				break;
			}
		}

		if(ok)
			return i;
	}

	return -1;
}

runsearch(e: ref IcState->EditorState): int
{
	i, col, startline, startcol: int;
	pattern, line: string;

	if(e == nil)
		return 0;

	pattern = common->trim(e.searchinput);
	if(pattern == "")
		pattern = e.lastsearch;

	if(pattern == ""){
		e.message = "Nothing to search";
		return 1;
	}

	e.lastsearch = pattern;

	startline = e.cursorline;
	startcol = e.cursorcol + 1;

	for(i = startline; source->ensureline(e, i); i++){
		if(i != startline)
			startcol = 0;

		line = source->getline(e, i);
		col = findplain(line, pattern, startcol);
		if(col >= 0){
			e.cursorline = i;
			e.cursorcol = col;
			e.mode = IcEditCommon->ModeEdit;
			e.message = "Found";
			return 1;
		}
	}

	for(i = 0; i <= startline && source->ensureline(e, i); i++){
		line = source->getline(e, i);
		col = findplain(line, pattern, 0);
		if(col >= 0){
			e.cursorline = i;
			e.cursorcol = col;
			e.mode = IcEditCommon->ModeEdit;
			e.message = "Found";
			return 1;
		}
	}

	e.mode = IcEditCommon->ModeEdit;
	e.message = "Nothing found";
	return 1;
}

switchtoviewer(state: ref IcState->AppState, e: ref IcState->EditorState): int
{
	rc: int;

	if(state == nil || e == nil){
		if(e != nil)
			e.message = "Viewer is unavailable here";
		return 1;
	}

	if(e.path == ""){
		e.filenameinput = common->basename(e.path);
		modalstart(e, IcEditCommon->ModeFilename);
		e.message = "Save before view";
		return 1;
	}

	if(e.dirty){
		if(!source->savefile(e))
			return 1;
	}

	e.active = 0;

	rc = viewer->start(state, e.path, IcViewerMod->ModeText);
	if(rc < 0){
		e.active = 1;
		e.message = "View failed";
		return 1;
	}

	return 1;
}

handleedit(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int
{
	rows: int;

	rows = common->bodyh(h);

	case k {
	Kf1 =>
		activatebutton(e, 1);
		modalstart(e, IcEditCommon->ModeHelp);
		return 1;

	Kf2 =>
		activatebutton(e, 2);
		if(e.path == "")
			modalstart(e, IcEditCommon->ModeFilename);
		else
			source->savefile(e);
		return 1;

	Kshiftf2 =>
		activatebutton(e, 2);
		e.filenameinput = common->basename(e.path);
		modalstart(e, IcEditCommon->ModeFilename);
		return 1;

	Kf3 =>
		activatebutton(e, 3);
		e.selectionmode = IcEditCommon->SelectionLine;
		e.message = "Line selection is not implemented yet";
		return 1;

	Kshiftf3 =>
		activatebutton(e, 3);
		e.selectionmode = IcEditCommon->SelectionBlock;
		e.message = "Block selection is not implemented yet";
		return 1;

	Kf4 =>
		activatebutton(e, 4);
		return switchtoviewer(state, e);

	Kf5 =>
		activatebutton(e, 5);
		e.message = "Copy insert is not implemented yet";
		return 1;

	Kf6 =>
		activatebutton(e, 6);
		e.message = "Move insert is not implemented yet";
		return 1;

	Kf7 =>
		activatebutton(e, 7);
		if(e.lastsearch != ""){
			e.searchinput = e.lastsearch;
			return runsearch(e);
		}
		e.searchinput = "";
		modalstart(e, IcEditCommon->ModeSearch);
		return 1;

	Kshiftf7 =>
		activatebutton(e, 7);
		e.searchinput = e.lastsearch;
		return runsearch(e);

	Kf8 =>
		activatebutton(e, 8);
		e.message = "Delete selection is not implemented yet";
		return 1;

	Kf9 =>
		activatebutton(e, 9);
		e.mode = IcEditCommon->ModeMenu;
		return 1;

	Kesc or Kf10 =>
		activatebutton(e, 10);
		if(e.dirty){
			modalstart(e, IcEditCommon->ModeConfirmQuit);
			return 1;
		}
		e.active = 0;
		return 2;

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
		e.cursorcol = len source->getline(e, e.cursorline);

	* =>
		if(printable(k))
			insertchar(e, k);
		else
			return 0;
	}

	return 1;
}

handleconfirm(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc){
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	if(k == Ky || k == KY){
		if(e.path == ""){
			modalstart(e, IcEditCommon->ModeFilename);
			return 1;
		}

		if(source->savefile(e)){
			e.active = 0;
			return 2;
		}

		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	if(k == Kn || k == KN){
		e.active = 0;
		return 2;
	}

	return 0;
}

handlefilename(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc){
		e.mode = IcEditCommon->ModeEdit;
		e.filenameinput = "";
		return 1;
	}

	if(k == Kenter || k == Kreturn){
		if(source->saveas(e, e.filenameinput)){
			e.mode = IcEditCommon->ModeEdit;
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

handlesearch(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc){
		e.mode = IcEditCommon->ModeEdit;
		e.searchinput = "";
		return 1;
	}

	if(k == Kenter || k == Kreturn)
		return runsearch(e);

	if(k == Kbackspace){
		if(len e.searchinput > 0)
			e.searchinput = e.searchinput[0:len e.searchinput - 1];
		return 1;
	}

	if(printable(k)){
		e.searchinput += sys->sprint("%c", k);
		return 1;
	}

	return 0;
}

handlehelp(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc || k == Kenter || k == Kreturn || k == Kf1){
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	return 0;
}

handlemenu(e: ref IcState->EditorState, k: int): int
{
	if(k == Kesc || k == Kf9){
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	e.message = "Menu items are not implemented yet";
	return 1;
}

handlekey(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int
{
	if(e == nil || !e.active)
		return 0;

	if(e.mode == IcEditCommon->ModeConfirmQuit)
		return handleconfirm(e, k);

	if(e.mode == IcEditCommon->ModeFilename)
		return handlefilename(e, k);

	if(e.mode == IcEditCommon->ModeSearch)
		return handlesearch(e, k);

	if(e.mode == IcEditCommon->ModeHelp)
		return handlehelp(e, k);

	if(e.mode == IcEditCommon->ModeMenu)
		return handlemenu(e, k);

	return handleedit(state, e, k, h);
}