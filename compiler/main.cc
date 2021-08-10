#include "program.h"
#include <sys/time.h>
#include <chrono>

using namespace std;

void compile(string detection, string cls, string mitigation, string out_name){
	Policy *d = new Policy(detection, "detection");
	Policy *c = new Policy(cls, "classification");
	Policy *m = new Policy(mitigation, "mitigation");
	Program *p = new Program(d, c, NULL, m);
	p->compile(out_name);
}


void compile_multivector (string detection, string cls1, string cls2, string mtg, string out_name) {
	Policy *d = new Policy(detection, "detection");
	Policy *c1 = new Policy(cls1, "classification");
	Policy *c2 = new Policy(cls2, "classification");
	Policy *m = new Policy(mtg, "mitigation");
	Program *p = new Program(d, c1, c2, m);
	p->compile(out_name);
}

void compile_coremelt() {
	string policy_dct("./policies/coremelt/detection.c");
	string policy_cls("./policies/coremelt/classification.c");
	string policy_mtg("./policies/coremelt/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/coremelt/");
}

void compile_crossfire() {
	string policy_dct("./policies/crossfire/detection.c");
	string policy_cls("./policies/crossfire/classification.c");
	string policy_mtg("./policies/crossfire/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/crossfire/");
}

void compile_spiffy() {
	string policy_dct("./policies/spiffy/detection.c");
	string policy_cls("./policies/spiffy/classification.c");
	string policy_mtg("./policies/spiffy/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/spiffy/");
}

void compile_spiffy2() {
	string policy_dct("./policies/spiffy2/detection.c");
	string policy_cls("./policies/spiffy2/classification.c");
	string policy_mtg("./policies/spiffy2/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/spiffy2/");
}

void compile_victimid() {
	string policy_dct("./policies/victim/detection.c");
	string policy_cls("./policies/victim/classification.c");
	string policy_mtg("./policies/victim/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/victim/");
}

void compile_keyflows() {
	string policy_dct("./policies/keyflows/detection.c");
	string policy_cls("./policies/keyflows/classification.c");
	string policy_mtg("./policies/keyflows/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/keyflows/");
}

void compile_pulsing() {
	string policy_dct("./policies/pulsing/detection.c");
	string policy_cls("./policies/pulsing/classification.c");
	string policy_mtg("./policies/pulsing/mitigation.c");
	compile(policy_dct, policy_cls, policy_mtg, "./output/pulsing/");
}

void multivector () {
	string policy_dct("./policies/composite/detection.c");
	string policy_cls1("./policies/composite/classification1.c");
	string policy_cls2("./policies/composite/classification2.c");
	string policy_mtg("./policies/composite/mitigation.c");
	compile_multivector (policy_dct, policy_cls1, policy_cls2, policy_mtg, "./output/multivector/");
}

int main () {
	auto start = chrono::steady_clock::now();

	compile_crossfire();
	compile_coremelt();
	compile_spiffy();
	compile_spiffy2();
	compile_victimid();
	compile_keyflows();
	compile_pulsing();
	multivector();

	auto end = chrono::steady_clock::now();
	cout << "Elapsed time in seconds: "
	<< chrono::duration_cast<chrono::milliseconds>(end - start).count()
	<< " milliseconds" << endl;
	return 0;
}
