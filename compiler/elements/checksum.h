#ifndef CHECKSUM_H
#define CHECKSUM_H


#include <assert.h>

class ChecksumV : public Element {
private:
	string name;

public:
	ChecksumV (string name) { this->name = name; }
	string compile(string indent){
		string code = indent + "/*************************************************************************\n" +
					  indent + "************   C H E C K S U M    V E R I F I C A T I O N   *************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "control MyVerifyChecksum(inout headers hdr, inout metadata meta) {\n";
		code += indent + "    apply { }\n";
		code += indent + "}\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};


class ChecksumC : public Element {
private:
	string name;

public:
	ChecksumC (string name) { this->name = name; }
	string compile(string indent){
		string code = indent + "/*************************************************************************\n" +
					  indent + "*************   C H E C K S U M    C O M P U T A T I O N   **************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "control MyComputeChecksum(inout headers hdr, inout metadata meta) {\n";
		code += indent + "  apply {\n";
		code += indent + "    update_checksum(\n";
		code += indent + "      hdr.ipv4.isValid(),\n";
		code += indent + "      { hdr.ipv4.version,\n";
		code += indent + "        hdr.ipv4.ihl,\n";
		code += indent + "        hdr.ipv4.diffserv,\n";
		code += indent + "        hdr.ipv4.totalLen,\n";
		code += indent + "        hdr.ipv4.identification,\n";
		code += indent + "        hdr.ipv4.flags,\n";
		code += indent + "        hdr.ipv4.fragOffset,\n";
		code += indent + "        hdr.ipv4.ttl,\n";
		code += indent + "        hdr.ipv4.protocol,\n";
		code += indent + "        hdr.ipv4.srcAddr,\n";
		code += indent + "        hdr.ipv4.dstAddr },\n";
		code += indent + "        hdr.ipv4.hdrChecksum,\n";
		code += indent + "        HashAlgorithm.csum16);\n";
		code += indent + "  }\n";
		code += indent + "}\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};


#endif