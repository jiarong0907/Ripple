#ifndef _DISTINCT_H
#define _DISTINCT_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "op.h"
#include "../utils/colors.h"

using namespace std;

class Distinct : public Op {
private:
	vector<string> keys;

	friend class Policy;
	friend class Program;

public:
	Distinct(){};

	void add_key(string key) { this->keys.push_back(key); }
	string to_string() {
		string ans;
		ans += "key: [";
		for (string key : this->keys)
			ans += key + ",";
		ans.pop_back();
		ans += "]\n";
		return ans;
	}
	void print() {
		cout << bold << yellow << "Distinct:" << reset << endl;
		cout << yellow << this->to_string() <<reset << endl;
	}
	string get_op_name() { return "Distinct"; }
};


#endif