implement KbTest;

include "sys.m";
sys: Sys;
include "draw.m";
include "keyboard.m";

KbTest: module {
init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
sys = load Sys Sys->PATH;

# Print /dev/consinfo
cfd := sys->open("/dev/consinfo", Sys->OREAD);
if(cfd != nil) {
buf := array[1024] of byte;
n := sys->read(cfd, buf, len buf);
if(n > 0)
sys->print("=== /dev/consinfo ===\n%s\n", string buf[0:n]);
cfd = nil;
} else
sys->print("cannot open /dev/consinfo\n");

# Read keyboard events from ekeyboard
ekfd := sys->open("/dev/ekeyboard", Sys->OREAD);
if(ekfd == nil) {
sys->print("cannot open /dev/ekeyboard\n");
return;
}
sys->print("=== Key test (press keys; 'q' quits) ===\n");
sys->print("Try: F1..F12, Shift/Ctrl/Alt+Fn, arrow+modifiers\n");
sys->print("     Ins, Del with modifiers; Shift/Ctrl/Alt alone\n\n");

rbuf := array[4] of byte;
for(;;) {
n := sys->read(ekfd, rbuf, len rbuf);
if(n <= 0)
break;
s := string rbuf[0:n];
if(len s == 0)
break;
r := s[0];
name := keynm(r);
sys->print("rune=0x%x  %s\n", r, name);
if(r == 'q' || r == 'Q')
break;
}
}

keynm(r: int): string
{
if(r >= 32 && r < 127)
return sys->sprint("'%c'", r);
if(r < 32)
return sys->sprint("ctrl-%c", r + 64);
case r {
Keyboard->Esc => return "Esc";
Keyboard->BackTab => return "Shift+Tab (BackTab)";
Keyboard->Home => return "Home";
Keyboard->End => return "End";
Keyboard->Up => return "Up";
Keyboard->Down => return "Down";
Keyboard->Left => return "Left";
Keyboard->Right => return "Right";
Keyboard->Pgup => return "Pgup";
Keyboard->Pgdown => return "Pgdown";
Keyboard->Ins => return "Ins";
Keyboard->Del => return "Del";
Keyboard->LShift => return "LShift";
Keyboard->RShift => return "RShift";
Keyboard->LCtrl => return "LCtrl";
Keyboard->RCtrl => return "RCtrl";
Keyboard->LAlt => return "LAlt";
Keyboard->RAlt => return "RAlt";
Keyboard->Caps => return "Caps";
# Plain function keys
Keyboard->KF|1 => return "F1";
Keyboard->KF|2 => return "F2";
Keyboard->KF|3 => return "F3";
Keyboard->KF|4 => return "F4";
Keyboard->KF|5 => return "F5";
Keyboard->KF|6 => return "F6";
Keyboard->KF|7 => return "F7";
Keyboard->KF|8 => return "F8";
Keyboard->KF|9 => return "F9";
Keyboard->KF|10 => return "F10";
Keyboard->KF|11 => return "F11";
Keyboard->KF|12 => return "F12";
# Shift+Fn
Keyboard->KFShift|1 => return "Shift+F1";
Keyboard->KFShift|2 => return "Shift+F2";
Keyboard->KFShift|5 => return "Shift+F5";
Keyboard->KFShift|10 => return "Shift+F10";
Keyboard->KFShift|12 => return "Shift+F12";
# Ctrl+Fn
Keyboard->KFCtrl|1 => return "Ctrl+F1";
Keyboard->KFCtrl|5 => return "Ctrl+F5";
Keyboard->KFCtrl|10 => return "Ctrl+F10";
Keyboard->KFCtrl|12 => return "Ctrl+F12";
# Alt+Fn
Keyboard->KFAlt|1 => return "Alt+F1";
Keyboard->KFAlt|5 => return "Alt+F5";
Keyboard->KFAlt|12 => return "Alt+F12";
# Mixed
Keyboard->KFCtrlShift|1 => return "Ctrl+Shift+F1";
Keyboard->KFCtrlShift|5 => return "Ctrl+Shift+F5";
Keyboard->KFCtrlAlt|1 => return "Ctrl+Alt+F1";
Keyboard->KFAltShift|1 => return "Alt+Shift+F1";
# Shift+nav
Keyboard->ViewShift|(Keyboard->Up-Keyboard->View) => return "Shift+Up";
Keyboard->ViewShift|(Keyboard->Down-Keyboard->View) => return "Shift+Down";
Keyboard->ViewShift|(Keyboard->Left-Keyboard->View) => return "Shift+Left";
Keyboard->ViewShift|(Keyboard->Right-Keyboard->View) => return "Shift+Right";
Keyboard->ViewShift|(Keyboard->Home-Keyboard->View) => return "Shift+Home";
Keyboard->ViewShift|(Keyboard->End-Keyboard->View) => return "Shift+End";
Keyboard->ViewShift|(Keyboard->Pgup-Keyboard->View) => return "Shift+Pgup";
Keyboard->ViewShift|(Keyboard->Pgdown-Keyboard->View) => return "Shift+Pgdn";
# Ctrl+nav
Keyboard->ViewCtrl|(Keyboard->Up-Keyboard->View) => return "Ctrl+Up";
Keyboard->ViewCtrl|(Keyboard->Down-Keyboard->View) => return "Ctrl+Down";
Keyboard->ViewCtrl|(Keyboard->Left-Keyboard->View) => return "Ctrl+Left";
Keyboard->ViewCtrl|(Keyboard->Right-Keyboard->View) => return "Ctrl+Right";
Keyboard->ViewCtrl|(Keyboard->Home-Keyboard->View) => return "Ctrl+Home";
Keyboard->ViewCtrl|(Keyboard->End-Keyboard->View) => return "Ctrl+End";
# Alt+nav
Keyboard->ViewAlt|(Keyboard->Up-Keyboard->View) => return "Alt+Up";
Keyboard->ViewAlt|(Keyboard->Down-Keyboard->View) => return "Alt+Down";
Keyboard->ViewAlt|(Keyboard->Left-Keyboard->View) => return "Alt+Left";
Keyboard->ViewAlt|(Keyboard->Right-Keyboard->View) => return "Alt+Right";
Keyboard->ViewAlt|(Keyboard->Home-Keyboard->View) => return "Alt+Home";
Keyboard->ViewAlt|(Keyboard->End-Keyboard->View) => return "Alt+End";
# Modified Ins/Del
Keyboard->ShiftIns => return "Shift+Ins";
Keyboard->ShiftDel => return "Shift+Del";
Keyboard->CtrlIns => return "Ctrl+Ins";
Keyboard->CtrlDel => return "Ctrl+Del";
Keyboard->AltIns => return "Alt+Ins";
Keyboard->AltDel => return "Alt+Del";
Keyboard->CtrlShiftIns => return "Ctrl+Shift+Ins";
Keyboard->CtrlShiftDel => return "Ctrl+Shift+Del";
}
return sys->sprint("unknown(0x%x)", r);
}
