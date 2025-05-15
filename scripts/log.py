from patchright.async_api import async_playwright
import asyncio
from json import dumps
import sys

if len(sys.argv) < 2:
    print('[-] Usage: python3 log.py <DEBUGPORT>')
    sys.exit(1)
else:
    PORT = int(sys.argv[1])

CDP_ENDPOINT = f"http://127.0.0.1:{PORT}"

def print_event(event_name, payload):
    print(f"\n-- [{event_name}] --")
    try:
        if isinstance(payload, str):
            print(payload)
        elif hasattr(payload, 'url'):
            print("[+] URL:", payload.url)
        elif hasattr(payload, 'message'):
            print("[+] Message:", payload.message)
        elif hasattr(payload, 'type'):
            print("[+] Type:", payload.type)
        else:
            print(json.dumps(payload, indent=2, default=str))
    except Exception as e:
        print("[-] Error printing event:", e)


async def hook_page_events(page):
    # From ChatGPT, don't judge if it's wrong :-)
    events = [
        "close", "console", "crash", "dialog", "domcontentloaded", "download", "filechooser",
        "framenavigated", "load", "pageerror", "popup", "request", "requestfailed",
        "requestfinished", "response", "websocket", "websocketclosed", "websocketerror",
        "websocketframeerror", "websocketframereceived", "websocketframesent", "worker"
    ]

    for event in events:
        try:
            page.on(event, lambda payload, e=event: print_event(e, payload))
        except Exception as ex:
            print(f"[-] Failed to hook event {event}: {ex}")

    print(f"[+] Hooked events on page: {page.url}")

async def main():
    async with async_playwright() as p:
        print(f'[+] Attempting to connect to: {CDP_ENDPOINT}');
        try:
            browser = await p.chromium.connect_over_cdp(CDP_ENDPOINT)
            print('[+] Successfully connected to Chrome!');
        except Exception as e:
            print(f'[-] Error while connecting to the browser: {e}')


        context = browser.contexts[0] if browser.contexts else await browser.new_context()

        # Hook existing pages
        for page in context.pages:
            await hook_page_events(page)

        # Hook future pages
        context.on("page", hook_page_events)

        print("[+] Listening to all events on all pages. Press Ctrl+C to stop.")
        await asyncio.Event().wait()  # Keep running

asyncio.run(main())
