#ifndef CONSTANT_H
#define CONSTANT_H


#include <assert.h>

class Constant : public Element {
private:
	string name;
	int width;
	long value;

public:
	Constant (string name, int width, long value) {
		this->name = name;
		this->width = width;
		this->value = value;
	}
	string compile(string indent){
		string code = indent + "const bit<"+to_string(this->width)+">";
		code += " " + this->name;
		code += " = " + to_string(this->value) + ";\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};

class ConstantList : public Element {
private:
	string name;
	vector<Constant> consts;

public:
	ConstantList (string name) { this->name = name; }

	bool name_exist(string name) {
		for (auto item : this->consts) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool const_exist(Constant con) {
		for (auto item : this->consts) {
			if (item.get_name() == con.get_name())
				return true;
		}
		return false;
	}

	bool add_const(Constant con) {
		// check name conflict
		if (const_exist(con))
			return false;
		this->consts.push_back(con);
		return true;
	}

	void init(bool has_retoute) {
		this->add_const(Constant("TYPE_IPV4", 16, 0x0021));
		this->add_const(Constant("TCP_PROTOCOL", 8, 6));
		this->add_const(Constant("ICMP_PROTOCOL", 8, 1));
		if (has_retoute){
			this->add_const(Constant("PROBE_PROTOCOL", 8, 254));
		}
		this->add_const(Constant("SYNC_PROTOCOL", 8, 252));
		this->add_const(Constant("NUM_RAND1", 32, 51646229));
		this->add_const(Constant("NUM_RAND2", 32, 122420729));
		this->add_const(Constant("TAU", 32, 524288));
		this->add_const(Constant("THRESH_UTIL_RESET", 32, 512000));
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		string code;
		for (auto item : this->consts)
			code += item.compile(indent);
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }
};


#endif