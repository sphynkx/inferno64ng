implement Command;

include "sys.m";
include "draw.m";
include "ic/viewer.m";

Command: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys: Sys;
	viewer: IcViewer;
	path: string;
	mode: int;

	ctxt = ctxt;

	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	viewer = load IcViewer IcViewer->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	viewer->init();

	mode = IcViewer->ModeText;

	argv = tl argv;
	if(argv == nil){
		sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	if(hd argv == "-x"){
		mode = IcViewer->ModeHex;
		argv = tl argv;
	}

	if(argv == nil){
		sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	path = hd argv;
	if(path == ""){
		sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	if(viewer->runfilemode(path, mode) < 0)
		sys->fprint(sys->fildes(2), "icview: cannot open %s\n", path);
}