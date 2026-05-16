implement IcBottomBar;

include "ic/bottombar.m";

IcCommands: module
{
	PATH: con "/dis/ic/commands.dis";

	CmdNone: con 0;
	CmdExit: con 1;
	CmdSwitchPanel: con 2;
	CmdTogglePanels: con 3;
	CmdToggleSelection: con 4;
	CmdCopy: con 5;
	CmdMove: con 6;
	CmdMkdir: con 7;
	CmdDelete: con 8;
};

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	group: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w, h: int): int;
	label: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text: string): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
	allocid: fn(t: ref IcView->Tree): int;
};

ui: IcUiMod;
view: IcViewMod;

FlashTicks: con 2;
ButtonCount: con 10;

CodeNormal: con "1;38;2;20;25;30;48;2;225;225;225";
CodeDisabled: con "38;2;120;120;120;48;2;205;205;205";
CodeActive: con "1;38;2;255;120;210;48;2;225;225;225";

ensurebuttons: fn(state: ref IcState->AppState, bar: ref IcState->BottomBarState);
buttonx: fn(rect: IcLayout->Rect, idx: int): int;
buttonw: fn(rect: IcLayout->Rect, idx: int): int;
buttontext: fn(fkey: int, text: string, w: int): string;
fittext: fn(s: string, w: int): string;
spaces: fn(n: int): string;
refreshcodes: fn(state: ref IcState->AppState, bar: ref IcState->BottomBarState);

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	ui->init();
	view->init();
}

spaces(n: int): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += " ";

	return s;
}

fittext(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s > w)
		return s[0:w];

	if(len s < w)
		return s + spaces(w - len s);

	return s;
}

buttontext(fkey: int, text: string, w: int): string
{
	return fittext(string fkey + " " + text, w);
}

buttonx(rect: IcLayout->Rect, idx: int): int
{
	return (rect.w * idx) / ButtonCount;
}

buttonw(rect: IcLayout->Rect, idx: int): int
{
	return ((rect.w * (idx + 1)) / ButtonCount) - buttonx(rect, idx);
}

newbar(): ref IcState->BottomBarState
{
	bar: ref IcState->BottomBarState;

	bar = ref IcState->BottomBarState;
	bar.id = -1;
	bar.buttons = array[0] of IcState->BottomButtonState;
	bar.activefkey = 0;
	bar.activewait = 0;

	return bar;
}

ensurebuttons(state: ref IcState->AppState, bar: ref IcState->BottomBarState)
{
	i: int;
	b: IcState->BottomButtonState;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil)
		return;

	if(bar.id <= 0)
		bar.id = view->allocid(state.ui.tree);

	if(ui->group(state.ui, state.mainid, bar.id, 0, 0, 1, 1) < 0)
		return;

	if(bar.buttons != nil && len bar.buttons == ButtonCount)
		return;

	bar.buttons = array[ButtonCount] of IcState->BottomButtonState;

	for(i = 0; i < ButtonCount; i++){
		b.id = view->allocid(state.ui.tree);
		b.labelid = view->allocid(state.ui.tree);
		b.fkey = i + 1;
		b.text = "";
		b.cmd = IcCommands->CmdNone;
		b.enabled = 0;
		b.active = 0;

		case i {
		0 =>
			b.text = "Help";
		1 =>
			b.text = "Menu";
		2 =>
			b.text = "View";
		3 =>
			b.text = "Edit";
		4 =>
			b.text = "Copy";
			b.cmd = IcCommands->CmdCopy;
			b.enabled = 1;
		5 =>
			b.text = "Move";
			b.cmd = IcCommands->CmdMove;
			b.enabled = 1;
		6 =>
			b.text = "MkDir";
			b.cmd = IcCommands->CmdMkdir;
			b.enabled = 1;
		7 =>
			b.text = "Delete";
			b.cmd = IcCommands->CmdDelete;
			b.enabled = 1;
		8 =>
			b.text = "Menu";
		9 =>
			b.text = "Exit";
			b.cmd = IcCommands->CmdExit;
			b.enabled = 1;
		}

		bar.buttons[i] = b;

		ui->group(state.ui, bar.id, bar.buttons[i].id, 0, 0, 1, 1);
		ui->label(state.ui, bar.buttons[i].id, bar.buttons[i].labelid, 0, 0, 1, "");
	}
}

refreshcodes(state: ref IcState->AppState, bar: ref IcState->BottomBarState)
{
	i: int;
	n: ref IcView->Node;
	code: string;

	if(state == nil || state.ui == nil || state.ui.tree == nil || bar == nil || bar.buttons == nil)
		return;

	for(i = 0; i < len bar.buttons; i++){
		bar.buttons[i].active = bar.buttons[i].fkey == bar.activefkey;

		n = view->find(state.ui.tree, bar.buttons[i].labelid);
		if(n == nil)
			continue;

		if(bar.buttons[i].active)
			code = CodeActive;
		else if(bar.buttons[i].enabled)
			code = CodeNormal;
		else
			code = CodeDisabled;

		view->setcode(n, code);
	}
}

build(state: ref IcState->AppState, bar: ref IcState->BottomBarState, rect: IcLayout->Rect): int
{
	i, x, w: int;
	g, l: ref IcView->Node;

	if(state == nil || state.ui == nil || bar == nil)
		return -1;

	ensurebuttons(state, bar);

	g = view->find(state.ui.tree, bar.id);
	if(g != nil){
		view->setbounds(g, rect.x, rect.y, rect.w, 1);
		view->show(g);
	}

	for(i = 0; i < len bar.buttons; i++){
		x = buttonx(rect, i);
		w = buttonw(rect, i);
		if(w < 1)
			w = 1;

		g = view->find(state.ui.tree, bar.buttons[i].id);
		if(g != nil){
			#
			# Button group coordinates are relative to the bottom bar group.
			#
			view->setbounds(g, x, 0, w, 1);
			view->show(g);
		}

		l = view->find(state.ui.tree, bar.buttons[i].labelid);
		if(l != nil){
			#
			# Label coordinates are relative to the button group.
			#
			view->setbounds(l, 0, 0, w, 1);
			view->settext(l, buttontext(bar.buttons[i].fkey, bar.buttons[i].text, w));
			view->show(l);
		}
	}

	refreshcodes(state, bar);
	return 0;
}

activatefkey(state: ref IcState->AppState, fkey: int): int
{
	if(state == nil || state.bottombar == nil)
		return -1;

	state.bottombar.activefkey = fkey;
	state.bottombar.activewait = FlashTicks;

	refreshcodes(state, state.bottombar);
	return 0;
}

handletick(state: ref IcState->AppState): int
{
	if(state == nil || state.bottombar == nil)
		return 0;

	if(state.bottombar.activewait <= 0)
		return 0;

	state.bottombar.activewait--;
	if(state.bottombar.activewait > 0)
		return 0;

	state.bottombar.activefkey = 0;
	refreshcodes(state, state.bottombar);

	return 1;
}