# use https://github.com/aboul3la/Sublist3r for google scan
# use dnsscan to get quick bruteforce and nameservers

import sys, json, tldextract
import multiprocessing
from sublist3r.sublist3r import *
import logging
logging.basicConfig(level=logging.ERROR)

#from dnscan.dnscan import *

domain_check = re.compile(
    "^(http|https)?[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$")

# TODO
def get_dnscan_subdomains(domain):
    pass

def get_sublist3r_subdomains(domain):
    subdomains_queue = multiprocessing.Manager().list()
    if not domain_check.match(domain):
        return []

    if not domain.startswith('http://') or not domain.startswith('https://'):
        domain = 'http://'+domain

    parsed_domain = urlparse.urlparse(domain)

    supported_engines = {'baidu':BaiduEnum,
                         'yahoo':YahooEnum,
                         'google':GoogleEnum,
                         'bing':BingEnum,
                         'ask':AskEnum,
                         'netcraft':NetcraftEnum,
                         'dnsdumpster':DNSdumpster,
                         'virstotal':Virustotal,
                         'threatcrowd':ThreatCrowd,
                         'ssl':CrtSearch,
                         'passivedns':PassiveDNS
                         }


    chosenEnums = [BaiduEnum, YahooEnum, GoogleEnum, BingEnum, AskEnum,
                   NetcraftEnum, DNSdumpster, Virustotal, ThreatCrowd, CrtSearch, PassiveDNS]

    #Start the engines enumeration
    enums = [enum(domain, [], q=subdomains_queue,
                  silent=True, verbose=False) for enum in chosenEnums]
    for enum in enums:
        enum.start()
    for enum in enums:
        enum.join()
    subdomains =  set(subdomains_queue)
    return subdomains

def get_subdomains(domain):
    return get_sublist3r_subdomains(domain)

def main():
    # read data from rdns files
    # for each entry in rdns we want to take the domains
    # and find subdomains for them.
    # some IPs might have NODOMAIN in them, dont take these
    # only the ones which have domains. then use these domains
    # but also store the bank name which needs to be outputted for
    # the final list, and then the subdomain and ips will be marked accordingly
    todo_list = []
    resolve = []
    with open(sys.argv[1]) as fp:
        rdns = json.load(fp)
    for asn, asdat in rdns.iteritems():
        for domain in asdat.get("domains", {}):
            continue
            todo_list.append((asdat["name"], domain))

    # read data from list of bank domains
    with open(sys.argv[2]) as fp:
        for l in fp:
            l = l.strip()
            todo_list.append((None, l))
    
    for (bank_name, domain) in todo_list:
        # List of bank_name, domain
        # Get just the tld of the domain
        ext = tldextract.extract(domain)
        root_domain = ".".join([ext.domain, ext.suffix])
        domain = ".".join(x for x in
                          [ext.subdomain, ext.domain, ext.suffix] if x)
        subds = get_subdomains(root_domain)
        for sub in subds:
            print >>sys.stderr, bank_name, sub
        print >>sys.stderr, bank_name, domain

if __name__ == "__main__":
    main()
