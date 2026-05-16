implement Command;

include "sys.m";
include "draw.m";

Command: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

IcAppRunner: module
{
	PATH: con "/dis/ic/app.dis";

	init: fn();
	runnew: fn(): int;
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	app: IcAppRunner;

	ctxt = ctxt;
	argv = argv;

	app = load IcAppRunner IcAppRunner->PATH;
	if(app == nil)
		raise "fail:load ic/app";

	app->init();

	if(app->runnew() < 0)
		raise "fail:ic/run";
}