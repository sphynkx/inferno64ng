implement IcViewButtons;

include "ic/viewbuttons.m";

IcUiMod: module
{
	PATH: con "/dis/lib/icurses/ui.dis";

	init: fn();
	label: fn(u: ref IcUi->Ui, parentid, id: int, x, y, w: int, text: string): int;
};

IcViewMod: module
{
	PATH: con "/dis/lib/icurses/view.dis";

	init: fn();
	allocid: fn(t: ref IcView->Tree): int;
	find: fn(t: ref IcView->Tree, id: int): ref IcView->Node;
	setbounds: fn(v: ref IcView->Node, x, y, w, h: int);
	settext: fn(v: ref IcView->Node, text: string);
	setcode: fn(v: ref IcView->Node, code: string);
	show: fn(v: ref IcView->Node);
};

IcRuntimeTheme: module
{
	PATH: con "/dis/ic/runtheme.dis";

	init: fn();
	loadtheme: fn(): ref IcState->ThemeState;
};

ViewerButton: adt
{
	labelid: int;
	fkey: int;
	text: string;
	enabled: int;
};

ui: IcUiMod;
view: IcViewMod;
runtheme: IcRuntimeTheme;

theme: ref IcState->ThemeState;

buttons: array of ViewerButton;
activefkey: int;
activewait: int;
wrapenabled: int;

ButtonCount: con 10;
ButtonGap: con 1;
FlashTicks: con 2;

DefaultBottomCode: con "1;38;2;20;25;30;48;2;170;225;255";
DefaultBottomActiveCode: con "1;38;2;255;120;210;48;2;170;225;255";
DefaultBottomDisabledCode: con "38;2;120;120;120;48;2;170;225;255";

ensurebuttons: fn(u: ref IcUi->Ui);
buttonx: fn(w, idx: int): int;
buttonw: fn(w, idx: int): int;
buttontext: fn(fkey: int, text: string, w: int): string;
buttoncode: fn(b: ViewerButton): string;
bottomcode: fn(): string;
bottomactivecode: fn(): string;
bottomdisabledcode: fn(): string;
spaces: fn(n: int): string;
fittext: fn(s: string, w: int): string;
setlabel: fn(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string);

init()
{
	ui = load IcUiMod IcUiMod->PATH;
	if(ui == nil)
		raise "fail:load icurses/ui";

	view = load IcViewMod IcViewMod->PATH;
	if(view == nil)
		raise "fail:load icurses/view";

	runtheme = load IcRuntimeTheme IcRuntimeTheme->PATH;
	if(runtheme == nil)
		raise "fail:load ic/runtheme";

	ui->init();
	view->init();
	runtheme->init();

	theme = runtheme->loadtheme();

	buttons = array[0] of ViewerButton;
	activefkey = 0;
	activewait = 0;
	wrapenabled = 1;
}

settheme(t: ref IcState->ThemeState)
{
	if(t != nil)
		theme = t;
}

setwrap(enabled: int)
{
	wrapenabled = enabled;

	if(buttons == nil || len buttons < 2)
		return;

	if(wrapenabled)
		buttons[1].text = "Unwrap";
	else
		buttons[1].text = "Wrap";
}

bottomcode(): string
{
	if(theme != nil && theme.commandbarcode != "")
		return theme.commandbarcode;

	return DefaultBottomCode;
}

bottomactivecode(): string
{
	if(theme != nil && theme.commandbaractivecode != "")
		return theme.commandbaractivecode;

	return DefaultBottomActiveCode;
}

bottomdisabledcode(): string
{
	if(theme != nil && theme.commandbardisabledcode != "")
		return theme.commandbardisabledcode;

	return DefaultBottomDisabledCode;
}

ensurebuttons(u: ref IcUi->Ui)
{
	i: int;
	b: ViewerButton;

	if(u == nil || u.tree == nil)
		return;

	if(buttons != nil && len buttons == ButtonCount)
		return;

	buttons = array[ButtonCount] of ViewerButton;

	for(i = 0; i < ButtonCount; i++){
		b.labelid = view->allocid(u.tree);
		b.fkey = i + 1;
		b.text = "";
		b.enabled = 0;

		case i {
		0 =>
			b.text = "Help";
		1 =>
			if(wrapenabled)
				b.text = "Unwrap";
			else
				b.text = "Wrap";
			b.enabled = 1;
		2 =>
			b.text = "Quit";
			b.enabled = 1;
		3 =>
			b.text = "Edit";
			b.enabled = 1;
		4 =>
			b.text = "GoTo";
			b.enabled = 1;
		5 =>
			b.text = "Hex";
		6 =>
			b.text = "Search";
			b.enabled = 1;
		7 =>
			b.text = "Codepage";
			b.enabled = 1;
		8 =>
			b.text = "Menu";
		9 =>
			b.text = "Quit";
			b.enabled = 1;
		}

		buttons[i] = b;
	}
}

buttonx(w, idx: int): int
{
	return (w * idx) / ButtonCount;
}

buttonw(w, idx: int): int
{
	x0, x1, bw: int;

	x0 = buttonx(w, idx);
	x1 = (w * (idx + 1)) / ButtonCount;

	bw = x1 - x0;
	if(idx < ButtonCount - 1)
		bw -= ButtonGap;

	if(bw < 1)
		bw = 1;

	return bw;
}

buttontext(fkey: int, text: string, w: int): string
{
	if(text == "")
		return fittext("F" + string fkey, w);

	return fittext("F" + string fkey + " " + text, w);
}

buttoncode(b: ViewerButton): string
{
	if(!b.enabled)
		return bottomdisabledcode();

	if(activewait > 0 && b.fkey == activefkey)
		return bottomactivecode();

	return bottomcode();
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

setlabel(u: ref IcUi->Ui, parentid, id, x, y, w: int, text, code: string)
{
	n: ref IcView->Node;

	if(u == nil || u.tree == nil)
		return;

	if(view->find(u.tree, id) == nil)
		ui->label(u, parentid, id, x, y, w, text);

	n = view->find(u.tree, id);
	if(n == nil)
		return;

	view->setbounds(n, x, y, w, 1);
	view->settext(n, fittext(text, w));
	view->setcode(n, code);
	view->show(n);
}

draw(u: ref IcUi->Ui, parentid, bottomid, w, h: int)
{
	i, x, bw: int;

	if(u == nil || u.tree == nil)
		return;

	setlabel(u, parentid, bottomid, 0, h - 1, w, spaces(w), bottomcode());

	ensurebuttons(u);

	for(i = 0; i < len buttons; i++){
		x = buttonx(w, i);
		bw = buttonw(w, i);

		setlabel(
			u,
			parentid,
			buttons[i].labelid,
			x,
			h - 1,
			bw,
			buttontext(buttons[i].fkey, buttons[i].text, bw),
			buttoncode(buttons[i])
		);
	}
}

activate(fkey: int)
{
	activefkey = fkey;
	activewait = FlashTicks;
}

handletick(): int
{
	if(activewait <= 0)
		return 0;

	activewait--;
	if(activewait > 0)
		return 0;

	activefkey = 0;
	return 1;
}