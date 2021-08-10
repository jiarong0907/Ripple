#ifndef ELEMENT_H
#define ELEMENT_H


#include <assert.h>

class Element {
public:
	Element () { }
	virtual string get_name() = 0;
	virtual string compile(string indent) = 0;
	virtual void print() = 0;
};


#endif