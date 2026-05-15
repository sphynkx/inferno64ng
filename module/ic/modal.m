include "ic/state.m";

IcModal: module
{
	PATH: con "/dis/ic/modal.dis";

	ResultNone: con 0;
	ResultOk: con 1;
	ResultCancel: con 2;

	Dialog: adt
	{
		title: string;
		message: array of string;

		checkbox: string;
		checked: int;

		result: int;
	};

	init: fn();

	copyconfirm: fn(title, message, checkbox: string, checked: int): ref Dialog;
	handlekey: fn(d: ref Dialog, k: int): int;
};