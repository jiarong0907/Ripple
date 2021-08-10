#ifndef _ZIP_H
#define _ZIP_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "op.h"
#include "../utils/colors.h"

using namespace std;

class Zip : public Op{
private:
	vector<string> key;
	string input1;
	string input2;

	friend class Policy;
	friend class Program;

public:
	Zip(){};

	void add_key(string key) { this->key.push_back(key); }
	void set_input1(string input1) { this->input1 = input1; }
	void set_input2(string input2) { this->input2 = input2; }
	string to_string() {
		string ans;

		ans += "key: ";
		for (string key : this->key)
			ans += key;
		ans.pop_back();
		ans += "\n";

		ans += "input1: " + this->input1;
		ans += "\n";

		ans += "input2: " + this->input2;
		ans += "\n";
		return ans;
	}
	void print() {
		cout << bold << yellow << "Zip:" << reset << endl;
		cout << yellow << this->to_string() <<reset << endl;
	}
	string get_op_name() { return "Zip"; }
};


#endif