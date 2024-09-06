#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
		break
		;;
	esac
done
install() {
sudo apt-get update
sudo apt-get install -y clang cmake build-essential git cargo
read -p "Enter your private key: " PRIVATE_KEY && echo "Private key: $PRIVATE_KEY"
if ! exists go; then
  printCyan "Installing Golang..." && sleep 1
  cd $HOME
  ver="1.22.0"
  wget "https://go.dev/dl/go$ver.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bash_profile
  source ~/.bash_profile
fi

if ! exists rustup; then
  printCyan "Installing Rustup..." && sleep 1
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
else
  rustup --version
fi
#clone & build
git clone -b v0.4.6 https://github.com/0glabs/0g-storage-node.git
cd 0g-storage-node
git submodule update --init
cargo build --release
sudo cp $HOME/0g-storage-node/target/release/zgs_node /usr/local/bin
cd $HOME
#env
echo 'export NETWORK_LISTEN_ADDRESS="$(wget -qO- eth0.me)"' >> ~/.bash_profile
echo 'export BLOCKCHAIN_RPC_ENDPOINT="https://archive-0g.josephtran.xyz"' >> ~/.bash_profile
source ~/.bash_profile
#change config
sed -i '
s|^\s*#\s*network_dir = "network"|network_dir = "network"|
s|^\s*#\s*rpc_enabled = true|rpc_enabled = true|
s|^\s*#\s*network_listen_address = "0.0.0.0"|network_listen_address = "'"$NETWORK_LISTEN_ADDRESS"'"|
s|^\s*#\s*network_libp2p_port = 1234|network_libp2p_port = 1234|
s|^\s*#\s*network_discovery_port = 1234|network_discovery_port = 1234|
s|^\s*#\s*blockchain_rpc_endpoint = "http://127.0.0.1:8545"|blockchain_rpc_endpoint = "'"$BLOCKCHAIN_RPC_ENDPOINT"'"|
s|^\s*#\s*log_contract_address = ""|log_contract_address = "0xbD2C3F0E65eDF5582141C35969d66e34629cC768"|
s|^\s*#\s*log_sync_start_block_number = 0|log_sync_start_block_number = 595059|
s|^\s*#\s*rpc_listen_address = "0.0.0.0:5678"|rpc_listen_address = "0.0.0.0:5678"|
s|^\s*#\s*mine_contract_address = ""|mine_contract_address = "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f"|
s|^\s*#\s*miner_key = ""|miner_key = ""|
' $HOME/0g-storage-node/run/config.toml
#add PK

sed -i 's|^miner_key = ""|miner_key = "'"$PRIVATE_KEY"'"|' $HOME/0g-storage-node/run/config.toml
#service
sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=0G Storage Node
After=network.target

[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zgs
sudo systemctl restart zgs
sudo systemctl status zgs
#snap
sudo systemctl stop zgs
aria2c -x5 -s4 https://vps5.josephtran.xyz/0g/storage_0gchain_snapshot.lz4
sleep 2
lz4 -c -d storage_0gchain_snapshot.lz4 | pv | tar -x -C $HOME/0g-storage-node/run
sleep 2
sudo systemctl restart zgs && sudo systemctl status zgs

}



uninstall() {
read -r -p "You really want to delete the node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
    sudo systemctl disable ogd.service
    sudo rm /etc/systemd/system/ogd.service
    sudo rm -rf $HOME/.0gchain
    sudo rm -rf $HOME/0g-chain
    echo "Done"
    cd $HOME
    ;;
    *)
        echo Сanceled
        return 0
        ;;
esac
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function