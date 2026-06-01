implement IcEditor;

include "ic/editor.m";
include "ic/viewcommon.m";

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
};

IcEditSource: module
{
	PATH: con "/dis/ic/editsource.dis";

	init: fn();
	newstate: fn(path, dir: string): ref IcState->EditorState;
	close: fn(e: ref IcState->EditorState);
};

IcEditCommon: module
{
	PATH: con "/dis/ic/editcommon.dis";

	ModeFilename: con 2;

	init: fn();
	dirname: fn(path: string): string;
};

IcEditDraw: module
{
	PATH: con "/dis/ic/editdraw.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);
	draw: fn(u: ref IcUi->Ui, parentid: int, e: ref IcState->EditorState, w, h: int);
	hide: fn(u: ref IcUi->Ui, e: ref IcState->EditorState);
	handletick: fn(e: ref IcState->EditorState): int;
};

IcEditKeys: module
{
	PATH: con "/dis/ic/editkeys.dis";

	init: fn();
	settheme: fn(theme: ref IcState->ThemeState);
	handlekey: fn(state: ref IcState->AppState, e: ref IcState->EditorState, k, h: int): int;
	handletick: fn(state: ref IcState->AppState, e: ref IcState->EditorState): int;
};

IcSearchDialogMod: module
{
	PATH: con "/dis/ic/searchdialog.dis";

	Style: adt
	{
		windowcode: string;
		framecode: string;
		textcode: string;
		fieldcode: string;
		fieldfocuscode: string;
		focuscode: string;
		cursorcode: string;
		buttoncode: string;
		buttonfocuscode: string;
		disabledcode: string;
		shadowcode: string;

		animticks: int;

		frameh: string;
		framev: string;
		framenw: string;
		framene: string;
		framesw: string;
		framese: string;
	};

	init: fn();
	setstyle: fn(style: Style);

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

IcRuntimeTheme: module
{
	PATH: con "/dis/ic/runtheme.dis";

	init: fn();
	loadtheme: fn(): ref IcState->ThemeState;
};

sys: Sys;
appfw: IcursesApp;
ui: IcUiMod;
common: IcEditCommon;
source: IcEditSource;
drawmod: IcEditDraw;
keys: IcEditKeys;
searchdialog: IcSearchDialogMod;
runtheme: IcRuntimeTheme;

theme: ref IcState->ThemeState;

applytheme: fn(t: ref IcState->ThemeState);
searchstyle: fn(t: ref IcState->ThemeState): IcSearchDialogMod->Style;

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

	common = load IcEditCommon IcEditCommon->PATH;
	if(common == nil)
		raise "fail:load ic/editcommon";

	source = load IcEditSource IcEditSource->PATH;
	if(source == nil)
		raise "fail:load ic/editsource";

	drawmod = load IcEditDraw IcEditDraw->PATH;
	if(drawmod == nil)
		raise "fail:load ic/editdraw";

	keys = load IcEditKeys IcEditKeys->PATH;
	if(keys == nil)
		raise "fail:load ic/editkeys";

	searchdialog = load IcSearchDialogMod IcSearchDialogMod->PATH;
	if(searchdialog == nil)
		raise "fail:load ic/searchdialog";

	runtheme = load IcRuntimeTheme IcRuntimeTheme->PATH;
	if(runtheme == nil)
		raise "fail:load ic/runtheme";

	appfw->init("icedit");
	ui->init();
	common->init();
	source->init();
	drawmod->init();
	keys->init();
	searchdialog->init();
	runtheme->init();

	theme = runtheme->loadtheme();
	drawmod->settheme(theme);
	applytheme(theme);
}

applytheme(t: ref IcState->ThemeState)
{
	if(t != nil)
		theme = t;

	drawmod->settheme(theme);

	if(searchdialog != nil)
		searchdialog->setstyle(searchstyle(theme));

	if(keys != nil)
		keys->settheme(theme);
}

searchstyle(t: ref IcState->ThemeState): IcSearchDialogMod->Style
{
	s: IcSearchDialogMod->Style;

	s.windowcode = "";
	s.framecode = "";
	s.textcode = "";
	s.fieldcode = "";
	s.fieldfocuscode = "";
	s.focuscode = "";
	s.cursorcode = "";
	s.buttoncode = "";
	s.buttonfocuscode = "";
	s.disabledcode = "";
	s.shadowcode = "";

	s.animticks = -1;

	s.frameh = "─";
	s.framev = "│";
	s.framenw = "┌";
	s.framene = "┐";
	s.framesw = "└";
	s.framese = "┘";

	if(t == nil)
		return s;

	s.windowcode = t.dialogwindowcode;
	s.framecode = t.dialogframecode;
	s.textcode = t.dialogtextcode;
	s.fieldcode = t.dialogfieldcode;
	s.fieldfocuscode = t.dialogfieldfocuscode;
	s.focuscode = t.dialogfocuscode;
	s.cursorcode = t.dialogcursorcode;
	s.buttoncode = t.dialogbuttoncode;
	s.buttonfocuscode = t.dialogbuttonfocuscode;
	s.disabledcode = t.dialogdisabledcode;
	s.shadowcode = t.dialogshadowcode;

	s.animticks = t.dialoganimticks;

	s.frameh = t.dialogframeh;
	s.framev = t.dialogframev;
	s.framenw = t.dialogframenw;
	s.framene = t.dialogframene;
	s.framesw = t.dialogframesw;
	s.framese = t.dialogframese;

	return s;
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

	theme = runtheme->loadtheme();
	applytheme(theme);

	e = source->newstate(path, common->dirname(path));
	if(e == nil)
		return -1;

	opts = appfw->defaultopts();
	opts.screenmode = IcursesApp->ScreenAlternate;
	opts.mouse = 0;
	opts.tickms = 100;

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

	applytheme(theme);
	drawmod->draw(u, rootid, e, w, h);
	if(searchdialog->active())
		searchdialog->draw(u, rootid, w, h);
	appfw->draw(ctx);

	running = 1;
	while(running){
		step = appfw->step(ctx);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			r = keys->handlekey(nil, e, step.key, h);
			if(r == 2)
				running = 0;
			else if(r != 0){
				applytheme(theme);
				drawmod->draw(u, rootid, e, w, h);
				if(searchdialog->active())
					searchdialog->draw(u, rootid, w, h);
				appfw->draw(ctx);
			}
		}

		if(step.kind == IcUi->StepTick){
			r = 0;

			if(drawmod->handletick(e))
				r = 1;

			if(searchdialog->active()){
				if(searchdialog->handletick(u, rootid, w, h))
					r = 1;
			}

			if(r){
				applytheme(theme);
				drawmod->draw(u, rootid, e, w, h);
				if(searchdialog->active())
					searchdialog->draw(u, rootid, w, h);
				appfw->draw(ctx);
			}

			(nw, nh, resized) = appfw->pollresize(ctx, w, h);
			if(resized){
				w = nw;
				h = nh;
				applytheme(theme);
				drawmod->draw(u, rootid, e, w, h);
				if(searchdialog->active())
					searchdialog->draw(u, rootid, w, h);
				appfw->draw(ctx);
			}
		}
	}

	source->close(e);
	appfw->close(ctx);
	return 0;
}

start(state: ref IcState->AppState, path: string): int
{
	if(state == nil || path == "")
		return -1;

	if(state.theme != nil)
		applytheme(state.theme);

	state.editor = source->newstate(path, common->dirname(path));
	if(state.editor == nil)
		return -1;

	return 0;
}

startnew(state: ref IcState->AppState, dir: string): int
{
	if(state == nil)
		return -1;

	if(state.theme != nil)
		applytheme(state.theme);

	state.editor = source->newstate("", dir);
	if(state.editor == nil)
		return -1;

	state.editor.mode = IcEditCommon->ModeFilename;
	return 0;
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.editor != nil && state.editor.active;
}

build(state: ref IcState->AppState, parentid, w, h: int): int
{
	if(state == nil || state.ui == nil || state.editor == nil || !state.editor.active)
		return -1;

	if(state.theme != nil)
		applytheme(state.theme);

	drawmod->draw(state.ui, parentid, state.editor, w, h);

	if(searchdialog->active())
		searchdialog->draw(state.ui, parentid, w, h);

	return 0;
}

handlekey(state: ref IcState->AppState, k: int): int
{
	r: int;

	if(state == nil || state.editor == nil)
		return 0;

	if(state.theme != nil)
		applytheme(state.theme);

	r = keys->handlekey(state, state.editor, k, state.height);

	if(!state.editor.active && state.ui != nil)
		drawmod->hide(state.ui, state.editor);

	return r;
}

handletick(state: ref IcState->AppState): int
{
	r: int;

	if(state == nil || state.editor == nil)
		return 0;

	if(state.theme != nil)
		applytheme(state.theme);

	r = 0;

	if(drawmod->handletick(state.editor))
		r = 1;

	if(keys != nil && keys->handletick(state, state.editor))
		r = 1;

	if(searchdialog->active()){
		if(searchdialog->handletick(state.ui, state.toolid, state.width, state.height))
			r = 1;
	}

	return r;
}