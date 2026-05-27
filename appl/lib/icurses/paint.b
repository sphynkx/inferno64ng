implement IcPaint;

include "icurses/paint.m";

sys: Sys;
ic: Icurses;
view: IcView;
canvas: IcCanvas;
theme: IcTheme;
glyph: IcGlyph;
textviewmod: IcTextView;

idx: fn(r: ref IcPaint->Renderer, x, y: int): int;
inrange: fn(r: ref IcPaint->Renderer, x, y: int): int;
sig: fn(ch, code: string): int;
initcell: fn(ch, code: string): IcPaint->Cell;
makecells: fn(n: int, ch, code: string): array of IcPaint->Cell;

drawnode: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawshadow: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawwindow: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawbutton: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawlabel: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawhbar: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawvbar: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawprogress: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawspinner: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawcontent: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawcanvas: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);

paramint: fn(s, key: string, def: int): int;
paramstr: fn(s, key, def: string): string;
drawtextviewline: fn(r: ref IcPaint->Renderer, x, y, w: int, text, basecode, searchcode: string, hstart, hend: int);

drawtextview: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
drawmodal: fn(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node);
split3: fn(s: string): (string, string, string);
modalbuttonlabel: fn(s: string): string;
modalbuttonw: fn(s: string): int;
modalbuttonstotalw: fn(button0, button1, button2: string, buttoncount: int): int;

styleat: fn(n: ref IcView->Node, i: int, def: string): string;
modalcode: fn(n: ref IcView->Node, kind: int): string;
modalframecode: fn(n: ref IcView->Node): string;
modaltextcode: fn(n: ref IcView->Node, bg: string): string;
modalfieldcode: fn(n: ref IcView->Node): string;
modalfocuscode: fn(n: ref IcView->Node): string;
modalbuttoncode: fn(n: ref IcView->Node): string;
modalbuttonfocuscode: fn(n: ref IcView->Node): string;

hline: fn(r: ref IcPaint->Renderer, x, y, w: int, ch, code: string);
vline: fn(r: ref IcPaint->Renderer, x, y, h: int, ch, code: string);
barfill: fn(size, value, total: int): int;
percent: fn(value, total: int): int;
percentstr: fn(value, total: int): string;
spinnerch: fn(style, frame: int): string;
samecell: fn(a, b: IcPaint->Cell): int;
putslimit: fn(r: ref IcPaint->Renderer, x, y, maxw: int, text, code: string);
shadecell: fn(r: ref IcPaint->Renderer, x, y: int, code: string);
shaderect: fn(r: ref IcPaint->Renderer, x, y, w, h: int, code: string);

wraptext: fn(text: string, width: int): array of string;
appendline: fn(a: array of string, s: string): array of string;
addword: fn(a: array of string, line, word: string, width: int): (array of string, string);

framechars: fn(style: int): array of string;
nodecode: fn(n: ref IcView->Node, def: string): string;
nodestyle: fn(n: ref IcView->Node, idx: int, def: string): string;

splitlines: fn(text: string): array of string;

CodeNormal: string;
CodeWindow: string;
CodeFrame: string;
CodeTitle: string;
CodeButton: string;
CodeFocus: string;
CodeStatus: string;
CodeScroll: string;
CodeShadow: string;
CodeModalCopy: string;
CodeModalOverwrite: string;
CodeModalFocus: string;
CodeModalButton: string;
CodeModalButtonFocus: string;

init()
{
	ci: Icurses->ConsInfo;

	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	ic = load Icurses Icurses->PATH;
	if(ic == nil)
		raise "fail:load icurses";

	view = load IcView IcView->PATH;
	if(view == nil)
		raise "fail:load icview";

	canvas = load IcCanvas IcCanvas->PATH;
	if(canvas == nil)
		raise "fail:load iccanvas";

	theme = load IcTheme IcTheme->PATH;
	if(theme == nil)
		raise "fail:load ictheme";

	glyph = load IcGlyph IcGlyph->PATH;
	if(glyph == nil)
		raise "fail:load icglyph";

	textviewmod = load IcTextView IcTextView->PATH;
	if(textviewmod == nil)
		raise "fail:load ictextview";

	ic->init();
	view->init();
	canvas->init();
	textviewmod->init();

	ci = ic->consinfo();

	theme->init(ci);
	glyph->init(ci);

	CodeNormal = theme->sgr(IcTheme->AttrNormal);
	CodeWindow = theme->sgr(IcTheme->AttrWindow);
	CodeFrame = theme->sgr(IcTheme->AttrFrame);
	CodeTitle = theme->sgr(IcTheme->AttrTitle);
	CodeButton = theme->sgr(IcTheme->AttrButton);
	CodeFocus = theme->sgr(IcTheme->AttrFocus);
	CodeStatus = theme->sgr(IcTheme->AttrStatus);
	CodeScroll = theme->sgr(IcTheme->AttrScroll);
	CodeShadow = theme->sgr(IcTheme->AttrShadow);
	CodeModalCopy = "38;2;25;25;25;48;2;210;210;210";
	CodeModalOverwrite = "38;2;40;15;35;48;2;255;185;225";
	CodeModalFocus = "1;38;2;0;0;0;48;2;170;225;255";
	CodeModalButton = "1;38;2;20;20;20;48;2;235;235;235";
	CodeModalButtonFocus = "1;38;2;0;0;0;48;2;170;225;255";
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

initcell(ch, code: string): IcPaint->Cell
{
	c: IcPaint->Cell;

	if(ch == "")
		ch = " ";
	if(code == "")
		code = CodeNormal;

	c.ch = ch;
	c.code = code;
	c.sig = sig(ch, code);

	return c;
}

makecells(n: int, ch, code: string): array of IcPaint->Cell
{
	a: array of IcPaint->Cell;
	i: int;

	if(n < 0)
		n = 0;

	a = array[n] of IcPaint->Cell;
	for(i = 0; i < n; i++)
		a[i] = initcell(ch, code);

	return a;
}

new(out: ref Sys->FD, w, h: int): ref IcPaint->Renderer
{
	r: ref IcPaint->Renderer;
	n: int;

	if(w <= 0)
		w = 1;
	if(h <= 0)
		h = 1;

	r = ref IcPaint->Renderer;
	r.out = out;
	r.w = w;
	r.h = h;
	r.framestyle = IcPaint->FrameSingle;

	n = w * h;

	r.front = makecells(n, "\001", "");
	r.back = makecells(n, " ", CodeNormal);

	if(out != nil){
		ic->resettty(out);
		ic->cleartty(out);
		ic->hidecursor(out);
	}

	return r;
}

close(r: ref IcPaint->Renderer)
{
	if(r == nil || r.out == nil)
		return;

	ic->showcursor(r.out);
	ic->resettty(r.out);
}

setframestyle(r: ref IcPaint->Renderer, style: int)
{
	if(r == nil)
		return;
	r.framestyle = style;
}

idx(r: ref IcPaint->Renderer, x, y: int): int
{
	return y * r.w + x;
}

inrange(r: ref IcPaint->Renderer, x, y: int): int
{
	if(r == nil)
		return 0;
	if(x < 0 || y < 0)
		return 0;
	if(x >= r.w || y >= r.h)
		return 0;
	return 1;
}

samecell(a, b: IcPaint->Cell): int
{
	if(a.sig != b.sig)
		return 0;
	if(a.ch != b.ch)
		return 0;
	if(a.code != b.code)
		return 0;
	return 1;
}

clear(r: ref IcPaint->Renderer)
{
	i, n: int;
	c: IcPaint->Cell;

	if(r == nil || r.back == nil)
		return;

	c = initcell(" ", CodeNormal);
	n = len r.back;
	for(i = 0; i < n; i++)
		r.back[i] = c;
}

putc(r: ref IcPaint->Renderer, x, y: int, ch, code: string)
{
	i: int;

	if(!inrange(r, x, y))
		return;

	if(ch == "")
		ch = " ";
	if(code == "")
		code = CodeNormal;

	i = idx(r, x, y);
	r.back[i] = initcell(ch, code);
}

puts(r: ref IcPaint->Renderer, x, y: int, text, code: string)
{
	i: int;

	if(r == nil || text == "")
		return;

	for(i = 0; i < len text; i++)
		putc(r, x + i, y, text[i:i+1], code);
}

putslimit(r: ref IcPaint->Renderer, x, y, maxw: int, text, code: string)
{
	i, n: int;

	if(r == nil || text == "" || maxw <= 0)
		return;

	n = len text;
	if(n > maxw)
		n = maxw;

	for(i = 0; i < n; i++)
		putc(r, x + i, y, text[i:i+1], code);
}

fillrect(r: ref IcPaint->Renderer, x, y, w, h: int, ch, code: string)
{
	xx, yy: int;

	if(r == nil)
		return;

	for(yy = 0; yy < h; yy++){
		for(xx = 0; xx < w; xx++)
			putc(r, x + xx, y + yy, ch, code);
	}
}

shadecell(r: ref IcPaint->Renderer, x, y: int, code: string)
{
	i: int;
	ch: string;

	if(!inrange(r, x, y))
		return;

	if(code == "")
		code = CodeShadow;

	i = idx(r, x, y);
	ch = r.back[i].ch;
	if(ch == "")
		ch = " ";

	r.back[i] = initcell(ch, code);
}

shaderect(r: ref IcPaint->Renderer, x, y, w, h: int, code: string)
{
	xx, yy: int;

	if(r == nil)
		return;

	if(w <= 0 || h <= 0)
		return;

	for(yy = 0; yy < h; yy++){
		for(xx = 0; xx < w; xx++)
			shadecell(r, x + xx, y + yy, code);
	}
}

hline(r: ref IcPaint->Renderer, x, y, w: int, ch, code: string)
{
	i: int;

	for(i = 0; i < w; i++)
		putc(r, x + i, y, ch, code);
}

vline(r: ref IcPaint->Renderer, x, y, h: int, ch, code: string)
{
	i: int;

	for(i = 0; i < h; i++)
		putc(r, x, y + i, ch, code);
}

barfill(size, value, total: int): int
{
	n: int;

	if(size <= 0)
		return 0;

	if(total <= 0)
		return 0;

	if(value < 0)
		value = 0;
	if(value > total)
		value = total;

	n = (value * size) / total;

	if(value > 0 && n <= 0)
		n = 1;

	if(n > size)
		n = size;

	return n;
}

percent(value, total: int): int
{
	p: int;

	if(total <= 0)
		return 0;

	if(value < 0)
		value = 0;
	if(value > total)
		value = total;

	p = (value * 100) / total;

	if(p < 0)
		p = 0;
	if(p > 100)
		p = 100;

	return p;
}

percentstr(value, total: int): string
{
	return sys->sprint("%d%%", percent(value, total));
}

spinnerch(style, frame: int): string
{
	if(frame < 0)
		frame = -frame;

	frame = frame % 4;

	if(style == IcPaint->SpinnerDots){
		if(frame == 0)
			return ".";
		if(frame == 1)
			return "o";
		if(frame == 2)
			return "O";
		return "o";
	}

	if(style == IcPaint->SpinnerLine){
		if(glyph != nil && glyph->profile() == IcGlyph->ProfileUnicode){
			if(frame == 0)
				return "◐";
			if(frame == 1)
				return "◓";
			if(frame == 2)
				return "◑";
			return "◒";
		}
	}

	if(frame == 0)
		return "-";
	if(frame == 1)
		return "/";
	if(frame == 2)
		return "|";
	return "+";
}

box(r: ref IcPaint->Renderer, x, y, w, h, style: int, code: string)
{
	f: IcGlyph->Frame;

	if(r == nil)
		return;

	if(w <= 0 || h <= 0)
		return;

	if(code == "")
		code = CodeFrame;

	if(glyph != nil)
		f = glyph->frame(style);
	else{
		f.h = "-";
		f.v = "|";
		f.nw = "+";
		f.ne = "+";
		f.sw = "+";
		f.se = "+";
	}

	if(w == 1 && h == 1){
		putc(r, x, y, f.nw, code);
		return;
	}

	if(h == 1){
		hline(r, x, y, w, f.h, code);
		return;
	}

	if(w == 1){
		vline(r, x, y, h, f.v, code);
		return;
	}

	hline(r, x, y, w, f.h, code);
	hline(r, x, y + h - 1, w, f.h, code);
	vline(r, x, y, h, f.v, code);
	vline(r, x + w - 1, y, h, f.v, code);

	putc(r, x, y, f.nw, code);
	putc(r, x + w - 1, y, f.ne, code);
	putc(r, x, y + h - 1, f.sw, code);
	putc(r, x + w - 1, y + h - 1, f.se, code);
}

hbar(r: ref IcPaint->Renderer, x, y, w, value, total: int, code: string)
{
	i, n: int;
	ch: string;

	if(r == nil)
		return;

	if(w <= 0)
		return;

	if(code == "")
		code = CodeScroll;

	if(glyph != nil)
		ch = glyph->block(1);
	else
		ch = "#";

	n = barfill(w, value, total);

	for(i = 0; i < w; i++){
		if(i < n)
			putc(r, x + i, y, ch, code);
		else
			putc(r, x + i, y, " ", CodeNormal);
	}
}

vbar(r: ref IcPaint->Renderer, x, y, h, value, total: int, code: string)
{
	i, n: int;
	ch: string;

	if(r == nil)
		return;

	if(h <= 0)
		return;

	if(code == "")
		code = CodeScroll;

	if(glyph != nil)
		ch = glyph->block(1);
	else
		ch = "#";

	n = barfill(h, value, total);

	for(i = 0; i < h; i++){
		if(i >= h - n)
			putc(r, x, y + i, ch, code);
		else
			putc(r, x, y + i, " ", CodeNormal);
	}
}

framechars(style: int): array of string
{
	a: array of string;
	f: IcGlyph->Frame;

	a = array[6] of string;

	if(glyph != nil){
		f = glyph->frame(style);

		a[0] = f.h;
		a[1] = f.v;
		a[2] = f.nw;
		a[3] = f.ne;
		a[4] = f.sw;
		a[5] = f.se;

		return a;
	}

	a[0] = "-";
	a[1] = "|";
	a[2] = "+";
	a[3] = "+";
	a[4] = "+";
	a[5] = "+";

	return a;
}

appendline(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(a == nil){
		b = array[1] of string;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;
	for(i = 0; i < n; i++)
		b[i] = a[i];
	b[n] = s;

	return b;
}

addword(a: array of string, line, word: string, width: int): (array of string, string)
{
	if(width <= 0)
		width = 1;

	if(line == "")
		return (a, word);

	if(len line + 1 + len word <= width)
		return (a, line + " " + word);

	a = appendline(a, line);
	return (a, word);
}

wraptext(text: string, width: int): array of string
{
	a: array of string;
	i, start: int;
	line, word: string;

	if(width <= 0)
		width = 1;

	a = array[0] of string;
	line = "";
	word = "";

	for(i = 0; i < len text; i++){
		if(text[i] == '\n'){
			if(word != ""){
				(a, line) = addword(a, line, word, width);
				word = "";
			}
			a = appendline(a, line);
			line = "";
			continue;
		}

		if(text[i] == ' ' || text[i] == '\t' || text[i] == '\r'){
			if(word != ""){
				(a, line) = addword(a, line, word, width);
				word = "";
			}
			continue;
		}

		start = i;
		while(i < len text && text[i] != ' ' && text[i] != '\t' && text[i] != '\r' && text[i] != '\n')
			i++;

		word = text[start:i];
		i--;

		if(len word > width){
			if(line != ""){
				a = appendline(a, line);
				line = "";
			}

			start = 0;
			while(start < len word){
				i = start + width;
				if(i > len word)
					i = len word;
				a = appendline(a, word[start:i]);
				start = i;
			}
			word = "";
		}
	}

	if(word != "")
		(a, line) = addword(a, line, word, width);

	if(line != "")
		a = appendline(a, line);

	if(len a == 0)
		a = appendline(a, "");

	return a;
}

drawcontent(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, h, cw, ch, i, start, total, barx, thumb: int;
	lines: array of string;
	content: string;
	sb: IcGlyph->Scrollbar;

	if(r == nil || t == nil || n == nil)
		return;

	content = view->getcontent(n);
	if(content == "")
		return;

	x = view->absx(t, n) + 1;
	y = view->absy(t, n) + 1;
	w = n.w - 2;
	h = n.h - 2;

	if(w <= 0 || h <= 0)
		return;

	cw = w;
	ch = h;

	if(n.scroll == IcView->ScrollBar && cw > 1)
		cw--;

	lines = wraptext(content, cw);
	total = len lines;

	start = 0;
	if(n.scroll != IcView->ScrollClip)
		start = n.scrollpos;

	if(start < 0)
		start = 0;
	if(start >= total)
		start = total - 1;
	if(start < 0)
		start = 0;

	for(i = 0; i < ch; i++){
		if(start + i >= total)
			break;
		putslimit(r, x, y + i, cw, lines[start + i], CodeWindow);
	}

	if(n.scroll == IcView->ScrollBar && total > ch){
		barx = x + cw;

		if(glyph != nil)
			sb = glyph->scrollbar();
		else{
			sb.v = "|";
			sb.h = "-";
			sb.thumb = "#";
		}

		vline(r, barx, y, ch, sb.v, CodeScroll);

		thumb = y;
		if(total > 0)
			thumb = y + (start * ch) / total;
		if(thumb < y)
			thumb = y;
		if(thumb >= y + ch)
			thumb = y + ch - 1;

		putc(r, barx, thumb, sb.thumb, CodeScroll);
	}
}

drawcanvas(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	c: ref IcCanvas->Canvas;
	cc: IcCanvas->Cell;
	x, y, w, h, xx, yy: int;

	if(r == nil || t == nil || n == nil)
		return;

	if(canvas == nil)
		return;

	c = canvas->find(n.id);
	if(c == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;
	h = n.h;

	if(w > canvas->w(c))
		w = canvas->w(c);
	if(h > canvas->h(c))
		h = canvas->h(c);

	for(yy = 0; yy < h; yy++){
		for(xx = 0; xx < w; xx++){
			cc = canvas->cell(c, xx, yy);
			putc(r, x + xx, y + yy, cc.ch, cc.code);
		}
	}
}

paramint(s, key: string, def: int): int
{
	i, j, v, ok, sign: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		sign = 1;
		if(j < len s && s[j] == '-'){
			sign = -1;
			j++;
		}

		v = 0;
		ok = 0;
		while(j < len s && s[j] >= '0' && s[j] <= '9'){
			v = v * 10 + int s[j] - int '0';
			j++;
			ok = 1;
		}

		if(ok)
			return sign * v;

		return def;
	}

	return def;
}

paramstr(s, key, def: string): string
{
	i, j: int;
	prefix: string;

	prefix = key + "=";

	for(i = 0; i < len s; i++){
		if(i > 0 && s[i - 1] != '\n')
			continue;

		if(i + len prefix > len s)
			continue;

		if(s[i:i + len prefix] != prefix)
			continue;

		j = i + len prefix;
		while(j < len s && s[j] != '\n' && s[j] != '\r')
			j++;

		if(j > i + len prefix)
			return s[i + len prefix:j];

		return def;
	}

	return def;
}

drawtextviewline(r: ref IcPaint->Renderer, x, y, w: int, text, basecode, searchcode: string, hstart, hend: int)
{
	i, n: int;
	code: string;

	if(r == nil || w <= 0)
		return;

	if(basecode == "")
		basecode = CodeNormal;

	if(searchcode == "")
		searchcode = basecode;

	n = len text;
	if(n > w)
		n = w;

	for(i = 0; i < n; i++){
		code = basecode;
		if(i >= hstart && i < hend)
			code = searchcode;

		putc(r, x + i, y, text[i:i + 1], code);
	}
}

drawtextview(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, h, row, lineidx, leftcol: int;
	searchline, searchstart, searchend, hstart, hend: int;
	content, code, searchcode: string;
	lines: array of string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;
	h = n.h;

	if(w <= 0 || h <= 0)
		return;

	content = view->getcontent(n);
	lines = splitlines(content);

	code = view->getcode(n);
	if(code == "")
		code = CodeWindow;

	fillrect(r, x, y, w, h, " ", code);

	lineidx = n.iarg0;
	leftcol = n.iarg1;
	if(lineidx < 0)
		lineidx = 0;
	if(leftcol < 0)
		leftcol = 0;

	searchline = paramint(n.sarg, "search_line", -1);
	searchstart = paramint(n.sarg, "search_start", -1);
	searchend = paramint(n.sarg, "search_end", -1);
	searchcode = paramstr(n.sarg, "search_code", "");

	for(row = 0; row < h; row++){
		if(lineidx + row >= len lines)
			break;

		if(leftcol >= len lines[lineidx + row])
			continue;

		hstart = -1;
		hend = -1;

		if(lineidx + row == searchline && searchstart >= 0 && searchend > searchstart){
			hstart = searchstart - leftcol;
			hend = searchend - leftcol;

			if(hstart < 0)
				hstart = 0;
			if(hend > w)
				hend = w;
		}

		drawtextviewline(r, x, y + row, w, lines[lineidx + row][leftcol:], code, searchcode, hstart, hend);
	}
}

nodecode(n: ref IcView->Node, def: string): string
{
	if(n != nil && n.code != "")
		return n.code;

	return def;
}

nodestyle(n: ref IcView->Node, idx: int, def: string): string
{
	if(n != nil && n.styles != nil && idx >= 0 && idx < len n.styles && n.styles[idx] != "")
		return n.styles[idx];

	return def;
}

drawshadow(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, h: int;
	code: string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;
	h = n.h;

	if(w <= 0 || h <= 0)
		return;

	code = view->getcode(n);
	if(code == "")
		code = CodeShadow;

	shaderect(r, x, y, w, h, code);
}

drawwindow(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, h, tx, style: int;
	title, windowcode, framecode, titlecode: string;
	fc: array of string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;
	h = n.h;

	if(w < 4 || h < 3)
		return;

	style = r.framestyle;
	if(n.frame != IcView->FrameDefault)
		style = n.frame;

	fc = framechars(style);

	windowcode = nodecode(n, CodeWindow);
	framecode = nodestyle(n, 0, CodeFrame);
	titlecode = nodestyle(n, 1, CodeTitle);

	fillrect(r, x, y, w, h, " ", windowcode);

	hline(r, x, y, w, fc[0], framecode);
	hline(r, x, y + h - 1, w, fc[0], framecode);
	vline(r, x, y, h, fc[1], framecode);
	vline(r, x + w - 1, y, h, fc[1], framecode);

	putc(r, x, y, fc[2], framecode);
	putc(r, x + w - 1, y, fc[3], framecode);
	putc(r, x, y + h - 1, fc[4], framecode);
	putc(r, x + w - 1, y + h - 1, fc[5], framecode);

	title = view->gettext(n);
	if(title != ""){
		tx = x + 2;
		if(tx < x + w - 1)
			putslimit(r, tx, y, w - 4, title, titlecode);
	}

	drawcontent(r, t, n);
}

drawbutton(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w: int;
	label, s, code: string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;

	if(w <= 0)
		w = len view->gettext(n) + 4;

	label = view->gettext(n);
	if(label == "")
		label = sys->sprint("%d", n.id);

	if(n.hotkey != "")
		s = "[" + n.hotkey + "] " + label;
	else
		s = "[ " + label + " ]";

	if(view->focusid(t) == n.id)
		code = CodeFocus;
	else
		code = CodeButton;

	fillrect(r, x, y, w, 1, " ", code);
	putslimit(r, x, y, w, s, code);
}

drawlabel(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w: int;
	text, code: string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;

	if(w <= 0)
		w = len view->gettext(n);
	if(w <= 0)
		return;

	text = view->gettext(n);
	code = view->getcode(n);
	if(code == "")
		code = CodeWindow;

	fillrect(r, x, y, w, 1, " ", code);
	putslimit(r, x, y, w, text, code);
}

drawhbar(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, value, total: int;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;

	if(w <= 0)
		return;

	value = n.iarg0;
	total = n.iarg1;
	if(total <= 0)
		total = 100;

	hbar(r, x, y, w, value, total, CodeScroll);
}

drawvbar(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, h, value, total: int;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	h = n.h;

	if(h <= 0)
		return;

	value = n.iarg0;
	total = n.iarg1;
	if(total <= 0)
		total = 100;

	vbar(r, x, y, h, value, total, CodeScroll);
}

drawprogress(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, value, total, style, barw, inner, fill, i, tailw, pstart: int;
	p, ch: string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;

	if(w < 3)
		return;

	value = n.iarg0;
	total = n.iarg1;
	style = n.iarg2;

	if(total <= 0)
		total = 100;

	fillrect(r, x, y, w, 1, " ", CodeWindow);

	barw = w;
	inner = w - 2;
	fill = 0;
	if(inner > 0)
		fill = barfill(inner, value, total);

	if(glyph != nil)
		ch = glyph->block(1);
	else
		ch = "#";

	if(style == IcPaint->ProgressSolid){
		if(w >= 2){
			putc(r, x, y, "[", CodeFrame);
			putc(r, x + w - 1, y, "]", CodeFrame);
			for(i = 0; i < inner; i++){
				if(i < fill)
					putc(r, x + 1 + i, y, ch, CodeFocus);
				else
					putc(r, x + 1 + i, y, " ", CodeWindow);
			}
		}
		return;
	}

	p = percentstr(value, total);

	if(style == IcPaint->ProgressText){
		putslimit(r, x, y, w, p, CodeTitle);
		return;
	}

	if(style == IcPaint->ProgressPercent){
		if(w >= 2){
			putc(r, x, y, "[", CodeFrame);
			putc(r, x + w - 1, y, "]", CodeFrame);
			for(i = 0; i < inner; i++){
				if(i < fill)
					putc(r, x + 1 + i, y, ch, CodeFocus);
				else
					putc(r, x + 1 + i, y, " ", CodeWindow);
			}
			pstart = x + 1 + (inner - len p) / 2;
			if(pstart < x + 1)
				pstart = x + 1;
			putslimit(r, pstart, y, inner, p, CodeTitle);
		}
		return;
	}

	tailw = w - barw;
	if(style == IcPaint->ProgressTail && tailw > 0)
		putslimit(r, x + barw, y, tailw, p, CodeTitle);
}

drawspinner(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, frame, style: int;
	ch: string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);

	frame = n.iarg0;
	style = n.iarg1;

	ch = spinnerch(style, frame);

	putc(r, x, y, ch, CodeTitle);
}

split3(s: string): (string, string, string)
{
	i, j: int;
	a, b, c: string;

	a = s;
	b = "";
	c = "";

	for(i = 0; i < len s; i++){
		if(s[i] == '\n'){
			a = s[0:i];
			j = i + 1;
			b = s[j:];
			for(; j < len s; j++){
				if(s[j] == '\n'){
					b = s[i + 1:j];
					c = s[j + 1:];
					return (a, b, c);
				}
			}
			return (a, b, c);
		}
	}

	return (a, b, c);
}

modalbuttonlabel(s: string): string
{
	return "[" + s + "]";
}

modalbuttonw(s: string): int
{
	return len modalbuttonlabel(s);
}

modalbuttonstotalw(button0, button1, button2: string, buttoncount: int): int
{
	w: int;

	w = 0;
	if(buttoncount > 0)
		w += modalbuttonw(button0);
	if(buttoncount > 1)
		w += 2 + modalbuttonw(button1);
	if(buttoncount > 2)
		w += 2 + modalbuttonw(button2);

	return w;
}

styleat(n: ref IcView->Node, i: int, def: string): string
{
	if(n == nil || n.styles == nil)
		return def;
	if(i < 0 || i >= len n.styles)
		return def;
	if(n.styles[i] == "")
		return def;
	return n.styles[i];
}

modalcode(n: ref IcView->Node, kind: int): string
{
	if(kind == 2)
		return styleat(n, 1, CodeModalOverwrite);
	return styleat(n, 0, CodeModalCopy);
}

modalframecode(n: ref IcView->Node): string
{
	return styleat(n, 2, CodeFrame);
}

modaltextcode(n: ref IcView->Node, bg: string): string
{
	code: string;

	code = styleat(n, 3, "");
	if(code != "")
		return code;

	if(bg != "")
		return bg;

	return CodeWindow;
}

modalfieldcode(n: ref IcView->Node): string
{
	return styleat(n, 4, CodeWindow);
}

modalfocuscode(n: ref IcView->Node): string
{
	return styleat(n, 5, CodeModalFocus);
}

modalbuttoncode(n: ref IcView->Node): string
{
	return styleat(n, 6, CodeModalButton);
}

modalbuttonfocuscode(n: ref IcView->Node): string
{
	return styleat(n, 7, CodeModalButtonFocus);
}

drawmodal(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	x, y, w, h, kind, checked, focus, buttoncount, liney, bx, bw, totalw: int;
	title, message, inputlabel, input, checkbox, button0, button1, button2: string;
	bg, framecode, textcode, fieldcode, fcode, bcode, bfcode: string;
	parts: array of string;
	lines: array of string;
	i: int;
	fc: array of string;

	if(r == nil || t == nil || n == nil)
		return;

	x = view->absx(t, n);
	y = view->absy(t, n);
	w = n.w;
	h = n.h;

	if(w < 4 || h < 3)
		return;

	title = n.text;
	message = n.content;
	inputlabel = n.code;
	input = n.hotkey;
	checkbox = n.command;
	buttoncount = n.targetid;
	checked = n.iarg0;
	focus = n.iarg1;
	kind = n.iarg2;

	(button0, button1, button2) = split3(n.sarg);

	bg = modalcode(n, kind);
	framecode = modalframecode(n);
	textcode = modaltextcode(n, bg);
	fieldcode = modalfieldcode(n);
	fcode = modalfocuscode(n);
	bcode = modalbuttoncode(n);
	bfcode = modalbuttonfocuscode(n);

	fillrect(r, x, y, w, h, " ", bg);

	fc = framechars(IcPaint->FrameSingle);
	hline(r, x, y, w, fc[0], framecode);
	hline(r, x, y + h - 1, w, fc[0], framecode);
	vline(r, x, y, h, fc[1], framecode);
	vline(r, x + w - 1, y, h, fc[1], framecode);
	putc(r, x, y, fc[2], framecode);
	putc(r, x + w - 1, y, fc[3], framecode);
	putc(r, x, y + h - 1, fc[4], framecode);
	putc(r, x + w - 1, y + h - 1, fc[5], framecode);

	if(title != "")
		putslimit(r, x + 2, y, w - 4, " " + title + " ", CodeTitle);

	liney = y + 2;
	lines = wraptext(message, w - 4);
	for(i = 0; i < len lines && liney < y + h - 2; i++){
		putslimit(r, x + 2, liney, w - 4, lines[i], textcode);
		liney++;
	}

	if(inputlabel != "" && liney < y + h - 2){
		putslimit(r, x + 2, liney, w - 4, inputlabel, textcode);
		liney++;
		if(liney < y + h - 2){
			fillrect(r, x + 2, liney, w - 4, 1, " ", fieldcode);
			if(focus == 4)
				putslimit(r, x + 2, liney, w - 4, input, fcode);
			else
				putslimit(r, x + 2, liney, w - 4, input, fieldcode);
			liney++;
		}
	}

	if(checkbox != "" && liney < y + h - 2){
		if(checked)
			checkbox = "[x] " + checkbox;
		else
			checkbox = "[ ] " + checkbox;

		if(focus == 0)
			putslimit(r, x + 2, liney, w - 4, checkbox, fcode);
		else
			putslimit(r, x + 2, liney, w - 4, checkbox, textcode);

		liney++;
	}

	totalw = modalbuttonstotalw(button0, button1, button2, buttoncount);
	bx = x + (w - totalw) / 2;
	if(bx < x + 2)
		bx = x + 2;

	if(buttoncount > 0){
		bw = modalbuttonw(button0);
		parts = array[] of { modalbuttonlabel(button0) };
		if(focus == 1)
			putslimit(r, bx, y + h - 2, bw, parts[0], bfcode);
		else
			putslimit(r, bx, y + h - 2, bw, parts[0], bcode);
		bx += bw + 2;
	}

	if(buttoncount > 1){
		bw = modalbuttonw(button1);
		parts = array[] of { modalbuttonlabel(button1) };
		if(focus == 2)
			putslimit(r, bx, y + h - 2, bw, parts[0], bfcode);
		else
			putslimit(r, bx, y + h - 2, bw, parts[0], bcode);
		bx += bw + 2;
	}

	if(buttoncount > 2){
		bw = modalbuttonw(button2);
		parts = array[] of { modalbuttonlabel(button2) };
		if(focus == 3)
			putslimit(r, bx, y + h - 2, bw, parts[0], bfcode);
		else
			putslimit(r, bx, y + h - 2, bw, parts[0], bcode);
	}
}

drawnode(r: ref IcPaint->Renderer, t: ref IcView->Tree, n: ref IcView->Node)
{
	i: int;
	c: ref IcView->Node;

	if(r == nil || t == nil || n == nil)
		return;

	if(!view->isvisibletree(t, n.id))
		return;

	if(n.kind == "shadow")
		drawshadow(r, t, n);
	else if(n.kind == "canvas")
		drawcanvas(r, t, n);
	else if(n.kind == "textview")
		drawtextview(r, t, n);
	else if(n.kind == "window")
		drawwindow(r, t, n);
	else if(n.kind == "button")
		drawbutton(r, t, n);
	else if(n.kind == "label")
		drawlabel(r, t, n);
	else if(n.kind == "hbar")
		drawhbar(r, t, n);
	else if(n.kind == "vbar")
		drawvbar(r, t, n);
	else if(n.kind == "progress")
		drawprogress(r, t, n);
	else if(n.kind == "spinner")
		drawspinner(r, t, n);
	else if(n.kind == "modal")
		drawmodal(r, t, n);

	for(i = 0; i < len n.children; i++){
		c = view->find(t, n.children[i]);
		drawnode(r, t, c);
	}
}

drawtree(r: ref IcPaint->Renderer, t: ref IcView->Tree)
{
	if(r == nil || t == nil)
		return;

	drawnode(r, t, view->root(t));
}

status(r: ref IcPaint->Renderer, row: int, text: string)
{
	if(r == nil)
		return;

	if(row < 0 || row >= r.h)
		return;

	fillrect(r, 0, row, r.w, 1, " ", CodeStatus);
	putslimit(r, 0, row, r.w, text, CodeStatus);
}

flush(r: ref IcPaint->Renderer)
{
	x, y, i: int;
	code, s: string;
	changed: int;

	if(r == nil || r.out == nil)
		return;

	for(y = 0; y < r.h; y++){
		changed = 0;

		for(x = 0; x < r.w; x++){
			i = idx(r, x, y);
			if(!samecell(r.front[i], r.back[i])){
				changed = 1;
				break;
			}
		}

		if(!changed)
			continue;

		x = 0;
		while(x < r.w){
			i = idx(r, x, y);
			code = r.back[i].code;
			s = "";

			while(x < r.w){
				i = idx(r, x, y);

				if(r.back[i].code != code)
					break;

				s += r.back[i].ch;
				r.front[i] = r.back[i];
				x++;
			}

			ic->cup(r.out, y + 1, x - len s + 1);
			ic->sgr(r.out, code);
			sys->fprint(r.out, "%s", s);
		}
	}

	ic->resettty(r.out);
}

canvasnew(id: int, w, h: int): int
{
	c: ref IcCanvas->Canvas;

	if(canvas == nil)
		return -1;

	c = canvas->newcanvas(id, w, h);
	if(c == nil)
		return -1;

	return 0;
}

canvasclear(id: int, ch, code: string): int
{
	c: ref IcCanvas->Canvas;

	if(canvas == nil)
		return -1;

	c = canvas->find(id);
	if(c == nil)
		return -1;

	canvas->clear(c, ch, code);
	return 0;
}

canvasfill(id: int, x, y, w, h: int, ch, code: string): int
{
	c: ref IcCanvas->Canvas;

	if(canvas == nil)
		return -1;

	c = canvas->find(id);
	if(c == nil)
		return -1;

	canvas->fillrect(c, x, y, w, h, ch, code);
	return 0;
}

canvasputc(id: int, x, y: int, ch, code: string): int
{
	c: ref IcCanvas->Canvas;

	if(canvas == nil)
		return -1;

	c = canvas->find(id);
	if(c == nil)
		return -1;

	canvas->putc(c, x, y, ch, code);
	return 0;
}

canvasputs(id: int, x, y: int, text, code: string): int
{
	c: ref IcCanvas->Canvas;

	if(canvas == nil)
		return -1;

	c = canvas->find(id);
	if(c == nil)
		return -1;

	canvas->puts(c, x, y, text, code);
	return 0;
}

splitlines(text: string): array of string
{
	a: array of string;
	i, start: int;

	a = array[0] of string;
	start = 0;

	for(i = 0; i <= len text; i++){
		if(i < len text && text[i] != '\n')
			continue;

		a = appendline(a, text[start:i]);
		start = i + 1;
	}

	if(len a == 0)
		a = appendline(a, "");

	return a;
}