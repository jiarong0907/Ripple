#ifndef _REDUCE_H
#define _REDUCE_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "op.h"
#include "../utils/colors.h"

using namespace std;

class Reduce : public Op {
private:
	vector<string> key;
	string result;
	string value;

	friend class Policy;
	friend class Program;

public:
	Reduce(){};

	void add_key(string key) { this->key.push_back(key);	}
	void set_result(string result) { this->result = result;	}
	string get_result() {return this->result;}
	void set_value(string value) { this->value = value; }
	string get_value() {return this->value;}
	string to_string() {
		string ans;

		//construct the key items:
		ans += "key: ";
		for (string key : this->key)
			ans += key + ", ";

		ans.pop_back();
		ans += "\n";

		ans += "Result: " + this->result;
		ans += "\n";

		ans += "Value: " + this->value;
		ans += "\n";

		return ans;
	}
	void print() {
		cout << bold << yellow << "Reduce:" << reset << endl;
		cout << yellow << this->to_string() <<reset << endl;
	}
	string get_op_name() { return "Reduce"; }
};


#endif