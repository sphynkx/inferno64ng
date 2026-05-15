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
		dst: string;
		kind: string;
		mode: int;
	};

	CopyState: adt
	{
		active: int;
		phase: int;

		index: int;
		overwriteall: int;
		errors: int;

		tasks: array of CopyTask;
	};

	ModalState: adt
	{
		active: int;
		kind: int;

		title: string;
		message: string;
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

		windowid: int;
		messageid: int;
		checkboxid: int;
		buttonsid: int;
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

		modal: ref ModalState;
		copy: ref CopyState;
	};
};