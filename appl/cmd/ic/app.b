implement IcApp;

include "ic/app.m";

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

IcScreen: module
{
	PATH: con "/dis/ic/screen.dis";

	init: fn();
	build: fn(state: ref IcState->AppState): int;
	rebuild: fn(state: ref IcState->AppState): int;
	redraw: fn(state: ref IcState->AppState): int;
};

IcInputData: module
{
	PATH: con "/dis/ic/input.dis";

	init: fn();
	handlekey: fn(state: ref IcState->AppState, k: int): int;
	handletick: fn(state: ref IcState->AppState): int;
};

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();
	loadstate: fn(): ref IcState->ConfigState;
};

IcThemeData: module
{
	PATH: con "/dis/ic/theme.dis";

	init: fn();
	loadstate: fn(cfg: ref IcState->ConfigState): ref IcState->ThemeState;
};

IcAppPanel: module
{
	PATH: con "/dis/ic/appanel.dis";

	init: fn();
	reloadtheme: fn(): int;
	newpanel: fn(side: int): ref IcState->PanelState;
};

IcTopBar: module
{
	PATH: con "/dis/ic/topbar.dis";

	init: fn();
	newbar: fn(): ref IcState->TopBarState;
};

IcBottomBar: module
{
	PATH: con "/dis/ic/bottombar.dis";

	init: fn();
	newbar: fn(): ref IcState->BottomBarState;
};

IcUserState: module
{
	PATH: con "/dis/ic/userstate.dis";

	init: fn();

	loadstate: fn(state: ref IcState->AppState): int;
	restore: fn(state: ref IcState->AppState): int;
	save: fn(state: ref IcState->AppState): int;
};

sys: Sys;
appfw: IcursesApp;
screen: IcScreen;
input: IcInputData;
cfgdata: IcConfigData;
themedata: IcThemeData;
appanel: IcAppPanel;
topbar: IcTopBar;
bottombar: IcBottomBar;
userstate: IcUserState;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	appfw = load IcursesApp IcursesApp->PATH;
	if(appfw == nil)
		raise "fail:load icurses/app";

	screen = load IcScreen IcScreen->PATH;
	if(screen == nil)
		raise "fail:load ic/screen";

	input = load IcInputData IcInputData->PATH;
	if(input == nil)
		raise "fail:load ic/input";

	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	themedata = load IcThemeData IcThemeData->PATH;
	if(themedata == nil)
		raise "fail:load ic/theme";

	appanel = load IcAppPanel IcAppPanel->PATH;
	if(appanel == nil)
		raise "fail:load ic/appanel";

	topbar = load IcTopBar IcTopBar->PATH;
	if(topbar == nil)
		raise "fail:load ic/topbar";

	bottombar = load IcBottomBar IcBottomBar->PATH;
	if(bottombar == nil)
		raise "fail:load ic/bottombar";

	userstate = load IcUserState IcUserState->PATH;
	if(userstate == nil)
		raise "fail:load ic/userstate";

	appfw->init("ic");
	screen->init();
	input->init();
	cfgdata->init();
	themedata->init();
	appanel->init();
	topbar->init();
	bottombar->init();
	userstate->init();
}

newstate(): ref IcState->AppState
{
	s: ref IcState->AppState;

	s = ref IcState->AppState;
	s.running = 1;
	s.width = 80;
	s.height = 24;
	s.activepanel = IcState->PanelLeft;
	s.panelshidden = 0;

	s.cfg = cfgdata->loadstate();
	s.theme = themedata->loadstate(s.cfg);
	appanel->reloadtheme();

	s.left = appanel->newpanel(IcState->SideLeft);
	s.right = appanel->newpanel(IcState->SideRight);
	s.topbar = topbar->newbar();
	s.bottombar = bottombar->newbar();

	userstate->loadstate(s);

	return s;
}

runnew(): int
{
	state: ref IcState->AppState;

	state = newstate();
	if(state == nil)
		return -1;

	return run(state);
}

run(state: ref IcState->AppState): int
{
	ctx: ref IcursesApp->Context;
	opts: IcursesApp->Options;
	step: IcUi->Step;
	nw, nh, resized: int;

	if(state == nil)
		return -1;

	state.out = sys->fildes(1);
	if(state.out == nil)
		return -1;

	opts = appfw->defaultopts();
	opts.screenmode = IcursesApp->ScreenAlternate;
	opts.mouse = 0;
	opts.tickms = 100;

	ctx = appfw->newctx(state.out, opts);
	if(ctx == nil)
		return -1;

	if(appfw->open(ctx) < 0)
		return -1;

	state.ui = appfw->ui(ctx);
	if(state.ui == nil){
		appfw->close(ctx);
		return -1;
	}

	state.width = appfw->width(ctx);
	state.height = appfw->height(ctx);

	if(screen->build(state) < 0){
		appfw->close(ctx);
		return -1;
	}

	userstate->restore(state);
	screen->redraw(state);

	while(state.running){
		step = appfw->step(ctx);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			if(input->handlekey(state, step.key) < 0)
				break;

			screen->redraw(state);
		}

		if(step.kind == IcUi->StepTick){
			if(input->handletick(state))
				screen->redraw(state);

			(nw, nh, resized) = appfw->pollresize(ctx, state.width, state.height);
			if(resized){
				state.width = nw;
				state.height = nh;
				screen->rebuild(state);
				userstate->restore(state);
				screen->redraw(state);
			}
		}
	}

	userstate->save(state);
	appfw->close(ctx);

	return 0;
}