#!/bin/bash

# Set SANDBOX_HOME environment variable
SANDBOX_HOME=~/agent


# Check if SANDBOX_HOME exists, if not create it and set ownership
if [ ! -d "$SANDBOX_HOME" ]; then
  mkdir -p "$SANDBOX_HOME"
  cp -a ~/.bashrc "${SANDBOX_HOME}"
  echo 'PS1="\[\e[48;5;208m\e[97m\]sandbox\[\e[0m\] \[\e[1;32m\]\h:\w\[\e[0m\]$ "' >> "${SANDBOX_HOME}/.bashrc"
fi

bwrap \
  --ro-bind /sbin /sbin \
  --ro-bind /bin /bin \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /etc /etc \
  --ro-bind /run/dbus /run/dbus \
  --ro-bind /run/systemd /run/systemd \
  --dev-bind /dev /dev \
  --proc /proc \
  --bind "/run/user/$(id -u)/bus" "/run/user/$(id -u)/bus" \
  --bind "${SANDBOX_HOME}" /home/agent \
  --ro-bind "${HOME}/.nvm/" /home/agent/.nvm/ \
  --ro-bind "${HOME}/.local/bin" /home/agent/.local/bin \
  --tmpfs /tmp \
  --clearenv \
  --setenv HOME /home/agent \
  --setenv PATH "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/home/agent/.local/bin" \
  --setenv DISPLAY "${DISPLAY}" \
  --setenv DBUS_SESSION_BUS_ADDRESS "${DBUS_SESSION_BUS_ADDRESS}" \
  --setenv TERM "${TERM}" \
  --setenv COLOTTERM "${COLORTERM}" \
  /bin/bash

