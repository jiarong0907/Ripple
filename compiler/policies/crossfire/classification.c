suspicious = panorama (100)
.filter(victimLks.size > 1)
.filter(link IN victimLks)
.reduce ([sip, dip, sport, dport], [flowsz], [pktlen])
.filter(flowsz < 100)
.distinct ([sip, dip, sport, dport])
// f=id will set id = 1 for each [sip, dip, sport, dport]
.map([sip, dip, sport, dport], [id], f=f_id)
.reduce ([sip, dip], [cnt], [id])
// return [sip] as suspicious if no other operations after the filter
.filter(cnt > 15)
