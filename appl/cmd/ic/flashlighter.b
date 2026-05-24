implement IcFlashlighter;

include "ic/flashlighter.m";

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

paint: IcPaintMod;
cfgdata: IcConfigData;

ConfigSection: con "flashlighter";

DefaultIdleTicks: con 300;
DefaultShadowPercent: con 35;

DefaultBeamCount: con 3;

DefaultRadiusMin: con 20;
DefaultRadiusMax: con 24;
DefaultRadiusYPercentMin: con 45;
DefaultRadiusYPercentMax: con 65;

DefaultSpeedMin: con 4;
DefaultSpeedMax: con 7;

DefaultBeamLifeMin: con 70;
DefaultBeamLifeMax: con 160;

DefaultPreferredAngleMin: con 25;
DefaultPreferredAngleMax: con 65;
DefaultPreferredAnglePercent: con 76;

DefaultCurveMinAmpPercent: con 18;
DefaultCurveMaxAmpPercent: con 42;

DefaultShadowCode: con "38;2;80;80;80;48;2;0;0;0";

SeedBase: con 246353424;
SeedMul: con 1103515245;
SeedAdd: con 12345;

ClampRgbMin: con 0;
ClampRgbMax: con 255;

CoverageScale: con 100;
EllipseScale: con 1000;
SubCellScale: con 4;

CurveScale: con 1000;

CurveAxisY: con 0;
CurveAxisX: con 1;

idx: fn(w, x, y: int): int;
clamp: fn(v, lo, hi: int): int;
abs: fn(v: int): int;
sig: fn(ch, code: string): int;
mkpaintcell: fn(ch, code: string): IcPaint->Cell;

nextseed: fn(s: ref IcState->ScreenSaverState): int;
randrange: fn(s: ref IcState->ScreenSaverState, lo, hi: int): int;

snapshot: fn(state: ref IcState->AppState): int;
initbeams: fn(s: ref IcState->ScreenSaverState);
makebeam: fn(s: ref IcState->ScreenSaverState, delaymax: int): IcState->ScreenBeam;
movebeam: fn(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam): IcState->ScreenBeam;
drawrenderer: fn(state: ref IcState->AppState): int;

token: fn(s: string, start: int): (string, int, int);
appendtoken: fn(out, t: string): string;
toint: fn(s: string, def: int): int;
darkrgb: fn(v, percent: int): int;
darkencode: fn(code: string, percent: int, fallback: string): string;
shadowcell: fn(ch, code: string, percent: int, fallback: string): IcState->ScreenCell;

chooseangle: fn(s: ref IcState->ScreenSaverState): int;
choosevector: fn(s: ref IcState->ScreenSaverState, angle: int): (int, int);

parabolaoffset: fn(b: IcState->ScreenBeam): int;
beamcoverage: fn(b: IcState->ScreenBeam, x, y: int): int;
beampercent: fn(s: ref IcState->ScreenSaverState, x, y: int): int;

init()
{
	paint = load IcPaintMod IcPaintMod->PATH;
	if(paint == nil)
		raise "fail:load icurses/paint";

	cfgdata = load IcConfigData IcConfigData->PATH;
	if(cfgdata == nil)
		raise "fail:load ic/config";

	paint->init();
	cfgdata->init();
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
	s.rx = DefaultRadiusMin;
	s.ry = DefaultRadiusMin;
	s.life = 0;

	s.pathkind = CurveAxisY;
	s.pathlife = 0;
	s.curveamp = 0;

	s.enabled = 1;
	s.idlelimit = DefaultIdleTicks;

	s.shadowpercent = cfgdata->getint(cfg, ConfigSection, "shadow_percent", DefaultShadowPercent);

	s.beamcount = cfgdata->getint(cfg, ConfigSection, "beam_count", DefaultBeamCount);

	s.radiusmin = cfgdata->getint(cfg, ConfigSection, "radius_min", DefaultRadiusMin);
	s.radiusmax = cfgdata->getint(cfg, ConfigSection, "radius_max", DefaultRadiusMax);
	s.radiusypercentmin = cfgdata->getint(cfg, ConfigSection, "radius_y_percent_min", DefaultRadiusYPercentMin);
	s.radiusypercentmax = cfgdata->getint(cfg, ConfigSection, "radius_y_percent_max", DefaultRadiusYPercentMax);

	s.speedmin = cfgdata->getint(cfg, ConfigSection, "speed_min", DefaultSpeedMin);
	s.speedmax = cfgdata->getint(cfg, ConfigSection, "speed_max", DefaultSpeedMax);

	s.lifemin = cfgdata->getint(cfg, ConfigSection, "beam_life_min", DefaultBeamLifeMin);
	s.lifemax = cfgdata->getint(cfg, ConfigSection, "beam_life_max", DefaultBeamLifeMax);

	s.preferredanglemin = cfgdata->getint(cfg, ConfigSection, "preferred_angle_min", DefaultPreferredAngleMin);
	s.preferredanglemax = cfgdata->getint(cfg, ConfigSection, "preferred_angle_max", DefaultPreferredAngleMax);
	s.preferredanglepercent = cfgdata->getint(cfg, ConfigSection, "preferred_angle_percent", DefaultPreferredAnglePercent);

	s.curveminamppercent = cfgdata->getint(cfg, ConfigSection, "curve_min_amp_percent", DefaultCurveMinAmpPercent);
	s.curvemaxamppercent = cfgdata->getint(cfg, ConfigSection, "curve_max_amp_percent", DefaultCurveMaxAmpPercent);

	s.shadowcode = cfgdata->get(cfg, ConfigSection, "shadow_code", DefaultShadowCode);

	if(s.shadowpercent < 0)
		s.shadowpercent = 0;
	if(s.shadowpercent > 100)
		s.shadowpercent = 100;

	if(s.beamcount < 1)
		s.beamcount = 1;
	if(s.beamcount > 5)
		s.beamcount = 5;

	if(s.radiusmin < 1)
		s.radiusmin = 1;
	if(s.radiusmax < s.radiusmin)
		s.radiusmax = s.radiusmin;

	if(s.radiusypercentmin < 10)
		s.radiusypercentmin = 10;
	if(s.radiusypercentmax < s.radiusypercentmin)
		s.radiusypercentmax = s.radiusypercentmin;

	if(s.speedmin < 1)
		s.speedmin = 1;
	if(s.speedmax < s.speedmin)
		s.speedmax = s.speedmin;

	if(s.lifemin < 1)
		s.lifemin = 1;
	if(s.lifemax < s.lifemin)
		s.lifemax = s.lifemin;

	if(s.preferredanglemin < 0)
		s.preferredanglemin = 0;
	if(s.preferredanglemax > 90)
		s.preferredanglemax = 90;
	if(s.preferredanglemax < s.preferredanglemin)
		s.preferredanglemax = s.preferredanglemin;

	if(s.preferredanglepercent < 0)
		s.preferredanglepercent = 0;
	if(s.preferredanglepercent > 100)
		s.preferredanglepercent = 100;

	if(s.curveminamppercent < 0)
		s.curveminamppercent = 0;
	if(s.curvemaxamppercent < s.curveminamppercent)
		s.curvemaxamppercent = s.curveminamppercent;

	return s;
}

idx(w, x, y: int): int
{
	return y * w + x;
}

clamp(v, lo, hi: int): int
{
	if(v < lo)
		return lo;
	if(v > hi)
		return hi;
	return v;
}

abs(v: int): int
{
	if(v < 0)
		return -v;
	return v;
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

token(s: string, start: int): (string, int, int)
{
	i: int;

	if(start < 0)
		start = 0;

	while(start < len s && s[start] == ';')
		start++;

	if(start >= len s)
		return ("", start, 0);

	i = start;
	while(i < len s && s[i] != ';')
		i++;

	return (s[start:i], i + 1, 1);
}

appendtoken(out, t: string): string
{
	if(t == "")
		return out;

	if(out != "")
		out += ";";

	return out + t;
}

toint(s: string, def: int): int
{
	i, v, ok, sg: int;

	if(s == "")
		return def;

	i = 0;
	sg = 1;

	if(s[0] == '-'){
		sg = -1;
		i++;
	}

	v = 0;
	ok = 0;

	for(; i < len s; i++){
		if(s[i] < '0' || s[i] > '9')
			return def;

		v = v * 10 + int s[i] - int '0';
		ok = 1;
	}

	if(!ok)
		return def;

	return v * sg;
}

darkrgb(v, percent: int): int
{
	v = (v * percent) / 100;
	return clamp(v, ClampRgbMin, ClampRgbMax);
}

darkencode(code: string, percent: int, fallback: string): string
{
	out, t, t2, tr, tg, tb: string;
	i, ok, changed, kind, r, g, b: int;

	if(code == "")
		return fallback;

	out = "";
	i = 0;
	changed = 0;

	for(;;){
		(t, i, ok) = token(code, i);
		if(!ok)
			break;

		if(t == "38" || t == "48"){
			(t2, i, ok) = token(code, i);
			if(ok && t2 == "2"){
				(tr, i, ok) = token(code, i);
				if(!ok)
					break;
				(tg, i, ok) = token(code, i);
				if(!ok)
					break;
				(tb, i, ok) = token(code, i);
				if(!ok)
					break;

				kind = toint(t, -1);
				r = toint(tr, 0);
				g = toint(tg, 0);
				b = toint(tb, 0);

				out = appendtoken(out, string kind);
				out = appendtoken(out, "2");
				out = appendtoken(out, string darkrgb(r, percent));
				out = appendtoken(out, string darkrgb(g, percent));
				out = appendtoken(out, string darkrgb(b, percent));

				changed = 1;
				continue;
			}

			out = appendtoken(out, t);
			if(ok)
				out = appendtoken(out, t2);
			continue;
		}

		out = appendtoken(out, t);
	}

	if(!changed)
		return fallback;

	return out;
}

shadowcell(ch, code: string, percent: int, fallback: string): IcState->ScreenCell
{
	r: IcState->ScreenCell;

	r.ch = ch;
	if(r.ch == "")
		r.ch = " ";

	r.code = darkencode(code, percent, fallback);

	return r;
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

snapshot(state: ref IcState->AppState): int
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

	if(r.w <= 0 || r.h <= 0 || r.front == nil)
		return -1;

	s.w = r.w;
	s.h = r.h;

	n = r.w * r.h;
	s.snapshot = array[n] of IcState->ScreenCell;
	s.shadow = array[n] of IcState->ScreenCell;

	for(i = 0; i < n; i++){
		s.snapshot[i].ch = r.front[i].ch;
		s.snapshot[i].code = r.front[i].code;

		s.shadow[i] = shadowcell(r.front[i].ch, r.front[i].code, s.shadowpercent, s.shadowcode);
	}

	return 0;
}

chooseangle(s: ref IcState->ScreenSaverState): int
{
	if(randrange(s, 0, 99) < s.preferredanglepercent)
		return randrange(s, s.preferredanglemin, s.preferredanglemax);

	return randrange(s, 0, 90);
}

choosevector(s: ref IcState->ScreenSaverState, angle: int): (int, int)
{
	speed, dx, dy, sx, sy: int;

	speed = randrange(s, s.speedmin, s.speedmax);
	if(speed < 1)
		speed = 1;

	angle = clamp(angle, 0, 90);

	#
	# Integer vector approximation for angle ranges.
	# It avoids floating point and keeps movement varied.
	#
	if(angle < 10){
		dx = speed;
		dy = 0;
	}else if(angle < 20){
		dx = speed;
		dy = speed / 3;
	}else if(angle < 30){
		dx = speed;
		dy = speed / 2;
	}else if(angle < 40){
		dx = speed;
		dy = (speed * 2) / 3;
	}else if(angle < 50){
		dx = speed;
		dy = speed;
	}else if(angle < 60){
		dx = (speed * 2) / 3;
		dy = speed;
	}else if(angle < 70){
		dx = speed / 2;
		dy = speed;
	}else if(angle < 80){
		dx = speed / 3;
		dy = speed;
	}else{
		dx = 0;
		dy = speed;
	}

	if(dx < 0)
		dx = -dx;
	if(dy < 0)
		dy = -dy;

	if(dx == 0 && dy == 0)
		dx = speed;

	sx = 1;
	sy = 1;

	if(randrange(s, 0, 1) == 0)
		sx = -1;
	if(randrange(s, 0, 1) == 0)
		sy = -1;

	return (dx * sx, dy * sy);
}

makebeam(s: ref IcState->ScreenSaverState, delaymax: int): IcState->ScreenBeam
{
	b: IcState->ScreenBeam;
	angle, ampbase, amp, marginx, marginy, targetx, targety: int;

	b.active = 1;
	b.delay = 0;

	if(delaymax > 0)
		b.delay = randrange(s, 0, delaymax);

	b.rx = randrange(s, s.radiusmin, s.radiusmax);
	b.ry = (b.rx * randrange(s, s.radiusypercentmin, s.radiusypercentmax)) / 100;

	if(b.rx > s.w / 3)
		b.rx = s.w / 3;
	if(b.rx < 1)
		b.rx = 1;

	if(b.ry > s.h / 4)
		b.ry = s.h / 4;
	if(b.ry < 3)
		b.ry = 3;

	angle = chooseangle(s);
	(b.dx, b.dy) = choosevector(s, angle);

	marginx = b.rx * 2;
	marginy = b.ry * 2;

	targetx = randrange(s, s.w / 5, (s.w * 4) / 5);
	targety = randrange(s, s.h / 5, (s.h * 4) / 5);

	b.x = targetx;
	b.y = targety;

	while(b.x - b.dx >= -marginx && b.x - b.dx <= s.w + marginx
	   && b.y - b.dy >= -marginy && b.y - b.dy <= s.h + marginy){
		b.x -= b.dx;
		b.y -= b.dy;
	}

	b.startx = b.x;
	b.starty = b.y;

	b.life = randrange(s, s.lifemin, s.lifemax);
	b.pathlife = b.life;

	if(abs(b.dx) >= abs(b.dy)){
		b.curveaxis = CurveAxisY;
		ampbase = b.ry;
	}else{
		b.curveaxis = CurveAxisX;
		ampbase = b.rx;
	}

	amp = (ampbase * randrange(s, s.curveminamppercent, s.curvemaxamppercent)) / 100;
	if(amp < 1)
		amp = 1;

	if(randrange(s, 0, 1) == 0)
		amp = -amp;

	b.curveamp = amp;

	return b;
}

initbeams(s: ref IcState->ScreenSaverState)
{
	i, delaymax: int;

	if(s == nil)
		return;

	s.beams = array[s.beamcount] of IcState->ScreenBeam;

	delaymax = s.lifemin / 2;
	if(delaymax < 1)
		delaymax = 1;

	for(i = 0; i < len s.beams; i++)
		s.beams[i] = makebeam(s, delaymax);
}

parabolaoffset(b: IcState->ScreenBeam): int
{
	total, passed, x, amp: int;

	total = b.pathlife;
	if(total <= 0)
		return 0;

	passed = total - b.life;
	if(passed < 0)
		passed = 0;
	if(passed > total)
		passed = total;

	x = (passed * CurveScale) / total;
	amp = b.curveamp;

	return (amp * 4 * x * (CurveScale - x)) / (CurveScale * CurveScale);
}

movebeam(s: ref IcState->ScreenSaverState, b: IcState->ScreenBeam): IcState->ScreenBeam
{
	offset, oldoffset, marginx, marginy: int;

	if(s == nil)
		return b;

	if(b.delay > 0){
		b.delay--;
		return b;
	}

	if(b.life <= 0)
		return makebeam(s, s.lifemin / 3);

	oldoffset = parabolaoffset(b);

	b.x += b.dx;
	b.y += b.dy;
	b.life--;

	offset = parabolaoffset(b);

	if(b.curveaxis == CurveAxisY)
		b.y += offset - oldoffset;
	else
		b.x += offset - oldoffset;

	marginx = b.rx * 3;
	marginy = b.ry * 3;

	if(b.x < -marginx || b.x > s.w + marginx || b.y < -marginy || b.y > s.h + marginy)
		b.life = 0;

	return b;
}

beamcoverage(b: IcState->ScreenBeam, x, y: int): int
{
	sx, sy, ox, oy, dxv, dyv, rx2, ry2, v, hits, samples: int;

	if(!b.active)
		return 0;

	if(b.delay > 0)
		return 0;

	if(b.rx <= 0 || b.ry <= 0)
		return 0;

	rx2 = (b.rx * SubCellScale) * (b.rx * SubCellScale);
	ry2 = (b.ry * SubCellScale) * (b.ry * SubCellScale);

	if(rx2 <= 0 || ry2 <= 0)
		return 0;

	hits = 0;
	samples = 0;

	for(oy = 1; oy <= 3; oy++){
		for(ox = 1; ox <= 3; ox++){
			sx = x * SubCellScale + ox;
			sy = y * SubCellScale + oy;

			dxv = sx - b.x * SubCellScale;
			dyv = sy - b.y * SubCellScale;

			v = ((dxv * dxv) * EllipseScale) / rx2
				+ ((dyv * dyv) * EllipseScale) / ry2;

			if(v <= EllipseScale)
				hits++;

			samples++;
		}
	}

	if(samples <= 0)
		return 0;

	return (hits * CoverageScale) / samples;
}

beampercent(s: ref IcState->ScreenSaverState, x, y: int): int
{
	i, cov, best, p: int;

	if(s == nil)
		return 0;

	best = 0;

	for(i = 0; i < len s.beams; i++){
		cov = beamcoverage(s.beams[i], x, y);
		if(cov > best)
			best = cov;
	}

	if(best <= 0)
		return s.shadowpercent;

	if(best >= CoverageScale)
		return 100;

	p = s.shadowpercent + ((100 - s.shadowpercent) * best) / CoverageScale;

	if(p < s.shadowpercent)
		p = s.shadowpercent;
	if(p > 100)
		p = 100;

	return p;
}

drawrenderer(state: ref IcState->AppState): int
{
	s: ref IcState->ScreenSaverState;
	r: ref IcPaint->Renderer;
	c: IcState->ScreenCell;
	x, y, i, n, p: int;

	if(state == nil || state.ui == nil || state.ui.renderer == nil)
		return -1;

	s = state.screensaver;
	if(s == nil || !s.active)
		return 0;

	if(s.snapshot == nil || s.shadow == nil)
		return -1;

	r = state.ui.renderer;

	if(r.back == nil)
		return -1;

	if(r.w != s.w || r.h != s.h)
		return -1;

	n = r.w * r.h;
	if(len r.back < n)
		return -1;

	for(y = 0; y < s.h; y++){
		for(x = 0; x < s.w; x++){
			i = idx(s.w, x, y);
			p = beampercent(s, x, y);

			if(p >= 100){
				c = s.snapshot[i];
			}else if(p <= s.shadowpercent){
				c = s.shadow[i];
			}else{
				c.ch = s.snapshot[i].ch;
				if(c.ch == "")
					c.ch = " ";
				c.code = darkencode(s.snapshot[i].code, p, s.shadowcode);
			}

			r.back[i] = mkpaintcell(c.ch, c.code);
		}
	}

	paint->flush(r);
	return 0;
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

	if(snapshot(state) < 0)
		return -1;

	s.seed = SeedBase + state.width * 97 + state.height * 131 + s.idleticks * 17;

	initbeams(s);

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

	for(i = 0; i < len s.beams; i++)
		s.beams[i] = movebeam(s, s.beams[i]);

	drawrenderer(state);
	return 1;
}