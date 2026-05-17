IcLayout: module
{
	PATH: con "/dis/ic/layout.dis";

	Rect: adt
	{
		x: int;
		y: int;
		w: int;
		h: int;
	};

	LayoutState: adt
	{
		screen: Rect;
		topbar: Rect;
		leftpanel: Rect;
		rightpanel: Rect;
		commandline: Rect;
		bottombar: Rect;
	};

	init: fn();
	compute: fn(w, h, panelshidden: int): LayoutState;
};