implement IcViewSearch;

include "ic/viewsearch.m";

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

SearchStyle: adt
{
	windowcode: string;
	framecode: string;
	textcode: string;
	fieldcode: string;
	fieldfocuscode: string;
	focuscode: string;
	buttoncode: string;
	buttonfocuscode: string;
	disabledcode: string;
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

s: IcViewCommon->SearchDialogState;
style: SearchStyle;

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
trim: fn(v: string): string;
parseconfig: fn(text: string);
parseconfigline: fn(section, line: string): string;
splitkeyvalue: fn(line: string): (string, string, int);

ensureids: fn(u: ref IcUi->Ui);
resetwindowids: fn();
dispose: fn(u: ref IcUi->Ui);
disposewindow: fn(u: ref IcUi->Ui);

fillstr: fn(n: int, ch: string): string;
spaces: fn(n: int): string;
fittext: fn(v: string, w: int): string;
topframe: fn(w: int, title: string): string;
bottomframe: fn(w: int): string;
midframe: fn(w: int): string;

setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);
checkbox: fn(checked: int, label: string): string;
fieldtext: fn(w: int): string;
buttontext: fn(kind: int): string;
focusnext: fn();
focusprev: fn();
printable: fn(k: int): int;
optioncode: fn(focus: int): string;
buttoncode: fn(focus: int): string;
togglefocus: fn(): int;

clampinputpos: fn();
insertchar: fn(k: int);
backspacechar: fn();
deletechar: fn();

drawshadow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawwindow: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;
drawalert: fn(u: ref IcUi->Ui, parentid, x, y, w, h: int): int;

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

	s.active = 0;
	s.alert = 0;
	s.alerttext = "";

	s.shadowid = -1;
	s.windowid = -1;
	s.inputid = -1;
	s.optionids = array[5] of int;
	s.buttonids = array[3] of int;

	resetwindowids();

	s.x = 0;
	s.y = 0;
	s.w = 0;
	s.h = 0;

	s.input = "";
	s.inputpos = 0;
	s.focus = IcViewCommon->SearchFocusInput;

	s.case_sensitive = 1;
	s.backward = 0;
	s.wrap = 1;
	s.regex = 0;
	s.anyencoding = 0;
	s.encoding = "utf-8";

	s.result = IcViewCommon->SearchNone;

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
	style.disabledcode = "38;2;120;120;120;48;2;210;210;210";
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
	v: string;

	v = trim(readfile("/env/user"));
	if(v == "")
		return DefaultUserName;

	return v;
}

trim(v: string): string
{
	a, b: int;

	a = 0;
	b = len v;

	while(a < b && (v[a] == ' ' || v[a] == '\t' || v[a] == '\n' || v[a] == '\r'))
		a++;

	while(b > a && (v[b - 1] == ' ' || v[b - 1] == '\t' || v[b - 1] == '\n' || v[b - 1] == '\r'))
		b--;

	if(a >= b)
		return "";

	return v[a:b];
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

	if(key == "viewer_search_window_code")
		style.windowcode = value;
	else if(key == "viewer_search_frame_code")
		style.framecode = value;
	else if(key == "viewer_search_text_code")
		style.textcode = value;
	else if(key == "viewer_search_field_code")
		style.fieldcode = value;
	else if(key == "viewer_search_field_focus_code")
		style.fieldfocuscode = value;
	else if(key == "viewer_search_focus_code")
		style.focuscode = value;
	else if(key == "viewer_search_button_code")
		style.buttoncode = value;
	else if(key == "viewer_search_button_focus_code")
		style.buttonfocuscode = value;
	else if(key == "viewer_search_disabled_code")
		style.disabledcode = value;
	else if(key == "viewer_search_shadow_code")
		style.shadowcode = value;
	else if(key == "viewer_search_frame_h")
		style.frameh = value;
	else if(key == "viewer_search_frame_v")
		style.framev = value;
	else if(key == "viewer_search_frame_nw")
		style.framenw = value;
	else if(key == "viewer_search_frame_ne")
		style.framene = value;
	else if(key == "viewer_search_frame_sw")
		style.framesw = value;
	else if(key == "viewer_search_frame_se")
		style.framese = value;
}

open(u: ref IcUi->Ui, parentid, w, h: int, pattern: string)
{
	if(u == nil || u.tree == nil)
		return;

	s.active = 1;
	s.alert = 0;
	s.alerttext = "";
	s.result = IcViewCommon->SearchNone;

	s.input = pattern;
	s.inputpos = len s.input;
	s.focus = IcViewCommon->SearchFocusInput;

	if(s.encoding == "")
		s.encoding = "utf-8";

	animstage = StageShadow;

	resetwindowids();
	ensureids(u);
	draw(u, parentid, w, h);
}

alert(u: ref IcUi->Ui, parentid, w, h: int, text: string)
{
	if(u == nil || u.tree == nil)
		return;

	s.active = 1;
	s.alert = 1;
	s.alerttext = text;
	s.result = IcViewCommon->SearchNone;
	s.focus = IcViewCommon->SearchFocusForward;

	animstage = StageShadow;

	resetwindowids();
	ensureids(u);
	draw(u, parentid, w, h);
}

close(u: ref IcUi->Ui)
{
	if(!s.active)
		return;

	if(animstage == StageWindow){
		disposewindow(u);
		animstage = StageClosingShadow;
		return;
	}

	dispose(u);
	s.active = 0;
	s.result = IcViewCommon->SearchNone;
	animstage = StageNone;
	resetwindowids();
}

active(): int
{
	return s.active;
}

isalert(): int
{
	return s.active && s.alert;
}

pattern(): string
{
	return s.input;
}

options(): IcViewCommon->SearchOptions
{
	o: IcViewCommon->SearchOptions;

	o.pattern = s.input;
	o.backward = s.backward;
	o.casefold = !s.case_sensitive;
	o.wrap = s.wrap;
	o.regex = s.regex;
	o.encoding = s.encoding;
	o.anyencoding = s.anyencoding;

	return o;
}

resetwindowids()
{
	i: int;

	s.windowid = -1;
	s.inputid = -1;

	if(s.optionids == nil || len s.optionids != 5)
		s.optionids = array[5] of int;

	for(i = 0; i < len s.optionids; i++)
		s.optionids[i] = -1;

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	for(i = 0; i < len s.buttonids; i++)
		s.buttonids[i] = -1;
}

ensureids(u: ref IcUi->Ui)
{
	i: int;

	if(u == nil || u.tree == nil)
		return;

	if(s.shadowid < 0)
		s.shadowid = view->allocid(u.tree);
	if(s.windowid < 0)
		s.windowid = view->allocid(u.tree);
	if(s.inputid < 0)
		s.inputid = view->allocid(u.tree);

	if(s.optionids == nil || len s.optionids != 5)
		s.optionids = array[5] of int;

	for(i = 0; i < 5; i++){
		if(s.optionids[i] <= 0)
			s.optionids[i] = view->allocid(u.tree);
	}

	if(s.buttonids == nil || len s.buttonids != 3)
		s.buttonids = array[3] of int;

	for(i = 0; i < 3; i++){
		if(s.buttonids[i] <= 0)
			s.buttonids[i] = view->allocid(u.tree);
	}
}

dispose(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);
	if(s.shadowid >= 0)
		view->removetree(u.tree, s.shadowid);

	s.shadowid = -1;
	resetwindowids();
}

disposewindow(u: ref IcUi->Ui)
{
	if(u == nil || u.tree == nil)
		return;

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);

	resetwindowids();
}

fillstr(n: int, ch: string): string
{
	v: string;
	i: int;

	v = "";
	for(i = 0; i < n; i++)
		v += ch;

	return v;
}

spaces(n: int): string
{
	return fillstr(n, " ");
}

fittext(v: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len v > w)
		return v[0:w];

	if(len v < w)
		return v + spaces(w - len v);

	return v;
}

topframe(w: int, title: string): string
{
	prefix: string;
	n: int;

	prefix = style.framenw + " " + title + " ";
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

	if(u == nil || u.tree == nil || id <= 0)
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

checkbox(checked: int, label: string): string
{
	if(checked)
		return "[x] " + label;

	return "[ ] " + label;
}

fieldtext(w: int): string
{
	v: string;

	clampinputpos();

	if(s.focus != IcViewCommon->SearchFocusInput)
		return fittext(s.input, w);

	v = s.input[0:s.inputpos] + "|" + s.input[s.inputpos:];
	return fittext(v, w);
}

buttontext(kind: int): string
{
	case kind {
	0 =>
		return "[< Forward >]";
	1 =>
		return "[ Backward ]";
	}

	return "[ Cancel ]";
}

optioncode(focus: int): string
{
	if(s.focus == focus)
		return style.focuscode;

	return style.textcode;
}

buttoncode(focus: int): string
{
	if(s.focus == focus)
		return style.buttonfocuscode;

	return style.buttoncode;
}

togglefocus(): int
{
	case s.focus {
	IcViewCommon->SearchFocusCase =>
		s.case_sensitive = !s.case_sensitive;
		return 1;

	IcViewCommon->SearchFocusBackward =>
		s.backward = !s.backward;
		return 1;

	IcViewCommon->SearchFocusWrap =>
		s.wrap = !s.wrap;
		return 1;

	IcViewCommon->SearchFocusRegex =>
		s.regex = !s.regex;
		return 1;

	IcViewCommon->SearchFocusAnyEncoding =>
		s.anyencoding = !s.anyencoding;
		return 1;
	}

	return 0;
}

clampinputpos()
{
	if(s.inputpos < 0)
		s.inputpos = 0;

	if(s.inputpos > len s.input)
		s.inputpos = len s.input;
}

insertchar(k: int)
{
	c: string;

	clampinputpos();
	c = sys->sprint("%c", k);

	s.input = s.input[0:s.inputpos] + c + s.input[s.inputpos:];
	s.inputpos++;
}

backspacechar()
{
	clampinputpos();

	if(s.inputpos <= 0)
		return;

	s.input = s.input[0:s.inputpos - 1] + s.input[s.inputpos:];
	s.inputpos--;
}

deletechar()
{
	clampinputpos();

	if(s.inputpos >= len s.input)
		return;

	s.input = s.input[0:s.inputpos] + s.input[s.inputpos + 1:];
}

printable(k: int): int
{
	if(k < 32)
		return 0;

	if(k >= 57344)
		return 0;

	return 1;
}

drawshadow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	n: ref IcView->Node;

	if(s.shadowid <= 0)
		s.shadowid = view->allocid(u.tree);

	ui->node(u, parentid, s.shadowid, "shadow", x + 1, y + 1, w, h);
	n = view->find(u.tree, s.shadowid);
	if(n != nil)
		view->setcode(n, style.shadowcode);

	view->bringtofront(u.tree, s.shadowid);
	return 0;
}

drawwindow(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, bx, row, bgid: int;

	ensureids(u);

	ui->node(u, parentid, s.windowid, "group", x, y, w, h);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w, topframe(w, "Search"), style.framecode);
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}
	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	if(s.focus == IcViewCommon->SearchFocusInput)
		setlabel(u, s.windowid, s.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldfocuscode);
	else
		setlabel(u, s.windowid, s.inputid, 4, 2, bodyw, fieldtext(bodyw), style.fieldcode);

	setlabel(u, s.windowid, s.optionids[0], 4, 4, bodyw,
		checkbox(s.case_sensitive, "Case sensitive"),
		optioncode(IcViewCommon->SearchFocusCase));

	setlabel(u, s.windowid, s.optionids[1], 4, 5, bodyw,
		checkbox(s.backward, "Backward"),
		optioncode(IcViewCommon->SearchFocusBackward));

	setlabel(u, s.windowid, s.optionids[2], 4, 6, bodyw,
		checkbox(s.wrap, "Wrap search"),
		optioncode(IcViewCommon->SearchFocusWrap));

	setlabel(u, s.windowid, s.optionids[3], 4, 7, bodyw,
		checkbox(s.regex, "Regex"),
		optioncode(IcViewCommon->SearchFocusRegex));

	setlabel(u, s.windowid, s.optionids[4], 4, 8, bodyw,
		checkbox(s.anyencoding, "Any encoding"),
		optioncode(IcViewCommon->SearchFocusAnyEncoding));

	setlabel(u, s.windowid, view->allocid(u.tree), 4, 9, bodyw,
		"Encoding: " + s.encoding,
		style.disabledcode);

	bx = (w - 38) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, s.windowid, s.buttonids[0], bx, 11, 13,
		buttontext(0),
		buttoncode(IcViewCommon->SearchFocusForward));

	setlabel(u, s.windowid, s.buttonids[1], bx + 15, 11, 12,
		buttontext(1),
		buttoncode(IcViewCommon->SearchFocusBackwardButton));

	setlabel(u, s.windowid, s.buttonids[2], bx + 29, 11, 10,
		buttontext(2),
		buttoncode(IcViewCommon->SearchFocusCancel));

	view->bringtofront(u.tree, s.windowid);
	return 0;
}

drawalert(u: ref IcUi->Ui, parentid, x, y, w, h: int): int
{
	bodyw, bx, row, bgid: int;

	ensureids(u);

	ui->node(u, parentid, s.windowid, "group", x, y, w, h);

	setlabel(u, s.windowid, view->allocid(u.tree), 0, 0, w, topframe(w, "Search"), style.framecode);
	for(row = 1; row < h - 1; row++){
		bgid = view->allocid(u.tree);
		setlabel(u, s.windowid, bgid, 0, row, w, midframe(w), style.framecode);
	}
	setlabel(u, s.windowid, view->allocid(u.tree), 0, h - 1, w, bottomframe(w), style.framecode);

	bodyw = w - 8;
	if(bodyw < 1)
		bodyw = 1;

	setlabel(u, s.windowid, view->allocid(u.tree), 4, 2, bodyw, s.alerttext, style.textcode);

	bx = (w - 6) / 2;
	if(bx < 2)
		bx = 2;

	setlabel(u, s.windowid, s.buttonids[0], bx, 4, 6, "[ OK ]", style.buttonfocuscode);

	view->bringtofront(u.tree, s.windowid);
	return 0;
}

draw(u: ref IcUi->Ui, parentid, w, h: int): int
{
	iw, wh, x, y: int;

	if(u == nil || u.tree == nil || !s.active)
		return -1;

	if(s.alert){
		iw = 44;
		wh = 7;
	}else{
		iw = 60;
		wh = 14;
	}

	if(iw > w - 4)
		iw = w - 4;
	if(iw < 38)
		iw = 38;

	if(wh > h - 2)
		wh = h - 2;
	if(wh < 7)
		wh = 7;

	x = (w - iw) / 2;
	y = (h - wh) / 2;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	s.x = x;
	s.y = y;
	s.w = iw;
	s.h = wh;

	if(animstage == StageShadow || animstage == StageClosingShadow)
		return drawshadow(u, parentid, x, y, iw, wh);

	if(s.windowid >= 0)
		view->removetree(u.tree, s.windowid);
	resetwindowids();

	drawshadow(u, parentid, x, y, iw, wh);

	if(s.alert)
		return drawalert(u, parentid, x, y, iw, wh);

	return drawwindow(u, parentid, x, y, iw, wh);
}

handletick(u: ref IcUi->Ui, parentid, w, h: int): int
{
	if(!s.active)
		return 0;

	if(animstage == StageShadow){
		animstage = StageWindow;
		draw(u, parentid, w, h);
		return 1;
	}

	if(animstage == StageClosingShadow){
		dispose(u);
		s.active = 0;
		s.result = IcViewCommon->SearchNone;
		animstage = StageNone;
		return 1;
	}

	return 0;
}

focusnext()
{
	s.focus++;
	if(s.focus > IcViewCommon->SearchFocusCancel)
		s.focus = IcViewCommon->SearchFocusInput;
}

focusprev()
{
	s.focus--;
	if(s.focus < IcViewCommon->SearchFocusInput)
		s.focus = IcViewCommon->SearchFocusCancel;
}

handlekey(u: ref IcUi->Ui, parentid, w, h, k: int): int
{
	if(!s.active)
		return IcViewCommon->SearchNone;

	if(animstage != StageWindow)
		return IcViewCommon->SearchNone;

	if(s.alert){
		if(k == EscapeKey || k == EnterKey || k == ReturnKey || k == SpaceKey){
			s.result = IcViewCommon->SearchAlertClosed;
			return s.result;
		}

		return IcViewCommon->SearchNone;
	}

	if(k == EscapeKey){
		s.result = IcViewCommon->SearchCancel;
		return s.result;
	}

	if(k == TabKey || k == DownKey){
		focusnext();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == UpKey){
		focusprev();
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == LeftKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputpos--;
			clampinputpos();
		}else
			focusprev();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == RightKey){
		if(s.focus == IcViewCommon->SearchFocusInput){
			s.inputpos++;
			clampinputpos();
		}else
			focusnext();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == BackspaceKey){
		if(s.focus == IcViewCommon->SearchFocusInput)
			backspacechar();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == DeleteKey){
		if(s.focus == IcViewCommon->SearchFocusInput)
			deletechar();

		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(s.focus == IcViewCommon->SearchFocusInput && printable(k)){
		insertchar(k);
		draw(u, parentid, w, h);
		return IcViewCommon->SearchNone;
	}

	if(k == SpaceKey){
		if(togglefocus()){
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}

		if(s.focus == IcViewCommon->SearchFocusForward){
			s.result = IcViewCommon->SearchForward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusBackwardButton){
			s.result = IcViewCommon->SearchBackward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusCancel){
			s.result = IcViewCommon->SearchCancel;
			return s.result;
		}
	}

	if(k == EnterKey || k == ReturnKey){
		if(s.focus == IcViewCommon->SearchFocusInput || s.focus == IcViewCommon->SearchFocusForward){
			s.result = IcViewCommon->SearchForward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusBackwardButton){
			s.result = IcViewCommon->SearchBackward;
			return s.result;
		}

		if(s.focus == IcViewCommon->SearchFocusCancel){
			s.result = IcViewCommon->SearchCancel;
			return s.result;
		}

		if(togglefocus()){
			draw(u, parentid, w, h);
			return IcViewCommon->SearchNone;
		}
	}

	return IcViewCommon->SearchNone;
}