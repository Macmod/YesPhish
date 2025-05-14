from patchright.async_api import async_playwright
from json import dumps
import asyncio

CDP_ENDPOINT = "http://127.0.0.1:9001"

async def run():
    async with async_playwright() as p:
        print(f'[+] Attempting to connect to: {CDP_ENDPOINT}');
        try:
            browser = await p.chromium.connect_over_cdp(CDP_ENDPOINT)
            print('[+] Successfully connected to Chrome!');
        except Exception as e:
            print(f'[-] Error while connecting to the browser: {e}')


        context = browser.contexts[0] if browser.contexts else await browser.new_context()

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
