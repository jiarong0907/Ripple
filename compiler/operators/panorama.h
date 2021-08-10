#ifndef _PANORAMA_H
#define _PANORAMA_H

#include <string>
#include <vector>
#include <cassert>
#include <iostream>
#include <regex>

#include "../utils/colors.h"

using namespace std;

class Panorama {
private:
    string ret_val;
    int window;

    friend class Policy;
    friend class Program;

public:
    Panorama(){};

    void set_return(string return_val){
        this->ret_val = return_val;
    }
    void set_window(int win){
        this->window = win;
    }
    string to_string() {
        //construct the from items:
        string ans = "return_val: [" + this->ret_val + "]\n";
        //construct the val items:
        ans += "Window: [" + std::to_string(this->window) + "]\n";
        return ans;
    }
    void print() {
        cout << bold << yellow << "Panorama:" << reset << endl;
        cout << yellow << this->to_string() <<reset << endl;
    }
};

#endif