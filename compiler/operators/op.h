#ifndef _OP_H
#define _OP_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "../utils/colors.h"

using namespace std;

class Op {
private:
	friend class Policy;
	friend class Program;

public:
	Op(){};

	virtual string to_string()= 0;
	virtual void print() = 0;
	virtual string get_op_name() = 0;
};


#endif