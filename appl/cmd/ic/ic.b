implement Command;

include "draw.m";
include "ic/app.m";

Command: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	app: IcApp;
	state: ref IcState->AppState;

	ctxt = ctxt;
	argv = argv;

	app = load IcApp IcApp->PATH;
	if(app == nil)
		raise "fail:load ic/app";

	app->init();

	state = app->newstate();
	if(state == nil)
		raise "fail:ic/state";

	app->run(state);
}