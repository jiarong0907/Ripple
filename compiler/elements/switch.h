#ifndef SWITCH_H
#define SWITCH_H


#include <assert.h>

class Switch : public Element {
private:
	string name;

public:
	Switch (string name) { this->name = name; }
	string compile(string indent){
		string code = indent + "/*************************************************************************\n" +
					  indent + "***********************  S W I T C H  *******************************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "V1Switch(\n";
		code += indent + "MyParser(),\n";
		code += indent + "MyVerifyChecksum(),\n";
		code += indent + "MyIngress(),\n";
		code += indent + "MyEgress(),\n";
		code += indent + "MyComputeChecksum(),\n";
		code += indent + "MyDeparser()\n";
		code += indent + ") main;\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};




#endif