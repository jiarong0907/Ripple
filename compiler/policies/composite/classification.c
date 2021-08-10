mal_coremelt = panorama (100)
.filter(victimLks.size > 3)
.filter(link IN victimLks)
.reduce ([sip], [flowsz], [pktlen])
.filter(flowsz > 100)


mal_crossfire = panorama (100)
.filter(victimLks.size > 3)
.filter(link IN victimLks)
.reduce ([sip, dip, sport, dport], [flowsz], [pktlen])
.filter(flowsz < 1)
.distinct ([sip, dip, sport, dport])
// f=id will set id = 1 for each [sip, dip, sport, dport]
.map([sip, dip, sport, dport], [id], f=id)
.reduce ([sip], [cnt], [id])
.filter(cnt > 1000)