#!/bin/bash
set -e 

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SANDBOX_NAME] [COMMAND]

Create and run commands in an isolated sandbox environment using bubblewrap.

Arguments:
    SANDBOX_NAME    Name of the sandbox (default: claude-desktop)
    COMMAND         Command to run in sandbox (default: /bin/bash)

Options:
    -h, --help     Show this help message and exit

Examples:
    $(basename "$0")                   # Start default sandbox with bash shell
    $(basename "$0") my-sandbox        # Start custom sandbox with bash shell
    $(basename "$0") my-sandbox ls -l  # Run 'ls -l' in custom sandbox

The sandbox will be created in \$HOME/sandboxes/SANDBOX_NAME if it doesn't exist.
EOF
    exit 1
}

# Handle help and invalid options
SANDBOX_NAME=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        --*)
            echo "Error: Unknown option $1"
            usage
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            ;;
        *)
            if [ -z "$SANDBOX_NAME" ]; then
                SANDBOX_NAME="$1"
            else
                break
            fi
            ;;
    esac
    shift
done

SANDBOX_NAME="${SANDBOX_NAME:-claude-desktop}"
SANDBOX_HOME="$HOME/sandboxes/${SANDBOX_NAME}"

if ! command -v bwrap &>/dev/null; then
    echo "bwrap not found. Installing bubblewrap..."
    sudo apt update && sudo apt install -y bubblewrap
fi

# Function to check and fix bubblewrap permissions
fix_bwrap_permissions() {
    echo "Checking bubblewrap permissions..."
    
    # Test if bubblewrap works with a simple command
    if ! bwrap --ro-bind / / --tmpfs /tmp --unshare-all --die-with-parent /bin/echo "test" &>/dev/null; then
        echo "Bubblewrap permission issue detected. Attempting fixes..."
        
        # Ubuntu 24.04+ specific: Check for AppArmor restrictions
        if grep -q "24.04" /etc/os-release 2>/dev/null || grep -q "noble" /etc/os-release 2>/dev/null; then
            echo "Detected Ubuntu 24.04+ - checking AppArmor restrictions..."
            if ! [ -f /etc/apparmor.d/bwrap ]; then
                echo "Creating AppArmor profile for bubblewrap (Ubuntu 24.04+ fix)..."
                sudo tee /etc/apparmor.d/bwrap << 'EOF' >/dev/null
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/bwrap>
}
EOF
                echo "Reloading AppArmor..."
                sudo systemctl reload apparmor
                sleep 2
                # Test again
                if bwrap --ro-bind / / --tmpfs /tmp --unshare-all --die-with-parent /bin/echo "test" &>/dev/null; then
                    echo "✅ Bubblewrap now working with AppArmor profile!"
                    return 0
                fi
            fi
        fi

	# Method 1: Try enabling user namespaces
        if [ -f /proc/sys/kernel/unprivileged_userns_clone ]; then
            current_userns=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
            if [ "$current_userns" = "0" ]; then
                echo "Attempting to enable user namespaces..."
                if echo 1 | sudo tee /proc/sys/kernel/unprivileged_userns_clone >/dev/null 2>&1; then
                    echo "User namespaces enabled temporarily."
                    # Test again
                    if bwrap --ro-bind / / --tmpfs /tmp --unshare-all --die-with-parent /bin/echo "test" &>/dev/null; then
                        echo "✅ Bubblewrap now working with user namespaces!"
                        return 0
                    fi
                fi
            fi
        fi
        
        # Method 2: Check subuid/subgid
        if ! grep -q "^$(whoami):" /etc/subuid 2>/dev/null; then
            echo "Adding subuid/subgid mappings..."
            echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid >/dev/null
            echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid >/dev/null
            # Test again
            if bwrap --ro-bind / / --tmpfs /tmp --unshare-all --die-with-parent /bin/echo "test" &>/dev/null; then
                echo "✅ Bubblewrap now working with subuid/subgid!"
                return 0
            fi
        fi
        
        # Method 3: Set setuid bit as fallback
        bwrap_path=$(which bwrap)
        if [ ! -u "$bwrap_path" ]; then
            echo "Setting setuid bit on bubblewrap as fallback..."
            echo "⚠️  Note: This is less secure than AppArmor profiles"
            if sudo chmod u+s "$bwrap_path"; then
                echo "✅ Setuid bit set on bubblewrap."
                # Test again
                if bwrap --ro-bind / / --tmpfs /tmp --unshare-all --die-with-parent /bin/echo "test" &>/dev/null; then
                    echo "✅ Bubblewrap now working with setuid!"
                    return 0
                fi
            fi
        fi
        
        echo "❌ Could not fix bubblewrap permissions. Please check your system configuration."
        return 1
    else
        echo "✅ Bubblewrap permissions are working correctly."
        return 0
    fi
}

# Check and fix bubblewrap permissions
fix_bwrap_permissions || exit 1

# create fake passwd file
grep "^$(whoami)" /etc/passwd | sed 's#[^\:]*:x:\([0-9\:]*\).*#agent:x:\1Agent:/home/agent:/bin/bash#' > "$HOME/sandboxes/fake_passwd.${SANDBOX_NAME}"

BWRAP_CMD=( 
  bwrap 
  --proc /proc
  --tmpfs /tmp
  --bind "${SANDBOX_HOME}" /home/agent
)

# Data-driven listing of potential mounts (source and destination).
# The first item in each line is the bwrap option (e.g. --ro-bind, --bind),
# followed by the source path and then the target path.
conditional_mounts=(
  "--ro-bind /sbin /sbin"
  "--ro-bind /bin /bin"
  "--ro-bind /usr /usr"
  "--ro-bind /lib /lib"
  "--ro-bind /lib64 /lib64"
  "--ro-bind /etc /etc"
  "--ro-bind \"$HOME/sandboxes/fake_passwd.${SANDBOX_NAME}\" /etc/passwd"
  "--ro-bind /run/dbus /run/dbus"
  "--ro-bind /run/systemd /run/systemd"
  "--ro-bind /run/resolvconf /run/resolvconf"
  "--ro-bind /snap /snap"
  "--ro-bind /sys /sys"
  "--bind /run/user/${UID}/bus /run/user/${UID}/bus"
  "--bind /run/user/${UID}/docker.pid /run/user/${UID}/docker.pid"
  "--bind /run/user/${UID}/docker.sock /run/user/${UID}/docker.sock"
  "--bind /run/user/${UID}/docker /run/user/${UID}/docker"
  "--bind /tmp/.X11-unix /tmp/.X11-unix"
  "--dev-bind /dev /dev"
  "--ro-bind \"${HOME}/.docker/contexts/meta/\" /home/agent/.docker/contexts/meta/"
  "--ro-bind /mnt/wsl /mnt/wsl"
)

# Conditionally append each mount if the source path exists
for mount_line in "${conditional_mounts[@]}"; do
  # Split line into array:  [--ro-bind] [/sbin] [/sbin], etc.
  read -r -a mount_args <<< "$mount_line"
  # The source is typically the second element, mount_args[1]
  if [[ -e "${mount_args[1]}" || "${mount_args[0]}" == "--proc" ]]; then
    BWRAP_CMD+=("${mount_args[@]}")
  fi
done

# Append always-included options (not path-dependent)
BWRAP_CMD+=(
  --clearenv
  --setenv HOME /home/agent
  --setenv PATH "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/home/agent/.local/bin"
  --setenv DISPLAY "${DISPLAY}"
  --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
  --setenv DBUS_SESSION_BUS_ADDRESS "${DBUS_SESSION_BUS_ADDRESS}"
  --setenv XDG_RUNTIME_DIR "${XDG_RUNTIME_DIR}"
  --setenv TERM "${TERM}"
  --setenv COLORTERM "${COLORTERM}"
  --setenv BASH_ENV "/home/agent/.bashrc"
)


# Check if SANDBOX_HOME exists, if not create it and set ownership
if [ ! -d "$SANDBOX_HOME" ]; then
  mkdir -p "$SANDBOX_HOME"

  cat > "${SANDBOX_HOME}/init.sh" <<EOF
#!/bin/bash

check_command() {
    if ! command -v "\$1" &> /dev/null; then
        echo "❌ \$1 not found"
        return 1
    else
        echo "✓ \$1 found"
        return 0
    fi
}

mkdir -p ~/Documents/CODE
mkdir -p ~/Documents/NOTES
mkdir -p ~/Downloads

echo "Installing uv/uvx..."
curl -LsSf https://astral.sh/uv/install.sh | sh

if check_command "electron"; then
  echo "Electron already installed"
else
  # Install electron globally via npm if not present
  echo "Instaling nvm..."
  # install nvm
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
  
  export NVM_DIR="\$HOME/.nvm"
  [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"  # This loads nvm
  
  echo "Installing node via nvm..."
  # install node
  nvm install 22
  
  echo "Installing electron via npm..."
  npm install -g electron
  if ! check_command "electron"; then
      echo "Failed to install electron. Please install it manually:"
      echo "sudo npm install -g electron"
      exit 1
  fi
  echo "Electron installed successfully"
fi
npx playwright install
EOF
  chmod +x "${SANDBOX_HOME}/init.sh"

  # Initialize the sandbox
  "${BWRAP_CMD[@]}" "./init.sh"

  cp -a ~/.bashrc "${SANDBOX_HOME}"
  echo 'PS1="\[\e[48;5;208m\e[97m\]sandbox '"${SANDBOX_NAME}"'\[\e[0m\] \[\e[1;32m\]\h:\w\[\e[0m\]$ "' >> "${SANDBOX_HOME}/.bashrc"

  echo "Sandbox initialized successfully!"
fi

if [ "$#" -gt 0 ]; then
  "${BWRAP_CMD[@]}" "$@"
else
  "${BWRAP_CMD[@]}" /bin/bash
fi
