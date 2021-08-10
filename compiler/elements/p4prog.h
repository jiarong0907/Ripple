#ifndef P4PROG_H
#define P4PROG_H

#include <assert.h>


class P4PROG : public Element {
private:
	string name;
	Include include;
	ConstantList constants;

public:
	P4PROG (string name, Policy* dct, Policy* cls, Policy* cls2, Policy* mtg, string code) {
		this->name = name;
		this->dct = dct;
		this->cls = cls;
		this->cls2 = cls2;
		this->mtg = mtg;
		this->code = code;
	}

	string compile(string indent){
		return this->code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};


#endif