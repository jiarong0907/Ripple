#include <regex>
#include <string>
#include "program.h"
#include "./utils/helper.h"
#include "operators.h"

using namespace std;

string Program::gen_dct () {
	string code =
"/*************************************************************************\n"
"********************        Detection here       *************************\n"
"*************************************************************************/\n"
"\n"
"		if (meta.detection_filter1 == 1) {\n";

	Policy* d = this->dct_p;
	int num_stmts = d->get_num_stmts();
	bool has_return = this->gen_paranoma(d, 0);
	int window = ((Panorama*)d->stmts[0].op)->window;
	bool first_filter = true;
	int pano_count = 1;

	for (int i = 1; i < num_stmts; i ++) {
		if (d->stmts[i].type == "Panorama") {
			has_return = this->gen_paranoma(d, i);
			pano_count += 1;
		} else if (d->stmts[i].type == "Map") {
			Map *m = (Map *)d->stmts[i].op;
			code += this->gen_map(d, i);
		} else if (d->stmts[i].type == "Filter") {
			Filter *f = (Filter *)d->stmts[i].op;

			// add window code when it is the first filter
			if (first_filter){
				first_filter = false;
				code += "            if (meta.d_wind_interval > "+to_string(window)+" * 1000){\n";
    			code += "                d_wind_last_ts.write(0, meta.this_ts_val);\n\n";
			}

			// add filter logic
			code += this->gen_branch(d, i, "detection", "Filter", pano_count);

			// if this is the last filter in this code sinppet, check whether we need to handle return
			if (i+1 == num_stmts || (i+1 < num_stmts && d->stmts[i+1].type == "Panorama")){
				if (has_return) {
					has_return = false;
					code += this->gen_return(d, i, "detection", pano_count);
				}
			}
			code += "            }\n";
		} else {
			throw_error("Do not support type "+d->stmts[i].type+" in detection currently.\n");
		}
	}

	code +="	 	}\n";
	return code;
}


string Program::gen_cls (string stage) {
	string code = "";
	string comment_name="";
	assert(stage == "classification" || stage == "classification1" || stage == "classification2");
	if (stage == "classification")
		comment_name = "Classification";
	else if (stage == "classification1")
		comment_name = "Classification1";
	else
		comment_name = "Classification2";


	code +=
			"\n\n/*************************************************************************\n"
			"********************     "+comment_name+" here     *************************\n"
			"*************************************************************************/\n"
			"\n";

	Policy* c;
	if (stage == "classification")
		c = this->cls_p1;
	else if (stage == "classification1")
		c = this->cls_p1;
	else
		c = this->cls_p2;

	int num_statements = c->get_num_stmts();
	string return_val = ((Panorama*)c->stmts[0].op)->ret_val;
	int window = ((Panorama*)c->stmts[0].op)->window;
	bool has_return = this->gen_paranoma(c, 0);
	int pano_count = 1;
	bool first_when = true;

	for (int i = 1; i < num_statements; i ++) {
		string filter;
		filter = "meta."+stage+"_filter"+to_string(pano_count)+" == 1";
		if (!in_metadata(stage+"_filter"+to_string(pano_count))) {
			this->filters.push_back(stage+"_filter"+to_string(pano_count));
			assert(this->metadata.add_field(MetadataField(stage+"_filter"+to_string(pano_count), 32)));
		}

		if (c->stmts[i].type == "Panorama") {
			window = ((Panorama*)c->stmts[i].op)->window;
			has_return = this->gen_paranoma(c, i);
			pano_count += 1;
			first_when = true;
		}
		else if (c->stmts[i].type == "Map") {
			Map *m = (Map *)c->stmts[i].op;
			code +="		if ("+filter+") {\n";
			code += this->gen_map(c, i);
			code += "	 	}\n";
		}
		else if (c->stmts[i].type == "Filter") {
			code +="		if ("+filter+") {\n";
			Filter *f = (Filter *)c->stmts[i].op;
			// add filter logic
			code += this->gen_branch(c, i, stage, "Filter", pano_count);
			// if this is the last filter is this code sinppet, check whether we need to handle return
			if (i+1 == num_statements || (i+1 < num_statements && c->stmts[i+1].type == "Panorama")){
				if (has_return) {
					has_return = false;
					code += this->gen_return(c, i, stage, pano_count);
				}
			}
			code += "	 	}\n";
		}
		else if (c->stmts[i].type == "Reduce"){
			code +="		if ("+filter+") {\n";
			code += this->gen_reduce(c, i, stage, window);
			code += "	 	}\n";
		}
		else if (c->stmts[i].type == "Distinct"){
			code +="		if ("+filter+") {\n";
			code += this->gen_distinct(c, i, stage, window, pano_count);
			code += "	 	}\n";
		}
		else if (c->stmts[i].type == "Zip"){
			code +="		if ("+filter+") {\n";
			code += this->gen_zip(c, i, stage);
			code += "	 	}\n";
		}
		else if (c->stmts[i].type == "When") {
			if (first_when)
				first_when = false;
			else {
				pano_count++;
				if (!in_metadata(stage+"_filter"+to_string(pano_count))) {
					this->filters.push_back(stage+"_filter"+to_string(pano_count));
					assert(this->metadata.add_field(MetadataField(stage+"_filter"+to_string(pano_count), 32)));
				}
			}

			code +="		if (meta."+stage+"_filter"+to_string(pano_count)+" == 1) {\n";
			// add when logic
			code += this->gen_branch(c, i, stage, "When", pano_count);
			code += "	 	}\n";

			pano_count++;

			// TODO: Support using when to return a value like filter
		}
		else{
			throw_error("Do not support type "+c->stmts[i].type+" in classification currently.\n");
		}
	}

	return code;
}

string Program::gen_mtg () {
	string code = "";
	code +=
			"\n\n/*************************************************************************\n"
			"***********************     Mitigation here     ******************************\n"
			"*******************************************************************************/\n"
			"\n";

	Policy* m = this->mtg_p;

	int num_statements = m->get_num_stmts();
	string return_val = ((Panorama*)m->stmts[0].op)->ret_val;
	int window = ((Panorama*)m->stmts[0].op)->window;
	bool has_return = this->gen_paranoma(m, 0);
	int pano_count = 1;

	for (int i = 1; i < num_statements; i ++) {
		if (m->stmts[i].type == "Panorama") {
			window = ((Panorama*)m->stmts[i].op)->window;
			has_return = this->gen_paranoma(m, i);
			pano_count++;
			if (!in_metadata("mitigation_filter"+to_string(pano_count))) {
				this->filters.push_back("mitigation_filter"+to_string(pano_count));
				assert(this->metadata.add_field(MetadataField("mitigation_filter"+to_string(pano_count), 32)));
			}
		}
		else if (m->stmts[i].type == "Filter") {
			code +="		if (meta.mitigation_filter"+to_string(pano_count)+" == 1) {\n";
			Filter *f = (Filter *)m->stmts[i].op;

			// add filter logic
			code += this->gen_branch(m, i, "mitigation", "Filter", pano_count);

			// if this is the last filter is this code sinppet, check whether we need to handle return
			if (i+1 == num_statements || (i+1 < num_statements && m->stmts[i+1].type == "Panorama")){
				if (has_return) {
					has_return = false;
					code += this->gen_return(m, i, "mitigation", pano_count);
				}
			}
			code += "	 	}\n";
		} else if (m->stmts[i].type == "When"){
			code +="		if (meta.mitigation_filter"+to_string(pano_count)+" == 1) {\n";
			When *f = (When *)m->stmts[i].op;
			// add when logic
			code += this->gen_branch(m, i, "mitigation", "When", pano_count);
			code += "	 	}\n";
			pano_count++;
			if (!in_metadata("mitigation_filter"+to_string(pano_count))) {
				this->filters.push_back("mitigation_filter"+to_string(pano_count));
				assert(this->metadata.add_field(MetadataField("mitigation_filter"+to_string(pano_count), 32)));
			}
		}
		else{
			throw_error("Do not support type "+m->stmts[i].type+" in mitigation currently.\n");
		}
	}

	return code;
}


string Program::gen_probe () {
	string code = "";
	code +=
			"/*************************************************************************\n"
			"**********************    Handle probes here     *************************\n"
			"*************************************************************************/\n\n";
	assert(this->has_reroute());
	assert(this->in_metadata("probe_update"));
	assert(this->in_metadata("swid"));
	assert(this->in_registers("probe_seqNo"));
	assert(this->in_registers("best_util"));
	assert(this->in_registers("best_path"));
	assert(this->in_constant("PROBE_PROTOCOL"));
	assert(this->tables.name_exist("probe"));

	code += read_file("./templates/template_probe.p4");
	this->code_func += read_file("./templates/template_func_probe.p4");

	return code;
}



check_zip_link_result Program::check_zip_link(Policy* pol){
	check_zip_link_result res;

	// Search for Zip
	for (int i = 0; i < pol->get_num_stmts(); i ++) {
		if (pol->stmts[i].type == "Zip") {
			Zip *z = (Zip *)pol->stmts[i].op;
			res.input1 = z->input1;
			res.input2 = z->input2;
		}
	}

	// search for link condition
	bool condition1 = false;
	bool condition2 = false;
	bool has_condition = false;
	for (int i = 0; i < pol->get_num_stmts(); i ++) {
		if (pol->stmts[i].type == "Filter" || pol->stmts[i].type == "When") {
			// Currently, we only support link == 1 || link == 2 like conditions
			bool is_complex;
			string lhs, rhs, op;
			Branch *b = (Branch*) pol->stmts[i].op;
			is_complex = b->is_complex;
			lhs = b->lhs;
			rhs = b->rhs;
			op = b->op;
			// Does not support complex and IN conditions
			if (!is_complex && op != "IN" && lhs == "link") {
				has_condition = true;
			}
		} else if (pol->stmts[i].type == "Reduce") {
			Reduce *r = (Reduce *)pol->stmts[i].op;
			if (r->result == res.input1 && has_condition){
				condition1 = true;
				has_condition = false;
			} else if (r->result == res.input2 && has_condition){
				condition2 = true;
				has_condition = false;
			}
		} else if (pol->stmts[i].type == "Panorama") {
			has_condition = false;
		}

		if (condition1 && condition2){
			res.result = true;
			return res;
		}
	}

	res.result = false;
	return res;
}

string Program::get_victimLks () {
	string victimLks="";
	for (auto item : this->mtg_p->stmts) {
		if (item.type =="Filter" || item.type=="When") {
			Branch *b = (Branch*)(item.op);
			if (!b->is_complex && b->lhs.find(".size") != b->lhs.npos){
				for (auto ret : this->global_vars) {
					if (ret+".size" ==b->lhs) {
						victimLks = ret;
						break;
					}
				}
			}
		}
	}
	return victimLks;
}

vector<string> Program::get_malflows () {
	string victimLks = this->get_victimLks();
	vector<string> malflows;
	for (int i=0; i<this->global_vars.size(); i++)
		if (this->global_vars[i] != victimLks && this->global_vars[i] != victimLks+"_size")
			malflows.push_back(this->global_vars[i]);
	return malflows;
}

void Program::get_global_var () {
	for (auto ret : this->returns) {
		for (auto item : this->mtg_p->stmts) {
			if (item.type =="Filter" || item.type=="When") {
				Branch *b = (Branch*)(item.op);
				string tmp_lhs = regex_replace(b->lhs, regex(".size"), "_size");
				bool cond1 = b->op != "IN" && !b->is_complex && (b->lhs==ret || tmp_lhs==ret || tmp_lhs==ret+"_size");
				bool cond2 = b->op == "IN" && !b->is_complex && b->rhs==ret;
				if (cond1 || cond2) {
					this->global_vars.push_back(ret);
					break;
				}
			}
		}
	}
}

string Program::gen_sync () {
	this->get_global_var();
	string code = "";
	code +=
			"/*************************************************************************\n"
			"**********************    Sync handler here     *************************\n"
			"*************************************************************************/\n\n";

	assert(this->in_metadata("swid"));
	assert(this->in_constant("SYNC_PROTOCOL"));
	assert(this->tables.name_exist("sync"));


	// determine whether we have ingress egress exchange where we need to sync extra info
	// Approach: First, we find whether we have a zip operation. If so, get two input and find it in previous reduce.
	// Then, check whether we have filter with conditions using link in previous lines
	bool cross_classification1 = false;
	bool cross_classification2 = false;

	Policy* c1 = this->cls_p1;
	Policy* c2 = this->cls_p2;
	assert(c1);

	string input11, input12;
	string input21, input22;

	string input11_reduce_name, input12_reduce_name;
	string input21_reduce_name, input22_reduce_name;

	cross_classification1 = this->check_zip_link(c1).result;
	input11 = this->check_zip_link(c1).input1;
	input12 = this->check_zip_link(c1).input2;
	input11_reduce_name = this->lhs_to_reg_prefix(c1, c1->get_num_stmts()-1, input11);
	input12_reduce_name = this->lhs_to_reg_prefix(c1, c1->get_num_stmts()-1, input12);

	if (c2){
		cross_classification2 = this->check_zip_link(c2).result;
		input21 = this->check_zip_link(c2).input1;
		input22 = this->check_zip_link(c2).input2;
		input21_reduce_name = this->lhs_to_reg_prefix(c2, c2->get_num_stmts()-1, input21);
		input22_reduce_name = this->lhs_to_reg_prefix(c2, c2->get_num_stmts()-1, input22);
	}

	// parameter string
	string indent = "								";
	string parameters="hdr, meta, standard_metadata, \\\n";
	for (auto item: this->global_vars)
		parameters += indent + item+", \\\n";


	// We assume the ingress appears before egress
	if (cross_classification1) {
		parameters += indent+input11_reduce_name+"_full_wind, \\\n";
		parameters += indent+input11+"_s0, \\\n";
		parameters += indent+input11+"_s1, \\\n";
		parameters += indent+input11+"_s2, \\\n";
		parameters += indent+input11_reduce_name+"_s0_w0, "+input11_reduce_name+"_s1_w0, "+input11_reduce_name+"_s2_w0, "+"\\\n";
		parameters += indent+input11_reduce_name+"_s0_w1, "+input11_reduce_name+"_s1_w1, "+input11_reduce_name+"_s2_w1, "+"\\\n";
		parameters += indent+input11_reduce_name+"_s0_w2, "+input11_reduce_name+"_s1_w2, "+input11_reduce_name+"_s2_w2, "+"\\\n";
	}

	if (cross_classification2) {
		parameters += indent+input21_reduce_name+"_full_wind, \\\n";
		parameters += indent+input21+"_s0, \\\n";
		parameters += indent+input21+"_s1, \\\n";
		parameters += indent+input21+"_s2, \\\n";
		parameters += indent+input21_reduce_name+"_s0_w0, "+input21_reduce_name+"_s1_w0, "+input21_reduce_name+"_s2_w0, "+"\\\n";
		parameters += indent+input21_reduce_name+"_s0_w1, "+input21_reduce_name+"_s1_w1, "+input21_reduce_name+"_s2_w1, "+"\\\n";
		parameters += indent+input21_reduce_name+"_s0_w2, "+input21_reduce_name+"_s1_w2, "+input21_reduce_name+"_s2_w2, "+"\\\n";
	}

	parameters += indent+"d_swid";

	// the returned code
	string indent1 = "		";
	code += indent1 + "if (hdr.ipv4.protocol == SYNC_PROTOCOL) {\n";
	code += indent1 + "    ctrl_sync.apply("+parameters+");\n\n";
	code += indent1 + "    if (meta.swid == 3){ // switch 3 is the root\n";
	code += indent1 + "        tab_sync_mcast.apply();\n";
	code += indent1 + "    } else {\n";
	code += indent1 + "        tab_sync_nhop.apply();\n";
	code += indent1 + "    }\n";
	code += indent1 + "}\n";


	// generate code_func
	string indent2 = "                  ";
	string func_parameters="";
	for (auto item : this->global_vars)
		func_parameters += indent2 + "in register<bit<32>> "+item+", \n";

	if (cross_classification1) {
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_full_wind, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11+"_s0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11+"_s1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11+"_s2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s0_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s1_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s2_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s0_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s1_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s2_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s0_w2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s1_w2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input11_reduce_name+"_s2_w2, ";
	}

	if (cross_classification2) {
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_full_wind, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21+"_s0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21+"_s1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21+"_s2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s0_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s1_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s2_w0, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s0_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s1_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s2_w1, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s0_w2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s1_w2, \n";
		func_parameters += indent2 + "in register<bit<32>> "+input21_reduce_name+"_s2_w2, ";
	}

	// determine the template based on the number of global variables
	string fname="";
	string code_func="";
	// Determine which one is victimLks
	string victimLks=this->get_victimLks();
	// determine which one is malflows
	vector<string> malflows=get_malflows();
	Header *sync = this->get_header_byname("sync");
	assert(sync);
	if (!c2) {
		assert(malflows.size()==1);
		if (!cross_classification1 && !cross_classification2){
			fname = "./templates/template_sync0.p4";
			code_func = read_file(fname);
			code_func = regex_replace(code_func, regex("parameters"), func_parameters);
			code_func = regex_replace(code_func, regex("victimLks"), victimLks);
			code_func = regex_replace(code_func, regex("malflows"), malflows[0]);
			sync->add_macro("HDR_FILED_128("+this->get_victimLks()+")");
			sync->add_macro("HDR_FILED_128("+this->get_malflows()[0]+")");
		} else if ((cross_classification1 && !cross_classification2) || (!cross_classification1 && cross_classification2)){
			fname = "./templates/template_sync1.p4";
			code_func = read_file(fname);
			code_func = regex_replace(code_func, regex("parameters"), func_parameters);
			code_func = regex_replace(code_func, regex("victimLks"), victimLks);
			code_func = regex_replace(code_func, regex("malflows"), malflows[0]);
			// replace input
			if (cross_classification1 && !cross_classification2) {
				code_func = regex_replace(code_func, regex("input_ingress"), input11_reduce_name);
				code_func = regex_replace(code_func, regex("input"), input11);
				sync->add_macro("HDR_FILED_64("+this->get_victimLks()+")");
				sync->add_macro("HDR_FILED_64("+this->get_malflows()[0]+")");
				sync->add_macro("HDR_FILED_64("+input11+"1)");
				sync->add_macro("HDR_FILED_64("+input11+"2)");
				sync->add_macro("HDR_FILED_64("+input11+"3)");
			} else if (!cross_classification1 && cross_classification2) {
				code_func = regex_replace(code_func, regex("input_ingress"), input21_reduce_name);
				code_func = regex_replace(code_func, regex("input"), input21);
				sync->add_macro("HDR_FILED_64("+this->get_victimLks()+")");
				sync->add_macro("HDR_FILED_64("+this->get_malflows()[0]+")");
				sync->add_macro("HDR_FILED_64("+input21+"1)");
				sync->add_macro("HDR_FILED_64("+input21+"2)");
				sync->add_macro("HDR_FILED_64("+input21+"3)");
			} else {throw_error("Do not support!\n");}
		} else { throw_error("Do not support!\n"); }
	} else {
		if (cross_classification1 || cross_classification2)
			throw_error("Do not support multi-vector policies with cross switch zip!\n");
		assert(malflows.size()==2);
		fname = "./templates/template_sync2.p4";
		code_func = read_file(fname);
		code_func = read_file(fname);
		code_func = regex_replace(code_func, regex("parameters"), func_parameters);
		code_func = regex_replace(code_func, regex("victimLks"), victimLks);
		code_func = regex_replace(code_func, regex("malflows1"), get_malflows()[0]);
		code_func = regex_replace(code_func, regex("malflows2"), get_malflows()[1]);
		sync->add_macro("HDR_FILED_128("+this->get_victimLks()+")");
		sync->add_macro("HDR_FILED_64("+this->get_malflows()[0]+")");
		sync->add_macro("HDR_FILED_64("+this->get_malflows()[1]+")");
	}
	this->code_func += code_func;
	return code;
}

void Program::compile (string out_name) {
	assert(this->parse());
	string delim(30,'=');
	cout << delim << " " << " code generation " << delim << endl;
	cout << "initilizing constants, headers, parser, deparser, meatdata, register, tables..." << endl;
	this->constants.init(this->has_reroute());
	this->headers.init(this->has_reroute());
	this->parser.init(this->has_reroute());
	this->deparser.init(this->has_reroute());
	this->metadata.init(this->has_reroute(), this->get_cls_p2()>0, this->dct_p->get_num_panorama(),
						this->cls_p1->get_num_panorama(), this->mtg_p->get_num_panorama(), this->filters);
	this->registers.init(this->has_reroute());
	this->tables.init();

	cout << "constructing ingress apply..." << endl;
	Apply apply = Apply("Apply");
	apply.set_regs(&this->registers);
	apply.set_tabs(&this->tables);
	apply.set_metadata(&this->metadata);
	apply.emit_init_others("        ", this->has_reroute(), this->cls_p2>0);

	cout << "generating detection..." << endl;
	Dct dct = Dct ("Dct", this->dct_p, this->cls_p1, this->cls_p2, this->mtg_p, this->gen_dct());
	cout << "generating classification..." << endl;
	string cls_code;
	if (!this->cls_p2) {
		cls_code = this->gen_cls("classification");
	}
	else {
		cls_code = this->gen_cls("classification1");
		cls_code += this->gen_cls("classification2");
	}
	Cls cls = Cls ("Cls", this->dct_p, this->cls_p1, this->cls_p2, this->mtg_p, cls_code);
	cout << "generating mitigation..." << endl;
	Mtg mtg = Mtg ("Mtg", this->dct_p, this->cls_p1, this->cls_p2, this->mtg_p, this->gen_mtg());
	cout << "generating probe..." << endl;
	string probe_code;
	if (this->has_reroute())
		probe_code = gen_probe();
	Probe probe = Probe ("Probe", this->dct_p, this->cls_p1, this->cls_p2, this->mtg_p, probe_code);
	cout << "generating sync..." << endl;
	Sync sync = Sync ("Sync", this->dct_p, this->cls_p1, this->cls_p2, this->mtg_p, this->gen_sync());

	cout << "assembling the code..." << endl;
	apply.emit_filter("        ", this->filters);
	apply.set_dct(&dct);
	apply.set_cls(&cls);
	apply.set_mtg(&mtg);
	apply.set_probe(&probe);
	apply.set_sync(&sync);

	this->ingress.set_regs(&this->registers);
	this->ingress.set_tabs(&this->tables);
	this->ingress.set_metadata(&this->metadata);
	this->ingress.set_apply(&apply);

	string code = "";
	code += this->include.compile("")+"\n";
	code += this->constants.compile("")+"\n";
	code += this->headers.compile("");
	code += this->metadata.compile("");
	code += this->parser.compile("")+"\n";
	code += this->checksumv.compile("")+"\n";
	code += this->ingress.compile("")+"\n";
	code += this->egress.compile("")+"\n";
	code += this->checksumc.compile("")+"\n";
	code += this->deparser.compile("")+"\n";
	code += this->p4switch.compile("")+"\n";

	cout << "writing into files..." << endl;
	cout << out_name << endl;
	ofstream outfile(out_name+"out.p4");
	outfile << code;
	outfile.close();

	ofstream outfile_func(out_name+"outfunc.p4");
	outfile_func << this->code_func;
	outfile_func.close();
	cout << "done" << endl << endl;
}
