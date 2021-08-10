#ifndef METADATA_H
#define METADATA_H


#include <assert.h>

#include "element.h"

class MetadataField : public Element {
private:
	string name;
	int width;

public:
	MetadataField (string name, int width) {
		this->name = name;
		this->width = width;
	}

	string get_name() {	return this->name; }
	int get_width() { return this->width; }
	string compile(string indent) {
		string code = indent + "bit<"+to_string(this->width)+">";
		code += " " + this->name+";\n";
		return code;
	}
	void print() { cout<<this->compile("")<<endl;	}
};

class Metadata : public Element {
private:
	string name;
	vector<MetadataField> fields;

public:
	Metadata (string name) { this->name = name; }

	bool name_exist(string name) {
		for (auto item : this->fields) {
			if (item.get_name() == name)
				return true;
		}
		return false;
	}

	bool field_exist(MetadataField field) {
		for (auto item : this->fields) {
			if (item.get_name() == field.get_name())
				return true;
		}
		return false;
	}

	bool add_field(MetadataField field) {
		// check name conflict
		if (field_exist(field))
			return false;
		this->fields.push_back(field);
		return true;
	}

	void init (bool has_reroute, bool has_c2, int d_pano, int c_pano, int m_pano, vector<string> &filters) {
		this->add_field(MetadataField("sip", 32));
		this->add_field(MetadataField("dip", 32));
		this->add_field(MetadataField("sport", 16));
		this->add_field(MetadataField("dport", 16));

		this->add_field(MetadataField("filter", 32));

		this->add_field(MetadataField("high_load", 32));
		this->add_field(MetadataField("swid", 32));
		this->add_field(MetadataField("link", 32));
		this->add_field(MetadataField("pktlen", 32));
		this->add_field(MetadataField("reroute", 32));

		this->add_field(MetadataField("this_ts_val", 48));
		this->add_field(MetadataField("d_wind_last_ts_val", 48));
		this->add_field(MetadataField("d_wind_interval", 48));
		if (has_reroute){
			this->add_field(MetadataField("probe_update", 32));
		}

		// detection filter
		for (int i=1; i <= d_pano; i++){
			this->add_field(MetadataField("detection_filter"+to_string(i), 32));
			filters.push_back("detection_filter"+to_string(i));
		}


		// classification filter
		if (!has_c2) {
			for (int i=1; i <= c_pano; i++){
				this->add_field(MetadataField("classification_filter"+to_string(i), 32));
				filters.push_back("classification_filter"+to_string(i));
			}
		} else {
			for (int i=1; i <= c_pano; i++){
				this->add_field(MetadataField("classification_filter"+to_string(i)+"_p1", 32));
				filters.push_back("classification_filter"+to_string(i)+"_p1");
			}
			for (int i=1; i <= c_pano; i++){
				this->add_field(MetadataField("classification_filter"+to_string(i)+"_p2", 32));
				filters.push_back("classification_filter"+to_string(i)+"_p2");
			}
		}

		// Mitigation filter
		for (int i=1; i <= m_pano; i++){
			this->add_field(MetadataField("mitigation_filter"+to_string(i), 32));
			filters.push_back("mitigation_filter"+to_string(i));
		}
	}

	string get_name() {	return this->name; }

	string compile(string indent) {
		string code = indent + "struct metadata {\n";
		for (auto item : this->fields)
			code += item.compile(indent + "    ");
		code += indent + "}\n\n";
		return code;
	}

	void print() { cout<<this->compile("")<<endl; }
};


#endif