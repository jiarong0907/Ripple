#ifndef INCLUDE_H
#define INCLUDE_H


#include <assert.h>

class Include : public Element {
private:
	string name;

public:
	Include (string name) { this->name = name; }
	string compile(string indent){
		string code = indent + "/* -*- P4_16 -*- */\n";
		// code += indent + "#include <pronet1.p4>\n";
		// code += indent + "#include \"../macro.p4\"\n";
		code += indent + "#include <core.p4>\n";
		code += indent + "#include <v1model.p4>\n";
		code += indent + "#include \"../macro.p4\"\n";
		code += indent + "#define DROP(); mark_to_drop();\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};




#endif