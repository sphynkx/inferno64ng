implement IcScreenSaverPlugin;

include "ic/scr.m";

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
paint: IcPaintMod;
cfgdata: IcConfigData;

ConfigSection: con "matrix";

DefaultIdleTicks: con 300;

DefaultAsciiChars: con "0123456789+=&%$?#ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
DefaultUnicodeChars: con "モエヤキオカ7ケサスz152ヨタワ4ネヌナ98ヒ0ホア3ウ セ¦:\"꞊ミラリ╌ツテニハソ▪—<>0|+*コシマムメ";
DefaultCharset: con "auto";

DefaultBgCode: con "0;30;40";
DefaultHeadCode: con "38;2;220;255;220;40";
DefaultBrightCode: con "38;2;100;255;140;40";
DefaultMidCode: con "38;2;0;190;70;40";
DefaultDimCode: con "38;2;0;100;35;40";
DefaultTailCode: con "38;2;0;40;15;40";

DefaultStreamCount: con 32;
DefaultTailMin: con 6;
DefaultTailMax: con 22;
DefaultDelayMinTicks: con 1;
DefaultDelayMaxTicks: con 5;
DefaultStartDepthMax: con 12;
DefaultStepChancePercent: con 25;

SeedBase: con 1357911;
SeedMul: con 1103515245;
SeedAdd: con 12345;

chars: string;
bgcode: string;
headcode: string;
brightcode: string;
midcode: string;
dimcode: string;
tailcode: string;
stepchance: int;
startdepthmax: int;

idx: fn(w, x, y: int): int;
sig: fn(ch, code: string): int;
mkpaintcell: fn(ch, code: string): IcPaint->Cell;

mixseed: fn(s: ref IcState->ScreenSaverState, v: int);
nextseed: fn(s: ref IcState->ScreenSaverState): int;
randrange: fn(s: ref IcState->ScreenSaverState, lo, hi: int): int;

loadconfig: fn(cfg: ref IcState->ConfigState, s: ref IcState->ScreenSaverState);
selectchars: fn(cfg: ref IcState->ConfigState): string;
rndchar: fn(s: ref IcState->ScreenSaverState): string;
streamcode: fn(pos, tail: int): string;

initframe: fn(state: ref IcState->AppState): int;
initstreams: fn(s: ref IcState->ScreenSaverState);
newstream: fn(s: ref IcState->ScreenSaverState, delaymax: int): IcState->ScreenBeam;
movestream: fn(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam): IcState->ScreenBeam;
drawstream: fn(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam, oldhead, newhead: int);
putcell: fn(s: ref IcState->ScreenSaverState, x, y: int, ch, code: string);

drawrenderer: fn(state: ref IcState->AppState): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

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
	return "matrix";
}

title(): string
{
	return "Matrix";
}

newstate(cfg: ref IcState->ConfigState): ref IcState->ScreenSaverState
{
	s: ref IcState->ScreenSaverState;

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
	s.rx = 0;
	s.ry = 0;
	s.life = 0;

	s.pathkind = 0;
	s.pathlife = 0;
	s.curveamp = 0;

	s.enabled = 1;
	s.idlelimit = DefaultIdleTicks;
	s.shadowpercent = 0;

	loadconfig(cfg, s);

	return s;
}

loadconfig(cfg: ref IcState->ConfigState, s: ref IcState->ScreenSaverState)
{
	s.beamcount = cfgdata->getint(cfg, ConfigSection, "stream_count", DefaultStreamCount);

	s.radiusmin = cfgdata->getint(cfg, ConfigSection, "tail_min", DefaultTailMin);
	s.radiusmax = cfgdata->getint(cfg, ConfigSection, "tail_max", DefaultTailMax);

	s.speedmin = cfgdata->getint(cfg, ConfigSection, "delay_min_ticks", DefaultDelayMinTicks);
	s.speedmax = cfgdata->getint(cfg, ConfigSection, "delay_max_ticks", DefaultDelayMaxTicks);

	startdepthmax = cfgdata->getint(cfg, ConfigSection, "start_depth_max", DefaultStartDepthMax);
	stepchance = cfgdata->getint(cfg, ConfigSection, "step_chance_percent", DefaultStepChancePercent);

	bgcode = cfgdata->get(cfg, ConfigSection, "background_code", DefaultBgCode);
	headcode = cfgdata->get(cfg, ConfigSection, "head_code", DefaultHeadCode);
	brightcode = cfgdata->get(cfg, ConfigSection, "bright_code", DefaultBrightCode);
	midcode = cfgdata->get(cfg, ConfigSection, "mid_code", DefaultMidCode);
	dimcode = cfgdata->get(cfg, ConfigSection, "dim_code", DefaultDimCode);
	tailcode = cfgdata->get(cfg, ConfigSection, "tail_code", DefaultTailCode);

	chars = selectchars(cfg);

	if(chars == "")
		chars = DefaultAsciiChars;

	if(s.beamcount < 1)
		s.beamcount = 1;
	if(s.beamcount > 200)
		s.beamcount = 200;

	if(s.radiusmin < 1)
		s.radiusmin = 1;
	if(s.radiusmax < s.radiusmin)
		s.radiusmax = s.radiusmin;

	if(s.speedmin < 1)
		s.speedmin = 1;
	if(s.speedmax < s.speedmin)
		s.speedmax = s.speedmin;

	if(startdepthmax < 1)
		startdepthmax = 1;

	if(stepchance < 0)
		stepchance = 0;
	if(stepchance > 100)
		stepchance = 100;
}

selectchars(cfg: ref IcState->ConfigState): string
{
	mode, a, u: string;
	ci: Icurses->ConsInfo;

	mode = cfgdata->get(cfg, ConfigSection, "charset", DefaultCharset);
	a = cfgdata->get(cfg, ConfigSection, "ascii_chars", DefaultAsciiChars);
	u = cfgdata->get(cfg, ConfigSection, "unicode_chars", DefaultUnicodeChars);

	if(mode == "ascii")
		return a;

	if(mode == "unicode")
		return u;

	ci = ic->consinfo();
	if(ci.ok && ci.utf8 && ci.source != "mingw-console")
		return u;

	return a;
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

rndchar(s: ref IcState->ScreenSaverState): string
{
	i, n: int;

	n = len chars;
	if(n <= 0)
		return " ";

	i = randrange(s, 0, n - 1);
	if(i < 0)
		i = 0;
	if(i >= n)
		i = n - 1;

	return chars[i:i + 1];
}

streamcode(pos, tail: int): string
{
	if(pos <= 0)
		return headcode;

	if(pos == 1)
		return brightcode;

	if(pos < tail / 3)
		return midcode;

	if(pos < (tail * 2) / 3)
		return dimcode;

	return tailcode;
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

	n = r.w * r.h;

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

initstreams(s: ref IcState->ScreenSaverState)
{
	i, delaymax: int;

	if(s == nil)
		return;

	s.beams = array[s.beamcount] of IcState->ScreenBeam;

	delaymax = s.speedmax * 4;
	if(delaymax < 1)
		delaymax = 1;

	for(i = 0; i < len s.beams; i++)
		s.beams[i] = newstream(s, delaymax);
}

newstream(s: ref IcState->ScreenSaverState, delaymax: int): IcState->ScreenBeam
{
	b: IcState->ScreenBeam;

	b.active = 1;
	b.x = randrange(s, 0, s.w - 1);
	b.y = -(1 + randrange(s, 0, startdepthmax));
	b.startx = b.x;
	b.starty = b.y;
	b.dx = 0;
	b.dy = 1;

	b.rx = randrange(s, s.radiusmin, s.radiusmax);
	b.ry = randrange(s, s.speedmin, s.speedmax);

	b.life = 0;
	b.pathlife = 0;
	b.curveaxis = 0;
	b.curveamp = 0;

	b.delay = 0;
	if(delaymax > 0)
		b.delay = randrange(s, 0, delaymax);

	return b;
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

drawstream(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam, oldhead, newhead: int)
{
	y, top, bot, pos: int;
	ch, code: string;

	if(s == nil || !b.active)
		return;

	top = oldhead - b.rx - 1;
	if(newhead - b.rx - 1 < top)
		top = newhead - b.rx - 1;

	bot = oldhead;
	if(newhead > bot)
		bot = newhead;

	if(top < 0)
		top = 0;
	if(bot >= s.h)
		bot = s.h - 1;

	for(y = top; y <= bot; y++){
		if(y < newhead - b.rx + 1 || y > newhead){
			putcell(s, b.x, y, " ", bgcode);
			continue;
		}

		pos = newhead - y;
		ch = rndchar(s);
		code = streamcode(pos, b.rx);

		putcell(s, b.x, y, ch, code);
	}
}

movestream(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam): IcState->ScreenBeam
{
	oldhead, step: int;

	if(s == nil)
		return b;

	if(b.delay > 0){
		b.delay--;
		return b;
	}

	if(b.life > 0){
		b.life--;
		return b;
	}

	oldhead = b.y;
	step = 1;

	if(randrange(s, 0, 99) < stepchance)
		step++;

	b.y += step;

	if(b.y - b.rx >= s.h)
		return newstream(s, s.speedmax * 2);

	drawstream(s, b, oldhead, b.y);

	b.life = b.ry + randrange(s, 0, b.ry);

	return b;
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

	initstreams(s);

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
	i: int;

	if(state == nil || state.screensaver == nil)
		return 0;

	s = state.screensaver;
	if(s == nil || !s.enabled)
		return 0;

	if(!s.active)
		return 0;

	mixseed(s, state.ui.ticks + sys->millisec());

	for(i = 0; i < len s.beams; i++)
		s.beams[i] = movestream(s, s.beams[i]);

	drawrenderer(state);
	return 1;
}