implement IcLayout;

include "ic/layout.m";

TopBarHeight: con 0;
CommandLineHeight: con 1;
BottomBarHeight: con 1;
MinPanelWidth: con 10;

init()
{
}

compute(w, h, panelshidden: int): IcLayout->LayoutState
{
	l: IcLayout->LayoutState;
	innerh, panelw: int;

	if(w < 20)
		w = 20;
	if(h < 6)
		h = 6;

	l.screen.x = 0;
	l.screen.y = 0;
	l.screen.w = w;
	l.screen.h = h;

	l.topbar.x = 0;
	l.topbar.y = 0;
	l.topbar.w = w;
	l.topbar.h = TopBarHeight;

	l.bottombar.x = 0;
	l.bottombar.y = h - BottomBarHeight;
	l.bottombar.w = w;
	l.bottombar.h = BottomBarHeight;

	l.commandline.x = 0;
	l.commandline.y = l.bottombar.y - CommandLineHeight;
	l.commandline.w = w;
	l.commandline.h = CommandLineHeight;

	innerh = h - TopBarHeight - CommandLineHeight - BottomBarHeight;
	if(innerh < 1)
		innerh = 1;

	if(panelshidden){
		l.leftpanel.x = 0;
		l.leftpanel.y = TopBarHeight;
		l.leftpanel.w = 0;
		l.leftpanel.h = 0;

		l.rightpanel.x = 0;
		l.rightpanel.y = TopBarHeight;
		l.rightpanel.w = 0;
		l.rightpanel.h = 0;

		return l;
	}

	panelw = w / 2;
	if(panelw < MinPanelWidth)
		panelw = MinPanelWidth;

	l.leftpanel.x = 0;
	l.leftpanel.y = TopBarHeight;
	l.leftpanel.w = panelw;
	l.leftpanel.h = innerh;

	l.rightpanel.x = panelw;
	l.rightpanel.y = TopBarHeight;
	l.rightpanel.w = w - panelw;
	l.rightpanel.h = innerh;

	return l;
}