include "icurses/panel.m";
include "icurses/config.m";

IcState: module
{
	PanelLeft: con 1;
	PanelRight: con 2;

	SideLeft: con 1;
	SideRight: con 2;

	ConfigState: adt
	{
		cfg: ref IcConfig->Config;

		home: string;
		userdir: string;
		userenabled: int;

		theme: string;

		themefile: string;
		keysfile: string;
		layoutfile: string;
		menusfile: string;
		statefile: string;

		userthemefile: string;
		userkeysfile: string;
		userlayoutfile: string;
		usermenusfile: string;

		screensavername: string;
		screensaverenabled: int;
		screensaveridleticks: int;
	};

	ThemeState: adt
	{
		frame: int;
		panelshadow: int;

		paneltopcode: string;
		panelbodycode: string;
		panelfocuscode: string;
		paneltitlecode: string;
		panelmarkedcode: string;
		panelmarkedfocuscode: string;

		menuwindowcode: string;
		menufocuscode: string;

		dialoganimticks: int;

		dialogwindowcode: string;
		dialogframecode: string;
		dialogtextcode: string;
		dialogfieldcode: string;
		dialogfieldfocuscode: string;
		dialogfocuscode: string;
		dialogcursorcode: string;
		dialogbuttoncode: string;
		dialogbuttonfocuscode: string;
		dialogdisabledcode: string;
		dialogshadowcode: string;

		dialogframeh: string;
		dialogframev: string;
		dialogframenw: string;
		dialogframene: string;
		dialogframesw: string;
		dialogframese: string;

		commandbarcode: string;
		commandbaractivecode: string;
		commandbardisabledcode: string;
		commandlinecode: string;
	};

	FsEntry: adt
	{
		name: string;
		isdir: int;
	};

	PanelDir: adt
	{
		path: string;
		items: array of FsEntry;
	};

	SelectedItem: adt
	{
		path: string;
		name: string;
		kind: string;
	};

	CopyTask: adt
	{
		src: string;
		rel: string;
		kind: string;
		mode: int;
	};

	DeleteTask: adt
	{
		path: string;
		kind: string;
	};

	CopyState: adt
	{
		active: int;
		phase: int;
		move: int;

		index: int;
		overwriteall: int;
		errors: int;

		target: string;
		singletarget: int;

		tasks: array of CopyTask;
	};

	DeleteState: adt
	{
		active: int;
		phase: int;

		index: int;
		errors: int;

		targetsummary: string;
		tasks: array of DeleteTask;
	};

	MkdirState: adt
	{
		active: int;
		phase: int;

		target: string;
		errors: int;
	};

	ModalState: adt
	{
		active: int;
		animating: int;
		animstage: int;
		animwait: int;

		kind: int;

		title: string;
		message: string;

		inputlabel: string;
		input: string;
		inputpos: int;
		inputhistorysection: string;
		inputhistoryopen: int;
		inputhistorysel: int;
		inputhistoryitems: array of string;
		inputhistoryids: array of int;

		checkbox: string;
		checked: int;

		focus: int;
		result: int;

		buttoncount: int;
		button0: string;
		button1: string;
		button2: string;

		hotkey0: string;
		hotkey1: string;
		hotkey2: string;

		x: int;
		y: int;
		w: int;
		h: int;

		shadowid: int;
		canvasid: int;
	};

	BottomButtonState: adt
	{
		id: int;
		labelid: int;
		fkey: int;
		text: string;
		cmd: int;
		enabled: int;
		active: int;
	};

	ViewerState: adt
	{
		active: int;
		mode: int;

		path: string;
		##source: ref Sys->FD;

		lines: array of string;
		wrapped: array of string;

		topline: int;
		nlines: int;

		topid: int;
		bottomid: int;
		bodyids: array of int;
		lastw: int;

		encoding: string;
		wrap: int;
	};

	EditorOp: adt
	{
		kind: int;
		line: int;
		count: int;
		addstart: int;
	};

	EditorState: adt
	{
		active: int;

		path: string;
		dir: string;

		fd: ref Sys->FD;
		length: big;

		offsets: array of big;
		noffsets: int;
		offsetcap: int;
		scanoff: big;
		eof: int;
		error: string;

		addlines: array of string;
		ops: array of EditorOp;

		lines: array of string;

		topline: int;
		nlines: int;
		cursorline: int;
		cursorcol: int;

		topid: int;
		bodyid: int;
		bottomid: int;

		buttonids: array of int;
		overlayids: array of int;
		selectionids: array of int;

		dirty: int;
		message: string;

		mode: int;
		filenameinput: string;

		searchinput: string;
		lastsearch: string;

		activefkey: int;
		activewait: int;

		selectionmode: int;
		selectionactive: int;
		selectionkind: int;
		selectionanchorline: int;
		selectionanchorcol: int;

		clipkind: int;
		cliplines: array of string;

		modalstage: int;
		modalwait: int;
	};

	PanelState: adt
	{
		id: int;

		side: int;
		active: int;

		path: string;
		dir: ref PanelDir;

		lastchildname: string;

		mountactive: int;
		mountkind: string;
		mountroot: string;
		mountorigin: string;
		mountsource: string;

		selected: array of SelectedItem;

		panel: ref IcPanel->Panel;
		model: ref IcPanel->Model;

		decorationids: array of int;
	};

	TopBarState: adt
	{
		id: int;
		backgroundid: int;
		active: int;
		focus: int;
		itemids: array of int;
	};

	BottomBarState: adt
	{
		id: int;
		commandlineid: int;
		buttons: array of BottomButtonState;
		activefkey: int;
		activewait: int;
	};

	ScreenCell: adt
	{
		ch: string;
		code: string;
	};

	ScreenBeam: adt
	{
		active: int;

		x: int;
		y: int;
		startx: int;
		starty: int;
		dx: int;
		dy: int;

		rx: int;
		ry: int;

		life: int;
		pathlife: int;

		curveaxis: int;
		curveamp: int;

		delay: int;
	};

	ScreenSaverState: adt
	{
		active: int;
		idleticks: int;

		canvasid: int;
		w: int;
		h: int;

		snapshot: array of ScreenCell;
		shadow: array of ScreenCell;

		beams: array of ScreenBeam;

		seed: int;

		x: int;
		y: int;
		dx: int;
		dy: int;

		rx: int;
		ry: int;

		life: int;

		pathkind: int;
		pathlife: int;
		curveamp: int;

		enabled: int;
		idlelimit: int;
		shadowpercent: int;

		beamcount: int;

		radiusmin: int;
		radiusmax: int;
		radiusypercentmin: int;
		radiusypercentmax: int;

		speedmin: int;
		speedmax: int;

		lifemin: int;
		lifemax: int;

		preferredanglemin: int;
		preferredanglemax: int;
		preferredanglepercent: int;

		curveminamppercent: int;
		curvemaxamppercent: int;

		shadowcode: string;
	};

	AppState: adt
	{
		running: int;

		width: int;
		height: int;

		out: ref Sys->FD;
		ui: ref IcUi->Ui;

		rootid: int;
		screensaverid: int;
		toolid: int;
		mainid: int;
		modalid: int;

		activepanel: int;
		panelshidden: int;

		cfg: ref ConfigState;
		theme: ref ThemeState;

		left: ref PanelState;
		right: ref PanelState;

		topbar: ref TopBarState;
		bottombar: ref BottomBarState;

		viewer: ref ViewerState;
		editor: ref EditorState;

		modal: ref ModalState;
		screensaver: ref ScreenSaverState;
		copy: ref CopyState;
		delete: ref DeleteState;
		mkdir: ref MkdirState;
	};
};