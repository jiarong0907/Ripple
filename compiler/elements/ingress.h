#ifndef INGRESS_H
#define INGRESS_H


#include <assert.h>
#include "register.h"
#include "table.h"
#include "dct.h"
#include "cls.h"
#include "mtg.h"
#include "probe.h"
#include "sync.h"

class Apply : public Element {
private:
	string name;
	RegisterList* regs;
	TableList* tabs;
	Metadata* metadata;

	string init_filter;
	string init_other;

	Dct* dct;
	Cls* cls;
	Mtg* mtg;
	Probe* probe;
	Sync* sync;

public:
	Apply (string name) { this->name = name; }
	void set_regs(RegisterList* regs) {this->regs = regs; }
	void set_tabs(TableList* tabs) {this->tabs = tabs; }
	void set_metadata(Metadata* meta) {this->metadata = meta; }
	void set_dct(Dct* dct) {this->dct = dct; }
	void set_cls(Cls* cls) {this->cls = cls; }
	void set_mtg(Mtg* mtg) {this->mtg = mtg; }
	void set_probe(Probe* probe) {this->probe = probe; }
	void set_sync(Sync* sync) {this->sync = sync; }

	void emit_filter(string indent, vector<string> filters) {
		string code = indent + "if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 0){\n";
		code       += indent + "    meta.filter = 1;\n";
		for (int i=0; i < filters.size(); i++)
			code   += indent + "    meta."+filters[i]+" = 1;\n";
		code       += indent + "} else {\n";
		code       += indent + "    meta.filter = 0;\n";
		for (int i=0; i < filters.size(); i++)
			code   += indent + "    meta."+filters[i]+" = 0;\n";
		code       += indent + "}\n\n";
		this->init_filter = code;
	}

	string emit_ts(string indent, string register_name, string interval_name){
		string code = indent +	register_name+".read(meta."+register_name+"_val, 0);\n";
		code       += indent +	"if (meta."+register_name+"_val == 0){\n";
		code       += indent +	"    "+register_name+".write(0, standard_metadata.ingress_global_timestamp);\n";
		code       += indent +	"    meta."+register_name+"_val = standard_metadata.ingress_global_timestamp;\n";
		code       += indent +	"}\n";
		code       += indent +	"meta."+interval_name+" = meta.this_ts_val - meta."+register_name+"_val;\n";
		return code;
	}

	void emit_init_others(string indent, bool has_reroute, bool has_c2){
		string code = indent + "if (meta.filter == 1){\n";
			  code += indent + "    meta.high_load = 1;\n";
			  code += indent + "    meta.sip = hdr.ipv4.srcAddr;\n";
			  code += indent + "    meta.dip = hdr.ipv4.dstAddr;\n";
			  code += indent + "    meta.sport = hdr.tcp.srcPort;\n";
			  code += indent + "    meta.dport = hdr.tcp.dstPort;\n";
			  code += indent + "    meta.pktlen = standard_metadata.packet_length;\n";
			  code += indent + "    meta.this_ts_val = standard_metadata.ingress_global_timestamp;\n\n";
			  code += indent + "    d_swid.read(meta.swid, 0);\n";
			  if (has_reroute){
			  	code += indent + "    reroute.read(meta.reroute, 0);\n";
			  }
			  code += indent + "    set_nhop_tab.apply();\n";
			  code += indent + "    meta.link = (meta.swid << 3) + (bit<32>)standard_metadata.egress_spec;\n";
		if (has_reroute){
			code   += indent + "    tab_dstIPtoSWID.apply();\n\n";
			Table tmp = Table("probe");
			this->tabs->add_table(tmp);
			this->tabs->add_table(Table("toSWID"));
			this->metadata->add_field(MetadataField("ip_to_swid", 32));
		}

		code += emit_ts(indent+"    ", "d_wind_last_ts", "d_wind_interval") + "\n";

		// Only one classification policy
		if (!has_c2){
			this->metadata->add_field(MetadataField("c_wind_last_ts_val", 48));
			this->metadata->add_field(MetadataField("c_wind_interval", 48));
			this->regs->add_register(Register("c_wind_last_ts", 48, 1));
			code += emit_ts(indent+"    ", "c_wind_last_ts", "c_wind_interval");
		}
		// There are two classification policy
		// TODO: support multiple classification policy
		else {
			this->metadata->add_field(MetadataField("c_wind_last_ts_p1_val", 48));
			this->metadata->add_field(MetadataField("c_wind_last_ts_p2_val", 48));
			this->metadata->add_field(MetadataField("c_wind_interval_p1", 48));
			this->metadata->add_field(MetadataField("c_wind_interval_p2", 48));
			this->regs->add_register(Register("c_wind_last_ts_p1", 48, 1));
			this->regs->add_register(Register("c_wind_last_ts_p2", 48, 1));
			code += emit_ts(indent+"    ", "c_wind_last_ts_p1", "c_wind_interval_p1");
			code += emit_ts(indent+"    ", "c_wind_last_ts_p2", "c_wind_interval_p2");
		}

		code += indent + "}\n";
		this->init_other = code;
	}

	string compile(string indent){
		string code = indent + "apply {\n\n";
		code += this->init_filter;
		code += this->init_other;
		code += this->dct->compile("");
		code += this->cls->compile("");
		code += this->mtg->compile("");
		code += this->probe->compile("");
		code += this->sync->compile("");
		code += indent + "}\n\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};


class Ingress : public Element {
private:
	string name;
	RegisterList* regs;
	TableList* tabs;
	Metadata* metadata;
	Apply* apply;

public:
	Ingress (string name) { this->name = name; }
	void set_regs(RegisterList *regs) {this->regs = regs; }
	void set_tabs(TableList *tabs) {this->tabs = tabs; }
	void set_metadata(Metadata *meta) {this->metadata = meta; }
	void set_apply(Apply *apply) {this->apply = apply; }

	string compile(string indent){
		string code = indent + "/*************************************************************************\n" +
					  indent + "**************  I N G R E S S   P R O C E S S I N G   *******************\n" +
					  indent + "*************************************************************************/\n\n";
		code += indent + "#include \"./outfunc.p4\"\n";
		code += indent + "control MyIngress(inout headers hdr,\n";
		code += indent + "                  inout metadata meta,\n";
		code += indent + "                  inout standard_metadata_t standard_metadata) {\n\n";
		code += this->regs->compile(indent + "    ");
		code += this->tabs->compile(indent + "    ");
		code += this->apply->compile(indent + "    ");
		code += "}\n\n";
		return code;
	}
	string get_name() { return this->name; }
	void print() { cout<<this->compile("")<<endl; }
};




#endif