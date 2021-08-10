#ifndef TABLE_H
#define TABLE_H


#include <assert.h>

#include "element.h"

class Table : public Element {
private:
	string name;

public:
	Table (string name) {
		assert (name=="nhop"||name=="probe"||name=="sync"||name=="toSWID");
		this->name = name;
	}
	string get_name() { return this->name; }
	string compile(string indent){
		string fname = "";
		if (this->name == "nhop") 			fname = "./templates/table_nhop.p4";
		else if (this->name == "probe") 	fname = "./templates/table_probe.p4";
		else if (this->name == "sync") 		fname = "./templates/table_sync.p4";
		else if (this->name == "toSWID") 	fname = "./templates/table_dstIPtoSWID.p4";

		ifstream infile(fname);
		assert(infile.is_open());

		string code, l;
		while (getline(infile, l))
			code += l + "\n";
		return code;
	}
	void print() { cout<<this->compile("")<<endl; }
};

class TableList : public Element {
private:
	string name;
	vector<Table> tabs;

public:
	TableList (string name) { this->name = name; }

	bool name_exist(string name) {
		for (auto item : this->tabs) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool table_exist(Table tab) {
		for (auto item : this->tabs) {
			if (item.get_name() == tab.get_name())
				return true;
		}
		return false;
	}

	bool add_table(Table tab) {
		// check name conflict
		if (table_exist(tab))
			return false;
		this->tabs.push_back(tab);
		return true;
	}

	void init () {
		this->add_table(Table("nhop"));
		this->add_table(Table("sync"));
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		string code;
		for (auto item : this->tabs)
			code += item.compile("");
		code += "\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }
};


#endif