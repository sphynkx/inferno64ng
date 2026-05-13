include "icurses/ui.m";

IcPanel: module
{
	PATH: con "/dis/lib/icurses/panel.dis";

	#
	# View modes.
	#
	ModeBrief2Col:   con 0;
	ModeWide1Col:    con 1;
	ModeTree:        con 2;
	ModeCustomFields: con 3;

	#
	# Cursor styles.
	#
	CursorArrow:      con 0;
	CursorBackground: con 1;
	CursorInverse:    con 2;
	CursorFrame:      con 3;
	CursorUnderline:  con 4;

	#
	# Sort directions.
	#
	SortAsc:  con 0;
	SortDesc: con 1;

	#
	# Item flags.
	# Keep this generic. Applications may use bits for selection/marking
	# or any other item state.
	#
	FlagMarked: con 1;
	FlagHidden: con 2;

	#
	# Rendered line metadata.
	#
	Line: adt
	{
		itemid:   int;
		depth:    int;
		isparent: int;
		text:     string;
		aux:      string;
		flags:    int;
	};

	#
	# One model item. The panel does not hardcode item kinds.
	# "kind" is an opaque application-defined string.
	#
	Item: adt
	{
		id:       int;
		parentid: int;

		name:     string;
		kind:     string;

		flags:    int;

		sarg:     string;
		iarg0:    int;
		iarg1:    int;
		iarg2:    int;

		fields:   array of string;
		sortby:   array of string;

		hotkey:   string;
		command:  string;
		targetid: int;
	};

	#
	# Input model for the panel.
	#
	Model: adt
	{
		rootid: int;
		items:  array of Item;
	};

	#
	# Display/sort/navigation options.
	#
	Options: adt
	{
		mode:             int;
		cursorstyle:      int;

		showframe:        int;
		framestyle:       int;

		showcommandbar:   int;
		commandbarrows:   int;

		showinfobar:      int;
		infobarrows:      int;

		showparentitem:   int;
		hideparentatroot: int;

		directoriesfirst: int;
		showhidden:       int;

		sortfield:        string;
		sortdirection:    int;
		sortsecondary:    string;

		columncount:      int;
		customfields:     array of string;

		mouseenabled:     int;
		wrapnav:          int;
		vimnav:           int;

		rowstep:          int;
		colstep:          int;
		pagestep:         int;
	};

	#
	# Panel runtime state.
	#
	Panel: adt
	{
		id:             int;
		titleid:        int;
		bodyid:         int;
		commandbarid:   int;
		infobarid:      int;

		rowids:         array of int;

		x:              int;
		y:              int;
		w:              int;
		h:              int;

		title:          string;
		status:         string;
		commandbar:     string;
		info:           string;

		model:          ref Model;
		opts:           Options;

		rootid:         int;
		currentid:      int;
		top:            int;

		lines:          array of Line;
	};

	init: fn();

	defaultopts: fn(): Options;

	new: fn(id: int, title: string, opts: Options): ref Panel;

	setbounds: fn(p: ref Panel, x, y, w, h: int): int;
	settitle: fn(p: ref Panel, title: string): int;
	setstatus: fn(p: ref Panel, status: string): int;
	setcommandbar: fn(p: ref Panel, text: string): int;
	setinfo: fn(p: ref Panel, text: string): int;

	setmodel: fn(p: ref Panel, model: ref Model): int;
	setopts: fn(p: ref Panel, opts: Options): int;
	setroot: fn(p: ref Panel, rootid: int): int;

	currentid: fn(p: ref Panel): int;
	currentname: fn(p: ref Panel): string;
	currentkind: fn(p: ref Panel): string;

	build: fn(u: ref IcUi->Ui, parentid: int, p: ref Panel): int;
	render: fn(u: ref IcUi->Ui, p: ref Panel): int;

	selectid: fn(u: ref IcUi->Ui, p: ref Panel, itemid: int): IcMsg->Msg;

	up: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	down: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	left: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	right: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	pageup: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	pagedown: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	home: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	end: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;
	activate: fn(u: ref IcUi->Ui, p: ref Panel): IcMsg->Msg;

	handlekey: fn(u: ref IcUi->Ui, p: ref Panel, k: int): IcMsg->Msg;
	handlemouse: fn(u: ref IcUi->Ui, p: ref Panel, mouse: string): IcMsg->Msg;
};