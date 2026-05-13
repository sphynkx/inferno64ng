implement IcApp;

include "ic/app.m";

IcRuntime: module
{
	PATH: con "/dis/ic/runtime.dis";

	init: fn();
	enter: fn(out: ref Sys->FD): int;
	leave: fn(out: ref Sys->FD);
	size: fn(): (int, int);
	pollresize: fn(oldw, oldh: int): (int, int, int);
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

sys: Sys;
runtime: IcRuntime;
screen: IcScreen;
input: IcInputData;
cfgdata: IcConfigData;
themedata: IcThemeData;
appanel: IcAppPanel;
topbar: IcTopBar;
bottombar: IcBottomBar;
ui: IcUi;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	runtime = load IcRuntime IcRuntime->PATH;
	if(runtime == nil)
		raise "fail:load ic/runtime";

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

	ui = load IcUi IcUi->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	runtime->init();
	screen->init();
	input->init();
	cfgdata->init();
	themedata->init();
	appanel->init();
	topbar->init();
	bottombar->init();
	ui->init();
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

	s.left = appanel->newpanel(IcState->SideLeft);
	s.right = appanel->newpanel(IcState->SideRight);
	s.topbar = topbar->newbar();
	s.bottombar = bottombar->newbar();

	return s;
}

run(state: ref IcState->AppState): int
{
	step: IcUi->Step;
	nw, nh, resized: int;

	if(state == nil)
		return -1;

	state.out = sys->fildes(1);
	if(state.out == nil)
		return -1;

	(state.width, state.height) = runtime->size();

	if(runtime->enter(state.out) < 0)
		return -1;

	state.ui = ui->new(state.out, state.width, state.height);
	if(state.ui == nil){
		runtime->leave(state.out);
		return -1;
	}

	ui->enablemouse(state.ui, 0);

	if(screen->build(state) < 0){
		ui->close(state.ui);
		runtime->leave(state.out);
		return -1;
	}

	screen->redraw(state);

	if(ui->start(state.ui) < 0){
		ui->close(state.ui);
		runtime->leave(state.out);
		return -1;
	}

	while(state.running){
		step = ui->step(state.ui);

		if(step.done)
			break;

		if(step.kind == IcUi->StepKey){
			if(input->handlekey(state, step.key) < 0)
				break;

			screen->redraw(state);
		}

		if(step.kind == IcUi->StepTick){
			(nw, nh, resized) = runtime->pollresize(state.width, state.height);
			if(resized){
				state.width = nw;
				state.height = nh;
				screen->rebuild(state);
				screen->redraw(state);
			}
		}
	}

	ui->stop(state.ui);
	ui->close(state.ui);
	runtime->leave(state.out);

	return 0;
}