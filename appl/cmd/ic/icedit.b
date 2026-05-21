implement Command;

include "sys.m";
include "draw.m";

Command: module
{
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

IcEditorRunner: module
{
	PATH: con "/dis/ic/editor.dis";

	init: fn();
	runfile: fn(path: string): int;
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	editor: IcEditorRunner;
	path: string;
	sys: Sys;

	ctxt = ctxt;

	sys = load Sys Sys->PATH;

	editor = load IcEditorRunner IcEditorRunner->PATH;
	if(editor == nil)
		raise "fail:load ic/editor";

	editor->init();

	argv = tl argv;
	if(argv == nil){
		if(sys != nil)
			sys->fprint(sys->fildes(2), "usage: icedit file\n");
		return;
	}

	path = hd argv;
	if(path == ""){
		if(sys != nil)
			sys->fprint(sys->fildes(2), "usage: icedit file\n");
		return;
	}

	if(editor->runfile(path) < 0){
		if(sys != nil)
			sys->fprint(sys->fildes(2), "icedit: cannot edit %s\n", path);
	}
}