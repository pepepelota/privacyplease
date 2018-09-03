import dns.reversename
import dns.resolver
from netaddr import IPSet, IPNetwork
import sys
import json
from scapy.all import sr, IP, TCP

# use google DNS
dns.resolver.default_resolver = dns.resolver.Resolver(configure=False)
dns.resolver.default_resolver.nameservers = ['8.8.8.8', '2001:4860:4860::8888',
                                             '8.8.4.4', '2001:4860:4860::8844']
dns.resolver.default_resolver.timeout = 1
dns.resolver.default_resolver.lifetime = 1

def main():
    # each entry is a asn
    # each asn has a key for ranges
    # each of those ranges has a dict of ip to rdns entries
    ctr = 0
    with open(sys.argv[1]) as fp:
        as_data = json.load(fp)
    for asn, asdat in as_data.iteritems():
        for rge in asdat.get("ranges", []):
            if rge in ["MISSING", "NA"]: continue
            print >>sys.stderr, asn, asdat["name"], rge
            ipdomains = get_domains(rge)
            if ipdomains:
                for ip, domains in ipdomains:
                    for d in domains:
                        asdat.setdefault("domains", {}).setdefault(d, []).append(ip)
    with open(sys.argv[1] + ".dns", "w") as fp:
        json.dump(as_data, fp, indent=2)

# does syn port scanning
def scan_web_port(ip):
    open = []
    packet = IP(dst=ip)
    packet /= TCP(dport=[80, 443], flags="S")
    answered, unanswered = sr(packet, timeout=1)
    for (send, recv) in answered:
        if not recv.getlayer("ICMP"):
            flags = recv.getlayer("TCP").sprintf("%flags%")
            if flags == "SA":
                open.append((send.dport))
    return open
    
def get_domains(ip_range):
    domains = []
    for i in IPSet([IPNetwork(ip_range)]):
        ip = str(i)
        n = dns.reversename.from_address(ip)
        try:
            domains.append(
                (ip, [n.to_text() for n in
                      dns.resolver.query(n,"PTR").rrset]))
            print >>sys.stderr, ".",
        except dns.resolver.NXDOMAIN as e:
            if scan_web_port(ip):
                domains.append((ip, ["NODOMAIN"]))
                print >>sys.stderr, "*"
            continue
            print >>sys.stderr, ip + " is NXDOMAIN"
        except dns.resolver.NoNameservers as e:
            print >>sys.stderr, ip + " has server fail"
            continue
        except dns.exception.Timeout as e:
            print >>sys.stderr, ip + " has dns timeout"
            continue
        except dns.resolver.NoAnswer as e:
            print >>sys.stderr, ip + " has no dns answer"
            continue

    return domains

if __name__ == "__main__":
    main()
