#ifndef _FILTER_H
#define _FILTER_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "../utils/colors.h"
#include "branch.h"

using namespace std;

class Filter : public Branch {
public:
	Filter() {};
	string to_string() {
		string ans;
		if (!this->get_complex()) {
			if (this->get_key()->size() == 0) {
				ans += "pred:  ";
				ans += this->get_lhs() + " ";
				ans += this->get_op() + " ";
				ans += this->get_rhs() + "\n";
			} else {
				ans += "pred: ";
				for (string key : *(this->get_key()))
					ans += key + " ";
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
		return ans;
	}
	void print() {
		cout << bold << yellow << "Filter:" << reset << endl;
		cout << yellow << this->to_string() << reset << endl;
	}
	string get_op_name() { return "Filter"; }

};

#endif