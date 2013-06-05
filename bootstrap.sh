#!/usr/bin/env bash

# The purpose of this script is bring the machine up to a point where:
#  - git and puppet are installed
#  - puppet git repo is checked out into /etc/puppet
#  - puppet apply is triggered (update.sh)
#
# Important to note that absolutely nothing else should be done in this script.
# The rest should be contained in the puppet manifests.
#

if ! which sudo
then
    echo "ERROR: Unable to run sudo. Exiting."
    exit 255
fi

sudo bash -ek <<EOF
#!/usr/bin/env bash

echo "
# Bootstrap Script

This script will \"bootstrap\" your local system,
connect it to a puppet manifest git repository and run puppet.
These actions are done as the root super-user, so you need to have
the ability to execute commands as root (if you did not already
run this script as root, that is).

Permissions escalation (sudo) performed and the script is now running with user id \$UID.
"
# Check that we are running on a supported system
host_system=\$(uname)
if [[ \$host_system == Darwin\* ]] || [[ \$host_system == Linux\* ]]
then
  echo "You are running \$(uname -s) on \$(uname -p), which is fine.
(You should feel good about that.)
Let's continue!"
else
  echo "ERROR: This script will run on Linux or Mac OS X systems only!
Your system reports as [\$host_system], which does not match the script
requirements and script will now exit.
"
  exit 1
fi
echo ""

echo 2

# Set our host name
read -p "Please select a hostname for this machine,
or hit enter to keep your current hostname [\$(hostname -s)]:
> " selected_hostname

if [[ $selected_hostname != "" ]] 
then
    echo "Your host name will be set to $selected_hostname"
    grep -q "$selected_hostname" /etc/hosts ||
        sed -i "s/127\.0\.0\.1\(\W*\)\(.*\)/127.0.0.1\1${selected_hostname} \2/" /etc/hosts
    echo "$selected_hostname" >/etc/hostname
    hostname "$selected_hostname"
fi


read -p "You will need an RSA key to connect to your git puppet repository.
You could either provide a key now or have one created for you.
Would you like to have a new RSA key created for you? [Y/n]:
> " create_key_choice

# We need to have the .ssh folder no matter what
[ -d /root/.ssh ] || mkdir /root/.ssh
chmod 700 /root/.ssh

if [[ $create_key_choice == "" ]] ||
   [[ $create_key_choice == y\* ]] ||
   [[ $create_key_choice == Y\* ]]
then
    create_key=true

    private_key_path=~/.ssh/id_rsa
    echo "Will create a new key pair"
    if [ -e \"$private_key_path\" ]
    then
        read -p "A private key already exists in $private_key_path.
Would you like to replace it with a new one?
(your old key will be backed up)
(if you choose no below, your existing key will be used)
[Y/n]:
> " response
        if [[ $response == '' ]]  ||
           [[ $response == y\* ]] ||
           [[ $response == Y\* ]]
        then
            ts=\$(date +%s)
            echo "Backing old key files up with the $ts extension"
            [ -e /root/.ssh/id_rsa ] && mv /root/.ssh/id_rsa /root/.ssh/id_rsa.$ts
            [ -e /root/.ssh/id_rsa.pub ] && mv /root/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub.$ts
        else
            echo "Reusing existing RSA key"
            create_key=false
        fi
    fi

    if $create_key
    then
        ssh-keygen -b 2048 -t rsa -C 'RSA key generated by bootstrap' -N '' -f /root/.ssh/id_rsa
        chmod 600 /root/.ssh/id_rsa*
        echo "A fresh key has been created for you.
Please use the following public RSA key when connecting to your git repository:
"
        cat /root/.ssh/id_rsa.pub

        echo "
Hit return when you have copied the key above."
        read
    fi
    
else
    echo "Will not create a new key pair, so you'll need to provide one"
    read -s -p "Please paste the contents of your private RSA key and hit enter:
> " private_key
    echo -n "$private_key" >/root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
fi


# Retrieve git repo URL
echo "Your credentials are now installed, continuoing to check out the puppet repo..."
read -p "Please paste the full URL to the git repo containing the puppet manifests for this server:
> " git_url

# Install packages
if which yum
then
    wget -O /etc/yum.repos.d/public-yum-el5.repo http://public-yum.oracle.com/public-yum-el5.repo
    rpm -Uvh http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm
    yum -y install puppet git
else    
    if which apt-get
    then
        # Update our system from bare minimum to usable level
        apt-get -q -y --force-yes update
        apt-get -q -y --force-yes install git puppet
    else
        echo "Unable to locate a package manager (neither yum nor apt-get found. Exiting with sadness."
        exit 2
    fi
fi

# Check out git repo
rm -fR /etc/puppet
GIT_SSL_NO_VERIFY=true git clone $git_url /etc/puppet

# Make a log file for puppet
puppet_log_file=/var/log/puppet/puppet.log
touch $puppet_log_file
chmod 600 $puppet_log_file

# Run puppet
timeout -k 10 290 nice -n 19 puppet apply --environment=production --modulepath /etc/puppet/modules --templatedir /etc/puppet/templates --logdest $puppet_log_file /etc/puppet/manifests/init.pp


EOF