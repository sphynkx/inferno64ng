implement IcEditKeys;

include "ic/editkeys.m";
include "ic/viewcommon.m";

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

IcEditBlock: module
{
	PATH: con "/dis/ic/editblock.dis";

	SelectionNone: con 0;
	SelectionLine: con 1;
	SelectionBlock: con 2;

	init: fn();

	active: fn(e: ref IcState->EditorState): int;
	kind: fn(e: ref IcState->EditorState): int;

	startline: fn(e: ref IcState->EditorState);
	startblock: fn(e: ref IcState->EditorState);
	clear: fn(e: ref IcState->EditorState);

	refresh: fn(e: ref IcState->EditorState);

	copyselection: fn(e: ref IcState->EditorState): int;
	paste: fn(e: ref IcState->EditorState): int;
	deleteselection: fn(e: ref IcState->EditorState): int;

	savepersistent: fn(e: ref IcState->EditorState): int;
	loadpersistent: fn(e: ref IcState->EditorState): int;
};

IcViewSearchMod: module
{
	PATH: con "/dis/ic/viewsearch.dis";

	init: fn();

	open: fn(u: ref IcUi->Ui, parentid, w, h: int, pattern: string);
	alert: fn(u: ref IcUi->Ui, parentid, w, h: int, text: string);
	close: fn(u: ref IcUi->Ui);

	active: fn(): int;
	isalert: fn(): int;

	draw: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handletick: fn(u: ref IcUi->Ui, parentid, w, h: int): int;
	handlekey: fn(u: ref IcUi->Ui, parentid, w, h, k: int): int;

	options: fn(): IcViewCommon->SearchOptions;
	pattern: fn(): string;
};

IcEditSearchRun: module
{
	PATH: con "/dis/ic/editsearchrun.dis";

	SearchResult: adt
	{
		found: int;
		alert: int;
		alerttext: string;
	};

	init: fn();

	reset: fn();
	lastpattern: fn(): string;

	run: fn(e: ref IcState->EditorState, opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult;
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
editblock: IcEditBlock;
viewsearch: IcViewSearchMod;
editsearchrun: IcEditSearchRun;
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
Kctrlf: con 6;

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
Kshiftf5: con 57461;
Kshiftf7: con 57463;
Kaltf7: con 57479;
Kctrlf7: con 57511;

printable: fn(k: int): int;
activatebutton: fn(e: ref IcState->EditorState, fkey: int);
modalstart: fn(e: ref IcState->EditorState, mode: int);

clampcursor: fn(e: ref IcState->EditorState);
selectionrefresh: fn(e: ref IcState->EditorState);

insertchar: fn(e: ref IcState->EditorState, k: int);
newline: fn(e: ref IcState->EditorState);
backspace: fn(e: ref IcState->EditorState);
deletechar: fn(e: ref IcState->EditorState);

moveleft: fn(e: ref IcState->EditorState);
moveright: fn(e: ref IcState->EditorState);
moveup: fn(e: ref IcState->EditorState);
movedown: fn(e: ref IcState->EditorState);
movepgup: fn(e: ref IcState->EditorState, rows: int);
movepgdown: fn(e: ref IcState->EditorState, rows: int);
movehome: fn(e: ref IcState->EditorState);
moveend: fn(e: ref IcState->EditorState);

toggleselectline: fn(e: ref IcState->EditorState);
startselectblock: fn(e: ref IcState->EditorState);
copyselection: fn(e: ref IcState->EditorState): int;
pastebuffer: fn(e: ref IcState->EditorState): int;
pastepersistentbuffer: fn(e: ref IcState->EditorState): int;
deleteselection: fn(e: ref IcState->EditorState): int;
savepersistentselection: fn(e: ref IcState->EditorState): int;

flushsearchdraw: fn(state: ref IcState->AppState): int;
closesearch: fn(state: ref IcState->AppState);
showsearchalert: fn(state: ref IcState->AppState, text: string);
runeditsearch: fn(state: ref IcState->AppState, e: ref IcState->EditorState, direction, fromcurrent: int): int;
handlesearchdialog: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k: int): int;

switchtoviewer: fn(state: ref IcState->AppState, e: ref IcState->EditorState): int;

handleedit: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int;
handleconfirm: fn(e: ref IcState->EditorState, k: int): int;
handlefilename: fn(e: ref IcState->EditorState, k: int): int;
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

	editblock = load IcEditBlock IcEditBlock->PATH;
	if(editblock == nil)
		raise "fail:load ic/editblock";

	viewsearch = load IcViewSearchMod IcViewSearchMod->PATH;
	if(viewsearch == nil)
		raise "fail:load ic/viewsearch";

	editsearchrun = load IcEditSearchRun IcEditSearchRun->PATH;
	if(editsearchrun == nil)
		raise "fail:load ic/editsearchrun";

	viewer = load IcViewerMod IcViewerMod->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	common->init();
	source->init();
	editblock->init();
	viewsearch->init();
	editsearchrun->init();
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

selectionrefresh(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	if(editblock->active(e))
		editblock->refresh(e);
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

	if(editblock->active(e))
		editblock->clear(e);

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

	if(editblock->active(e))
		editblock->clear(e);

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

	if(editblock->active(e)){
		deleteselection(e);
		return;
	}

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

	if(editblock->active(e)){
		deleteselection(e);
		return;
	}

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
		selectionrefresh(e);
		return;
	}

	if(e.cursorline > 0){
		e.cursorline--;
		e.cursorcol = len source->getline(e, e.cursorline);
	}

	selectionrefresh(e);
}

moveright(e: ref IcState->EditorState)
{
	line: string;
	n: int;

	clampcursor(e);

	line = source->getline(e, e.cursorline);

	if(e.cursorcol < len line){
		e.cursorcol++;
		selectionrefresh(e);
		return;
	}

	n = source->linecount(e);
	if(e.cursorline + 1 < n){
		e.cursorline++;
		e.cursorcol = 0;
	}

	selectionrefresh(e);
}

moveup(e: ref IcState->EditorState)
{
	e.cursorline--;
	clampcursor(e);
	selectionrefresh(e);
}

movedown(e: ref IcState->EditorState)
{
	e.cursorline++;
	clampcursor(e);
	selectionrefresh(e);
}

movepgup(e: ref IcState->EditorState, rows: int)
{
	e.cursorline -= rows;
	clampcursor(e);
	selectionrefresh(e);
}

movepgdown(e: ref IcState->EditorState, rows: int)
{
	e.cursorline += rows;
	clampcursor(e);
	selectionrefresh(e);
}

movehome(e: ref IcState->EditorState)
{
	e.cursorcol = 0;
	clampcursor(e);
	selectionrefresh(e);
}

moveend(e: ref IcState->EditorState)
{
	clampcursor(e);
	e.cursorcol = len source->getline(e, e.cursorline);
	selectionrefresh(e);
}

toggleselectline(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	if(editblock->active(e)){
		editblock->copyselection(e);
		editblock->clear(e);
		e.message = "Selection copied";
		return;
	}

	editblock->startline(e);
}

startselectblock(e: ref IcState->EditorState)
{
	if(e == nil)
		return;

	editblock->startblock(e);
}

copyselection(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	if(!editblock->active(e)){
		e.message = "No selection";
		return 1;
	}

	editblock->copyselection(e);
	editblock->clear(e);
	e.message = "Selection copied";
	return 1;
}

pastebuffer(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	if(editblock->active(e))
		editblock->clear(e);

	return editblock->paste(e);
}

pastepersistentbuffer(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	if(editblock->active(e))
		editblock->clear(e);

	if(!editblock->loadpersistent(e)){
		e.message = "Clipboard file is empty";
		return 1;
	}

	return editblock->paste(e);
}

deleteselection(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	if(!editblock->active(e)){
		e.message = "No selection";
		return 1;
	}

	return editblock->deleteselection(e);
}

savepersistentselection(e: ref IcState->EditorState): int
{
	if(e == nil)
		return 0;

	return editblock->savepersistent(e);
}

flushsearchdraw(state: ref IcState->AppState): int
{
	if(state == nil || state.ui == nil)
		return 0;

	if(!viewsearch->active())
		return 0;

	return viewsearch->handletick(state.ui, state.toolid, state.width, state.height);
}

closesearch(state: ref IcState->AppState)
{
	if(state == nil || state.ui == nil)
		return;

	viewsearch->close(state.ui);
	flushsearchdraw(state);
}

showsearchalert(state: ref IcState->AppState, text: string)
{
	if(state == nil || state.ui == nil)
		return;

	viewsearch->alert(state.ui, state.toolid, state.width, state.height, text);
	flushsearchdraw(state);
}

runeditsearch(state: ref IcState->AppState, e: ref IcState->EditorState, direction, fromcurrent: int): int
{
	opts: IcViewCommon->SearchOptions;
	r: IcEditSearchRun->SearchResult;

	if(state == nil || e == nil)
		return 0;

	opts = viewsearch->options();

	r = editsearchrun->run(e, opts, direction, fromcurrent);

	if(r.alert){
		showsearchalert(state, r.alerttext);
		return 1;
	}

	if(r.found){
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	return 0;
}

handlesearchdialog(state: ref IcState->AppState, e: ref IcState->EditorState, k: int): int
{
	r: int;

	if(state == nil || state.ui == nil || e == nil)
		return 0;

	r = viewsearch->handlekey(state.ui, state.toolid, state.width, state.height, k);

	if(r == IcViewCommon->SearchNone)
		return 1;

	if(r == IcViewCommon->SearchCancel){
		closesearch(state);
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	if(r == IcViewCommon->SearchAlertClosed){
		closesearch(state);
		e.mode = IcEditCommon->ModeEdit;
		return 1;
	}

	if(r == IcViewCommon->SearchForward){
		closesearch(state);
		return runeditsearch(state, e, IcViewCommon->SearchDirForward, 0);
	}

	if(r == IcViewCommon->SearchBackward){
		closesearch(state);
		return runeditsearch(state, e, IcViewCommon->SearchDirBackward, 0);
	}

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
	Kctrlf =>
		return savepersistentselection(e);

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
		toggleselectline(e);
		return 1;

	Kshiftf3 =>
		activatebutton(e, 3);
		startselectblock(e);
		return 1;

	Kf4 =>
		activatebutton(e, 4);
		return switchtoviewer(state, e);

	Kf5 =>
		activatebutton(e, 5);
		return pastebuffer(e);

	Kshiftf5 =>
		activatebutton(e, 5);
		return pastepersistentbuffer(e);

	Kf6 =>
		activatebutton(e, 6);
		return copyselection(e);

	Kf7 =>
		if(state == nil || state.ui == nil){
			e.message = "Search is unavailable here";
			return 1;
		}

		activatebutton(e, 7);
		e.mode = IcEditCommon->ModeSearch;
		viewsearch->open(state.ui, state.toolid, state.width, state.height, editsearchrun->lastpattern());
		flushsearchdraw(state);
		return 1;

	Kshiftf7 =>
		activatebutton(e, 7);
		return runeditsearch(state, e, IcViewCommon->SearchDirForward, 1);

	Kaltf7 or Kctrlf7 =>
		activatebutton(e, 7);
		return runeditsearch(state, e, IcViewCommon->SearchDirBackward, 1);

	Kf8 =>
		activatebutton(e, 8);
		return deleteselection(e);

	Kf9 =>
		activatebutton(e, 9);
		e.mode = IcEditCommon->ModeMenu;
		return 1;

	Kesc or Kf10 =>
		activatebutton(e, 10);
		if(editblock->active(e)){
			editblock->clear(e);
			return 1;
		}

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
		movepgup(e, rows);

	Kpgdown =>
		movepgdown(e, rows);

	Khome =>
		movehome(e);

	Kend =>
		moveend(e);

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

	if(e.mode == IcEditCommon->ModeSearch || viewsearch->active())
		return handlesearchdialog(state, e, k);

	if(e.mode == IcEditCommon->ModeConfirmQuit)
		return handleconfirm(e, k);

	if(e.mode == IcEditCommon->ModeFilename)
		return handlefilename(e, k);

	if(e.mode == IcEditCommon->ModeHelp)
		return handlehelp(e, k);

	if(e.mode == IcEditCommon->ModeMenu)
		return handlemenu(e, k);

	return handleedit(state, e, k, h);
}