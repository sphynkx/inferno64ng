implement Command;

include "sys.m";
include "draw.m";

Command: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

IcViewerRunner: module
{
	PATH: con "/dis/ic/viewer.dis";

	ModeText: con 0;
	ModeHex: con 1;

	init: fn();
	runfilemode: fn(path: string, mode: int): int;
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	viewer: IcViewerRunner;
	path: string;
	mode: int;

	ctxt = ctxt;

	viewer = load IcViewerRunner IcViewerRunner->PATH;
	if(viewer == nil)
		raise "fail:load ic/viewer";

	viewer->init();

	mode = IcViewerRunner->ModeText;

	argv = tl argv;
	if(argv == nil){
		sys := load Sys Sys->PATH;
		if(sys != nil)
			sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	if(hd argv == "-x"){
		mode = IcViewerRunner->ModeHex;
		argv = tl argv;
	}

	if(argv == nil){
		sys := load Sys Sys->PATH;
		if(sys != nil)
			sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	path = hd argv;
	if(path == ""){
		sys := load Sys Sys->PATH;
		if(sys != nil)
			sys->fprint(sys->fildes(2), "usage: icview [-x] file\n");
		return;
	}

	if(viewer->runfilemode(path, mode) < 0){
		sys := load Sys Sys->PATH;
		if(sys != nil)
			sys->fprint(sys->fildes(2), "icview: cannot open %s\n", path);
	}
}