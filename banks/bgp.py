# get database of bgp autonomous systems
# Requires PhantomJS to bypass bgp.he.net JS

import json
import requests
import lxml.html
import sys
from unidecode import unidecode
import re
import base64
import random
import socket
import struct
import urllib
import shlex
import subprocess
#from selenium import webdriver
import time
import os

AS_LINK = "http://www.cidr-report.org/as2.0/autnums.html"
AS_MAIN_LINK = "http://www.cidr-report.org/as2.0/"
AS_ROOT = "http://bgp.he.net"
AS_COOKIE = None
IP_ROOT = "http://ipinfo.io/"

def cidr():
    s = time.time()
    print >>sys.stderr, "Starting CIDR scrape @ " + str(s)
    banks = []
    num_as = requests.get(AS_MAIN_LINK)
    nas_req = lxml.html.fromstring(num_as.text)
    est_total_as = sum([int(x.text[:-2])
                        for x in nas_req.xpath("//tt")[16:18]])
    req = requests.get(AS_LINK)
    doc = lxml.html.fromstring(req.text)
    links = [l.text for l in doc.xpath("//a")]
    names = doc.xpath("/html/body/pre/text()") + doc.xpath("/html/body/pre/peering/text()")
    # Remove initial newline, and join "SWITCH Peering requests: , CH\n'" because of colon
    names = names[1:560] + [names[560] + names[561]] + names[562:]
    assert(len(names) == len(links))
    # Should be more raw AS values than the main page has listed
    assert(len(names) > est_total_as)
    for as_number, as_name in zip(links, names):
        if "bank" in as_name.lower():
            banks.append((as_number, unidecode(as_name)))
    print >>sys.stderr, "Scrape took " + str(time.time() - s)
    return banks

def henet():
    s = time.time()
    print >>sys.stderr, "Starting HE.Net scrape @ " + str(s)
    ases = []
    d = requests.get(AS_ROOT + "/report/world", headers={"User-Agent": "Mozilla"})
    odoc = lxml.html.fromstring(d.text)
    total_as = int(odoc.xpath(
        '//div[@id="countries"]/h2')[0].text.split(":")[-1].strip())
    for i in xrange(1, total_as):
        region = odoc.xpath('//*[@id="table_countries"]/tbody/tr[' + str(i) + ']/td[2]')[0].text.strip()
        d = requests.get(AS_ROOT + "/country/" + region, headers={"User-Agent": "Mozilla"})
        doc = lxml.html.fromstring(d.text)
        for tr in doc.xpath('//table[@id="asns"]//tr')[1:]:
            cols = tr.xpath(".//td")
            asn = cols[0].xpath("./a")[0].text
            name, adj, routes, adj6, routes6 = [td.text for td in cols[1:]]
            ases.append((asn, name))
    null_name_as = [i[0] for i in ases if not i[1]]
    print >>sys.stderr, "Scrape took " + str(time.time() - s)
    return [i for i in ases if i[1] and "bank" in i[1].lower()]
    
def blg():
    s = time.time()
    print >>sys.stderr, "Starting BLG scrape @ " + str(s)
    ases = []
    reg = re.compile("(AS\d+)(.*)")
    for link in ["http://www.bgplookingglass.com/list-of-autonomous-system-numbers",
                 "http://www.bgplookingglass.com/list-of-autonomous-system-numbers-2"]:
        d = requests.get(link)
        doc = lxml.html.fromstring(d.text)
        pre = doc.xpath('//*[@id="content"]/div[3]/div[2]/pre')
        for l in pre[0].itertext():
            l = l.strip()
            if not l.startswith("AS"): continue
            asn, name = reg.match(l).groups()
            name = name.strip()
            asn = asn.strip()
            ases.append((asn, name))

    ''' can filter on "money" too, but too many false positives
    AS17126 E-money
    AS17915 GEMONEY1-AS-AP GE Capital Finance Australasia P/L TA GE Money
    AS21802 STADION - Stadion Money Management, Inc.
    AS23178 MMI-NET - MONEY MANAGEMENT INTERNATIONAL
    AS24977 MONEYLINE-UK Moneyline Telerate
    AS25587 DXI-SOL-CORE MoneyAM Ltd
    AS29898 MONEYGRAM-INTERNATIONAL-INC - MoneyGram International Inc
    AS35232 EUROMONEYPL-AS Euromoney Polska SA
    AS38323 MONEYHOST-AS-AP MoneyHost Pty Ltd
    AS39004 MONEYOU-AS MoneYou B.V.
    AS41963 MSFG Moneysupermarket.com Ltd.
    AS43247 YAMONEY-AS "Yandex.Money" NBCO LLC
    AS48740 OMT-AS Online Money Transfer S.A.L.
    AS49882 MONEYBOOKERS Skrill Limited
    AS57601 GM-AS GlobalMoney LTD
    AS60256 MEGANETWORK-ASN E-Money Net Developers 24 Company Private Joint Stock
    '''
    print >>sys.stderr, "Scrape took " + str(time.time() - s)
    return [i for i in ases if "bank" in i[1].lower()] #or "money" in i[1].lower()]

    # Not all AS in order
    '''
    idx = 0
    for i in xrange(len(ases) - 1):
        if int(ases[idx][0][2:]) != int(ases[idx+1][0][2:]) - 1:
            print ases[idx], ases[idx+1]
        idx += 1
    '''
    
def get_cookie():
    driver = webdriver.PhantomJS()
    driver.get("http://bgp.he.net/AS14#_prefixes")
    # not sure why we need this but we do...
    time.sleep(2)
    for i in driver.get_cookies():
        if i["name"] == "c":
            return i["value"]

def get_ranges_henet(asn):
    global AS_COOKIE
    while not AS_COOKIE:
        AS_COOKIE = get_cookie()
        print >>sys.stderr, "Cookie fetch failed...Maybe IP ban"
        time.sleep(5)
    cookie = AS_COOKIE
    cookies = {"c": cookie}
    assert(cookie)
    headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.100 Safari/537.36"}
    d = requests.get(AS_ROOT + "/" +  asn, headers=headers, cookies=cookies)
    doc = lxml.html.fromstring(d.text)
    ipv4r = [t.text for t in doc.xpath("//table[@id='table_prefixes4']//tr//a")]
    #ipv6r = [t.text for t in doc.xpath("//table[@id='table_prefixes6']//tr//a")]
    return ipv4r

def get_ranges_ipinfo(asn):
    d = requests.get(IP_ROOT + asn)
    doc = lxml.html.fromstring(d.text)
    if "Sorry, we couldn't find the page you requested!" in d.text:
        return ["MISSING"]
    if "There are no known IP addresses belonging to this network" in d.text:
        return ["NA"]
    ranges = [t.text for t in
              doc.xpath("//table[@class='table table-striped']")[1].xpath(
                  ".//tr//a[not(contains(@class, 'flag'))]")]
    return ranges
    
def main():
    if os.path.isfile("bank_as.json"):
        with open("bank_as.json") as fp:
            bdi = json.load(fp)
    else:
        banks = cidr() + henet() + blg()        
        bdi = {}
        for (asn, bname) in banks:
            asn = asn.strip()
            bname = bname.strip()
            if bname > len(bdi.get(asn, {}).get("name", "")):
                bdi.setdefault(asn, {})["name"] = bname
    ctr = 0
    LIMIT = 1000
    for (asn, data) in bdi.iteritems():
        # already processed and valid
        if ("ranges" in data
            and all("AS" not in x for x in data["ranges"])):
            #and data["ranges"] != ["NA"]):
            continue
        bdi[asn]["ranges"] = list(get_ranges_ipinfo(asn))
        print >>sys.stderr, asn, bdi[asn]
        ctr += 1
        if ctr >= LIMIT:
            break

    done = sum(1 for (asn, data) in bdi.iteritems() if "ranges" in data)
    total = len(bdi)
    if done != total:
        print >>sys.stderr, "%d/%d ASN ranges processed. Daily limit has reached, please run script again in 24 hours" % (done, len(bdi))
    with open("bank_as.json", "w") as fp:
        json.dump(bdi, fp, indent=2)

if __name__ == "__main__":
    main()
