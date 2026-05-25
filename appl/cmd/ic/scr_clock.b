implement IcScreenSaverPlugin;

include "ic/scr.m";
include "daytime.m";

IcConfigData: module
{
	PATH: con "/dis/ic/config.dis";

	init: fn();

	get: fn(c: ref IcState->ConfigState, section, key, def: string): string;
	getint: fn(c: ref IcState->ConfigState, section, key: string, def: int): int;
};

IcPaintMod: module
{
	PATH: con "/dis/lib/icurses/paint.dis";

	init: fn();

	flush: fn(r: ref IcPaint->Renderer);
};

sys: Sys;
ic: Icurses;
daytime: Daytime;
paint: IcPaintMod;
cfgdata: IcConfigData;

ConfigSection: con "clock";

DefaultIdleTicks: con 300;

DefaultBackgroundCode: con "0;30;40";
DefaultSegmentCode: con "1;38;2;160;255;60;40";
DefaultDateCode: con "38;2;110;210;80;40";

DefaultSegmentCharUnicode: con "█";
DefaultSegmentCharAscii: con "#";
DefaultBlankChar: con " ";

DefaultShowDate: con 1;
DefaultMoveDelayTicks: con 3;
DefaultMoveStep: con 1;

DigitW: con 5;
DigitH: con 7;
ColonW: con 1;
GapW: con 1;

SeedBase: con 975318642;
SeedMul: con 1103515245;
SeedAdd: con 12345;

bgcode: string;
segmentcode: string;
datecode: string;
segmentchar: string;
blankchar: string;

showdate: int;
movedelay: int;
movestep: int;

idx: fn(w, x, y: int): int;
sig: fn(ch, code: string): int;
mkpaintcell: fn(ch, code: string): IcPaint->Cell;

mixseed: fn(s: ref IcState->ScreenSaverState, v: int);
nextseed: fn(s: ref IcState->ScreenSaverState): int;
randrange: fn(s: ref IcState->ScreenSaverState, lo, hi: int): int;

loadconfig: fn(cfg: ref IcState->ConfigState);
selectsegmentchar: fn(cfg: ref IcState->ConfigState): string;

initframe: fn(state: ref IcState->AppState): int;
fillframe: fn(s: ref IcState->ScreenSaverState, ch, code: string);
drawrenderer: fn(state: ref IcState->AppState): int;

clockw: fn(): int;
clockh: fn(): int;
initmotion: fn(state: ref IcState->AppState);
movecanvas: fn(state: ref IcState->AppState);

clearclockrect: fn(s: ref IcState->ScreenSaverState, x, y: int);

putcell: fn(s: ref IcState->ScreenSaverState, x, y: int, ch, code: string);
puttext: fn(s: ref IcState->ScreenSaverState, x, y: int, text, code: string);

digitrow: fn(d, row: int): string;
drawdigit: fn(s: ref IcState->ScreenSaverState, x, y, d: int);
drawcolon: fn(s: ref IcState->ScreenSaverState, x, y: int);
drawclockat: fn(s: ref IcState->ScreenSaverState, x, y: int);

pad2: fn(v: int): string;
pad4: fn(v: int): string;
weekday: fn(w: int): string;
datestring: fn(tm: ref Daytime->Tm): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	daytime = load Daytime Daytime->PATH;
	if(daytime == nil)
		raise "fail:load daytime";

	paint = load IcPaintMod IcPaintMod->PATH;
	if(paint == nil)
		raise "fail:load icurses/paint";

	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	ic->init();
	paint->init();
	cfgdata->init();
}

name(): string
{
	return "clock";
}

title(): string
{
	return "Clock";
}

newstate(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState
{
	s: ref IcState->ScreenSaverState;

	loadconfig(cfg);

	s = ref IcState->ScreenSaverState;

	s.active = 0;
	s.idleticks = 0;

	s.canvasid = -1;
	s.w = 0;
	s.h = 0;

	s.snapshot = array[0] of IcState->ScreenCell;
	s.shadow = array[0] of IcState->ScreenCell;
	s.beams = array[0] of IcState->ScreenBeam;

	s.seed = SeedBase;

	s.x = 0;
	s.y = 0;
	s.dx = 1;
	s.dy = 1;
	s.rx = clockw();
	s.ry = clockh();
	s.life = 0;

	s.pathkind = 0;
	s.pathlife = 0;
	s.curveamp = 0;

	s.enabled = 1;
	s.idlelimit = DefaultIdleTicks;
	s.shadowpercent = 0;

	return s;
}

loadconfig(cfg: ref IcState->ConfigState)
{
	bgcode = cfgdata->get(cfg, ConfigSection, "background_code", DefaultBackgroundCode);
	segmentcode = cfgdata->get(cfg, ConfigSection, "segment_code", DefaultSegmentCode);
	datecode = cfgdata->get(cfg, ConfigSection, "date_code", DefaultDateCode);

	segmentchar = selectsegmentchar(cfg);
	blankchar = cfgdata->get(cfg, ConfigSection, "blank_char", DefaultBlankChar);

	showdate = cfgdata->getint(cfg, ConfigSection, "show_date", DefaultShowDate);
	movedelay = cfgdata->getint(cfg, ConfigSection, "move_delay_ticks", DefaultMoveDelayTicks);
	movestep = cfgdata->getint(cfg, ConfigSection, "move_step", DefaultMoveStep);

	if(segmentchar == "")
		segmentchar = DefaultSegmentCharAscii;

	if(blankchar == "")
		blankchar = " ";

	if(showdate != 0)
		showdate = 1;

	if(movedelay < 1)
		movedelay = 1;

	if(movestep < 1)
		movestep = 1;
	if(movestep > 4)
		movestep = 4;
}

selectsegmentchar(cfg: ref IcState->ConfigState): string
{
	mode, uch, ach: string;
	ci: Icurses->ConsInfo;

	mode = cfgdata->get(cfg, ConfigSection, "segment_char", "auto");
	uch = cfgdata->get(cfg, ConfigSection, "unicode_segment_char", DefaultSegmentCharUnicode);
	ach = cfgdata->get(cfg, ConfigSection, "ascii_segment_char", DefaultSegmentCharAscii);

	if(mode == "ascii")
		return ach;

	if(mode == "unicode")
		return uch;

	if(mode != "auto" && mode != "")
		return mode;

	ci = ic->consinfo();
	if(ci.ok && ci.utf8 && ci.source != "mingw-console")
		return uch;

	return ach;
}

idx(w, x, y: int): int
{
	return y * w + x;
}

sig(ch, code: string): int
{
	h, i: int;

	h = 0;

	for(i = 0; i < len ch; i++)
		h = (h * 33) ^ int ch[i];

	for(i = 0; i < len code; i++)
		h = (h * 33) ^ int code[i];

	return h;
}

mkpaintcell(ch, code: string): IcPaint->Cell
{
	c: IcPaint->Cell;

	if(ch == "")
		ch = " ";
	if(code == "")
		code = "0";

	c.ch = ch;
	c.code = code;
	c.sig = sig(ch, code);

	return c;
}

mixseed(s: ref IcState->ScreenSaverState, v: int)
{
	if(s == nil)
		return;

	if(v < 0)
		v = -v;

	s.seed = ((s.seed * 257) ^ (v + 17)) + SeedAdd;
	if(s.seed < 0)
		s.seed = -s.seed;
}

nextseed(s: ref IcState->ScreenSaverState): int
{
	if(s == nil)
		return SeedBase;

	s.seed = s.seed * SeedMul + SeedAdd;
	if(s.seed < 0)
		s.seed = -s.seed;

	return s.seed;
}

randrange(s: ref IcState->ScreenSaverState, lo, hi: int): int
{
	v, span: int;

	if(hi < lo)
		hi = lo;

	span = hi - lo + 1;
	if(span <= 0)
		return lo;

	v = nextseed(s);
	if(v < 0)
		v = -v;

	return lo + (v % span);
}

clockw(): int
{
	return DigitW * 6 + ColonW * 2 + GapW * 7;
}

clockh(): int
{
	if(showdate)
		return DigitH + 2;

	return DigitH;
}

initframe(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;
	r: ref IcPaint->Renderer;
	i, n: int;

	if(state == nil || state.ui == nil || state.ui.renderer == nil)
		return -1;

	s = state.screensaver;
	if(s == nil)
		return -1;

	r = state.ui.renderer;
	if(r.w <= 0 || r.h <= 0)
		return -1;

	s.w = r.w;
	s.h = r.h;

	n = s.w * s.h;

	s.snapshot = array[n] of IcState->ScreenCell;
	s.shadow = array[n] of IcState->ScreenCell;

	for(i = 0; i < n; i++){
		s.snapshot[i].ch = " ";
		s.snapshot[i].code = bgcode;

		s.shadow[i].ch = " ";
		s.shadow[i].code = bgcode;
	}

	return 0;
}

fillframe(s: ref IcState->ScreenSaverState, ch, code: string)
{
	i, n: int;

	if(s == nil || s.shadow == nil)
		return;

	n = len s.shadow;
	for(i = 0; i < n; i++){
		s.shadow[i].ch = ch;
		if(s.shadow[i].ch == "")
			s.shadow[i].ch = " ";

		s.shadow[i].code = code;
		if(s.shadow[i].code == "")
			s.shadow[i].code = bgcode;
	}
}

initmotion(state: ref IcState->AppState)
{
	s: ref IcState->ScreenSaverState;
	maxx, maxy: int;

	if(state == nil || state.screensaver == nil)
		return;

	s = state.screensaver;

	maxx = s.w - clockw();
	maxy = s.h - clockh();

	if(maxx < 0)
		maxx = 0;
	if(maxy < 0)
		maxy = 0;

	s.x = randrange(s, 0, maxx);
	s.y = randrange(s, 0, maxy);

	s.dx = 1;
	s.dy = 1;

	if(randrange(s, 0, 1) == 0)
		s.dx = -1;
	if(randrange(s, 0, 1) == 0)
		s.dy = -1;

	s.life = 0;
}

movecanvas(state: ref IcState->AppState)
{
	s: ref IcState->ScreenSaverState;
	maxx, maxy: int;

	if(state == nil || state.screensaver == nil)
		return;

	s = state.screensaver;

	s.life++;
	if(s.life < movedelay)
		return;

	s.life = 0;

	maxx = s.w - clockw();
	maxy = s.h - clockh();

	if(maxx < 0)
		maxx = 0;
	if(maxy < 0)
		maxy = 0;

	s.x += s.dx * movestep;
	s.y += s.dy * movestep;

	if(s.x < 0){
		s.x = 0;
		s.dx = 1;
	}

	if(s.y < 0){
		s.y = 0;
		s.dy = 1;
	}

	if(s.x > maxx){
		s.x = maxx;
		s.dx = -1;
	}

	if(s.y > maxy){
		s.y = maxy;
		s.dy = -1;
	}
}

clearclockrect(s: ref IcState->ScreenSaverState, x, y: int)
{
	xx, yy, w, h: int;

	if(s == nil)
		return;

	w = clockw();
	h = clockh();

	for(yy = 0; yy < h; yy++){
		for(xx = 0; xx < w; xx++)
			putcell(s, x + xx, y + yy, blankchar, bgcode);
	}
}

putcell(s: ref IcState->ScreenSaverState, x, y: int, ch, code: string)
{
	i: int;

	if(s == nil || s.shadow == nil)
		return;

	if(x < 0 || y < 0 || x >= s.w || y >= s.h)
		return;

	i = idx(s.w, x, y);

	s.shadow[i].ch = ch;
	if(s.shadow[i].ch == "")
		s.shadow[i].ch = " ";

	s.shadow[i].code = code;
	if(s.shadow[i].code == "")
		s.shadow[i].code = bgcode;
}

puttext(s: ref IcState->ScreenSaverState, x, y: int, text, code: string)
{
	i: int;

	for(i = 0; i < len text; i++)
		putcell(s, x + i, y, text[i:i + 1], code);
}

digitrow(d, row: int): string
{
	case d {
	0 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "#   #";
		3 => return "#   #";
		4 => return "#   #";
		5 => return "#   #";
		6 => return " ### ";
		}

	1 =>
		case row {
		0 => return "  #  ";
		1 => return " ##  ";
		2 => return "  #  ";
		3 => return "  #  ";
		4 => return "  #  ";
		5 => return "  #  ";
		6 => return " ### ";
		}

	2 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "    #";
		3 => return "   # ";
		4 => return "  #  ";
		5 => return " #   ";
		6 => return "#####";
		}

	3 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "    #";
		3 => return " ### ";
		4 => return "    #";
		5 => return "#   #";
		6 => return " ### ";
		}

	4 =>
		case row {
		0 => return "#   #";
		1 => return "#   #";
		2 => return "#   #";
		3 => return "#####";
		4 => return "    #";
		5 => return "    #";
		6 => return "    #";
		}

	5 =>
		case row {
		0 => return "#####";
		1 => return "#    ";
		2 => return "#    ";
		3 => return "#### ";
		4 => return "    #";
		5 => return "#   #";
		6 => return " ### ";
		}

	6 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "#    ";
		3 => return "#### ";
		4 => return "#   #";
		5 => return "#   #";
		6 => return " ### ";
		}

	7 =>
		case row {
		0 => return "#####";
		1 => return "    #";
		2 => return "   # ";
		3 => return "  #  ";
		4 => return " #   ";
		5 => return "#    ";
		6 => return "#    ";
		}

	8 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "#   #";
		3 => return " ### ";
		4 => return "#   #";
		5 => return "#   #";
		6 => return " ### ";
		}

	9 =>
		case row {
		0 => return " ### ";
		1 => return "#   #";
		2 => return "#   #";
		3 => return " ####";
		4 => return "    #";
		5 => return "#   #";
		6 => return " ### ";
		}
	}

	return "     ";
}

drawdigit(s: ref IcState->ScreenSaverState, x, y, d: int)
{
	row, col: int;
	line, ch: string;

	for(row = 0; row < DigitH; row++){
		line = digitrow(d, row);
		for(col = 0; col < DigitW; col++){
			ch = line[col:col + 1];
			if(ch != " ")
				putcell(s, x + col, y + row, segmentchar, segmentcode);
			else
				putcell(s, x + col, y + row, blankchar, bgcode);
		}
	}
}

drawcolon(s: ref IcState->ScreenSaverState, x, y: int)
{
	row: int;

	for(row = 0; row < DigitH; row++){
		if(row == 2 || row == 4)
			putcell(s, x, y + row, segmentchar, segmentcode);
		else
			putcell(s, x, y + row, blankchar, bgcode);
	}
}

pad2(v: int): string
{
	if(v < 0)
		v = 0;

	if(v < 10)
		return "0" + string v;

	return string v;
}

pad4(v: int): string
{
	if(v < 0)
		v = 0;

	if(v < 10)
		return "000" + string v;
	if(v < 100)
		return "00" + string v;
	if(v < 1000)
		return "0" + string v;

	return string v;
}

weekday(w: int): string
{
	case w {
	0 => return "Sun";
	1 => return "Mon";
	2 => return "Tue";
	3 => return "Wed";
	4 => return "Thu";
	5 => return "Fri";
	6 => return "Sat";
	}

	return "";
}

datestring(tm: ref Daytime->Tm): string
{
	if(tm == nil)
		return "";

	return pad4(tm.year + 1900) + "-"
		+ pad2(tm.mon + 1) + "-"
		+ pad2(tm.mday) + " "
		+ weekday(tm.wday);
}

drawclockat(s: ref IcState->ScreenSaverState, x, y: int)
{
	tm: ref Daytime->Tm;
	text: string;
	p: int;

	if(s == nil)
		return;

	tm = daytime->local(daytime->now());
	if(tm == nil)
		return;

	p = x;

	drawdigit(s, p, y, tm.hour / 10);
	p += DigitW + GapW;

	drawdigit(s, p, y, tm.hour % 10);
	p += DigitW + GapW;

	drawcolon(s, p, y);
	p += ColonW + GapW;

	drawdigit(s, p, y, tm.min / 10);
	p += DigitW + GapW;

	drawdigit(s, p, y, tm.min % 10);
	p += DigitW + GapW;

	drawcolon(s, p, y);
	p += ColonW + GapW;

	drawdigit(s, p, y, tm.sec / 10);
	p += DigitW + GapW;

	drawdigit(s, p, y, tm.sec % 10);

	if(showdate){
		text = datestring(tm);
		puttext(s, x + (clockw() - len text) / 2, y + DigitH + 1, text, datecode);
	}
}

drawrenderer(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;
	r: ref IcPaint->Renderer;
	i, n: int;

	if(state == nil || state.ui == nil || state.ui.renderer == nil)
		return -1;

	s = state.screensaver;
	if(s == nil || !s.active)
		return 0;

	if(s.shadow == nil)
		return -1;

	r = state.ui.renderer;

	if(r.back == nil)
		return -1;

	if(r.w != s.w || r.h != s.h)
		return -1;

	n = r.w * r.h;
	if(len r.back < n || len s.shadow < n)
		return -1;

	for(i = 0; i < n; i++)
		r.back[i] = mkpaintcell(s.shadow[i].ch, s.shadow[i].code);

	paint->flush(r);
	return 0;
}

active(state: ref IcState->AppState): int
{
	return state != nil && state.screensaver != nil && state.screensaver.active;
}

resetidle(state: ref IcState->AppState)
{
	if(state == nil || state.screensaver == nil)
		return;

	state.screensaver.idleticks = 0;
}

build(state: ref IcState->AppState): int
{
	if(!active(state))
		return 0;

	return drawrenderer(state);
}

start(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;

	if(state == nil)
		return -1;

	if(state.screensaver == nil)
		state.screensaver = newstate(state.cfg);

	s = state.screensaver;
	if(s == nil || !s.enabled)
		return 0;

	if(s.active)
		return 0;

	if(initframe(state) < 0)
		return -1;

	s.seed = SeedBase
		+ state.width * 97
		+ state.height * 131
		+ state.ui.ticks * 17
		+ sys->millisec();

	mixseed(s, len s.shadow);

	fillframe(s, blankchar, bgcode);
	initmotion(state);
	drawclockat(s, s.x, s.y);

	s.active = 1;

	return drawrenderer(state);
}

stop(state: ref IcState->AppState): int
{
	if(state == nil || state.screensaver == nil)
		return 0;

	state.screensaver.active = 0;
	state.screensaver.idleticks = 0;

	return 1;
}

handletick(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;
	oldx, oldy: int;

	if(state == nil || state.screensaver == nil)
		return 0;

	s = state.screensaver;
	if(s == nil || !s.enabled)
		return 0;

	if(!s.active)
		return 0;

	mixseed(s, state.ui.ticks + sys->millisec());

	oldx = s.x;
	oldy = s.y;

	movecanvas(state);

	clearclockrect(s, oldx, oldy);
	drawclockat(s, s.x, s.y);

	drawrenderer(state);
	return 1;
}