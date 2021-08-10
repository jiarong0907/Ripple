#!/usr/bin/python
# -*- coding: utf-8 -*-
"""sim/SimPathDB.py:
"""

# Built-in modules
from time import *
import sys
import os
import json
#import random as rd

# Third-party modules
import networkx as nx
# User-defined modules
import SimConfig as Config


class SimPathDB:

    def setup_path_db(self):
        print('='*80)
        print("Building path database for all src-dst node pairs...")
        path_db = {}     # empty dict

        # read path from json
        with open(Config.PATH_DB) as f:
            json_dict = json.load(f)

        npath = json_dict['npath']
        paths = json_dict['paths']
        for path in paths.values():
            src  = path['src']
            dst  = path['dst']
            hops = path['hops']
            path_db[(src, dst)] = hops


        self.path_db = path_db

        # print(self.path_db)
        print("Finish building path database for all src-dst node pairs.")


    def build_pathdb_kpath_yen(self, src, dst, k=Config.K_PATH):
        """Yen's algorithm for building k-path.
        Please refer to Yen's paper.

        Args:
            src (string): Source node, which is an edge switch.
            dst (string): Dest node, also an edge switch. src != dst
            k (int): # of paths to find from src to dst

        return:
            list: list of k available paths from src to dst.
                  Each path is represented by a list of node names.
        """
        st_time = time()

        if (Config.K_PATH < 0):
            print("Yen's algorithm: wrong value of K_PATH")
            sys.exit(1)


        if (Config.SHOW_K_PATH_CONST > 0):
            print("Finding %d paths from %s to %s" %(k, src, dst))

        confirmed_paths = []
        confirmed_paths.append(nx.shortest_path(self.topo, src, dst) )
        if (k <= 1):
            return confirmed_paths

        potential_paths = []

        for j in range(1, k):
            for i in range(0, len(confirmed_paths[j-1]) - 1):
                myTopo = nx.DiGraph(self.topo)      # Copy the topology graph
                myPath = confirmed_paths[j-1]
                spurNode = myPath[i]
                rootPath = myPath[0:i+1]

                l = len(rootPath)

                for p in confirmed_paths:
                    if (rootPath == p[0:l]):
                        if (myTopo.has_edge(p[l-1], p[l])):
                            myTopo.remove_edge(p[l-1], p[l])
                        else:
                            pass

                for q in rootPath[:-1]:
                    myTopo.remove_node(q)

                try:
                    spurPath = nx.shortest_path(myTopo, spurNode, dst)
                    totalPath = rootPath + spurPath[1:]
                    potential_paths.append(totalPath)
                except:
                    spurPath = []

            if (len(potential_paths) == 0):
                break

            potential_paths = sorted(potential_paths, key=lambda x: len(x) )
            confirmed_paths.append(potential_paths[0])
            potential_paths = []

        ed_time = time()

        if (Config.SHOW_K_PATH_CONST > 0):
            print("%d-paths from %s to %s:" %(k, src, dst), confirmed_paths)
            print("Time elapsed:", ed_time-st_time)

        return confirmed_paths



    def find_path(self, src_node):
        """Given src and dst IPs, find the path in the database.
        1. Path is described as a list of node names (strings).

        Args:
            src_node : source host

        Returns:
            list of strings: Chosen path

        """
        src = src_node.flow_srcsw
        dst = src_node.flow_dstsw
        return self.path_db[(src, dst)]


