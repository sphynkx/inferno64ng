implement IcModal;

include "ic/modal.m";

EnterKey: con 10;
ReturnKey: con 13;
EscapeKey: con 27;
SpaceKey: con 32;

init()
{
}

copyconfirm(title, message, checkbox: string, checked: int): ref IcModal->Dialog
{
	d: ref IcModal->Dialog;

	d = ref IcModal->Dialog;
	d.title = title;
	d.message = array[1] of string;
	d.message[0] = message;
	d.checkbox = checkbox;
	d.checked = checked != 0;
	d.result = IcModal->ResultNone;

	return d;
}

handlekey(d: ref IcModal->Dialog, k: int): int
{
	if(d == nil)
		return IcModal->ResultCancel;

	if(k == EscapeKey){
		d.result = IcModal->ResultCancel;
		return d.result;
	}

	if(k == SpaceKey){
		d.checked = !d.checked;
		return IcModal->ResultNone;
	}

	if(k == EnterKey || k == ReturnKey){
		d.result = IcModal->ResultOk;
		return d.result;
	}

	return IcModal->ResultNone;
}