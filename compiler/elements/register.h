#ifndef REGISTER_H
#define REGISTER_H


#include <assert.h>

#include "element.h"

class Register : public Element {
private:
	string name;
	int width;
	int size;

public:
	Register (string name, int width, int size) {
		this->name = name;
		this->width = width;
		this->size = size;
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		string code = indent + "register";
		code += " <bit<"+to_string(this->width)+">>";
		code += "("+to_string(this->size)+")";
		code += " " + this->name+";\n";

		return code;
	}

	void print() { cout<<this->compile("")<<endl;	}
};

class RegisterList : public Element {
private:
	string name;
	vector<Register> regs;

public:
	RegisterList (string name) { this->name = name; }

	bool name_exist(string name) {
		for (auto item : this->regs) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool register_exist(Register reg) {
		for (auto item : this->regs) {
			if (item.get_name() == reg.get_name())
				return true;
		}
		return false;
	}

	bool add_register(Register reg) {
		// check name conflict
		if (register_exist(reg))
			return false;
		this->regs.push_back(reg);
		return true;
	}

	void init (bool has_reroute) {
		this->add_register(Register("d_swid", 32, 1));
		this->add_register(Register("link_thresh", 32, 65536));
		this->add_register(Register("d_link_util", 32, 65536));
		this->add_register(Register("d_link_last_ts", 48, 65536));
		this->add_register(Register("d_wind_last_ts", 48, 1));
		if (has_reroute){
			this->add_register(Register("probe_seqNo", 32, 1024));
			this->add_register(Register("best_util", 32, 1024));
			this->add_register(Register("best_path", 32, 1024));
			this->add_register(Register("reroute", 32, 1));
		}
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		string code;
		for (auto item : this->regs)
			code += item.compile(indent);
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }
};


#endif