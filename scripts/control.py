from patchright.sync_api import sync_playwright
from json import dumps
import code

CDP_ENDPOINT = "http://127.0.0.1:9001"

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
