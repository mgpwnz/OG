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
# Install dependencies for building from source
sudo apt update
sudo apt install -y curl git jq lz4 build-essential

# Install Go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.21.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source .bash_profile
#moniker
while true; do
  read -p "Enter Validator name (MONIKER): " MONIKER
  if [ -n "$MONIKER" ]; then
    break
  else
    echo "Validator name (MONIKER) cannot be empty. Please enter a value."
  fi
done
# Clone project repository
cd && rm -rf 0g-chain
git clone https://github.com/0glabs/0g-chain
cd 0g-chain
git checkout v0.2.3

# Build binary
make install

# Set node CLI configuration
0gchaind config chain-id zgtendermint_16600-2
0gchaind config keyring-backend test
0gchaind config node tcp://localhost:26657

# Initialize the node
0gchaind init "$MONIKER" --chain-id zgtendermint_16600-2

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/0g-testnet/genesis.json > $HOME/.0gchain/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/0g-testnet/addrbook.json > $HOME/.0gchain/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "81987895a11f6689ada254c6b57932ab7ed909b6@54.241.167.190:26656,010fb4de28667725a4fef26cdc7f9452cc34b16d@54.176.175.48:26656,e9b4bc203197b62cc7e6a80a64742e752f4210d5@54.193.250.204:26656,68b9145889e7576b652ca68d985826abd46ad660@18.166.164.232:26656"|' $HOME/.0gchain/config/config.toml

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

# Create a service
sudo tee /etc/systemd/system/ogd.service > /dev/null << EOF
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
sudo systemctl enable ogd.service

# Start the service and check the logs
sudo systemctl start ogd.service
sudo journalctl -u ogd.service -f --no-hostname -o cat
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