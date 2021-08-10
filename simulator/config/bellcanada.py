#!/usr/bin/python

"""config.txt: Configuration file. Contains the parameter needed.
"""

import os
import math

# ---------------------------------------
# System setting
# ---------------------------------------
EXP_NAME                = 'bellcanada'
TOPO                    = './topologies/bellcanada/bellcanada.gml'
PATH_DB                 = './topologies/bellcanada/path.json'
ATTACK                  = './topologies/bellcanada/attack.json'
REROUTE1                = './topologies/bellcanada/reroute-0.json'
REROUTE2                = './topologies/bellcanada/reroute-1.json'
REROUTE1_NOCLASS        = './topologies/bellcanada/reroute-0-noclass.json'
REROUTE2_NOCLASS        = './topologies/bellcanada/reroute-1-noclass.json'
REROUTE1_SAMCLASS       = './topologies/bellcanada/reroute-0-samclass.json'
REROUTE2_SAMCLASS       = './topologies/bellcanada/reroute-1-samclass.json'

LOG_DIR                 = os.path.join('./logs/', EXP_NAME)
SIM_TIME                = 10.0 # 10 seconds
CAP_PER_LINK            = 40000000 # 40Gbps
SRC_LIMITED             = 1  # If 1, flow rates are limited by its source rate.
                             # If 0, flow can transmit as fast as possible subject to link capacity constraints and max-min fairness.
SYSTEM_TYPE             = 'RIPPLE' # RIPPLE or SDN
K_PATH                  = 100   # Number of predefined path per src-dst pair. -1 means list all shortest.
PERIOD_DETECT           = 0.100
PERIOD_ClASS            = 0.100
PERIOD_UPDATE_FLOWRATE  = 0.0500  # Period of doing link util and table util logging.
HAS_CLASSIFICATION      = 1
SAMPLED_CLASSIFICATION  = 0
assert not (HAS_CLASSIFICATION == 0 and SAMPLED_CLASSIFICATION==1)
CLASS_SAMPLE_RATE       = 0.01 # 1% flows are sent to the central controller for classification
CONGEST_THRESH          = 0.95 # The link that has more 95% utilization is regarded as congested
CONGEST_LINK_THRESH     = 1    # if 1 or more links are congested, the network is under attack

IP_SEGMENT              = 8192
NO_DEFENSE              = 0
ROLLING                 = 0

# ----------------------------------------
# Synchronization Parameters
# ----------------------------------------
LINK_DELAY              = 0.0005    # per-link latency is 500us
SYNC_PERIOD             = 0.01      # 10ms
SOL_TIME_DPCLASS        = 5.9353    # get from sol experiments
SOL_TIME_NOCLASS        = 6.3032    # get from sol experiments
SOL_TIME_SAMCLASS       = 0.0988    # get from sol experiments
RULE_INSTALL_TIME       = 0.003     # 3ms to install rule entries
SDN_SOFTWARE_TIME       = 0.001     # the controller solftware time, test from ns3 experiments


# ----------------------------------------
# Attack-related Parameters
# ----------------------------------------
ATTACK_START            = 2
ATTACK_PERIOD           = 2
ATTACK_TYPE             = 'CROSSFIRE'
ROLLING_GAP             = 1
ROLLING_ROUNDS          = 3
NORM_FLOW_RATE          = 10000   #1Mbps


# ----------------------------------------
# Crossfire Parameters
# ----------------------------------------
CROSSFIRE_RATE          = 1000       #100Kbps
CROSSFIRE_RATE_THRESH   = 2000       #200Kbps
CROSSFIRE_NFLOW_THRESH  = 5
CROSSFIRE_FLOW_PER_HOST = 10



# ----------------------------------------
# Logging Options
# ----------------------------------------
LOG_LINK_UTIL           = 1
LOG_LEVEL               = 2
LOG_LINK1                = ('sw35', 'sw40')
LOG_LINK2                = ('sw45', 'sw34')
PERIOD_LOGGING          = 0.005


# ----------------------------------------
# Screen Printing Options
# ----------------------------------------
SHOW_PROGRESS           = 1
SHOW_K_PATH_CONST       = 0
PERIOD_PRINTING         = 0.100
PRINT_LINK_UTIL         = 0
SHOW_SUMMARY            = 1
