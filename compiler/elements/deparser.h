#ifndef DEPARSER_H
#define DEPARSER_H


#include <assert.h>

#include "element.h"

class P4Deparser : public Element {
private:
	string name;
	vector<string> hdrs;

public:
	P4Deparser (string name) { this->name = name; }

	bool header_exist(string s) {
		for (auto item : this->hdrs) {
			if (item == s)
				return true;
		}
		return false;
	}

	bool add_header(string s) {
		if (header_exist(s))
			return false;
		this->hdrs.push_back(s);
		return true;
	}

	void init (bool has_reroute) {
		this->add_header("ppp");
		this->add_header("ipv4");
		this->add_header("tcp");
		if (has_reroute)
			this->add_header("probe");
		this->add_header("sync");
	}

	string get_name() {	return this->name; }
	string compile(string indent) {
		string code = indent + "/*************************************************************************\n" +
					  indent + "***********************  D E P A R S E R  *******************************\n" +
					  indent + "*************************************************************************/\n\n";
		code       += indent + "control MyDeparser(packet_out packet, in headers hdr) {\n";
		code 	   += indent + "   apply {\n";
		for (auto hdr : this->hdrs)
			code   += indent + "		packet.emit(hdr." + hdr+");\n";
		code 	   += indent + "	}\n";
		code       += indent + "}\n";
		return code;
	}
	void print() { cout<<this->compile("")<<endl;	}
};


#endif