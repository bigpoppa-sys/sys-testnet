#!/bin/bash

# to run script simply paste
# bash <(curl -sL https://raw.githubusercontent.com/bigpoppa-sys/sysmn/master/test-script.sh)

# syscoin conf file
SYSCOIN_CONF=$(cat <<EOF
#rpc config
testnet=1
[test]
rpcuser=user
rpcpassword=password
listen=1
daemon=1
server=1
assetindex=1
port=18369
rpcport=18370
rpcallowip=127.0.0.1
gethtestnet=1
addnode=54.190.239.153
addnode=52.40.171.92
EOF
)

# syscoind.service config
SENTINEL_CONF=$(cat <<EOF
# syscoin conf location
syscoin_conf=/root/.syscoin/syscoin.conf
# db connection details
db_name=database/sentinel.db
db_driver=sqlite
network=mainnet
EOF
)

# syscoind.service config
CRON=$(cat <<EOF
*/5 * * * * cd /root/syscoin/src/sentinel && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log
@reboot /root/syscoin/src/syscoind -daemon >/dev/null 2>&1
EOF
)

pause(){
  echo ""
  read -n1 -rsp $'Press any key to continue or Ctrl+C to exit...\n'
  clear
}

update_system(){
  echo "$MESSAGE_UPDATE"
  # update package and upgrade Ubuntu
  sudo DEBIAN_FRONTEND=noninteractive apt -y update
  sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade
  sudo DEBIAN_FRONTEND=noninteractive apt -y autoremove
  clear
}

maybe_prompt_for_swap_file(){
  # Create swapfile if less than 8GB memory
  MEMORY_RAM=$(free -m | awk '/^Mem:/{print $2}')
  MEMORY_SWAP=$(free -m | awk '/^Swap:/{print $2}')
  MEMORY_TOTAL=$(($MEMORY_RAM + $MEMORY_SWAP))
  if [ $MEMORY_RAM -lt 3800 ]; then
      echo "You need to upgrade your server to 4 GB RAM."
       exit 1
  fi
  if [ $MEMORY_TOTAL -lt 7700 ]; then
      CREATE_SWAP="Y";
  fi
}

maybe_create_swap_file(){
  if [ "$CREATE_SWAP" = "Y" ]; then
    echo "Creating a 4GB swapfile..."
    sudo swapoff -a
    sudo dd if=/dev/zero of=/swap.img bs=1M count=4096
    sudo chmod 600 /swap.img
    sudo mkswap /swap.img
    sudo swapon /swap.img
    echo '/swap.img none swap sw 0 0' | sudo tee --append /etc/fstab > /dev/null
    sudo mount -a
    echo "Swapfile created."
    clear
  fi
}

install_ufw(){
  echo "$MESSAGE_UFW"
  sudo apt-get install ufw -y
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow 18369/tcp
  sudo ufw allow 30303/tcp
  yes | sudo ufw enable
  clear
}

install_dependencies(){
  echo "Installing Dependencies"
  # build tools
  sudo apt install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils python3 software-properties-common
  # boost
  sudo apt install -y libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libboost-iostreams-dev
  # bdb 4.8
  sudo add-apt-repository -y ppa:bitcoin/bitcoin
  sudo apt update -y
  sudo apt install -y libdb4.8-dev libdb4.8++-dev
  # zmq
  sudo apt install -y libzmq3-dev
  # git
  sudo apt install -y git
  # virtualenv python
  sudo apt install -y python-virtualenv
  clear
}

build_syscoin(){
  echo "Build"	
  git clone http://www.github.com/syscoin/syscoin 
  cd syscoin 
  git checkout dev-4.x
  git pull
  ./autogen.sh 
  ./configure
  make -j$(nproc)
  clear	
}

create_conf(){
  echo "Creating Conf"
  sudo mkdir ~/.syscoin
  echo "$SYSCOIN_CONF" > ~/.syscoin/syscoin.conf
  clear
}

start_syscoind(){
  cd ~/syscoin/src
  ./syscoind
}

install_sentinel(){
  echo "Install Sentinel"
  cd ~/syscoin/src
  git clone https://github.com/syscoin/sentinel.git
  cd sentinel
  git checkout master
  echo "$SENTINEL_CONF" > ~/syscoin/src/sentinel/sentinel.conf
  clear
}

install_virtualenv(){
  echo "Install Venv"
  cd ~/sentinel
  # install virtualenv
  sudo apt-get install -y python-virtualenv virtualenv
  # setup virtualenv
  virtualenv venv
  venv/bin/pip install -r requirements.txt
  clear
}

setup_cron(){
  crontab -l | { cat; echo "$CRON"; } | crontab -
  clear
}

pause
#system updates
update_system
maybe_prompt_for_swap_file
maybe_create_swap_file
install_ufw
install_dependencies

#install syscoin
build_syscoin
create_conf

#run
start_syscoind

#install watchdog
install_sentinel
install_virtualenv
setup_cron
