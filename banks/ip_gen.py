import itertools
import dns.name
import dns.resolver
import tldextract
import json
import logging
logging.basicConfig(level=logging.ERROR)
import sys

# use google DNS
dns.resolver.default_resolver = dns.resolver.Resolver(configure=False)
dns.resolver.default_resolver.nameservers = ['8.8.8.8', '2001:4860:4860::8888',
                                             '8.8.4.4', '2001:4860:4860::8844']
dns.resolver.default_resolver.timeout = 1
dns.resolver.default_resolver.lifetime = 1


# grab ips that have been resolved previously because of rdns
def rdns(rdns):
    with open(rdns) as fp:
        rdns = json.load(fp)
    for asn, asdat in rdns.iteritems():
        for domain, ips in asdat.get("domains", {}).iteritems():
            
            yield (asdat["name"], domain, ",".join(ips))

# get list of domains that need to be resolved coming from
# both raw domain lists, subdomains of raw domain list,
# and subdomains from rdns entries
def raw(raw):
    with open(raw) as fp:
        for l in fp:
            name, domain = [x.strip() for x in l.split(" ")]
            ips = resolve(domain)
            if ips:
                yield (name, domain, ",".join(ips))

def resolve(domain):
    try:
        ips = [n.to_text() for n
               in dns.resolver.query(dns.name.from_text(domain), "A").rrset]
    except (dns.resolver.NXDOMAIN, dns.resolver.Timeout):
        return []
    return ips 
    
def main():
    bnlook = {}
    output = []

    # give bank name to domains with the common top level domain
    for (name, domain, ip) in itertools.chain(rdns(sys.argv[1]), raw(sys.argv[2])):
        ext = tldextract.extract(domain)
        root_domain = ".".join([ext.domain, ext.suffix])
        domain = ".".join(x for x in
                          [ext.subdomain, ext.domain, ext.suffix] if x)
        if name:
            if root_domain in bnlook:
                if name != bnlook[root_domain]:
                    raise ValueError("root %s for %s is also for %s" % (
                        root_domain, bnlook[root_domain], name))
            else:
                bnlook[root_domain] = name
        output.append((name, domain, root_domain, ip))

    # print domains
    for name, domain, root_domain, ip in output:
        if root_domain in bnlook:
            name = bnlook[root_domain]
        print >>sys.stderr, "%s\t%s\t%s" % (name, domain, ip)

if __name__ == "__main__":
    main()
