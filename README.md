# YesPhish

This is a fork of [NoPhish](https://github.com/powerseb/NoPhish) (by `powerseb`) with improvements and bugfixes.

> [!IMPORTANT]
> This is the `patchright-chrome` branch, an experiment that totally replaces Firefox with a [patched Chrome](https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python) version that supports undetected browser automation.

> [!NOTE]
> In this branch, all periodic session/cookie/profile dumps were disabled, as it's more complicated to perform these steps using Chrome's profile files than it is in Firefox. Use the provided patchright scripts or make your own to interact with the browser and dump information such as browser cookies:
>
> * [scripts/biscuits.py](scripts/biscuits.py): Dumps all browser cookies every time a navigation occurs.
> * [scripts/control.py](scripts/control.py): Spawns a REPL shell in which you can control the browser.
> * [scripts/log.py](scripts/log.py): Monitors a bunch of browser events (may be helpful as boilerplate/troubleshooting utility for the development of new scripts).
>
> Specifying custom preferences for the browser will also not work. Please change Chrome's command-line flags directly in [setup.sh](setup.sh) if you must.

## Using this branch

This branch uses Chrome by default, but to enable remote debugging and be able to run patchright scripts you must still set `-x true` when running `setup.sh`, as it is in the main branch. All other options should work the same way.

Example:
```bash
$ ./setup.sh -u 1 -d localhost -t https://www.google.com -x true
```

Then grab the debugging port of your target VNC container's browser from the output, and use it in your own patchright script, or call the provided scripts specifying that port:
```bash
$ python3 scripts/control.py 9001
```

For other instructions, please refer to the main branch's [README.md](https://github.com/Macmod/YesPhish/blob/main/README.md)
