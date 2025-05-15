from patchright.sync_api import sync_playwright
from json import dumps
import code
import sys

if len(sys.argv) < 2:
    print('[-] Usage: python3 control.py <DEBUGPORT>')
    sys.exit(1)
else:
    PORT = int(sys.argv[1])

CDP_ENDPOINT = f"http://127.0.0.1:{PORT}"

with sync_playwright() as p:
    print(f'[+] Attempting to connect to: {CDP_ENDPOINT}');
    try:
        browser = p.chromium.connect_over_cdp(CDP_ENDPOINT)
        print('[+] Successfully connected to Chrome!');
        print('[+] Use the `browser` and `context` objects in the JS shell below to control the browser.');
    except Exception as e:
        print(f'[-] Error while connecting to the browser: {e}')


    context = browser.contexts[0] if browser.contexts else browser.new_context()


    page = context.pages[0]

    code.interact(local={'browser': browser, 'context': context})    
