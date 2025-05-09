const puppeteer = require('puppeteer');

const args = process.argv.slice(2);

const FIREFOX_WS_ENDPOINT = 'ws://127.0.0.1:PORT/session'.replace('PORT', args[0]);

// Timestamp helper
const log = (label, info = '') => {
    const ts = new Date().toISOString();
    console.log(`[${ts}] [${label}] ${info}`);
};

const monitorPage = async (page) => {
    page.on('close', () => log('page.close', 'Page was closed.'));
    page.on('console', msg => log('page.console', `Message: ${msg.text()}`));
    page.on('dialog', dialog => {
        log('page.dialog', `Type: ${dialog.type()} | Message: ${dialog.message()}`);
        dialog.dismiss().catch(() => {}); // Avoid hanging if not handled
    });
    page.on('domcontentloaded', () => log('page.domcontentloaded', 'DOM fully loaded.'));
    page.on('error', err => log('page.error', `Page crashed or error occurred: ${err}`));
    page.on('frameattached', frame => log('page.frameattached', `URL: ${frame.url()}`));
    page.on('framedetached', frame => log('page.framedetached', `Frame detached.`));
    page.on('framenavigated', frame => log('page.framenavigated', `Navigated to: ${frame.url()}`));
    page.on('load', () => log('page.load', 'Page fully loaded.'));
    page.on('metrics', data => log('page.metrics', `Metrics reported: ${JSON.stringify(data)}`));
    page.on('pageerror', err => log('page.pageerror', `Unhandled exception: ${err}`));
    page.on('popup', popup => log('page.popup', 'A new popup/tab was opened.'));
    page.on('request', req => log('page.request', `URL: ${req.url()}`));
    page.on('requestfailed', req => log('page.requestfailed', `URL: ${req.url()} | Reason: ${req.failure().errorText}`));
    page.on('requestfinished', req => log('page.requestfinished', `URL: ${req.url()}`));
    page.on('response', res => log('page.response', `URL: ${res.url()} | Status: ${res.status()}`));
    page.on('workercreated', worker => log('page.workercreated', `Worker URL: ${worker.url()}`));
    page.on('workerdestroyed', worker => log('page.workerdestroyed', `Worker URL: ${worker.url()}`));
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

        process.on('exit', async () => {
            console.log("[~] Disconnecting from Firefox...");
            await browser.disconnect();
            console.log('[+] Done!');
        });

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

        // Monitor other browser events
        browser.on('targetdestroyed', target => {
            log('browser.targetdestroyed', `Target destroyed: ${target.url()}`);
        });

        browser.on("targetchanged", async (target) => {
            log('browser.targetchanged', `Target changed: ${target.url()}`);
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

