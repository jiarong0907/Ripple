#ifndef CLS_H
#define CLS_H


#include <assert.h>
#include "register.h"
#include "table.h"

class Cls : public Element {
private:
	string name;
	RegisterList* regs;
	TableList* tabs;
	Metadata* metadata;
	Policy* dct;
	Policy* cls;
	Policy* cls2;
	Policy* mtg;
	string code;

public:
	Cls (string name, Policy* dct, Policy* cls, Policy* cls2, Policy* mtg, string code) {
		this->name = name;
		this->dct = dct;
		this->cls = cls;
		this->cls2 = cls2;
		this->mtg = mtg;
		this->code = code;
	}

	void set_regs(RegisterList *regs) {this->regs = regs; }
	void set_tabs(TableList *tabs) {this->tabs = tabs; }
	void set_metadata(Metadata *meta) {this->metadata = meta; }

	string compile(string indent){
		return this->code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};


#endif