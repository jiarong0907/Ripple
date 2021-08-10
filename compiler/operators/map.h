#ifndef _MAP_H
#define _MAP_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "op.h"
#include "../utils/colors.h"

using namespace std;

class Map : public Op  {
private:
    vector<string> from;
    string to;
    string func;

    friend class Policy;
    friend class Program;

public:
    Map(){};

    //helper functions:
    void add_from(string from) { this->from.push_back(from); }
    void set_to(string to) { this->to = to; }
    void set_func(string func) { this->func = func; }
    string to_string() {
		string ans;

		//construct the from items:
		ans += "from: [";
		for (int i = 0; i < this->from.size(); i++)
			ans += this->from[i] + ",";
		ans.pop_back();
		ans += "]\n";

		//construct the val items:
		ans += "to: [";
		for (int i = 0; i < this->to.size(); i ++)
			ans += this->to[i] + ",";
		ans.pop_back();
		ans += "]\n";

		//construct the func:
		ans += "func: " + this->func + "\n";
		return ans;
	}
    void print() {
		cout << bold << yellow << "Map:" << reset << endl;
		cout << yellow << this->to_string() <<reset << endl;
	}
	string get_op_name() { return "Map"; }
};





#endif