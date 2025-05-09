const puppeteer = require('puppeteer');

const args = process.argv.slice(2);

const FIREFOX_WS_ENDPOINT = 'ws://127.0.0.1:PORT/session'.replace('PORT', args[0]);

// Timestamp helper
const log = (label, info = '') => {
    const ts = new Date().toISOString();
    console.log(`[${ts}] [${label}] ${info}`);
};

const monitorPage = async (page) => {
    const url = await page.url();
    try {
        const initialCookies = await page.cookies();
        log('page.initialcookies', `URL: ${url} | Cookies:\n` + JSON.stringify(initialCookies));
    } catch(error) {
        console.error(`Error getting initial cookies for ${url}: ${error.message}`);
    }

    page.on('response', (res) => {
        const request = res.request();
        const url = request.url();
        const headers = res.headers();
        const setCookieHeader = headers["set-cookie"];
        if (setCookieHeader) {
            log('page.response.set-cookie', `URL: ${url} | Cookies:\n` + JSON.stringify(setCookieHeader))
        }
    });

    page.on("framenavigated", async (frame) => {
        if (frame === page.mainFrame()) { // Ensure it's the main frame that navigated
            const newUrl = frame.url();
            try {
                const navCookies = await page.cookies();
                log('page.navigationcookies', `URL: ${newUrl} | Cookies:\n` + JSON.stringify(navCookies));
            } catch (error) {
                console.error(`Error getting cookies after navigation to ${newUrl}: ${error.message}`);
            }
        }
    });
}

const disconnectBrowser = async (browser) => {
    console.log("[~] Disconnecting from Firefox...");
    await browser.disconnect();
    console.log('[+] Done!');
}

(async () => {
    console.log(`[+] Attempting to connect to: ${FIREFOX_WS_ENDPOINT}`);
    let browser = null;

    try {
        // Connect to an existing instance of Firefox via WebSocket
        browser = await puppeteer.connect({
            browserWSEndpoint: FIREFOX_WS_ENDPOINT,
            product: 'firefox',
            protocol: 'webDriverBiDi', // Required for Firefox >= 2023 versions
            headers: {
                Host: '127.0.0.1:9222', // Required to make the BiDi inside the container happy
            }
        });

        process.on('SIGINT', async () => {await disconnectBrowser(browser)});
        process.on('SIGQUIT', async () => {await disconnectBrowser(browser)});
        process.on('SIGTERM', async () => {await disconnectBrowser(browser)});

        console.log('[+] Successfully connected to Firefox!');

        // Monitor existing pages
        pages = await browser.pages();
        for(const page of pages) {
            await monitorPage(page);
        }

        // Monitor new pages that are opened
        browser.on("targetcreated", async (target) => {
            if (target.type() === "page") {
                try {
                    const page = await target.page();
                    if (page) {
                        monitorPage(page)
                    }
                } catch (error) {
                    console.error(`Error processing new page: ${error.message}`);
                }
            }
        });
    } catch (error) {
        console.error('[X] Failed to connect or interact with the existing Firefox instance:', error);

        if (browser && browser.isConnected()) {
            try {
                await browser.disconnect();
            } catch (disconnectError) {
                console.error('[!] Error while trying to disconnect after failure:', disconnectError);
            }
        }
    }
})();

