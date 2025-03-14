#!/bin/bash

# Set SANDBOX_HOME environment variable
SANDBOX_HOME=~/agent


# Check if SANDBOX_HOME exists, if not create it and set ownership
if [ ! -d "$SANDBOX_HOME" ]; then
  mkdir -p "$SANDBOX_HOME"
  cp -a ~/.bashrc "${SANDBOX_HOME}"
  echo 'PS1="\[\e[48;5;208m\e[97m\]sandbox\[\e[0m\] \[\e[1;32m\]\h:\w\[\e[0m\]$ "' >> "${SANDBOX_HOME}/.bashrc"


  # Install electron globally via npm if not present
  if ! check_command "electron"; then
    echo "Instaling nvm..."
    # install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash

    echo "Installing node via nvm..."
    # install node
    nvm install node

    echo "Installing electron via npm..."
    npm install -g electron
    if ! check_command "electron"; then
        echo "Failed to install electron. Please install it manually:"
        echo "sudo npm install -g electron"
        exit 1
    fi
    echo "Electron installed successfully"
  fi
fi

BWRAP_CMD=(
  bwrap
  --ro-bind /sbin /sbin
  --ro-bind /bin /bin
  --ro-bind /usr /usr
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --ro-bind /etc /etc
  --ro-bind /run/dbus /run/dbus
  --ro-bind /run/systemd /run/systemd
  --dev-bind /dev /dev
  --proc /proc
  --bind "/run/user/$(id -u)/bus" "/run/user/$(id -u)/bus"
  --bind "${SANDBOX_HOME}" /home/agent
  --tmpfs /tmp
  --clearenv
  --setenv HOME /home/agent
  --setenv PATH "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/home/agent/.local/bin"
  --setenv DISPLAY "${DISPLAY}"
  --setenv DBUS_SESSION_BUS_ADDRESS "${DBUS_SESSION_BUS_ADDRESS}"
  --setenv TERM "${TERM}"
  --setenv COLOTTERM "${COLORTERM}"
)

"${BWRAP_CMD[@]}" /bin/bash

#  --ro-bind "${HOME}/.nvm/" /home/agent/.nvm/ \
#  --ro-bind "${HOME}/.local/bin" /home/agent/.local/bin \
