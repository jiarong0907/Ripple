#ifndef PARSER_H
#define PARSER_H


#include <assert.h>

#include "element.h"

class TransitionRule : public Element {
private:
	string name;
	string key;
	string action;

public:
	TransitionRule (string name, string key, string action) {
		this->name = name;
		this->key = key;
		this->action = action;
	}
	string get_name() {	return this->name; }
	string get_key() { return this->key; }
	string get_action() { return this->action; }
	string compile(string indent) { return indent + this->key + " : " + this->action+";\n";	}
	void print() { cout<<this->compile("")<<endl;	}
};


class Transition : public Element {
private:
	string name;
	string select_field;
	vector<TransitionRule> rules;
	bool has_default;

public:
	Transition () {}

	Transition (string name, string select_field,  bool has_default=false) {
		this->name = name;
		this->select_field = select_field;
		this->has_default = has_default;
	}

	Transition (string name, string select_field, vector<TransitionRule> rules, bool has_default=false) {
		this->name = name;
		this->select_field = select_field;
		this->rules = rules;
		this->has_default = has_default;
	}

	bool rule_exist(TransitionRule r) {
		for (auto item : this->rules) {
			if (item.get_key() == r.get_key() && item.get_action() == r.get_action())
				return true;
		}
		return false;
	}

	bool add_rule(TransitionRule r) {
		if (rule_exist(r))
			return false;
		this->rules.push_back(r);
		return true;
	}

	string get_name() {	return this->name; }
	string compile(string indent) {
		string code = indent + "transition select(" + select_field + ") {\n";
		for (auto item : rules)
			code += item.compile(indent + "    ");
		if (this->has_default)
			code += indent + "    default: accept;\n";
		code += indent + "}\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl;	}
};


class ParseState : public Element {
private:
	string name;
	Transition tran;
	bool is_start;
	bool is_accept;

public:
	ParseState (string name, bool is_start=true, bool is_accept=false) {
		this->name = name;
		this->is_start = is_start;
		this->is_accept = is_accept;
	}
	ParseState (string name, Transition tran, bool is_start=false, bool is_accept=false) {
		this->name = name;
		this->tran = tran;
		this->is_start = is_start;
		this->is_accept = is_accept;
	}
	Transition* get_trans() { return &tran; }
	string get_name() {	return this->name; }
	string compile(string indent) {
		if (this->is_start) {
			string code = indent + "state start {\n";
			code       += indent + "    transition parse_ppp;\n";
			code       += indent + "}\n";
			return code;
		}
		string code = indent + "state parse_" + this->name + " {\n";
		code += indent + "    packet.extract(hdr." + this->name + ");\n";
		if (this->is_accept) code += indent + "    transition accept;\n";
		else                 code += this->tran.compile(indent + "    ");
		code += indent + "}\n";
		return code;
	}
	void print() { cout<<this->compile("")<<endl; }
};


class P4Parser : public Element {
private:
	string name;
	vector<ParseState> states;

public:
	P4Parser (string name) { this->name = name; }
	P4Parser (string name, vector<ParseState> states) {
		this->name = name;
		this->states = states;
	}

	bool state_exist(ParseState s) {
		for (auto item : this->states) {
			if (item.get_name() == s.get_name())
				return true;
		}
		return false;
	}

	bool add_state(ParseState s) {
		if (state_exist(s))
			return false;
		this->states.push_back(s);
		return true;
	}

	ParseState* get_state_byname(string name) {
		for (auto &item : states) {
			if (item.get_name() == name)
				return &item;
		}
		return NULL;
	}

	void init (bool has_reroute) {
		ParseState start_state("start", true);
		this->add_state(start_state);

		Transition ppp_trans("ppp_trans", "hdr.ppp.pppType", true);
		ppp_trans.add_rule(TransitionRule("ppp_trans1", "TYPE_IPV4", "parse_ipv4"));
		ParseState ppp_state("ppp", ppp_trans);
		this->add_state(ppp_state);

		Transition ipv4_trans("ipv4_trans", "hdr.ipv4.protocol", true);
		ipv4_trans.add_rule(TransitionRule("ipv4_trans1", "TCP_PROTOCOL", "parse_tcp"));
		ipv4_trans.add_rule(TransitionRule("ipv4_trans2", "SYNC_PROTOCOL", "parse_sync"));
		ParseState ipv4_state("ipv4", ipv4_trans);
		this->add_state(ipv4_state);

		ParseState tcp_state("tcp", false, true);
		this->add_state(tcp_state);

		if (has_reroute) {
			ParseState probe_state("probe", false, true);
			this->add_state(probe_state);

			assert(this->get_state_byname("ipv4"));
			this->get_state_byname("ipv4")->get_trans()
					->add_rule(TransitionRule("ipv4_trans3", "PROBE_PROTOCOL", "parse_probe"));
		}

		// Other SYNC header fields must be added after analyzing data structure required to be sync'ed.
		ParseState sync_state("sync", false, true);
		this->add_state(sync_state);
	}

	string get_name() {	return this->name; }
	string compile(string indent) {
		string code = indent + "/*************************************************************************\n" +
					  indent + "*********************** P A R S E R  ***********************************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "parser MyParser(packet_in packet,\n";
		code 	   += indent + "                out headers hdr,\n";
		code 	   += indent + "                inout metadata meta,\n";
		code 	   += indent + "                inout standard_metadata_t standard_metadata) {\n\n";
		for (auto item : states)
			code += item.compile(indent + "    ")+"\n";
		code += indent + "}\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl;	}
};


#endif