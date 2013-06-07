#!/usr/bin/bash -ei

# The purpose of this script is bring the machine up to a point where:
#  - git and puppet are installed
#  - puppet git repo is checked out into /etc/puppet
#  - puppet apply is run once
#
# Important to note that absolutely nothing else should be done in this script.
# The rest should be contained in the puppet manifests.
#

if ! which sudo
then
    echo "ERROR: Unable to run sudo. Exiting."
    exit 255
fi

# Work in a temporary directory 
# Create a trap that removes our directory when we are done
TMPDIR=`mktemp -d`
trap "rm -rf $TMPDIR" EXIT

cat >$TMPDIR/bootstrap.sh <<EOF
#!/bin/bash -ei

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
if [[ \$host_system == Darwin* ]] || [[ \$host_system == Linux* ]]
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

# Set our host name
read -p "Please select a hostname for this machine,
or hit enter to keep your current hostname [\$(hostname -s)]:
> " selected_hostname

if [[ \$selected_hostname != "" ]] 
then
    echo "Your host name will be set to \$selected_hostname"
    grep -q "\$selected_hostname" /etc/hosts ||
        sed -i "s/127\.0\.0\.1\(\W*\)\(.*\)/127.0.0.1\1\$selected_hostname \2/" /etc/hosts
    echo "\$selected_hostname" >/etc/hostname
    hostname "\$selected_hostname"
    [ -e /etc/init.d/hostname ] && /etc/init.d/hostname restart
fi


read -p "You will need an RSA key to connect to your git puppet repository.
You could either provide a key now or have one created for you.
Would you like to have a new RSA key created for you? [Y/n]:
> " create_key_choice

# We need to have the .ssh folder no matter what
[ -d /root/.ssh ] || mkdir /root/.ssh
chmod 700 /root/.ssh

if [[ \$create_key_choice == "" ]] ||
   [[ \$create_key_choice == y* ]] ||
   [[ \$create_key_choice == Y* ]]
then
    create_key=true

    private_key_path=~/.ssh/id_rsa
    echo "Will create a new key pair"
    if [ -e \$private_key_path ]
    then
        read -p "A private key already exists in \$private_key_path.
Would you like to replace it with a new one?
(your old key will be backed up)
(if you choose no below, your existing key will be used)
[Y/n]:
> " response
        if [[ \$response == '' ]]  ||
           [[ \$response == y* ]] ||
           [[ \$response == Y* ]]
        then
            ts=\$(date +%s)
            echo "Backing old key files up with the \$ts extension"
            [ -e /root/.ssh/id_rsa ] && mv /root/.ssh/id_rsa /root/.ssh/id_rsa.\$ts
            [ -e /root/.ssh/id_rsa.pub ] && mv /root/.ssh/id_rsa.pub /root/.ssh/id_rsa.pub.\$ts
        else
            echo "Reusing existing RSA key"
            create_key=false
        fi
    fi

    if \$create_key
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

    echo -n "" >/root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa

    echo "Please paste the contents of your private RSA key at the prompt.
You may end your input with CTRL-D."
    while read -p "> " input
    do    
        echo "\$input" >>/root/.ssh/id_rsa
    done
fi

# Retrieve git repo URL
echo "Your credentials are now installed, proceeding to check out the puppet repo..."
read -p "Please paste the full URL to the git repo containing the puppet manifests for this server:
> " git_url

# Install packages
if which yum
then
    rpm -Uvh http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm || true
    rpm -Uvh http://repo.webtatic.com/yum/centos/5/latest.rpm || true
    yum install --enablerepo=webtatic git || true
    \curl -L https://get.rvm.io | bash -s stable --ruby=1.9.3 --gems=puppet
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
export GIT_SSL_NO_VERIFY=true
echo "StrictHostKeyChecking=no" >>/root/.ssh/config
chmod 600 /root/.ssh/config
git clone \$git_url /etc/puppet

# Make a log file for puppet
puppet_log_dir=/var/log/puppet
puppet_log_file=\$puppet_log_dir/puppet.log
mkdir \$puppet_log_dir
chmod 755 \$puppet_log_dir
touch \$puppet_log_file
chmod 644 \$puppet_log_file

# Run puppet
source /usr/local/rvm/scripts/rvm
puppet apply --verbose --environment=production --modulepath /etc/puppet/modules --templatedir /etc/puppet/templates /etc/puppet/manifests/init.pp

EOF
chmod 755 $TMPDIR/bootstrap.sh
sudo bash -c $TMPDIR/bootstrap.sh
