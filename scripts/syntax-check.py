"""Syntax check of a local ABAP source file on an SAP system, without creating anything.

The source is compiled by ADT in the context of an existing program.
Usage: python syntax-check.py <file> [<file> ...]
System: environment variables SAP_HOST (https://host:port), SAP_USER,
SAP_PASSWORD, SAP_CLIENT (default 100) and SAP_PROGRAM (any existing
program of that system, lower case; it only gives the compile context).
The certificate of the system is verified; set SAP_INSECURE=1 only for a
system with a self-signed certificate that you trust.
Nothing is written on the system.
"""
import base64
import http.cookiejar
import os
import ssl
import sys
import urllib.request
import xml.etree.ElementTree as ET

def required(name):
    value = os.environ.get(name)
    if not value:
        sys.exit(name + ' is not set')
    return value


HOST = required('SAP_HOST')
USER = required('SAP_USER')
CLIENT = os.environ.get('SAP_CLIENT', '100')
CONTEXT = '/sap/bc/adt/programs/programs/' + required('SAP_PROGRAM')


def opener():
    password = required('SAP_PASSWORD')
    context = ssl.create_default_context()
    if os.environ.get('SAP_INSECURE') == '1':
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    result = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=context),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    basic = base64.b64encode(f'{USER}:{password}'.encode()).decode()
    result.addheaders = [('Authorization', 'Basic ' + basic)]
    return result


def check(http, token, source):
    body = f'''<?xml version="1.0" encoding="UTF-8"?>
<chkrun:checkObjectList xmlns:chkrun="http://www.sap.com/adt/checkrun" xmlns:adtcore="http://www.sap.com/adt/core">
  <chkrun:checkObject adtcore:uri="{CONTEXT}" chkrun:version="active">
    <chkrun:artifacts>
      <chkrun:artifact chkrun:contentType="text/plain; charset=utf-8" chkrun:uri="{CONTEXT}/source/main">
        <chkrun:content>{base64.b64encode(source.encode('utf-8')).decode()}</chkrun:content>
      </chkrun:artifact>
    </chkrun:artifacts>
  </chkrun:checkObject>
</chkrun:checkObjectList>'''
    request = urllib.request.Request(
        f'{HOST}/sap/bc/adt/checkruns?reporters=abapCheckRun&sap-client={CLIENT}',
        data=body.encode('utf-8'), method='POST',
        headers={'Content-Type': 'application/vnd.sap.adt.checkobjects+xml',
                 'Accept': 'application/vnd.sap.adt.checkmessages+xml',
                 'x-csrf-token': token})
    body = http.open(request, timeout=120).read().decode('utf-8')
    messages = []
    for element in ET.fromstring(body).iter():
        if element.tag.endswith('}checkMessage'):
            attributes = {key.split('}')[-1]: value for key, value in element.attrib.items()}
            messages.append((attributes.get('type', '?'), attributes.get('uri', ''), attributes.get('shortText', '')))
    return messages


def main():
    http = opener()
    request = urllib.request.Request(
        f'{HOST}/sap/bc/adt/core/discovery?sap-client={CLIENT}',
        headers={'x-csrf-token': 'fetch', 'Accept': '*/*'})
    token = http.open(request, timeout=60).headers.get('x-csrf-token')

    failed = False
    for path in sys.argv[1:]:
        source = open(path, encoding='utf-8').read()
        messages = check(http, token, source)
        lines = source.split('\n')
        print(f'{os.path.basename(path)}: {len(lines)} lines, {len(messages)} message(s)')
        for kind, uri, text in messages:
            position = uri.split('#start=')[-1] if '#start=' in uri else ''
            line = int(position.split(',')[0]) if position else 0
            print(f'  {kind} line {line}: {text}')
            if 0 < line <= len(lines):
                print(f'      {lines[line - 1].strip()}')
            failed = failed or kind in ('E', 'A')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
