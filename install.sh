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
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
	    . $HOME/.bash_profile
fi

if [ ! $OG_ALIAS ]; then
	read -p "Enter validator name: " OG_ALIAS
	echo 'export OG_ALIAS='\"${OG_ALIAS}\" >> $HOME/.bash_profile
fi
echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
. $HOME/.bash_profile
sleep 1
cd $HOME
sudo apt update
sudo apt install cmake make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-12-dev git jq ncdu bsdmainutils htop -y < "/dev/null"
sleep 1
VERSION=1.21.3
wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version

cd $HOME
############
# Clone project repository
cd && rm -rf 0g-chain
git clone https://github.com/0glabs/0g-chain
cd 0g-chain
git checkout v0.1.0

# Build binary
make install

# Set node CLI configuration
0gchaind config chain-id zgtendermint_16600-1
0gchaind config keyring-backend test
0gchaind config node tcp://localhost:26657

# Initialize the node
0gchaind init "$OG_ALIAS" --chain-id zgtendermint_16600-1

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/0g-testnet/genesis.json > $HOME/.0gchain/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/0g-testnet/addrbook.json > $HOME/.0gchain/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656"|' $HOME/.0gchain/config/config.toml

# Set minimum gas price
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0025ua0gi"|' $HOME/.0gchain/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "17"|' \
  $HOME/.0gchain/config/app.toml

# Download latest chain data snapshot
curl "https://snapshots-testnet.nodejumper.io/0g-testnet/0g-testnet_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.0gchain"
#change ports
sed -i.bak -e "s%:26658%:33658%; s%:26657%:33657%; s%:6060%:6760%; s%:26656%:33656%; s%:26660%:33660%" $HOME/.0gchain/config/config.toml && sed -i.bak -e "s%:9090%:9790%; s%:9091%:9791%; s%:1317%:2017%; s%:8545%:9245%; s%:8546%:9246%; s%:6065%:6765%" $HOME/.0gchain/config/app.toml && sed -i.bak -e "s%:26657%:33657%" $HOME/.0gchain/config/client.toml 
# Create a service
sudo tee /etc/systemd/system/0gchaind.service > /dev/null << EOF
[Unit]
Description=0G node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which 0gchaind) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable 0gchaind.service
############
cd $HOME
# Start the service and check the logs
sudo systemctl start 0gchaind.service
sudo journalctl -u 0gchaind.service -f --no-hostname -o cat

}
uninstall() {
read -r -p "You really want to delete the node? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
    sudo systemctl disable 0gchaind.service
    sudo rm /etc/systemd/system/0gchaind.service
    sudo rm -rf $HOME/.0gchain
    sudo rm -rf $HOME/0gchain
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