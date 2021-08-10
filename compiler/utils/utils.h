#ifndef _UTILS_H
#define _UTILS_H

#include <string>
#include <vector>
#include <map>
#include <cassert>
#include <iostream>
#include <fstream>
#include <regex>
#include <arpa/inet.h>

using namespace std;

/**
 * Split a string into tokens by deliminators
*/
vector<string> split(const string& str, const string& delim) {
	vector<string> tokens;
	size_t prev = 0, pos = 0;
	do
	{
		pos = str.find(delim, prev);
		if (pos == string::npos) pos = str.length();
		string token = str.substr(prev, pos-prev);
		if (!token.empty()) tokens.push_back(token);
		prev = pos + delim.length();
	}
	while (pos < str.length() && prev < str.length());
	return tokens;
}

/**
 * trim functions
 */
string & ltrim(string & str)
{
  auto it2 =  find_if(str.begin(), str.end(), [](char ch){ return !isspace<char>(ch, locale::classic()); } );
  str.erase( str.begin() , it2);
  return str;
}

string & rtrim(string & str)
{
  auto it1 =  find_if(str.rbegin(), str.rend(), [](char ch){ return !isspace<char>(ch, locale::classic()); } );
  str.erase(it1.base(), str.end());
  return str;
}

/**
 * Use this for triming a string's starting and ending white space.
 */
string & trim(string & str)
{
   return ltrim(rtrim(str));
}

/**
 * Check that the given string only contains digits.
*/
bool has_only_digits(const string s) {
	bool ans = true;
	for (size_t n = 0; n < s.length(); n++) {
		if (!isdigit(s[n])) {
			ans = false;
			break;
		}
	}
	return ans;
}


/**
 * Starting at the start index, extract the first [] substring from the params_string.
 * Return the index pointing to the right square bracket.
 */
int extract_substr_sqaure(string params_string, int start_idx, string* enclosed_substr) {
	int i = start_idx;
	while ((i<params_string.length()) && (params_string[i] != '['))
		i ++;
	//i points to '[' of the first list of items
	int j = i+1;
	while ((j<params_string.length()) && (params_string[j] != ']'))
		j ++;
	//j points to ']' of the first list of items;
	int len = j-(i+1);

	//extract variables from this [] enclosed region
	*enclosed_substr = params_string.substr(i+1, len);
	return j;
}


/**
 * Starting at the start index, extract the first [] enclosed conds list from the params_string.
 * Return the index pointing to the right square bracket.
 *
 * TODO: Use this function when '||' and '&&' is suported for when function.
 */
int extract_conds_sqaure(string params_string, int start_idx, vector<string>* conds) {
	string conds_str;
	int j = extract_substr_sqaure(params_string, start_idx, &conds_str);
	string delim("||");
	*conds = split(conds_str, delim);
	return j;
}


/**
 * extract the '||' connected condtions from the params_string.
 */
int extract_vars_sqaure(string params_string, int start_idx, vector<string>* variables) {
	string items_str;
	int j = extract_substr_sqaure(params_string, start_idx, &items_str);
	//extract variables from this [] enclosed region
	string delim(",");
	*variables = split(items_str, delim);
	return j;
}

/**
 * Find all the substrings that match the pattern in the given str.
 * Stores matches in rets vector.
 * Return the number of elements in the reslts vector.
 */
int reg_extract_all(string str, vector<string>* rets, vector<int>* results_idx, regex pattern)
{
	sregex_iterator iter(str.begin(), str.end(), pattern);
	sregex_iterator end;
	//iterate through all the matches
	while(iter != end)
	{
		//match str
		rets->push_back(iter->str());
		//match idx
		results_idx->push_back(iter->position());
		++iter;
	}
	return rets->size();
}

/**
 * Extract the () enclosed parameters substring of current line of a operation.
 * Return the substring.
 */
string extract_params(string current_line) {
	vector<string> params; //stores all parameters
	vector<int> params_idx; //stores indices of all parameters

	regex params_pattern("\\(.*\\)"); //pattern of arithop
	reg_extract_all(current_line, &params, &params_idx, params_pattern);
	string params_string = params[0];
	return params_string;
}

/**
 * Extract the first variable name from the start_idx of str.
 * Return the idx pointing to the end of this variabel_name.
 */
int extract_var(string str, int start_idx, string* result) {
	int i, j, len;
	i = start_idx;
	while ((i<str.length()) && ((str[i]<'a')||(str[i]>'z')))
		i ++;
		//i now points to the first character of the lhs variable of the filter predicate.
	j = i+1;
	while ( (j<str.length()) &&  ( ((str[j]>='a')&&(str[j]<='z')) || ((str[j]>='A')&&(str[j]<='Z')) ||(str[j]=='.') || (str[j]=='_') || ((str[j]>='0')&&(str[j]<='9'))) )
		j ++;
	len = j-i;
	*result = str.substr(i, len);
	return j;
}

/**
 * Extract the first real number string from the start_idx of str.
 * Return the idx pointing to the end of this variabel_name.
 */
int extract_realnum(string str, int start_idx, string* result) {
	int i, j, len;
	i = start_idx;
	while ( (i<str.length()) &&  ((str[i]<'0')||(str[i]>'9')) )
		i ++;
		//i now points to the first character of the lhs variable of the filter predicate.
	j = i+1;
	while ( (j<str.length()) &&  ( ((str[j]>='0')&&(str[j]<='9')) || (str[j]=='.') ) )
		j ++;
	len = j-i;
	*result = str.substr(i, len);
	return j;
}


void extract_conds(string conds, Branch* branch) {
	//split '||' connected conds

	branch->set_complex(false);

	vector<string> arithops; // stores all arithops
	vector<int> arithops_idx; // stores indices of all arithops
	vector<string> ops; // stores all operators
	vector<string> ipset; // stores all ipset
	vector<int> ops_idx; //sotreas indices of all operators
	vector<int> ipset_idx; //sotreas indices of all operators

	regex arithop_pattern("\\+|-|\\*|/"); // pattern of arithop
	regex op_pattern("<=|==|>=|>|<|!=|IN"); // pattern of operators
	regex ipset_pattern("IPSET\\[(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])/(8|16|24|32)\\]"); // pattern of operators
	reg_extract_all(conds, &arithops, &arithops_idx, arithop_pattern); //extract all arithops
	reg_extract_all(conds, &ops, &ops_idx, op_pattern); // extract all operators
	reg_extract_all(conds, &ipset, &ipset_idx, ipset_pattern); // extract all ipset

	assert(ipset.size()==0||ipset.size()==1);

	// is this a simple predicate 'lhs op rhs' or a complex predicate 'field1 arithop field2 op rhs'?
	if (arithops.size() != 0)
		branch->set_complex(true);

	if (ipset.size()==1) {
		string subnet;
		extract_substr_sqaure(ipset[0], 0, &subnet);
		string ip = split(subnet, "/")[0];
		string suffix = split(subnet, "/")[1];
		uint32_t netmask; // network ip subnet mask
		if (suffix=="8") 		netmask=0xff000000;
		else if (suffix=="16") 	netmask=0xffff0000;
		else if (suffix=="24") 	netmask=0xffffff00;
		else 				 	netmask=0xffffffff;
		branch->set_ipset(true);
		branch->set_ip_start((htonl(inet_addr(ip.c_str())) & netmask)); // first ip in subnet
		branch->set_ip_end((branch->get_ip_start() | ~netmask)); // last ip in subnet
		string vars = conds.substr(0, ops_idx[0]);
		string delim(",");
		vector<string> keys = split(vars, delim);
		string lhs;
		if (keys.size() > 1) {
			for (string key : keys) {
				branch->add_key(trim(key));
			}
		} else {
			lhs = trim(keys[0]);
			branch->add_key(lhs);
		}
		branch->set_lhs(lhs);
		branch->set_op("IN");
		branch->set_rhs("NULL");
		branch->set_complex(false);
		return;
	}


	if (!branch->get_complex()) {
		//pred_op
		int end_of_op = ops_idx[0] + ops[0].size();
		string op = ops[0];

		string lhs, rhs;
		/*process simple predicate 'lhs op rhs'*/
		if (op=="IN") {
			// lhs
			string vars = conds.substr(0, ops_idx[0]);
			string delim(",");
			vector<string> keys = split(vars, delim);
			if (keys.size() > 1) {
				for (string key : keys) {
					branch->add_key(trim(key));
				}
			} else {
				lhs = trim(keys[0]);
				branch->add_key(lhs);
			}
			// then rhs must be a global variable that has already been defined in some policies
			extract_var(conds, end_of_op, &rhs);
		} else {
			/**
			* TODO: Future lhs, rhs matching using reg-ex:
			* *https://stackoverflow.com/questions/27927913/find-index-of-first-match-using-c-regex
			*/
			//extracting the filter condition, lhs
			extract_var(conds, 0, &lhs);
			//((op=="<=")||(op==">=")||(op==">")||(op=="<")||(op=="==")||(op=="!=")) {
			// then rhs must be a number
			extract_realnum(conds, end_of_op, &rhs);
		}

		branch->set_lhs(lhs);
		branch->set_op(op);
		branch->set_rhs(rhs);

	} else {
		/*process a complex predicate 'field1 arithop field2 op rhs' */

		//extracting field1
		string field1;
		extract_var(conds, 0, &field1);

		//extract arithmetic operator arithop
		int end_of_arithop = arithops_idx[0] + arithops[0].size();
		string arithop = arithops[0];

		//extract field2
		string field2;
		extract_var(conds, end_of_arithop, &field2);

		//extract comparison operator op
		int end_of_op = ops_idx[0] + ops[0].size();
		string op = ops[0];

		//extract rhs, which must be a number
		string rhs;
		extract_realnum(conds, end_of_op, &rhs);

		//construct complex filter:
		branch->set_cplx_field1(field1);
		branch->set_cplx_field2(field2);
		branch->set_cplx_arithop(arithop);
		branch->set_cplx_op(op);
		branch->set_cplx_rhs(rhs);
	}
}




#endif