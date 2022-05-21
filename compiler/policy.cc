#include "policy.h"
#include "utils/utils.h"
#include "utils/colors.h"

extern bool equal_set(vector<string> set1, vector<string> set2);

Policy::Policy(string input_file, string file_type) {

	ifstream infile(input_file.c_str());
	assert(infile.is_open());
	cout << "reading from file " + input_file <<endl;

	// read file
	string l;
	regex r ("//.*");
	while (getline(infile, l)) {
		if (l.empty()) //empty line
			continue;
		if (regex_match(l,r)) //comment line
			continue;
		this->lines.push_back(l);
	}

	//parse policy type
	assert(this->lines.size() > 0);
	if (file_type.compare("detection") == 0)
		this->type = TYPE_DETECTION;
	else if (file_type.compare("classification") == 0)
		this->type = TYPE_CLASSIFICATION;
	else if (file_type.compare("mitigation") == 0)
		this->type = TYPE_MITIGATION;
	else
		throw_error("File type not valid.");
}

/**
 * Extract supported operators from lines after the first line
 */
void Policy::parse() {
	string delim(30,'=');
	cout << delim << " " << this->get_type() << " policy parse " << delim << endl;
	for (int i = 0; i < lines.size(); i ++) {
		string cur_line = lines[i];
		if (0 == cur_line.rfind(".map", 0)) {
			cout << "> Processing a map policy: " << blue << cur_line << reset << endl;
			Map *map = parse_map(cur_line);
			add_stmt(map);
		} else if (0 == cur_line.rfind(".reduce", 0)) {
			cout << "> Processing a reduce policy: " << blue << cur_line << reset << endl;
			Reduce *reduce = parse_reduce(cur_line);
			add_stmt(reduce);
		} else if (0 == cur_line.rfind(".filter", 0)) {
			cout << "> Processing a filter policy: " << blue << cur_line << reset << endl;
			Filter *filter = parse_filter(cur_line);
			add_stmt(filter);
		} else if (0 == cur_line.rfind(".distinct", 0)) {
			cout << "> Processing a distinct policy: " << blue << cur_line << reset << endl;
			Distinct *distinct = parse_distinct(cur_line);
			add_stmt(distinct);
		} else if (0 == cur_line.rfind(".zip", 0)) {
			cout << "> Processing a zip policy: " << blue << cur_line << reset << endl;
			Zip *zip = parse_zip(cur_line);
			add_stmt(zip);
		} else if (0 == cur_line.rfind(".when", 0)) {
			cout << "> Processing a when policy: " << blue << cur_line << reset << endl;
			When *when = parse_when(cur_line);
			add_stmt(when);
		} else if (0 < cur_line.find("panorama")) {
			cout << "> Processing a panorama policy: " << blue << cur_line << reset << endl;
			Panorama *panorama = parse_panorama(cur_line);
			add_stmt(panorama);
			this->num_panorama += 1;
		} else {
			throw_error("Cannot recognize line the operator!");
		}
	}
	grammar_check();
}

Panorama* Policy::parse_panorama(string line)
{
	regex reg_pano("(\\w+)\\s*=\\s*panorama\\s*\\((\\d+)\\)");
	if (!std::regex_match(line.begin(), line.end(), reg_pano)) {
		throw_error("Invalid Panorama statement");
	}

	smatch match;
	Panorama* pano = new Panorama();

	if (regex_search(line, match, reg_pano)) {
		this->global_var = match.str(1);
		pano->set_return(match.str(1));
		this->window = stoi(match.str(2));
		pano->set_window(this->window);
	} else {
		throw_error("Invalid Panorama statement");
	}

	pano->print();
	return pano;
}


//extracts a reduce policy from a given line
Reduce* Policy::parse_reduce(string line) {
	// .reduce ([sip], [egflowsz], [pktlen])
	regex reg_reduce("\\.reduce\\s*\\(\\[((\\w+(,\\s*\\w+)*|\\*))\\],\\s*\\[(\\w+)\\],\\s\\[(\\w+)\\]\\)");
	if (!std::regex_match(line.begin(), line.end(), reg_reduce)) {
		throw_error("Invalid Reduce statement");
	}

	smatch match;
	Reduce *reduce = new Reduce();
	if (regex_search(line, match, reg_reduce)) {
		vector<string> keys = split(match.str(1), ",");
		for (string item: keys)
			reduce->add_key(trim(item));
		reduce->set_result(match.str(4));
		reduce->set_value(match.str(5));
	} else {
		throw_error("Invalid Reduce statement");
	}

	reduce->print();
	return reduce;
}

//extracts a filter policy from a given line
Filter* Policy::parse_filter(string line) {
	Filter *filter = new Filter();

	// conditionss substring
	string params = extract_params(line);
	string condition = params.substr(1, params.size()-1);
	extract_conds(condition, filter);
	filter->print();
	//gammar check
	if (!((filter->op=="IN"&&(!filter->is_complex)) || filter->op!="IN"))
		throw_error("When the op=IN, the condition must not be complex!\n");
	if (!((filter->op=="IN"&&filter->keys.size()>0) || (filter->op!="IN"&& filter->keys.size()==0)))
		throw_error("When the op=IN, we must have keys; otherwise keys is always empty!\n");
	if (!filter->is_complex && filter->rhs.find(".size")!=filter->rhs.npos)
		throw_error("Not support .size appearing at right hand size!\n");
	if (filter->is_complex && filter->cplx_rhs.find(".size")!=filter->cplx_rhs.npos)
		throw_error("Not support .size appearing at right hand size!\n");
	if (filter->is_ipset && (filter->is_complex || filter->op!="IN" || filter->keys.size()>1))
		throw_error("Not support IPSET with complex predicate or ops other than IN or multiple keys!\n");
	if (filter->is_ipset && filter->lhs!="sip" && filter->lhs!="dip")
		throw_error("Not support IPSET with lhs other than sip or dip!\n");
	return filter;
}

//extracts a distinct policy from a given line
Distinct* Policy::parse_distinct (string line) {
	regex reg_distinct("\\.distinct\\s*\\(\\[(\\w+(,\\s*\\w+)*)\\]\\)");
	if (!std::regex_match(line.begin(), line.end(), reg_distinct)) {
		throw_error("Invalid Distinct statement");
	}

	smatch match;
	Distinct *distinct = new Distinct();
	if (regex_search(line, match, reg_distinct)) {
		cout<<match.str(1)<<endl;
		vector<string> keys = split(match.str(1), ",");
		for (string item: keys)
			distinct->add_key(trim(item));
	} else {
		throw_error("Invalid Distinct statement");
	}

	distinct->print();
	return distinct;
}


//extracts a when policy from a given line
When* Policy::parse_when(string cur_line) {
	When *when = new When();

	//extract the '[]' enclosed conditions.
	string params = extract_params(cur_line);
	string conds;
	extract_substr_sqaure(params, 0, &conds);
	extract_conds(conds, when);
	if (when->lhs.find(".isempty") != when->lhs.npos)
		when->has_empty = true;

	//extract the user-defined function, fwd=
	regex func("fwd=(\\w+)");
	smatch match;
	if (regex_search(cur_line, match, func))
		when->set_func(match.str(1));
	else
		when->set_func("");

	when->print();
	// grammar check
	if (when->func != "f_reroute" && when->func != "f_drop" && when->func != "")
		throw_error("Only support f_reroute and f_drop as when func.");
	if (!when->is_complex && when->rhs.find(".size")!=when->rhs.npos)
		throw_error("Not support .size appearing at right hand size!\n");
	if (when->is_complex && when->cplx_rhs.find(".size")!=when->cplx_rhs.npos)
		throw_error("Not support .size appearing at right hand size!\n");
	if (when->is_ipset && (when->is_complex || when->op!="IN" || when->keys.size()>1))
		throw_error("Not support IPSET with complex predicate or ops other than IN or multiple keys!\n");
	if (when->is_ipset && when->lhs!="sip" && when->lhs!="dip")
		throw_error("Not support IPSET with lhs other than sip or dip!\n");
	return when;
}


//extracts a map policy from a given line
Map* Policy::parse_map(string line) {
	regex reg_map("\\.map\\s*\\(\\[(\\w+(,\\s*\\w+)*)\\],\\s*\\[(\\w+)\\],\\sf=(\\w+)\\)");
	if (!std::regex_match(line.begin(), line.end(), reg_map)) {
		throw_error("Invalid Map statement");
	}

	smatch match;
	Map *map = new Map();
	if (regex_search(line, match, reg_map)) {
		vector<string> keys = split(match.str(1), ",");
		for (string item: keys)
			map->add_from(trim(item));
		map->set_to(match.str(3));
		map->set_func(match.str(4));
	} else {
		throw_error("Invalid Map statement");
	}

	map->print();
	// grammar check
	if (map->from[0] == "link") {
		if (map->from.size() != 1)
			throw_error("The from size of Map must be 1!\n");
		if (map->func != "f_load")
			throw_error("The map func must be load when the from is link!\n");
	} else {
		if (map->func != "f_id")
			throw_error("When the Map from is not link, the function must be f_id. Other funcs have not been supported!\n");
	}
	return map;
}

//extracts a zip policy from a given line
Zip* Policy::parse_zip(string line) {
	regex reg_zip("\\.zip\\s*\\(\\[(\\w+(,\\s*\\w+)*)\\],\\s*\\[(\\w+)\\],\\s*\\[(\\w+)\\]\\)");
	if (!std::regex_match(line.begin(), line.end(), reg_zip)) {
		throw_error("Invalid Zip statement");
	}

	smatch match;
	Zip * zip = new Zip();
	if (regex_search(line, match, reg_zip)) {
		vector<string> keys = split(match.str(1), ",");
		for (string item: keys)
			zip->add_key(trim(item));
		zip->set_input1(match.str(3));
		zip->set_input2(match.str(4));
	} else {
		throw_error("Invalid Zip statement");
	}

	zip->print();
	return zip;
}

int Policy::add_stmt (Filter *f) {
	stmt s;
	s.op = (Op*)f;
	s.type = "Filter";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (Reduce *r) {
	stmt s;
	s.op = (Op*)r;
	s.type = "Reduce";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (Distinct *d) {
	stmt s;
	s.op = (Op*)d;
	s.type = "Distinct";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (When *w) {
	stmt s;
	s.op = (Op*)w;
	s.type = "When";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (Zip *z) {
	stmt s;
	s.op = (Op*)z;
	s.type = "Zip";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (Panorama *p) {
	stmt s;
	s.op = (Op*)p;
	s.type = "Panorama";
	this->stmts.push_back(s);
	return this->stmts.size();
}

int Policy::add_stmt (Map *m) {
	stmt s;
	s.op = (Op*)m;
	s.type = "Map";
	this->stmts.push_back(s);
	return this->stmts.size();
}

extern int get_zip_reduce_line(Policy* pol, string input);
extern bool check_zip_cross(Policy* pol, string input);
extern bool check_zip_filter(Policy* pol, int reduce_line);

bool Policy::grammar_check() {
	// The policy cannot be empty
	if (this->stmts.empty())
		throw_error("This policy is empty!\n");

	// Must start with a Panorama stmt
	if (this->stmts[0].type != "Panorama")
		throw_error("The first stmt of a policy must be Panorama!\n");

	for (int line=0; line<this->stmts.size(); line++) {
		if (this->stmts[line].type=="Map"){
			Map *m = (Map *)this->stmts[line].op;
			// if use distinct, then the key of the map and the distinct must be consistent
			if (this->stmts[line-1].type == "Distinct"){
				Distinct *dis = (Distinct *)this->stmts[line-1].op;
				if (!equal_set(m->from, dis->keys))
					throw_error("The key of the map and the distinct must be consistent!\n");
			}
		}
	}

	for (int line=0; line<this->stmts.size(); line++) {
		if (this->stmts[line].type=="Zip"){
			Zip *z = (Zip *)this->stmts[line].op;
			int input1_line = get_zip_reduce_line(this, z->input1);
    		int input2_line = get_zip_reduce_line(this, z->input2);
			if (input1_line<=0 || input2_line<=0)
				throw_error("The zip input must be the result of reduce!\n");

			vector<string> input1_key = ((Reduce*)this->stmts[input1_line].op)->key;
			vector<string> input2_key = ((Reduce*)this->stmts[input2_line].op)->key;
			if(!equal_set(input1_key, input2_key))
				throw_error("The key of the reduce must be the same!\n");

			bool input1_cross = check_zip_cross(this, z->input1);
			bool input2_cross = check_zip_cross(this, z->input2);
			if(!((input1_cross && input2_cross) || (!input1_cross && !input2_cross)))
				throw_error("The Zip input must be both cross switches or not!\n");

			int reduce_line1 = get_zip_reduce_line(this, z->input1);
			int reduce_line2 = get_zip_reduce_line(this, z->input2);
			if (!check_zip_filter(this, reduce_line1) || !check_zip_filter(this, reduce_line2))
				throw_error("Currently, we only support link == 1 || link == 2 like conditions for Zip!\n");
		}
	}

	// has self zip
	for (int line=0; line<this->stmts.size(); line++) {
		if (this->stmts[line].type=="Zip"){
			Zip *z = (Zip *)this->stmts[line].op;
			if (z->input1==z->input2){
				this->has_selfzip = true;
				this->szip.input1 = z->input1+"1";
				this->szip.input2 = z->input2+"2";
				bool find_reduce = false;
				for (int i=line-1; i>=0; i++){
					if (this->stmts[i].type=="Reduce"){
						Reduce *r = (Reduce *)this->stmts[i].op;
						if (r->result==z->input1) {
							find_reduce = true;
							this->szip.reduce_value = r->value;
							break;
						}
					}
				}
				if (!find_reduce)
					throw_error("Do not find a reduce for self Zip!\n");
			}
		}
	}
}

void Policy::print_stmt() {

	cout << "Printing a Type-" << this->type << " policy with " << this->stmts.size() << " stmts" << endl;
	for (int i = 0; i < this->stmts.size(); i ++) {
		cout << "==statement " << i << endl;
		if (this->stmts[i].type == "Map") {
			Map *m = (Map *)this->stmts[i].op;
			m->print();
		} else if (this->stmts[i].type == "Filter") {
			Filter *f = (Filter *)this->stmts[i].op;
			f->print();
		} else if (this->stmts[i].type == "Reduce") {
			Reduce *r = (Reduce *)this->stmts[i].op;
			r->print();
		} else if (this->stmts[i].type == "Distinct") {
			Distinct *d = (Distinct *)this->stmts[i].op;
			d->print();
		} else if (this->stmts[i].type == "When") {
			When *w = (When *)this->stmts[i].op;
			w->print();
		} else if (this->stmts[i].type == "Zip") {
			Zip *z = (Zip *)this->stmts[i].op;
			z->print();
		} else if (this->stmts[i].type == "Panorama") {
			Panorama *p = (Panorama *)this->stmts[i].op;
			p->print();
		} else {
			throw_error("Cannot support statement type " + this->stmts[i].type);
		}
	}

}

