#!/bin/bash

CONTAINER_DIR="/var/lib/machines/epilogue"
MACHINE=epilogue

install_packages() {
	if ! dpkg -s $* &>/dev/null; then
		apt-get install -y $* -y --no-install-suggests --no-install-recommends
	fi
}

create_user() {
	if id -u epilogue &>/dev/null; then
		return
	fi

	if [ -v $MAINUSER_UID ]; then
		MAINUSER_UID=1000
	fi

	if [ -v $MAINUSER_GID ]; then
		MAINUSER_GID=1000
	fi

	groupadd -g $MAINUSER_GID epilogue
	useradd epilogue -m -s /bin/bash -u $MAINUSER_UID -g $MAINUSER_GID
}

backend() {
	install_packages "golang"
	cd backend
	go build
	cd -

	# setup service
	cp /app/config/backend.service /etc/systemd/system/epilogue-backend.service
	systemctl daemon-reload
	systemctl enable --now epilogue-backend
}

backend_dev() {
	install_packages "golang inotify-tools"
	tmux new-window -t epilogue:2 -n 'backend'
	tmux send 'su epilogue' ENTER
	tmux send 'cd backend && while :; do go run . & p=$!; inotifywait -r -e modify .; kill $p; done' ENTER
}

frontend() {
	# install deps
	install_packages "npm nginx rsync"

	# build and copy build files
	cd frontend
	npm run build
	cd -

	# rsync frontend/build/ /var/

	systemctl enable nginx
}

frontend_dev() {
	install_packages "npm"
	tmux new-window -t epilogue:1 -n 'frontend'
	tmux send 'su epilogue' ENTER
	tmux send 'cd frontend && npm run dev' ENTER
}

standalone() {
	backend
	frontend
}

standalone_dev() {
	install_packages "tmux"
	systemd-run -p Type=forking tmux new-session -d -s epilogue

	frontend_dev
	backend_dev
}

container() {

	case "$1" in
		"stop") machinectl stop $MACHINE; exit $? ;;
		"shell") machinectl shell $MACHINE; exit $? ;;
	esac

	if ! [ -d $CONTAINER_DIR ]; then
		debootstrap --include=systemd,dbus noble $CONTAINER_DIR https://archive.ubuntu.com/ubuntu/
	fi

	if ! machinectl list | grep -w $MACHINE &>/dev/null; then
		systemd-nspawn -q -M $MACHINE -E MAINUSER_UID=$(stat -c "%u" .) -E MAINUSER_GID=$(stat -c "%g" .) --hostname $MACHINE -b --bind ./:/app/:idmap -U -D $CONTAINER_DIR &
		sleep 2
		machinectl shell root@$MACHINE /app/scripts/machine-setup.sh $1
	fi
}

if [ $UID -ne 0 ]; then
	sudo $0 $@
	exit $?
fi

if [ "$1" == "container" ]; then
	container $2
	exit $?
fi

create_user
cd /app/
cp config/sources.list /etc/apt/sources.list
apt update
apt upgrade -y

case $1 in
	"standalone") standalone ;;
	"standalone-dev") standalone_dev ;;
esac
