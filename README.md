# Ripple: A Programmable, Decentralized Link-Flooding Defense Against Adaptive Adversaries

Ripple is a programmable, decentralized link-flooding defense against dynamic adversaries. One can specify a range of defenses using the declarative policy language in Ripple without caring about the low-level details. 
Under the hood, the Ripple compiler will compile the policy to P4 programs and synchronize the global state across switches. For more information, please read our [paper](https://jxing.me/pdf/ripple-sec21.pdf).


## The Ripple compiler

The compiler is under `./compiler`. The example policies are in `./compiler/policies` To run the code
```
make
./ripple
```
The generated P4 code will be stored in `./compiler/policies/output`. To compile the P4 code, you need to install `p4c` and `bmv2` in advance, and then run
```
p4c-bm2-ss --p4v 16 "out.p4" -o "out.json"
```


## The flow-level simulator for link-flooding attacks and defenses

This is a flow-level simulator to simulate link-flooding attacks and defenses. The code is developed based on an SDN simulator FlowSim-PyPy(https://github.com/cgi0911/FlowSim-PyPy). It currently supports Crossfire attacks and defenses including blindly rerouting or classification + rerouting for both SDN and P4 solutions, but more attacks and defenses can be easily added. 
The code simulates the attack and defense in an event-driven manner. It first schedules a few deterministic events in advance including flow arrival, periodic flow rate update, and attack at a certain time point. More events will be scheduled at runtime. For example, once detecting the attack, a classification event will be scheduled if it is enabled. 

### To run the code

**Step1:** The simulator uses a configuration file to config the simulation. You first need to update the configuration accordingly in `simulator/config`.

**Step2:** It is recommended to run the simulator with PyPy (https://www.pypy.org/) environment, which is much faster than conventional Python distributions. 

**Step3:** The entry point of the simulator is `simulator/run_sim.py`. After modifying the configuration file path in it, you can now run the simulation with `python2.7 run_sim.py`.

**Step4:** The simulation will generate log files stored in `simulator/logs`. They would be very helpful to understand the simulation results.


## Known issues
- The Ripple language does not have a formal syntax, so we opt for an ad-hoc manner to parse and compile the policy. Currently, the compiler can support examples under the policy folder. It might ("must") have bugs for other policies. Feel free to enhance the code and create a pull request.

- The FlowSim-PyPy is developed with Python2 and we inherit its code, so the current simulator can only be run with Python2. It will require some engineering efforts to support Python3. Please feel free to try and create a pull request.

## Citation
If you feel our paper and code is helpful, please consider citing our paper by:
```
@inproceedings{xing2020ripple,
  title={Ripple: A Programmable, Decentralized Link-Flooding Defense Against Adaptive Adversaries},
  author={Xing, Jiarong and Wu, Wenqing and Chen, Ang},
  booktitle={30th USENIX Security Symposium (USENIX Security'21)},
  year={2021}
}
```


## License
The code is released under the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html).


