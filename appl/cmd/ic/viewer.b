implement IcViewer;

include "icurses/ui.m";
include "bufio.m";
include "ic/viewer.m";

#
# IcursesApp framework module (declared locally to avoid include chain conflicts).
#
IcursesApp: module
{
PATH: con "/dis/lib/icurses/app.dis";

ScreenNormal:    con 0;
ScreenAlternate: con 1;

Options: adt
{
screenmode: int;
mouse:      int;
tickms:     int;
};

Context: adt
{
out:        ref Sys->FD;
ui:         ref IcUi->Ui;

w:          int;
h:          int;

screenmode: int;
mouse:      int;
tickms:     int;

appscreen:  int;
opened:     int;
started:    int;
};

init:        fn(name: string);
defaultopts: fn(): Options;
newctx:      fn(out: ref Sys->FD, opts: Options): ref Context;

open:        fn(c: ref Context): int;
close:       fn(c: ref Context);

ui:          fn(c: ref Context): ref IcUi->Ui;
width:       fn(c: ref Context): int;
height:      fn(c: ref Context): int;

step:        fn(c: ref Context): IcUi->Step;
draw:        fn(c: ref Context): int;
pollresize:  fn(c: ref Context, oldw, oldh: int): (int, int, int);
};

#
# IcView module (declared locally, needed for removetree on canvas rebuild).
#
IcViewMod: module
{
PATH: con "/dis/lib/icurses/view.dis";

init:       fn();
removetree: fn(t: ref IcView->Tree, id: int): int;
};

sys:     Sys;
appfw:   IcursesApp;
uimod:   IcUi;
viewmod: IcViewMod;
bufio:   Bufio;

Iobuf: import bufio;

# ID for the content canvas widget.
CanvasId: con 10;

# Local key code aliases (Icurses is already in scope via the include chain).
Kesc: con 27;
Kq:   con int 'q';

loadlines:     fn(path: string): array of string;
drawcontent:   fn(u: ref IcUi->Ui, canvasid, topline, viewh: int, lines: array of string);
setstatustext: fn(u: ref IcUi->Ui, path: string, topline, nlines: int);
buildcanvas:   fn(u: ref IcUi->Ui, w, h: int): int;

init()
{
sys = load Sys Sys->PATH;
if(sys == nil)
raise "fail:load sys";

appfw = load IcursesApp IcursesApp->PATH;
if(appfw == nil)
raise "fail:load icurses/app";

uimod = load IcUi IcUi->PATH;
if(uimod == nil)
raise "fail:load icurses/ui";

viewmod = load IcViewMod IcViewMod->PATH;
if(viewmod == nil)
raise "fail:load icurses/view";

bufio = load Bufio Bufio->PATH;
if(bufio == nil)
raise "fail:load bufio";

appfw->init("icview");
uimod->init();
viewmod->init();
}

runfile(path: string): int
{
return runfilemode(path, ModeText);
}

#
# Read a file into an array of lines.
# Returns nil if the file cannot be opened.
#
loadlines(path: string): array of string
{
b:     ref Iobuf;
lines: array of string;
tmp:   array of string;
line:  string;
n, i:  int;

b = bufio->open(path, Bufio->OREAD);
if(b == nil)
return nil;

lines = array[0] of string;
n = 0;

while((line = b.gets('\n')) != nil){
if(len line > 0 && line[len line - 1] == '\n')
line = line[0:len line - 1];

tmp = array[n + 1] of string;
for(i = 0; i < n; i++)
tmp[i] = lines[i];
tmp[n] = line;
lines = tmp;
n++;
}

b.close();

return lines;
}

#
# Paint the visible file lines onto the canvas starting from topline.
#
drawcontent(u: ref IcUi->Ui, canvasid, topline, viewh: int, lines: array of string)
{
i, row, nlines: int;

nlines = 0;
if(lines != nil)
nlines = len lines;

uimod->canvasclear(u, canvasid, " ", "0");

row = 0;
for(i = topline; i < nlines && row < viewh; i++){
uimod->canvasputs(u, canvasid, 0, row, lines[i], "0");
row++;
}
}

#
# Update the status bar with file path and current position.
#
setstatustext(u: ref IcUi->Ui, path: string, topline, nlines: int)
{
s: string;

s = path + "  [" + string (topline + 1) + "/" + string nlines + "]";
uimod->setstatus(u, s);
}

#
# (Re)build the content canvas.  Removes any existing canvas with CanvasId first
# so it can be recreated with updated dimensions on terminal resize.
# Returns the canvas id on success, -1 on failure.
#
buildcanvas(u: ref IcUi->Ui, w, h: int): int
{
rootid, viewh: int;

if(u == nil || u.tree == nil)
return -1;

# Remove previous canvas (no-op if not yet present).
viewmod->removetree(u.tree, CanvasId);

viewh = h - 2;
if(viewh < 1)
viewh = 1;

rootid = uimod->rootid(u);
return uimod->canvas(u, rootid, CanvasId, 0, 0, w, viewh);
}

#
# Open a file and display it in the terminal viewer.
# mode: ModeText (0) for text display, ModeHex (1) reserved for future hex display.
# Returns 0 on success, -1 if the file cannot be opened or the UI fails.
#
runfilemode(path: string, mode: int): int
{
ctx:             ref IcursesApp->Context;
opts:            IcursesApp->Options;
step:            IcUi->Step;
u:               ref IcUi->Ui;
lines:           array of string;
topline, nlines: int;
viewh, w, h:     int;
nw, nh, resized: int;
running:         int;

mode = mode;# reserved for future hex mode

lines = loadlines(path);
if(lines == nil)
return -1;

nlines = len lines;

opts = appfw->defaultopts();
opts.screenmode = IcursesApp->ScreenAlternate;
opts.mouse = 0;
opts.tickms = 200;

ctx = appfw->newctx(sys->fildes(1), opts);
if(ctx == nil)
return -1;

if(appfw->open(ctx) < 0)
return -1;

u = appfw->ui(ctx);
if(u == nil){
appfw->close(ctx);
return -1;
}

w = appfw->width(ctx);
h = appfw->height(ctx);

viewh = h - 2;
if(viewh < 1)
viewh = 1;

topline = 0;

if(buildcanvas(u, w, h) < 0){
appfw->close(ctx);
return -1;
}

uimod->sethelp(u, "Up/Dn/PgUp/PgDn/Home/End=scroll  q/F10=quit");

drawcontent(u, CanvasId, topline, viewh, lines);
setstatustext(u, path, topline, nlines);
appfw->draw(ctx);

running = 1;
while(running){
step = appfw->step(ctx);

if(step.done)
break;

if(step.kind == IcUi->StepKey){
case step.key {
Kq or Kesc or Icurses->Kf10 =>
running = 0;

Icurses->Kup =>
if(topline > 0)
topline--;

Icurses->Kdown =>
if(topline + viewh < nlines)
topline++;

Icurses->Kpgup =>
topline -= viewh;
if(topline < 0)
topline = 0;

Icurses->Kpgdown =>
topline += viewh;
if(topline + viewh > nlines)
topline = nlines - viewh;
if(topline < 0)
topline = 0;

Icurses->Khome =>
topline = 0;

Icurses->Kend =>
topline = nlines - viewh;
if(topline < 0)
topline = 0;
}

if(running){
drawcontent(u, CanvasId, topline, viewh, lines);
setstatustext(u, path, topline, nlines);
appfw->draw(ctx);
}
}

if(step.kind == IcUi->StepTick){
(nw, nh, resized) = appfw->pollresize(ctx, w, h);
if(resized){
w = nw;
h = nh;
viewh = h - 2;
if(viewh < 1)
viewh = 1;

buildcanvas(u, w, h);
drawcontent(u, CanvasId, topline, viewh, lines);
setstatustext(u, path, topline, nlines);
appfw->draw(ctx);
}
}
}

appfw->close(ctx);

return 0;
}
