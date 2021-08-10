#ifndef _PARSER_H
#define _PARSER_H

#include <string>
#include <vector>
#include <iostream>

#include "./operators/map.h"
#include "./operators/panorama.h"
#include "./operators/filter.h"
#include "./operators/branch.h"
#include "./operators/reduce.h"
#include "./operators/when.h"
#include "./operators/distinct.h"
#include "./operators/zip.h"
#include "./operators/op.h"
#include "./utils/colors.h"

// Types of queries
#define TYPE_DETECTION 0
#define TYPE_CLASSIFICATION 1
#define TYPE_MITIGATION 2

using namespace std;

#ifndef throw_error
#define throw_error(msg) throw std::runtime_error(string(__FILE__)+":"+std::to_string(__LINE__)+" --> "+msg);
#endif

struct stmt {
	Op* op;
	string type;
};

struct selfzip {
	string reduce_value;
	string input1;
	string input2;
};

class Policy {
private:
	int type; 				// detection, classification, or mitigation
	vector<string> lines;
	vector<stmt> stmts;

	string global_var; //name of the global variable, to be propagated.
	int window;

	string trigger_cond_lhs;
	string trigger_cond_op;
	string trigger_cond_rhs;
	bool has_selfzip=false;
	selfzip szip;
	int num_panorama=0;

	friend class Program;

public:
	Policy(){};
	Policy(string input_file);
	Policy(string input_file, string file_type);

	void parse();
	Map* parse_map(string current_line);
	Reduce* parse_reduce(string current_line);
	Filter* parse_filter(string current_line);
	Distinct* parse_distinct(string current_line);
	When* parse_when(string current_line);
	Zip* parse_zip(string current_line);
	Panorama* parse_panorama(string current_line);


	int add_stmt(Map *);
	int add_stmt(Reduce *);
	int add_stmt(Filter *);
	int add_stmt(Distinct *);
	int add_stmt(When *);
	int add_stmt(Zip *);
	int add_stmt(Panorama *);

	string get_type() {
		if (this->type == TYPE_DETECTION) 				return "DETECTION";
		else if (this->type == TYPE_CLASSIFICATION)		return "CLASSIFICATION";
		else if (this->type == TYPE_MITIGATION)			return "MITIGATION";
		throw 	invalid_argument("Unrecognized policy type.");
	}

	string to_string() {
		string s;
		for (string l: lines)
			s += l + "\n";
		return s;
	};

	void print() {cout << this->to_string() << endl; }
	void print_stmt();

	int get_num_stmts() { return stmts.size(); }
	vector<stmt> get_stmts() {return stmts;}
	int get_num_panorama () { return this->num_panorama; }
	bool grammar_check();
};



#endif