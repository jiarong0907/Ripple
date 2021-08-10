#ifndef HELPER_H
#define HELPER_H

#define LINK_BANDWIDTH 10
bool LINK_REG = true;

string read_file (string fname) {
	ifstream infile(fname);
	assert(infile.is_open());

	string code, l;
	while (getline(infile, l))
		code += l + "\n";
	return code;
}

bool Program::find_reroute(Policy* pol){
    for (int i = 0; i < pol->get_num_stmts(); i ++) {
		if (pol->stmts[i].type == "When") {
            When *w = (When *)pol->stmts[i].op;
            if (w->func == "f_reroute")
                return true;
        }
    }

    return false;
}

bool Program::has_reroute(){
    bool has_reroute = this->find_reroute (this->dct_p);
    if (!has_reroute){
        has_reroute = this->find_reroute (this->cls_p1);
    }
    if ((!has_reroute) && (this->cls_p2)){
        has_reroute = this->find_reroute (this->cls_p2);
    }
    if ((!has_reroute) && (this->mtg_p)){
        has_reroute = this->find_reroute (this->mtg_p);
    }

    return has_reroute;
}

Header* Program::get_header_byname(string name){
    return this->headers.get_header_byname(name);
}

bool Program::is_filter_on_link(Policy* pol, string lhs){
    for (int i = 0; i < pol->get_num_stmts(); i ++) {
		if (pol->stmts[i].type == "Map") {
            Map *m = (Map *)pol->stmts[i].op;
            if (m->from[0] == "link"){
                if (m->to == lhs)
                    return true;
            }
        }
    }

    return false;
}

bool Program::in_metadata(string key) {
    return this->metadata.name_exist(key);
}

bool Program::in_registers(string key) {
    return this->registers.name_exist(key);
}

bool Program::in_registers_reduce_result(Policy* pol, int from_line, string key) {
    assert(from_line>0 && from_line<pol->get_num_stmts());
    bool cross_panorama = false;
    if (pol->stmts[from_line].type == "Zip") {
        cross_panorama = true;
    }

    for (int i = from_line-1; i > 0; i --) {
        if (!cross_panorama && pol->stmts[i].type == "Panorama") {
            break;
        } else if (pol->stmts[i].type == "Reduce"){
            Reduce *r = (Reduce *)pol->stmts[i].op;
            if (r->result == key){
                string reg_name = "reduce_"+r->value+"_to_"+r->result+"_full_wind";
                if (this->in_registers(reg_name)) {
                    return true;
                }
            }
        }
    }

    return false;
}

bool Program::in_return(string key) {
    for (int i=0; i<this->returns.size(); i++){
        if (this->returns[i] == key){
            return true;
        }
    }

    return false;
}

bool Program::in_constant(string key) {
    return this->constants.name_exist(key);
}

int get_zip_reduce_line(Policy* pol, string input) {
    int reduce_line = -1;
    for (int i = 0; i < pol->get_num_stmts(); i ++) {
        if (pol->get_stmts()[i].type == "Reduce") {
            Reduce *r = (Reduce *)pol->get_stmts()[i].op;
            if (r->get_result() == input) reduce_line = i;
        }
    }
    return reduce_line;
}

bool check_zip_cross(Policy* pol, string input){
    bool result = false;
    for (int i=get_zip_reduce_line(pol, input) - 1; i>0; i--) {
        if (pol->get_stmts()[i].type == "Filter" || pol->get_stmts()[i].type == "When") {
			Branch *b = (Branch *)pol->get_stmts()[i].op;
            if (!b->get_complex() && b->get_lhs()=="link" && b->get_op() =="=="){
                result = true;
                break;
            }
        } else if (pol->get_stmts()[i].type == "Panorama") {
            result = false;
            break;
        }
    }
    return result;
}

bool check_zip_filter(Policy* pol, int reduce_line){
    for (int i = reduce_line-1; i > 0; i --) {
		if (pol->get_stmts()[i].type == "Panorama") {
			break;
		} else if (pol->get_stmts()[i].type == "Filter" || pol->get_stmts()[i].type == "When") {
			Branch *b = (Branch *)pol->get_stmts()[i].op;
			bool is_complex;
			string lhs, rhs, op;
			is_complex = b->get_complex();
			lhs = b->get_lhs();
			rhs = b->get_rhs();
			op = b->get_op();
			if (lhs=="link" and op != "==")
				return false;
			break;
		}
	}
    return true;
}

#endif