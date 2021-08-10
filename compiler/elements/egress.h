#ifndef EGRESS_H
#define EGRESS_H


#include <assert.h>

class Egress : public Element {
private:
	string name;

public:
	Egress (string name) { this->name = name; }
	string compile(string indent){
		string code = indent + "/*************************************************************************\n" +
					  indent + "****************  E G R E S S   P R O C E S S I N G   *******************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "control MyEgress(inout headers hdr,\n";
		code += indent + "                 inout metadata meta,\n";
		code += indent + "                 inout standard_metadata_t standard_metadata) {\n";
		code += indent + "    apply {    }\n";
		code += indent + "}\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};




#endif