#!/bin/sh

set -eu

platform="$1"

env

cd ~/

if [ "${platform}" = "freebsd" ]; then
    while true; do
        env ASSUME_ALWAYS_YES=YES pkg bootstrap && \
        pkg install -y \
            bash \
            curl \
            gtar \
            python \
            py27-Jinja2 \
            py27-virtualenv \
            py27-cryptography \
            sudo \
         && break
         echo "Failed to install packages. Sleeping before trying again..."
         sleep 10
    done

    pip --version 2>/dev/null || curl --silent --show-error https://bootstrap.pypa.io/get-pip.py | python
elif [ "${platform}" = "rhel" ]; then
    if grep '8\.' /etc/redhat-release; then
        while true; do
            curl -o /etc/yum.repos.d/rhel-8-beta.repo http://downloads.redhat.com/redhat/rhel/rhel-8-beta/rhel-8-beta.repo && \
            dnf config-manager --set-enabled rhel-8-for-x86_64-baseos-beta-rpms && \
            dnf config-manager --set-enabled rhel-8-for-x86_64-appstream-beta-rpms && \
            yum -y module install python36 && \
            yum install -y \
                gcc \
                python3-devel \
                python3-jinja2 \
                python3-virtualenv \
                python3-cryptography \
                iptables \
             && break
             echo "Failed to install packages. Sleeping before trying again..."
             sleep 10
        done

        # When running from source our python shebang is: #!/usr/bin/env python
        # To avoid modifying all of our scripts while running tests we make sure `python` is in our PATH.
        if [ ! -f /usr/bin/python ]; then
            ln -s /usr/bin/python3 /usr/bin/python
        fi
        if [ ! -f /usr/bin/pip ]; then
            ln -s /usr/bin/pip3 /usr/bin/pip
        fi
        if [ ! -f /usr/bin/virtualenv ]; then
            ln -s /usr/bin/virtualenv-3 /usr/bin/virtualenv
        fi
    else
        while true; do
            yum install -y \
                gcc \
                python-devel \
                python-jinja2 \
                python-virtualenv \
                python2-cryptography \
             && break
             echo "Failed to install packages. Sleeping before trying again..."
             sleep 10
        done

        pip --version 2>/dev/null || curl --silent --show-error https://bootstrap.pypa.io/get-pip.py | python
    fi
fi

if [ "${platform}" = "freebsd" ] || [ "${platform}" = "osx" ]; then
    pip install virtualenv

    # Tests assume loopback addresses other than 127.0.0.1 will work.
    # Add aliases for loopback addresses used by tests.

    for i in 3 4 254; do
        ifconfig lo0 alias "127.0.0.${i}" up
    done

    ifconfig lo0
fi

# Since tests run as root, we also need to be able to ssh to localhost as root.
sed -i= 's/^# *PermitRootLogin.*$/PermitRootLogin yes/;' /etc/ssh/sshd_config

if [ "${platform}" = "freebsd" ]; then
    # Restart sshd for configuration changes and loopback aliases to work.
    service sshd restart
fi

# Generate our ssh key and add it to our authorized_keys file.
# We also need to add localhost's server keys to known_hosts.

if [ ! -f "${HOME}/.ssh/id_rsa.pub" ]; then
    ssh-keygen -q -t rsa -N '' -f "${HOME}/.ssh/id_rsa"
    cp "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/authorized_keys"
    for key in /etc/ssh/ssh_host_*_key.pub; do
        pk=$(cat "${key}")
        echo "localhost ${pk}" >> "${HOME}/.ssh/known_hosts"
    done
fi

# Improve prompts on remote host for interactive use.
# shellcheck disable=SC1117
cat << EOF > ~/.bashrc
alias ls='ls -G'
export PS1='\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF

# Make sure ~/ansible/ is the starting directory for interactive shells.
if [ "${platform}" = "osx" ]; then
    echo "cd ~/ansible/" >> ~/.bashrc
fi
