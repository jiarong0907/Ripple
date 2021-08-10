#ifndef _WHEN_H
#define _WHEN_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "../utils/colors.h"
#include "branch.h"

using namespace std;

class When : public Branch {
private:
	string func;
	bool has_empty=false;
	friend class Policy;
	friend class Program;

public:
	When() {};
	void set_func(string func) { this->func = func; }
	string get_func() { return this->func; }
	bool get_empty() { return this->has_empty; }
	string to_string() {
		string ans;
		if (!this->get_complex()) {
			if (this->get_key()->size() == 0) {
				ans += "pred:  ";
				ans += this->get_lhs() + " ";
				ans += this->get_op() + " ";
				ans += this->get_rhs() + "\n";
			}else {
				ans += "pred: ";
				for (string key : *(this->get_key())) {
					ans += key;
					ans += " ";
				}
				ans += this->get_op() + " ";
				ans += this->get_rhs() + "\n";
			}
		} else {
			ans += "complex pred: ";
			ans += this->get_cplx_field1() + " ";
			ans += this->get_cplx_arithop() + " ";
			ans += this->get_cplx_field2() + " ";
			ans += this->get_cplx_op() + " ";
			ans += this->get_cplx_rhs() + "\n";
		}
		ans += "func: " + this->func + "\n";
		ans += "has empty: " + std::to_string(has_empty) + "\n";
		return ans;
	}
	void print() {
		cout << bold << yellow << "When:" << reset << endl;
		cout << yellow << this->to_string() <<reset << endl;
	}
	string get_op_name() { return "When"; }
};


#endif