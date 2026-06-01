implement IcEditDraw;

include "ic/editdraw.m";

IcEditCommon: module
{
	PATH: con "/dis/ic/editcommon.dis";

	ModeEdit: con 0;
	ModeConfirmQuit: con 1;
	ModeFilename: con 2;
	ModeHelp: con 3;
	ModeSearch: con 4;
	ModeMenu: con 5;

	SelectionLine: con 1;
	SelectionBlock: con 2;

	ButtonCount: con 10;
	ButtonGap: con 1;
	ModalStageMax: con 3;

	EditorButton: adt
	{
		fkey: int;
		text: string;
		enabled: int;
	};

	init: fn();
	spaces: fn(n: int): string;
	repeat: fn(s: string, n: int): string;
	fittext: fn(s: string, w: int): string;
	bodyh: fn(h: int): int;
	buttondef: fn(idx: int): EditorButton;
};

IcEditSource: module
{
	PATH: con "/dis/ic/editsource.dis";

	init: fn();
	refreshwindow: fn(e: ref IcState->EditorState, rows: int);
};

IcEditSearchRun: module
{
	PATH: con "/dis/ic/editsearchrun.dis";

	init: fn();
	searchsarg: fn(e: ref IcState->EditorState, h: int): string;
};

IcEditBlock: module
{
	PATH: con "/dis/ic/editblock.dis";

	init: fn();

	active: fn(e: ref IcState->EditorState): int;
	span: fn(e: ref IcState->EditorState, line, width: int): (int, int, int);
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

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	setstatusrows: fn(u: ref IcUi->Ui, helprow, statusrow: int);
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
	textview: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
};

common: IcEditCommon;
source: IcEditSource;
editsearchrun: IcEditSearchRun;
editblock: IcEditBlock;
view: IcViewMod;
ui: IcUiMod;

theme: ref IcState->ThemeState;

DefaultTopCode: con "1;38;2;20;25;30;48;2;225;225;225";
DefaultMenuCode: con "1;38;2;20;25;30;48;2;210;235;255";
DefaultBodyCode: con "38;2;220;230;255;48;2;20;45;90";
DefaultBottomCode: con "1;38;2;20;25;30;48;2;170;225;255";
DefaultBottomActiveCode: con "1;38;2;255;120;210;48;2;170;225;255";
DefaultBottomDisabledCode: con "38;2;120;120;120;48;2;170;225;255";
DefaultCursorCode: con "1;38;2;0;0;0;48;2;255;235;80";
DefaultSelectionCode: con "1;38;2;0;0;0;48;2;170;225;255";

DefaultModalCode: con "1;38;2;20;20;20;48;2;225;225;225";
DefaultModalTitleCode: con "1;38;2;255;255;255;48;2;40;105;160";
DefaultModalInputCode: con "1;38;2;255;255;255;48;2;55;160;220";
DefaultModalButtonCode: con "1;38;2;0;0;0;48;2;170;225;255";
DefaultModalShadowCode: con "38;2;120;120;120;48;2;0;0;0";

ensureids: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
ensurebuttonids: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
ensureoverlayids: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
ensureselectionids: fn(u: ref IcUi->Ui, e: ref IcState->EditorState, rows: int);

hideoverlay: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
hideselection: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
setshadow: fn(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, code: string);
setbody: fn(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, e: ref IcState->EditorState, content, code: string);

toptext: fn(e: ref IcState->EditorState): string;
visiblecontent: fn(e: ref IcState->EditorState, rows, w: int): string;
cursorarg: fn(e: ref IcState->EditorState, rows: int): string;

buttonx: fn(w, idx: int): int;
buttonw: fn(w, idx: int): int;
buttontext: fn(b: IcEditCommon->EditorButton, w: int): string;
buttoncode: fn(e: ref IcState->EditorState, b: IcEditCommon->EditorButton): string;
drawbuttonbar: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int);

drawselection: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, rows, w: int);
drawmodal: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int, title, line1, inputline, line3: string, input: int);
drawmodeoverlay: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int);

topcode: fn(): string;
menucode: fn(): string;
bodycode: fn(): string;
bottomcode: fn(): string;
bottomactivecode: fn(): string;
bottomdisabledcode: fn(): string;
cursorcode: fn(): string;
selectioncode: fn(): string;
modalcode: fn(): string;
modaltitlecode: fn(): string;
modalinputcode: fn(): string;
modalbuttoncode: fn(): string;
modalshadowcode: fn(): string;

init()
{
	common = load IcEditCommon IcEditCommon->PATH;
	if(common == nil)
		raise "fail:load ic/editcommon";

	source = load IcEditSource IcEditSource->PATH;
	if(source == nil)
		raise "fail:load ic/editsource";

	editsearchrun = load IcEditSearchRun IcEditSearchRun->PATH;
	if(editsearchrun == nil)
		raise "fail:load ic/editsearchrun";

	editblock = load IcEditBlock IcEditBlock->PATH;
	if(editblock == nil)
		raise "fail:load ic/editblock";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	common->init();
	source->init();
	editsearchrun->init();
	editblock->init();
	view->init();
	ui->init();

	theme = nil;
}

settheme(t: ref IcState->ThemeState)
{
	if(t != nil)
		theme = t;
}

topcode(): string
{
	if(theme != nil && theme.paneltopcode != "")
		return theme.paneltopcode;

	return DefaultTopCode;
}

menucode(): string
{
	if(theme != nil && theme.menuwindowcode != "")
		return theme.menuwindowcode;

	return DefaultMenuCode;
}

bodycode(): string
{
	if(theme != nil && theme.panelbodycode != "")
		return theme.panelbodycode;

	return DefaultBodyCode;
}

bottomcode(): string
{
	if(theme != nil && theme.commandbarcode != "")
		return theme.commandbarcode;

	return DefaultBottomCode;
}

bottomactivecode(): string
{
	if(theme != nil && theme.commandbaractivecode != "")
		return theme.commandbaractivecode;

	return DefaultBottomActiveCode;
}

bottomdisabledcode(): string
{
	if(theme != nil && theme.commandbardisabledcode != "")
		return theme.commandbardisabledcode;

	return DefaultBottomDisabledCode;
}


cursorcode(): string
{
	if(theme != nil && theme.dialogfocuscode != "")
		return theme.dialogfocuscode;

	return DefaultCursorCode;
}

selectioncode(): string
{
	if(theme != nil && theme.menufocuscode != "")
		return theme.menufocuscode;

	return DefaultSelectionCode;
}

modalcode(): string
{
	if(theme != nil && theme.dialogtextcode != "")
		return theme.dialogtextcode;

	return DefaultModalCode;
}

modaltitlecode(): string
{
	if(theme != nil && theme.dialogframecode != "")
		return theme.dialogframecode;

	return DefaultModalTitleCode;
}

modalinputcode(): string
{
	if(theme != nil && theme.dialogfieldcode != "")
		return theme.dialogfieldcode;

	return DefaultModalInputCode;
}

modalbuttoncode(): string
{
	if(theme != nil && theme.dialogbuttonfocuscode != "")
		return theme.dialogbuttonfocuscode;

	return DefaultModalButtonCode;
}

modalshadowcode(): string
{
	if(theme != nil && theme.dialogshadowcode != "")
		return theme.dialogshadowcode;

	return DefaultModalShadowCode;
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

ensurebuttonids(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	i: int;

	if(u == nil || u.tree == nil || e == nil)
		return;

	if(e.buttonids != nil && len e.buttonids == IcEditCommon->ButtonCount)
		return;

	e.buttonids = array[IcEditCommon->ButtonCount] of int;
	for(i = 0; i < len e.buttonids; i++)
		e.buttonids[i] = view->allocid(u.tree);
}

ensureoverlayids(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	i: int;

	if(u == nil || u.tree == nil || e == nil)
		return;

	if(e.overlayids != nil && len e.overlayids == 18)
		return;

	e.overlayids = array[18] of int;
	for(i = 0; i < len e.overlayids; i++)
		e.overlayids[i] = view->allocid(u.tree);
}

ensureselectionids(u: ref IcUi->Ui, e: ref IcState->EditorState, rows: int)
{
	i: int;

	if(u == nil || u.tree == nil || e == nil)
		return;

	if(rows < 1)
		rows = 1;

	if(e.selectionids != nil && len e.selectionids == rows)
		return;

	e.selectionids = array[rows] of int;
	for(i = 0; i < rows; i++)
		e.selectionids[i] = view->allocid(u.tree);
}

hide(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || e == nil)
		return;

	n = view->find(u.tree, e.topid);
	if(n != nil)
		view->hide(n);

	n = view->find(u.tree, e.bodyid);
	if(n != nil)
		view->hide(n);

	n = view->find(u.tree, e.bottomid);
	if(n != nil)
		view->hide(n);

	if(e.buttonids != nil){
		for(i = 0; i < len e.buttonids; i++){
			n = view->find(u.tree, e.buttonids[i]);
			if(n != nil)
				view->hide(n);
		}
	}

	hideselection(u, e);
	hideoverlay(u, e);
}

hideoverlay(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || e == nil || e.overlayids == nil)
		return;

	for(i = 0; i < len e.overlayids; i++){
		n = view->find(u.tree, e.overlayids[i]);
		if(n != nil)
			view->hide(n);
	}
}

hideselection(u: ref IcUi->Ui, e: ref IcState->EditorState)
{
	i: int;
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || e == nil || e.selectionids == nil)
		return;

	for(i = 0; i < len e.selectionids; i++){
		n = view->find(u.tree, e.selectionids[i]);
		if(n != nil)
			view->hide(n);
	}
}

setlabel(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || id <= 0)
		return;

	if(view->find(u.tree, id) == nil)
		ui->label(u, parentid, id, x, y, w, text);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, common->fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

setshadow(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil || id <= 0)
		return;

	if(w <= 0 || h <= 0)
		return;

	if(view->find(u.tree, id) == nil)
		ui->node(u, parentid, id, "shadow", x, y, w, h);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, h);
	view->setcode(n, code);
	view->show(n);
}

setbody(u: ref IcUi->Ui, parentid, id, x, y, w, h: int, e: ref IcState->EditorState, content, code: string)
{
	n: ref IcView->Node;
	sarg: string;

	if(u == nil || u.tree == nil || id <= 0)
		return;

	if(view->find(u.tree, id) == nil)
		ui->textview(u, parentid, id, x, y, w, h);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	sarg = cursorarg(e, h);

	view->setbounds(n, x, y, w, h);
	view->setcontent(n, content);
	view->setcode(n, code);
	view->setargs(n, sarg, 0, 0, 0);
	view->show(n);
}

toptext(e: ref IcState->EditorState): string
{
	mark, name, sel: string;

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

	sel = "";
	if(e.selectionactive && e.selectionkind == IcEditCommon->SelectionLine)
		sel = "  sel:line";
	else if(e.selectionactive && e.selectionkind == IcEditCommon->SelectionBlock)
		sel = "  sel:block";

	if(e.message != "")
		return " " + name + mark
			+ "  line:" + string (e.cursorline + 1)
			+ "  col:" + string (e.cursorcol + 1)
			+ "  lines:" + string e.nlines
			+ sel + "  " + e.message;

	return " " + name + mark
		+ "  line:" + string (e.cursorline + 1)
		+ "  col:" + string (e.cursorcol + 1)
		+ "  lines:" + string e.nlines
		+ sel;
}

visiblecontent(e: ref IcState->EditorState, rows, w: int): string
{
	i: int;
	line, text: string;

	if(e == nil)
		return "";

	source->refreshwindow(e, rows);

	text = "";

	for(i = 0; i < rows; i++){
		if(i >= 0 && i < len e.lines){
			line = e.lines[i];

			if(e.topline + i == e.cursorline && e.cursorcol >= len line)
				line += " ";

			text += common->fittext(line, w);
		}else
			text += common->spaces(w);

		if(i < rows - 1)
			text += "\n";
	}

	return text;
}

cursorarg(e: ref IcState->EditorState, rows: int): string
{
	searcharg: string;
	row, start, end: int;

	if(e == nil)
		return "";

	searcharg = editsearchrun->searchsarg(e, rows);
	if(searcharg != "")
		return searcharg;

	if(e.mode != IcEditCommon->ModeEdit)
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
		+ "search_code=" + cursorcode() + "\n";
}

buttonx(w, idx: int): int
{
	return (w * idx) / IcEditCommon->ButtonCount;
}

buttonw(w, idx: int): int
{
	x0, x1, bw: int;

	x0 = buttonx(w, idx);
	x1 = (w * (idx + 1)) / IcEditCommon->ButtonCount;

	bw = x1 - x0;
	if(idx < IcEditCommon->ButtonCount - 1)
		bw -= IcEditCommon->ButtonGap;

	if(bw < 1)
		bw = 1;

	return bw;
}

buttontext(b: IcEditCommon->EditorButton, w: int): string
{
	return common->fittext("F" + string b.fkey + " " + b.text, w);
}

buttoncode(e: ref IcState->EditorState, b: IcEditCommon->EditorButton): string
{
	if(!b.enabled)
		return bottomdisabledcode();

	if(e != nil && e.activewait > 0 && e.activefkey == b.fkey)
		return bottomactivecode();

	return bottomcode();
}

drawbuttonbar(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int)
{
	i, x, bw: int;
	b: IcEditCommon->EditorButton;

	if(u == nil || e == nil)
		return;

	setlabel(u, parentid, e.bottomid, 0, h - 1, w, common->spaces(w), bottomcode());

	ensurebuttonids(u, e);

	for(i = 0; i < IcEditCommon->ButtonCount; i++){
		b = common->buttondef(i);
		x = buttonx(w, i);
		bw = buttonw(w, i);

		setlabel(u, parentid, e.buttonids[i], x, h - 1, bw, buttontext(b, bw), buttoncode(e, b));
	}
}

drawselection(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, rows, w: int)
{
	i, ok, start, end, line: int;

	if(u == nil || e == nil)
		return;

	hideselection(u, e);

	if(!editblock->active(e))
		return;

	ensureselectionids(u, e, rows);

	for(i = 0; i < rows; i++){
		line = e.topline + i;
		(start, end, ok) = editblock->span(e, line, w);
		if(!ok)
			continue;

		if(start < 0)
			start = 0;
		if(end > w)
			end = w;
		if(end <= start)
			continue;

		setshadow(u, parentid, e.selectionids[i], start, 1 + i, end - start, 1, selectioncode());
	}
}

drawmodal(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int, title, line1, inputline, line3: string, input: int)
{
	x, y, mw, mh: int;
	top, bottom, empty: string;

	if(u == nil || e == nil)
		return;

	ensureoverlayids(u, e);

	mw = 62;
	if(mw > w - 4)
		mw = w - 4;
	if(mw < 28)
		mw = 28;

	mh = 9;
	x = (w - mw) / 2;
	y = (h - mh) / 2;
	if(x < 0)
		x = 0;
	if(y < 1)
		y = 1;

	if(e.modalstage > 0){
		setshadow(u, parentid, e.overlayids[0], x + mw, y + 1, 1, mh - 1, modalshadowcode());
		setshadow(u, parentid, e.overlayids[1], x + 1, y + mh, mw, 1, modalshadowcode());
	}

	top = "╔" + common->repeat("═", mw - 2) + "╗";
	bottom = "╚" + common->repeat("═", mw - 2) + "╝";
	empty = "║" + common->spaces(mw - 2) + "║";

	setlabel(u, parentid, e.overlayids[2], x, y, mw, top, modaltitlecode());
	setlabel(u, parentid, e.overlayids[3], x, y + 1, mw, "║ " + common->fittext(title, mw - 4) + " ║", modaltitlecode());
	setlabel(u, parentid, e.overlayids[4], x, y + 2, mw, empty, modalcode());
	setlabel(u, parentid, e.overlayids[5], x, y + 3, mw, "║ " + common->fittext(line1, mw - 4) + " ║", modalcode());

	if(input)
		setlabel(u, parentid, e.overlayids[6], x, y + 4, mw, "║ " + common->fittext(inputline, mw - 4) + " ║", modalinputcode());
	else
		setlabel(u, parentid, e.overlayids[6], x, y + 4, mw, "║ " + common->fittext(inputline, mw - 4) + " ║", modalcode());

	setlabel(u, parentid, e.overlayids[7], x, y + 5, mw, "║ " + common->fittext(line3, mw - 4) + " ║", modalcode());
	setlabel(u, parentid, e.overlayids[8], x, y + 6, mw, empty, modalcode());
	setlabel(u, parentid, e.overlayids[9], x, y + 7, mw, "║ " + common->fittext("OK: Enter    Cancel: Esc", mw - 4) + " ║", modalbuttoncode());
	setlabel(u, parentid, e.overlayids[10], x, y + 8, mw, bottom, modalcode());
}

drawmodeoverlay(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int)
{
	if(e.mode == IcEditCommon->ModeHelp){
		drawmodal(u, parentid, e, w, h,
			"IC Editor help",
			"F2 Save, Shift+F2 Save as",
			"F3 Line selection, Shift+F3 Block selection",
			"F4 View, F7 Search, F9 Menu, F10 Quit",
			0);
		return;
	}

	if(e.mode == IcEditCommon->ModeFilename){
		drawmodal(u, parentid, e, w, h,
			"Save as",
			"File name:",
			" " + e.filenameinput,
			"",
			1);
		return;
	}

	if(e.mode == IcEditCommon->ModeConfirmQuit){
		drawmodal(u, parentid, e, w, h,
			"Unsaved changes",
			"Save changes before exit?",
			"Y - save and quit, N - quit without saving",
			"Esc - cancel",
			0);
		return;
	}
}

draw(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int)
{
	rows: int;
	content: string;

	if(u == nil || e == nil)
		return;

	rows = common->bodyh(h);

	ensureids(u, e);
	hideoverlay(u, e);

	if(e.nlines < 1)
		e.nlines = 1;

	if(e.cursorline < 0)
		e.cursorline = 0;
	if(e.cursorline >= e.nlines)
		e.cursorline = e.nlines - 1;
	if(e.cursorline < 0)
		e.cursorline = 0;

	if(e.topline < 0)
		e.topline = 0;
	if(e.cursorline < e.topline)
		e.topline = e.cursorline;
	if(e.cursorline >= e.topline + rows)
		e.topline = e.cursorline - rows + 1;

	ui->setstatusrows(u, -1, -1);

	if(e.mode == IcEditCommon->ModeMenu)
		setlabel(u, parentid, e.topid, 0, 0, w, " File   Edit   Search   Command   Format   Windows   Settings", menucode());
	else
		setlabel(u, parentid, e.topid, 0, 0, w, toptext(e), topcode());

	content = visiblecontent(e, rows, w);
	setbody(u, parentid, e.bodyid, 0, 1, w, rows, e, content, bodycode());

	drawselection(u, parentid, e, rows, w);

	drawbuttonbar(u, parentid, e, w, h);
	drawmodeoverlay(u, parentid, e, w, h);
}

handletick(e: ref IcState->EditorState): int
{
	changed: int;

	if(e == nil)
		return 0;

	changed = 0;

	if(e.activewait > 0){
		e.activewait--;
		if(e.activewait <= 0)
			e.activefkey = 0;
		changed = 1;
	}

	if(e.mode == IcEditCommon->ModeHelp
	|| e.mode == IcEditCommon->ModeFilename
	|| e.mode == IcEditCommon->ModeConfirmQuit){
		if(e.modalstage < IcEditCommon->ModalStageMax){
			e.modalstage++;
			changed = 1;
		}
	}

	return changed;
}