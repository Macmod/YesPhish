const repl = require('node:repl');

function startShell(browser) {
    myrepl = repl.start('> ');
    myrepl.context.browser = browser;
}

const puppeteer = require('puppeteer');

const args = process.argv.slice(2);

const FIREFOX_WS_ENDPOINT = 'ws://127.0.0.1:PORT/session'.replace('PORT', args[0]);

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

    console.log('[+] Successfully connected to Firefox!');
    console.log('[+] Use the `browser` object in the JS shell below to control the browser.');
    startShell(browser);
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

