#ifndef HEADER_H
#define HEADER_H


#include <assert.h>

#include "element.h"


class HeaderField : public Element {
private:
	string name;
	int width;

public:
	HeaderField (string name, int width) {
		this->name = name;
		this->width = width;
	}

	string compile(string indent) { return indent+"bit<"+to_string(this->width)+"> " + this->name+";\n"; }
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};

class Header : public Element  {
private:
	string name;
	vector<HeaderField> fields;
	vector<string> macros;

public:
	Header (string name) { this->name = name; }

	// header field exist
	bool name_exist(string name) {
		for (auto item : this->fields) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool field_exist(HeaderField field) {
		for (auto item : this->fields) {
			if (item.get_name() == field.get_name())
				return true;
		}
		return false;
	}

	bool macro_exist(string name) {
		for (auto item : this->macros) {
			if (item == name)
				return true;
		}
		return false;
	}

	bool add_field(HeaderField field) {
		if (field_exist(field))
			return false;
		this->fields.push_back(field);
		return true;
	}

	bool add_macro(string name) {
		if (macro_exist(name))
			return false;
		this->macros.push_back(name);
		return true;
	}

	string get_name() { return this->name;	}

	string compile(string indent) {
		string code = indent + "header " + this->name + "_t {\n";
		for (auto item : this->fields)
			code += item.compile(indent + "    ");
		for (auto item : this->macros)
			code += indent + "    " + item + "\n";
		code +="}\n\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }

};

class HeaderList : public Element {
private:
	string name;
	vector<Header> hdrs;

public:
	HeaderList (string name) { this->name = name; }

	vector<Header> get_hdrs() { return this->hdrs; }

	Header* get_header_byname(string name){
		for (Header &item : this->hdrs) {
			if (item.get_name() == name)
				return &item;
		}
		return NULL;
	}

	// header exist
	bool name_exist(string name) {
		for (auto item : this->hdrs) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool header_exist(Header hdr) {
		for (auto item : this->hdrs) {
			if (item.get_name() == hdr.get_name())
				return true;
		}
		return false;
	}

	bool add_header(Header hdr) {
		// check name conflict
		if (header_exist(hdr))
			return false;
		this->hdrs.push_back(hdr);
		return true;
	}

	void init (bool has_reroute) {
		// This is for ns3 simulation
		// Header ppp("ppp");
		// ppp.add_field(HeaderField("pppType", 16));
		// this->add_header(ppp);

		// This is for bmv2
		Header ether("ethernet");
		ether.add_field(HeaderField("dstAddr", 48));
		ether.add_field(HeaderField("srcAddr", 48));
		ether.add_field(HeaderField("etherType", 16));
		this->add_header(ether);

		Header ipv4("ipv4");
		ipv4.add_field(HeaderField("version", 4));
		ipv4.add_field(HeaderField("ihl", 4));
		ipv4.add_field(HeaderField("diffserv", 8));
		ipv4.add_field(HeaderField("totalLen", 16));
		ipv4.add_field(HeaderField("identification", 16));
		ipv4.add_field(HeaderField("flags", 3));
		ipv4.add_field(HeaderField("fragOffset", 13));
		ipv4.add_field(HeaderField("ttl", 8));
		ipv4.add_field(HeaderField("protocol", 8));
		ipv4.add_field(HeaderField("hdrChecksum", 16));
		ipv4.add_field(HeaderField("srcAddr", 32));
		ipv4.add_field(HeaderField("dstAddr", 32));
		this->add_header(ipv4);

		Header tcp("tcp");
		tcp.add_field(HeaderField("srcPort", 16));
		tcp.add_field(HeaderField("dstPort", 16));
		tcp.add_field(HeaderField("seqNo", 32));
		tcp.add_field(HeaderField("ackNo", 32));
		tcp.add_field(HeaderField("dataOffset", 4));
		tcp.add_field(HeaderField("res", 3));
		tcp.add_field(HeaderField("ecn", 3));
		tcp.add_field(HeaderField("ctrl", 6));
		tcp.add_field(HeaderField("window", 16));
		tcp.add_field(HeaderField("checksum", 16));
		tcp.add_field(HeaderField("urgentPtr", 16));
		this->add_header(tcp);

		if (has_reroute) {
			Header probe("probe");
			probe.add_field(HeaderField("seqNo", 32));
			probe.add_field(HeaderField("util", 32));
			probe.add_field(HeaderField("dstSWID", 32));
			this->add_header(probe);
		}

		// Other SYNC header fields must be added after analyzing data structure required to be sync'ed.
		Header sync("sync");
		sync.add_field(HeaderField("srcSWUID", 32));
		sync.add_field(HeaderField("seqNo", 32));
		sync.add_field(HeaderField("offset", 32));
		this->add_header(sync);
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		ifstream infile("./templates/header_separation.p4");
		assert(infile.is_open());

		string code, l;
		while (getline(infile, l))
			code += indent + l + "\n";

		for (auto item : this->hdrs)
			code += indent + item.compile("");
		code += "\n";

		code += indent + "struct headers {\n";
		for (auto item : this->hdrs)
			code += indent + "    " + item.get_name()+"_t \t" +item.get_name()+";\n";
		code +="}\n\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }
};


#endif