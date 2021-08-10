#ifndef PROGRAM_H
#define PROGRAM_H

#include <string>
#include <vector>
#include <map>
#include <cassert>
#include <iostream>
#include <fstream>
#include <regex>
#include <assert.h>

#include "policy.h"
#include "./elements/element.h"
#include "./elements/include.h"
#include "./elements/register.h"
#include "./elements/constant.h"
#include "./elements/metadata.h"
#include "./elements/header.h"
#include "./elements/parser.h"
#include "./elements/table.h"
#include "./elements/checksum.h"
#include "./elements/ingress.h"
#include "./elements/egress.h"
#include "./elements/switch.h"
#include "./elements/deparser.h"

using namespace std;

struct check_zip_link_result {
	bool result;
	string input1;
	string input2;
};

class Program {

private:
	Policy *dct_p = NULL;
	Policy *cls_p1 = NULL;
	Policy *cls_p2 = NULL; //an additional, only useful when composing queries
	Policy *mtg_p = NULL;

	Include include = Include("Include");
	RegisterList registers = RegisterList("RegisterList");
	Metadata metadata = Metadata("Metadata");
	ConstantList constants = ConstantList("ConstantList");
	HeaderList headers = HeaderList("HeaderList");
	P4Parser parser = P4Parser("P4Parser");
	TableList tables = TableList("TableList");
	ChecksumV checksumv = ChecksumV("ChecksumV");
	ChecksumC checksumc = ChecksumC("ChecksumC");
	Ingress ingress = Ingress("Ingress");
	Egress egress = Egress("Egress");
	Switch p4switch = Switch("Switch");
	P4Deparser deparser = P4Deparser("P4Deparser");

	vector<string> returns;
	vector<string> global_vars;
	vector<string> filters;
	string code_func="";

	string gen_dct();
	string gen_dct_map(string from, string to);
	string gen_dct_window(int window);
	string gen_dct_filter(string to, string op, string thresh);
	string gen_dct_return(string from, string to, string ret_val);
	string gen_cls(string stage);
	string gen_mtg();
	string gen_probe();
	string gen_sync();

	bool gen_paranoma(Policy* pol, int from_line);
	string gen_map(Policy* pol, int from_line);
	string gen_map_load (string from, string to);
	string gen_branch(Policy* pol, int from_line, string stage, string type, int panorama_count);
	bool branch_check(Policy* pol, int from_line, string lhs, string rhs, string op,
                            string cplx_field1, string cplx_field2, vector<string> keys, bool is_complex);
	string gen_branch_simple_in(Policy* pol, int from_line, string stage, int pano_num, string rhs,
                                	vector<string> keys, string func);
	string gen_empty(Policy* pol, int from_line, string stage, int pano_num, string lhs);
	string gen_ipset(Policy* pol, int from_line, string stage, int pano_num, string lhs);
	string gen_branch_main(Policy* pol, int from_line, string lhs, string cplx_field1, string cplx_field2, string filter_name,
                                bool is_complex, bool legal_register, bool has_size);
	string gen_branch_condition(Policy* pol, int from_line, string lhs, string rhs, string op, string cplx_field1, string cplx_field2,
                                        string cplx_op, string cplx_arithop, string cplx_rhs, bool is_complex, bool legal_register);
	string gen_return(Policy* pol, int from_line, string stage, int panorama_count);
	string get_distinct_ret(Policy* pol, int from_line);
	string gen_rd_window(string stage, int window, string reg_prefix, string indent1,
                                string indent2, string sketch_size, string &func_code, bool four_wind);
	string gen_reduce(Policy* pol, int from_line, string stage, int window);
	string gen_distinct(Policy* pol, int from_line, string stage, int window, int pano_num);
	string gen_when(Policy* pol, int from_line, string stage);
	string gen_when_name(When *w, string stage);
	string gen_when_body(When *w, string func_name, string &code_func);
	string gen_zip(Policy* pol, int from_line, string stage);


	bool has_reroute();
	bool find_reroute(Policy* pol);

	Header* get_header_byname(string name);
	bool in_metadata(string key);
	bool in_registers(string key);
	bool in_registers_reduce_result(Policy* pol, int from_line, string key);
	bool in_return(string key);
	bool in_constant(string key);
	bool has_return_val(string val, Policy* pol);
	bool find_dotsize(Policy* pol, string return_val);
	bool has_dotsize(string return_val);
	bool is_filter_on_link(Policy* pol, string lhs);
	bool filter_on_reg(Policy* pol, int from_line, string filter_name);
	bool find_reg_later(Policy* pol, int from_line, string filter_name);
	string lhs_to_reg_prefix(Policy* pol, int from_line, string filter_name);
	check_zip_link_result check_zip_link(Policy* pol);
	string get_victimLks ();
	vector<string> get_malflows ();
	void get_global_var ();
	int get_panorama_num(Policy* pol);
	bool parse() {
		if (this->dct_p) this->dct_p->parse();
		else return false;
		if (this->cls_p1) this->cls_p1->parse();
		else return false;
		if (this->cls_p2) this->cls_p2->parse();
		if (this->mtg_p) this->mtg_p->parse();
		else return false;
		return true;
	}

public:
	Program (Policy *d, Policy *c1, Policy *c2, Policy *m) {
		assert(d && c1 && m);
		this->dct_p = d;
		this->cls_p1 = c1;
		this->cls_p2 = c2;
		this->mtg_p = m;
	}

	Policy* get_dct_p() { return this->dct_p; }
	Policy* get_cls_p1() { return this->cls_p1; }
	Policy* get_cls_p2() { return this->cls_p2; } //only useful when there are two queries.
	Policy* get_mtg_p() { return this->mtg_p; }

	bool cross_pano(Policy* pol, int from_line, string filter_name);

	void compile(string out_path);
};

#endif




