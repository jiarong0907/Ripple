#ifndef _BRANCH_H
#define _BRANCH_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "op.h"
#include "../utils/colors.h"

using namespace std;

//TODO: support || &&
struct condition {
	/*most predicates we have are just 'lhs op rhs'*/
	string lhs; //the predicate
	string op; // >, <, >=, <=, ==, !=, IN
	string rhs;

	/*
	*keys of IN condtion.
	*It is filled when there are more than two pred_lhs for IN condtion.
	*If that is the case, pred_lhs is empty.
	*/
	vector<string> keys;

	/*sometimes it can be more complex, 'field1 arithop field2 op rhs'*/
	bool is_complex;
	string cplx_field1;
	string cplx_field2;
	string cplx_arithop; // +,-,*,/
	string cplx_op; // <,>,<=,>=,==,!=
	string cplx_rhs;
};

//Base abstract class for filter and when
class Branch : public Op {
private:
	// conditions are connected by '||'
	vector<condition> condtions;
	/*most predicates we have are just 'lhs op rhs'*/
	string lhs; //the predicate
	string op; // >, <, >=, <=, ==, !=, IN
	string rhs;

	/*
	*keys of IN condtion.
	*It is filled when there are more than two pred_lhs for IN condtion.
	*If that is the case, pred_lhs is empty.
	*/
	vector<string> keys;

	/*sometimes it can be more complex, 'field1 arithop field2 op rhs'*/
	bool is_complex=false;
	bool is_ipset=false;
	string cplx_field1;
	string cplx_field2;
	string cplx_arithop; // +,-,*,/
	string cplx_op; // <,>,<=,>=,==,!=
	string cplx_rhs;
	uint32_t ip_start;
	uint32_t ip_end;
	friend class Policy;
	friend class Program;

public:
	Branch() {};
	void set_lhs(string lhs) { this->lhs = lhs; }
	string get_lhs() { return this->lhs; }
	void set_rhs(string rhs) { this->rhs = rhs; }
	string get_rhs() { return this->rhs; }
	void set_op(string op) { this->op = op; }
	string get_op() { return this->op; }
	void add_key(string key) { this->keys.push_back(key); }
	vector<string>* get_key() { return &(this->keys); }
	void set_complex(bool complex) { this->is_complex = complex; }
	bool get_complex() { return this->is_complex; }
	void set_cplx_field1(string cplx_field1){ this->cplx_field1 = cplx_field1; }
	string get_cplx_field1() { return this->cplx_field1; }
	void set_cplx_field2(string cplx_field2) { this->cplx_field2 = cplx_field2; }
	string get_cplx_field2() {	return this->cplx_field2; }
	void set_cplx_arithop(string cplx_arithop) { this->cplx_arithop = cplx_arithop;	}
	string get_cplx_arithop() {	return this->cplx_arithop; }
	void set_cplx_op(string cplx_op) { this->cplx_op = cplx_op;	}
	string get_cplx_op() { return this->cplx_op; }
	void set_cplx_rhs(string cplx_rhs) { this->cplx_rhs = cplx_rhs;	}
	string get_cplx_rhs() { return this->cplx_rhs; }
	void set_ipset(bool ipset) { this->is_ipset = ipset; }
	bool get_ipset() { return this->is_ipset; }
	void set_ip_start(uint32_t s) { this->ip_start=s; }
	uint32_t get_ip_start() { return this->ip_start; }
	void set_ip_end(uint32_t e) { this->ip_end=e; }
	uint32_t get_ip_end() { return this->ip_end; }
	virtual string to_string()= 0;
	virtual void print() = 0;
	virtual string get_op_name() = 0;
};

#endif