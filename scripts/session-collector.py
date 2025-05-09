#!/usr/bin/python

import os
import sys
import sqlite3
import argparse
import re
import lz4.block  # pip install lz4 --user
import json

def mozlz4_to_text(filepath):
    # Given the path to a "mozlz4", "jsonlz4", "baklz4" etc. file, 
    # return the uncompressed text.
    bytestream = open(filepath, "rb")
    bytestream.read(8)  # skip past the b"mozLz40\0" header
    valid_bytes = bytestream.read()
    text = lz4.block.decompress(valid_bytes)
    return text


def main(args):

  filepath_in = os.path.join('output', args[0])
  oformat = args[1]

  phis = "phis" + re.search('user(.+?)-', filepath_in).group(1)
  
  # local sqlite Chrome cookie database path
  file = os.path.join("output", "phis.db")

  # Check if summary database exists
  ## if not create db 
  conn = sqlite3.connect(file)
  c = conn.cursor()
  c.execute("CREATE TABLE IF NOT EXISTS cookies ([id] INTEGER PRIMARY KEY, [phis] TEXT, [name] TEXT, [value] TEXT, [host] TEXT, [expiry] TEXT, [path] TEXT,[isSecure] TEXT,[isHttpOnly] TEXT,[sameSite] TEXT, [source] TEXT)")
  conn.commit()
  c.execute("DELETE FROM cookies WHERE phis = ? AND source = ?",(phis,"session"))
  conn.commit()    

  # Is this useless?
  if os.path.exists(os.path.join('output', phis+".json")):
    os.remove(os.path.join('output', phis+".json"))
  
  sessions_path = os.path.join('output', phis+'-sessions.json')
  if os.path.exists(sessions_path):
    os.remove(sessions_path)  
  
  try:
    text = mozlz4_to_text(filepath_in)
  except:
    print("No sessions")
    sys.exit(1)
  
  #print(text.decode('utf8').replace("'", '"'))
  #json_raw = text.decode('utf8').replace("'", '"')
  json_for = json.loads(text)
  
  #print(json_for["cookies"])
  
  for i in json_for["cookies"]:

    cookie_host = i["host"]
    cookie_name = i["name"]
    cookie_value = i["value"]
    cookie_path = i["path"]
    if 'secure' not in i:
      cookie_secure = False
    else:
      cookie_secure = i["secure"]
    
    if 'httponly' not in i:
      cookie_httponly = False
    else:
      cookie_httponly = i["httponly"]
    
    if 'sameSite' not in i:
      cookie_samesite = 0
    else:
      cookie_samesite = i["sameSite"]
    
    if cookie_host[:1] == ".":
      ThisDomain = "Valid for subdomains"
      ThisDomainRaw = False
    else:
      ThisDomain = "Valid for host only"
      ThisDomainRaw = True
            
    if cookie_secure == 1:
      SendFor = "Encrypted connections only"
      SendForRaw = True
    else:
      SendFor = "Any type of connection"
      SendForRaw = False
        
    if cookie_samesite == 0:
      sameSiteRaw = "no_restriction"
    elif cookie_samesite == 1:
      sameSiteRaw = "lax"
    elif cookie_samesite == 2:
      sameSiteRaw = "strict"
        
    if cookie_httponly == 1:
      HTTPonly = True
    else:
      HTTPonly = False
        

    if oformat == "simple":
        cookie = {
            "domain": cookie_host,
            "hostOnly": ThisDomainRaw,
            "httpOnly": HTTPonly,
            "name": cookie_name,
            "path": cookie_path,
            "sameSite": sameSiteRaw,
            "secure": SendForRaw,
            "session": True,
            "storeId": "0",
            "value": cookie_value
        }
        json_object = json.dumps(cookie, indent=2)
        with open(sessions_path, "a") as outfile:
          outfile.write(json_object + ",\n")
    
  c.execute("INSERT INTO cookies(phis,name,value,host,expiry, path, isSecure, isHttpOnly, sameSite, source) VALUES(?,?,?,?,?,?,?,?,?,?)",(phis,cookie_name,cookie_value,cookie_host,"0", cookie_path, cookie_secure, cookie_httponly, cookie_samesite,"session"))
  conn.commit()
    
  conn.close()
    
  if os.path.exists(sessions_path) and oformat == "simple":
    with open(sessions_path, 'r', encoding='utf-8') as file:
      data = file.readlines()
    data[0] = "[{\n"
    data[-1]= "}]"
    with open(sessions_path, 'w', encoding='utf-8') as file:
      file.writelines(data)

if __name__ == "__main__":
  args = sys.argv[1:]
  if args and not args[0] in ("--help", "-h"):
    main(args)
  else:
    print("Usage: session-collector.py <jsonlz4 file to read>")
