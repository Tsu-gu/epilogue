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
	install_packages golang
	cd backend
	go build
	cd -

	# setup service
	cp /app/config/backend.service /etc/systemd/system/epilogue-backend.service
	systemctl daemon-reload
	systemctl enable --now epilogue-backend
}

backend_dev() {
	install_packages golang inotify-tools
	tmux new-window -t epilogue:2 -n 'backend'
	tmux send 'su epilogue' ENTER
	tmux send 'cd backend && while :; do go run . & p=$!; inotifywait -r -e modify .; kill $p; done' ENTER
}

database() {
	install_packages postgresql postgresql-contrib
	systemctl enable --now postgresql
}

frontend() {
	# install deps
	install_packages npm nginx rsync

	# build and copy build files
	cd frontend
	npm run build
	cd -

	# rsync frontend/build/ /var/

	systemctl enable nginx
}

frontend_dev() {
	install_packages npm
	tmux new-window -t epilogue:1 -n 'frontend'
	tmux send 'su epilogue' ENTER
	tmux send 'cd frontend && npm run dev' ENTER
}

release() {
	cp config/hosts.standalone /etc/hosts
	backend
	frontend
	database
}

develop() {
	install_packages tmux
	systemd-run -p Type=forking tmux new-session -d -s epilogue

	frontend_dev
	backend_dev
	database
}

required_commands() {
	failure=0
	for package in $*; do
		if ! command -v $package &>/dev/null; then
			failure=1
			echo "$package is missing, install it in your system to make it work" >&2
		fi
	done
	return $failure
}

container() {
	if command -v apt &>/dev/null; then
		install_packages systemd-container debootstrap
	fi

	if ! required_commands "systemd-nspawn debootstrap" ; then
		return
	fi

	case "$1" in
		"stop") machinectl stop $MACHINE; exit $? ;;
		"shell") machinectl shell $MACHINE /usr/bin/tmux a; exit $? ;;
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

if [ -z $1 ]; then
	exit 0
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
	"develop") develop ;;
	"release") release ;;
esac
