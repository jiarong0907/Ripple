before = panorama (100)
.when ([rerouteip.isempty == 1])
.reduce ([sip], [flowsz1], [pktlen])

after = panorama (100)
.when ([rerouteip.isempty == 0])
.reduce ([sip], [flowsz2], [pktlen])

rerouteip = panorama (100)
.when([victimLks.size > 3], fwd=f_reroute)
.distinct ([sip])

suspicious = panorama (100)
.filter(sip IN rerouteip)
.zip([sip], [flowsz1], [flowsz2])
.filter(flowsz2 - flowsz1 < 100)