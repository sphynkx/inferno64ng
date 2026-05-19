implement IcViewGoto;

include "ic/viewgoto.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	node: fn(u: ref IcUi->Ui, parentid, id: int, kind: string, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	allocid: fn(t: ref IcView->Tree): int;
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	removetree: fn(t: ref IcView->Tree, id: int): int;
	bringtofront: fn(t: ref IcView->Tree, id: int): int;
};

GotoStyle: adt
{
	windowcode: string;
	framecode: string;
	textcode: string;
	fieldcode: string;
	fieldfocuscode: string;
	focuscode: string;
	buttoncode: string;
	buttonfocuscode: string;
	shadowcode: string;

	frameh: string;
	framev: string;
	framenw: string;
	framene: string;
	framesw: string;
	framese: string;
};

sys: Sys;
ui: IcUiMod;
view: IcViewMod;

g: IcViewCommon->GotoState;
style: GotoStyle;
inputpos: int;

StageNone: con 0;
StageShadow: con 1;
StageWindow: con 2;
StageClosingShadow: con 3;

animstage: int;

ThemeSection: con "theme";
DefaultThemeFile: con "/lib/ic/theme.cfg";
UserBaseDir: con "/usr";
UserConfigDir: con "ic";
ThemeFileName: con "theme.cfg";
DefaultUserName: con "inferno";

TabKey: con 9;
EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;
BackspaceKey: con 8;
DeleteKey: con 127;
UpKey: con 57362;
DownKey: con 57363;
LeftKey: con 57364;
RightKey: con 57365;

initstyle: fn();
loadtheme: fn();
loadthemefile: fn(path: string);
applythemevalue: fn(section, key, value: string);
readfile: fn(path: string): string;
username: fn(): string;
trim: fn(s: string): string;
parseconfig: fn(text: string);
parseconfigline: fn(section, line: string): string;
splitkeyvalue: fn(line: string): (string, string, int);

ensureids: fn(u: ref IcUi->Ui);
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
topframe: fn(w: int): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
radiotext: fn(mode: int, label: string): string;
fieldtext: fn(w: int): string;
buttontext: fn(kind: int): string;
focusnext: fn();
focusprev: fn();
printable: fn(k: int): int;
typecode: fn(focus: int): string;
buttonstyle: fn(focus: int): string;
setfocusmode: fn(focus: int): int;

clampinputpos: fn();
insertchar: fn(k: int);
backspacechar: fn();
deletechar: fn();
normalizedinput: fn(): string;
autochoosemode: fn(k: int);
ishexmark: fn(k: int): int;
ispercentmark: fn(k: int): int;

drawshadow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawwindow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	ui->init();
	view->init();

	initstyle();
	loadtheme();

	g.active = 0;
	g.shadowid = -1;
	g.windowid = -1;
	g.inputid = -1;
	g.typeids = array[4] of int;
	g.buttonids = array[2] of int;
	g.input = "";
	g.mode = IcViewCommon->GotoLine;
	g.focus = IcViewCommon->GotoFocusInput;
	g.result = IcViewCommon->GotoNone;
	inputpos = 0;

	animstage = StageNone;
}

initstyle()
{
	style.windowcode = "38;2;20;20;20;48;2;210;210;210";
	style.framecode = "1;38;2;35;35;35;48;2;210;210;210";
	style.textcode = "38;2;20;20;20;48;2;210;210;210";
	style.fieldcode = "1;38;2;255;255;255;48;2;55;160;220";
	style.fieldfocuscode = "1;38;2;255;255;255;48;2;35;135;205";
	style.focuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.buttoncode = "1;38;2;20;20;20;48;2;235;235;235";
	style.buttonfocuscode = "1;38;2;0;0;0;48;2;170;225;255";
	style.shadowcode = "38;2;120;120;120;48;2;0;0;0";

	style.frameh = "─";
	style.framev = "│";
	style.framenw = "┌";
	style.framene = "┐";
	style.framesw = "└";
	style.framese = "┘";
}

loadtheme()
{
	loadthemefile(DefaultThemeFile);
	loadthemefile(UserBaseDir + "/" + username() + "/" + UserConfigDir + "/" + ThemeFileName);
}

loadthemefile(path: string)
{
	text: string;

	text = readfile(path);
	if(text == "")
		return;

	parseconfig(text);
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

username(): string
{
	s: string;

	s = trim(readfile("/env/user"));
	if(s == "")
		return DefaultUserName;

	return s;
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

parseconfig(text: string)
{
	i, start: int;
	line, section: string;

	section = "";
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		line = text[start:i];
		section = parseconfigline(section, line);
		start = i + 1;
	}
}

parseconfigline(section, line: string): string
{
	key, value: string;
	ok: int;

	line = trim(line);
	if(line == "")
		return section;

	if(line[0] == '#')
		return section;

	if(line[0] == '[' && len line > 2 && line[len line - 1] == ']')
		return trim(line[1:len line - 1]);

	(key, value, ok) = splitkeyvalue(line);
	if(ok)
		applythemevalue(section, key, value);

	return section;
}

splitkeyvalue(line: string): (string, string, int)
{
	i: int;

	for(i = 0; i < len line; i++){
		if(line[i] == '=')
			return (trim(line[0:i]), trim(line[i + 1:]), 1);
	}

	return ("", "", 0);
}

applythemevalue(section, key, value: string)
{
	if(section != ThemeSection)
		return;

	if(key == "viewer_goto_window_code")
		style.windowcode = value;
	else if(key == "viewer_goto_frame_code")
		style.framecode = value;
	else if(key == "viewer_goto_text_code")
		style.textcode = value;
	else if(key == "viewer_goto_field_code")
		style.fieldcode = value;
	else if(key == "viewer_goto_field_focus_code")
		style.fieldfocuscode = value;
	else if(key == "viewer_goto_focus_code")
		style.focuscode = value;
	else if(key == "viewer_goto_button_code")
		style.buttoncode = value;
	else if(key == "viewer_goto_button_focus_code")
		style.buttonfocuscode = value;
	else if(key == "viewer_goto_shadow_code")
		style.shadowcode = value;
	else if(key == "viewer_goto_frame_h")
		style.frameh = value;
	else if(key == "viewer_goto_frame_v")
		style.framev = value;
	else if(key == "viewer_goto_frame_nw")
		style.framenw = value;
	else if(key == "viewer_goto_frame_ne")
		style.framene = value;
	else if(key == "viewer_goto_frame_sw")
		style.framesw = value;
	else if(key == "viewer_goto_frame_se")
		style.framese = value;
}

open(u: ref IcUi->Ui, parentid, w, h: int)
{
	if(u == nil || u.tree == nil)
		return;

	g.active = 1;
	g.input = "";
	g.mode = IcViewCommon->GotoLine;
	g.focus = IcViewCommon->GotoFocusInput;
	g.result = IcViewCommon->GotoNone;
	inputpos = 0;
	animstage = StageShadow;

	ensureids(u);
	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!g.active)
		return;

	if(animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		return;
	}

	dispose(u);
	g.active = 0;
	g.result = IcViewCommon->GotoNone;
	animstage = StageNone;
}

active(): int
{
	return g.active;
}

mode(): int
{
	return g.mode;
}

input(): string
{
	return normalizedinput();
}

ensureids(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil)
		return;

	if(g.shadowid < 0)
		g.shadowid = view->allocid(u.tree);
	if(g.windowid < 0)
		g.windowid = view->allocid(u.tree);
	if(g.inputid < 0)
		g.inputid = view->allocid(u.tree);

	if(g.typeids == nil || len g.typeids != 4)
		g.typeids = array[4] of int;

	for(i = 0; i < 4; i++){
		if(g.typeids[i] <= 0)
			g.typeids[i] = view->allocid(u.tree);
	}

	if(g.buttonids == nil || len g.buttonids != 2)
		g.buttonids = array[2] of int;

	for(i = 0; i < 2; i++){
		if(g.buttonids[i] <= 0)
			g.buttonids[i] = view->allocid(u.tree);
	}
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(g.windowid >= 0)
		view->removetree(u.tree, g.windowid);
	if(g.shadowid >= 0)
		view->removetree(u.tree, g.shadowid);
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(g.windowid >= 0)
		view->removetree(u.tree, g.windowid);
}

fillstr(n: int, ch: string): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += ch;

	return s;
}

spaces(n: int): string
{
	return fillstr(n, " ");
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

topframe(w: int): string
{
	prefix, title: string;
	n: int;

	title = " GoTo ";
	prefix = style.framenw + title;
	n = w - len prefix - len style.framene;
	if(n < 0)
		n = 0;

	return fittext(prefix + fillstr(n, style.frameh) + style.framene, w);
}

bottomframe(w: int): string
{
	if(w < 2)
		return fittext(style.framesw, w);

	return style.framesw + fillstr(w - 2, style.frameh) + style.framese;
}

midframe(w: int): string
{
	if(w < 2)
		return fittext(style.framev, w);

	return style.framev + spaces(w - 2) + style.framev;
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

radiotext(mode: int, label: string): string
{
	if(g.mode == mode)
		return "(*) " + label;

	return "( ) " + label;
}

fieldtext(w: int): string
{
	s: string;

	clampinputpos();

	if(g.focus != IcViewCommon->GotoFocusInput)
		return fittext(g.input, w);

	s = g.input[0:inputpos] + "|" + g.input[inputpos:];
	return fittext(s, w);
}

buttontext(kind: int): string
{
	if(kind == 0)
		return "[< OK >]";

	return "[ Cancel ]";
}

typecode(focus: int): string
{
	if(g.focus == focus)
		return style.focuscode;

	return style.textcode;
}

buttonstyle(focus: int): string
{
	if(g.focus == focus)
		return style.buttonfocuscode;

	return style.buttoncode;
}

setfocusmode(focus: int): int
{
	case focus {
	IcViewCommon->GotoFocusLine =>
		g.mode = IcViewCommon->GotoLine;
		return 1;

	IcViewCommon->GotoFocusPercent =>
		g.mode = IcViewCommon->GotoPercent;
		return 1;

	IcViewCommon->GotoFocusOffsetDec =>
		g.mode = IcViewCommon->GotoOffsetDec;
		return 1;

	IcViewCommon->GotoFocusOffsetHex =>
		g.mode = IcViewCommon->GotoOffsetHex;
		return 1;
	}

	return 0;
}

clampinputpos()
{
	if(inputpos < 0)
		inputpos = 0;

	if(inputpos > len g.input)
		inputpos = len g.input;
}

ishexmark(k: int): int
{
	if(k >= 'a' && k <= 'f')
		return 1;
	if(k >= 'A' && k <= 'F')
		return 1;
	if(k == 'x' || k == 'X')
		return 1;
	if(k == 'h' || k == 'H')
		return 1;

	return 0;
}

ispercentmark(k: int): int
{
	return k == '%';
}

autochoosemode(k: int)
{
	if(ispercentmark(k)){
		g.mode = IcViewCommon->GotoPercent;
		return;
	}

	if(ishexmark(k))
		g.mode = IcViewCommon->GotoOffsetHex;
}

insertchar(k: int)
{
	c: string;

	clampinputpos();
	autochoosemode(k);

	c = sys->sprint("%c", k);
	g.input = g.input[0:inputpos] + c + g.input[inputpos:];
	inputpos++;
}

backspacechar()
{
	clampinputpos();

	if(inputpos <= 0)
		return;

	g.input = g.input[0:inputpos - 1] + g.input[inputpos:];
	inputpos--;
}

deletechar()
{
	clampinputpos();

	if(inputpos >= len g.input)
		return;

	g.input = g.input[0:inputpos] + g.input[inputpos + 1:];
}

normalizedinput(): string
{
	s: string;

	s = trim(g.input);

	if(g.mode == IcViewCommon->GotoPercent){
		if(len s > 0 && s[len s - 1] == '%')
			s = s[0:len s - 1];

		return trim(s);
	}

	if(g.mode != IcViewCommon->GotoOffsetHex)
		return s;

	if(len s >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
		s = s[2:];

	if(len s > 0 && (s[len s - 1] == 'h' || s[len s - 1] == 'H'))
		s = s[0:len s - 1];

	return trim(s);
}

drawshadow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	n: ref IcView->Node;

	ui->node(u, parentid, g.shadowid, "shadow", x + 1, y + 1, w, h);
	n = view->find(u.tree, g.shadowid);
	if(n != nil)
		view->setcode(n, style.shadowcode);

	view->bringtofront(u.tree, g.shadowid);
	return 0;
}

drawwindow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, bx, row, bgid: int;

	ui->node(u, parentid, g.windowid, "group", x, y, w, h);

	setlabel(u, g.windowid, view->allocid(u.tree), 0, 0, w, topframe(w), style.framecode);
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, g.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}
	setlabel(u, g.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	if(g.focus == IcViewCommon->GotoFocusInput)
		setlabel(u, g.windowid, g.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldfocuscode);
	else
		setlabel(u, g.windowid, g.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldcode);

	setlabel(u, g.windowid, g.typeids[0], 4, 4, bodyw,
		radiotext(IcViewCommon->GotoLine, "Line number"),
		typecode(IcViewCommon->GotoFocusLine));

	setlabel(u, g.windowid, g.typeids[1], 4, 5, bodyw,
		radiotext(IcViewCommon->GotoPercent, "Percent"),
		typecode(IcViewCommon->GotoFocusPercent));

	setlabel(u, g.windowid, g.typeids[2], 4, 6, bodyw,
		radiotext(IcViewCommon->GotoOffsetDec, "Offset (decimal)"),
		typecode(IcViewCommon->GotoFocusOffsetDec));

	setlabel(u, g.windowid, g.typeids[3], 4, 7, bodyw,
		radiotext(IcViewCommon->GotoOffsetHex, "Offset (hex)"),
		typecode(IcViewCommon->GotoFocusOffsetHex));

	bx = (w - 23) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, g.windowid, g.buttonids[0], bx, 10, 9,
		buttontext(0),
		buttonstyle(IcViewCommon->GotoFocusOk));

	setlabel(u, g.windowid, g.buttonids[1], bx + 12, 10, 10,
		buttontext(1),
		buttonstyle(IcViewCommon->GotoFocusCancel));

	view->bringtofront(u.tree, g.windowid);
	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	iw, wh, x, y: int;

	if(u == nil || u.tree == nil || !g.active)
		return -1;

	ensureids(u);
	dispose(u);

	iw = 52;
	wh = 13;

	if(iw > w - 4)
		iw = w - 4;
	if(iw < 38)
		iw = 38;

	if(wh > h - 2)
		wh = h - 2;
	if(wh < 12)
		wh = 12;

	x = (w - iw) / 2;
	y = (h - wh) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	g.x = x;
	g.y = y;
	g.w = iw;
	g.h = wh;

	if(animstage == StageShadow || animstage == StageClosingShadow)
		return drawshadow(u, parentid, x, y, iw, wh);

	drawshadow(u, parentid, x, y, iw, wh);
	return drawwindow(u, parentid, x, y, iw, wh);
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	if(!g.active)
		return 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		g.active = 0;
		g.result = IcViewCommon->GotoNone;
		animstage = StageNone;
		return 1;
	}

	return 0;
}

focusnext()
{
	g.focus++;
	if(g.focus > IcViewCommon->GotoFocusCancel)
		g.focus = IcViewCommon->GotoFocusInput;
}

focusprev()
{
	g.focus--;
	if(g.focus < IcViewCommon->GotoFocusInput)
		g.focus = IcViewCommon->GotoFocusCancel;
}

printable(k: int): int
{
	if(k >= '0' && k <= '9')
		return 1;

	if(k == '%')
		return 1;

	if(k >= 'a' && k <= 'f')
		return 1;

	if(k >= 'A' && k <= 'F')
		return 1;

	if(k == 'x' || k == 'X')
		return 1;

	if(k == 'h' || k == 'H')
		return 1;

	return 0;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	if(!g.active)
		return IcViewCommon->GotoNone;

	if(animstage != StageWindow)
		return IcViewCommon->GotoNone;

	if(k == EscapeKey){
		g.result = IcViewCommon->GotoCancel;
		return g.result;
	}

	if(k == TabKey || k == DownKey){
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == UpKey){
		focusprev();
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == LeftKey){
		if(g.focus == IcViewCommon->GotoFocusInput){
			inputpos--;
			clampinputpos();
		}else
			focusprev();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == RightKey){
		if(g.focus == IcViewCommon->GotoFocusInput){
			inputpos++;
			clampinputpos();
		}else
			focusnext();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == BackspaceKey){
		if(g.focus == IcViewCommon->GotoFocusInput)
			backspacechar();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == DeleteKey){
		if(g.focus == IcViewCommon->GotoFocusInput)
			deletechar();

		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(g.focus == IcViewCommon->GotoFocusInput && printable(k)){
		insertchar(k);
		draw(u, parentid, w, h);
		return IcViewCommon->GotoNone;
	}

	if(k == SpaceKey){
		if(setfocusmode(g.focus)){
			draw(u, parentid, w, h);
			return IcViewCommon->GotoNone;
		}

		if(g.focus == IcViewCommon->GotoFocusOk || g.focus == IcViewCommon->GotoFocusInput){
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusCancel){
			g.result = IcViewCommon->GotoCancel;
			return g.result;
		}
	}

	if(k == EnterKey || k == ReturnKey){
		if(setfocusmode(g.focus)){
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusOk || g.focus == IcViewCommon->GotoFocusInput){
			g.result = IcViewCommon->GotoOk;
			return g.result;
		}

		if(g.focus == IcViewCommon->GotoFocusCancel){
			g.result = IcViewCommon->GotoCancel;
			return g.result;
		}
	}

	return IcViewCommon->GotoNone;
}