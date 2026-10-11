"""Free SQL through ADT data preview, read only.
Usage: adt-query.py <host:port> <client> "<sql>" [rows]
User and password from the environment variables SAP_USER and SAP_PASSWORD.
The certificate is verified; SAP_INSECURE=1 switches that off for a trusted
self-signed system."""
import base64, http.cookiejar, json, os, ssl, sys, urllib.request
import xml.etree.ElementTree as ET

host, client, sql = sys.argv[1], sys.argv[2], sys.argv[3]
rows = sys.argv[4] if len(sys.argv) > 4 else '200'
user, password = os.environ['SAP_USER'], os.environ['SAP_PASSWORD']
ctx = ssl.create_default_context()
if os.environ.get('SAP_INSECURE') == '1':
    ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
http = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
http.addheaders = [('Authorization', 'Basic ' + base64.b64encode(f'{user}:{password}'.encode()).decode())]
token = http.open(urllib.request.Request(f'https://{host}/sap/bc/adt/core/discovery?sap-client={client}', headers={'x-csrf-token': 'fetch', 'Accept': '*/*'}), timeout=60).headers.get('x-csrf-token')
req = urllib.request.Request(f'https://{host}/sap/bc/adt/datapreview/freestyle?sap-client={client}&rowNumber={rows}', data=sql.encode('utf-8'), method='POST',
                             headers={'Content-Type': 'text/plain', 'Accept': 'application/xml, application/vnd.sap.adt.datapreview.table.v1+xml', 'x-csrf-token': token})
try:
    body = http.open(req, timeout=120).read().decode('utf-8')
except urllib.error.HTTPError as e:
    sys.exit(f'HTTP {e.code}: {e.read().decode("utf-8", "replace")[:600]}')
root = ET.fromstring(body)
ns = {'dp': 'http://www.sap.com/adt/dataPreview'}
columns = []
for col in root.findall('.//dp:columns', ns):
    name = col.find('dp:metadata', ns).get('{http://www.sap.com/adt/dataPreview}name')
    values = [d.text or '' for d in col.findall('dp:dataSet/dp:data', ns)]
    columns.append((name, values))
if not columns:
    print(body[:800]); sys.exit()
n = len(columns[0][1])
print(' | '.join(c[0] for c in columns))
for i in range(n):
    print(' | '.join(c[1][i].strip() for c in columns))
