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

		themefile: string;
		keysfile: string;
		layoutfile: string;
		menusfile: string;

		userthemefile: string;
		userkeysfile: string;
		userlayoutfile: string;
		usermenusfile: string;
	};

	ThemeState: adt
	{
		frame: int;
		panelshadow: int;

		modalanimticks: int;

		modalcopycode: string;
		modaloverwritecode: string;
		modalframecode: string;
		modaltextcode: string;
		modalshadowcode: string;

		modalfieldcode: string;
		modalfocuscode: string;
		modalbuttoncode: string;
		modalbuttonfocuscode: string;

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
	};

	EditorState: adt
	{
		active: int;

		path: string;
		dir: string;

		lines: array of string;

		topline: int;
		cursorline: int;
		cursorcol: int;

		topid: int;
		bodyid: int;
		bottomid: int;

		dirty: int;
		message: string;

		mode: int;
		filenameinput: string;
	};

	PanelState: adt
	{
		id: int;

		side: int;
		active: int;

		path: string;
		dir: ref PanelDir;

		lastchildname: string;

		selected: array of SelectedItem;

		panel: ref IcPanel->Panel;
		model: ref IcPanel->Model;
	};

	TopBarState: adt
	{
		id: int;
	};

	BottomBarState: adt
	{
		id: int;
		commandlineid: int;
		buttons: array of BottomButtonState;
		activefkey: int;
		activewait: int;
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
		copy: ref CopyState;
		delete: ref DeleteState;
		mkdir: ref MkdirState;
	};
};