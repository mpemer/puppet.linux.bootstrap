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

# Headless mode is triggered by providing at least a private rsa key
# and a git url in the form of environment variables to the script.
# If none of the variables below are provided, the script will assume
# interactive mode and start a user dialog.
#
# Rules:
# Check if we are running headless with all parameters available
# If so, don't run dialogs and go straight to installation
# If only partial parameters are available, fail
# If no parameters available, run dialog, then go to installation
#
# Input Variables:
#
# BOOTSTRAP_RSA_KEY
# - contents of private part to RSA key
# - used for authentication to puppet git repository
#
# BOOTSTRAP_GIT_URL
# - complete url go puppet git repository
#
# BOOTSTRAP_HOST_NAME
# - Optional, if you want to name this machine
# - this would be the place for you to provide a host name
# - the host name is often used in puppet repositories
# - to identify which 'node' should be invoked
#

# Global input variables
rsa_key="$BOOTSTRAP_RSA_KEY"
git_url="$BOOTSTRAP_GIT_URL"
host_name="$BOOTSTRAP_HOST_NAME"

# Helpers
create_new_rsa_key=false
replace_rsa_key=true
root_home=\$(grep -E '^root:' /etc/passwd | cut -d':' -f6)

#############################################################################
# Start interactive dialog
# (if we have not already been provided what we need)
#
if [[ \$rsa_key == "" ]] && [[ \$git_url == "" ]]
then
    echo "
# Bootstrap Script

Entering into interactive mode...

This script will \"bootstrap\" your local system,
connect it to a puppet manifest git repository and run puppet.
These actions are done as the root super-user, so you need to have
the ability to execute commands as root (if you did not already
run this script as root, that is).

Permissions escalation (sudo) performed and the script is now running with user id \$UID.
"

    # Collect host name
    read -p "Please select a hostname for this machine,
or hit enter to keep your current hostname [\$(hostname -s)]:
> " host_name

    # Collect RSA key
    read -p "You will need an RSA key to connect to your git puppet repository.
You could either provide a key now or have one created for you.
Would you like to have a new RSA key created for you? [Y/n]:
> " create_key_choice

    if [[ \$create_key_choice == "" ]] ||
       [[ \$create_key_choice == y* ]] ||
       [[ \$create_key_choice == Y* ]]
    then
        echo "Will create a new key pair"
        create_new_rsa_key=true
    else
        echo "Will not create a new key pair, so you'll need to provide one"
        echo "Please paste the contents of your private RSA key at the prompt.
You may end your input with an empty line or CTRL-D."
        read -p "> " rsa_key
        while read -p "> " input
        do
            if [[ \$input == "" ]]
            then
                break
            fi
            rsa_key="\$rsa_key\n\$input"
        done
    fi

    # Double-check if we should replace an already existing key
    private_key_path=~/.ssh/id_rsa
    if [ -e \$private_key_path ]
    then
        read -p "A private key already exists in \$private_key_path.
Would you like to replace it with the new one?
(your old key will be backed up)
(if you choose no below, your existing key will be used)
[Y/n]:
> " response
        if [[ \$response == '' ]]  ||
           [[ \$response == y* ]] ||
           [[ \$response == Y* ]]
        then
            replace_rsa_key=true
        else
            replace_rsa_key=true
        fi
    fi

    # Collect git url
    read -p "Please enter (or paste) the full URL to the git repo containing the puppet manifests for this server:
    > " git_url

fi


#############################################################################
# Check again: do we have everything we need?
#

# Are all required parameters defined?
if [ -z \${rsa_key+x} ] || [ -z \${git_url+x} ]
then
  echo "ERROR: not all required information was provided
The script cannot continue without a private RSA key and a git url
requirements and therefore script will now exit.
"
  exit 1
fi

# Are we running on a supported system?
# TODO: This check is currently very shallow and should be improved
host_system=\$(uname)
if [[ \$host_system == Darwin* ]] || [[ \$host_system == Linux* ]]
then
  echo "You are running \$(uname -s) on \$(uname -p), which is fine.
(You should feel good about that.)

Let's continue!
  "
else
  echo "ERROR: This script will run on Linux or Mac OS X systems only!
Your system reports as [\$host_system], which does not match the script
requirements and therefore script will now exit.
"
  exit 2
fi


#############################################################################
# Do the actual work
#

# Install packages, if needed
if which puppet && which git
then
    echo "Both puppet and git are already installed.
Assuming all is good and skipping package installation."
else
    if which yum
    # If yum exists, assume we are on a RH5 system
    then
        # TODO: This is a hard-coded section that will soon need to change
        yes | rpm -Uvh http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm || true
        yes | rpm -Uvh http://repo.webtatic.com/yum/centos/5/latest.rpm || true
        yum -y install --enablerepo=webtatic git || true
        \curl -L https://get.rvm.io | bash -s stable --ruby=1.9.3 --gems=puppet
    else    
        if which apt-get
        # If yum does not exist, but apt-get exists, assume we are on a debian system
        then
            # Update our system from bare minimum to usable level
            packages="git puppet"
            if ! apt-get -q -y --force-yes install \$packages
            then
                apt-get -q -y --force-yes update
                apt-get -q -y --force-yes install \$packages
            fi
        else
            echo "Unable to locate a package manager (neither yum nor apt-get found. Exiting with sadness."
            exit 3
        fi
        # TODO: this section needs to be updated to also support mac os x and newer RH
    fi
fi

# Set the host name
if [[ \$host_name != "" ]] 
then
    echo "Setting host name to \$host_name"
    grep -q "\$host_name" /etc/hosts ||
        sed -i "s/127\.0\.0\.1\(\W*\)\(.*\)/127.0.0.1\1\$host_name \2/" /etc/hosts
    echo "\$host_name" >/etc/hostname
    hostname "\$host_name"
    [ -e /etc/init.d/hostname ] && /etc/init.d/hostname restart
fi

# Set up the RSA key for connecting to git puppet repo

# We need to have the .ssh folder no matter what
# And that folder should always have 700 permissions
[ -d \$root_home/.ssh ] || mkdir \$root_home/.ssh
chmod 700 \$root_home/.ssh

# Did we choose to replace the existing key? - if so back it up.
if \$replace_rsa_key
then
    ts=\$(date +%s)
    if [ -e \$root_home/.ssh/id_rsa ]
    then
        echo "Backing \$root_home/.ssh/id_rsa up as \$root_home/.ssh/id_rsa.\$ts"
        mv -f \$root_home/.ssh/id_rsa \$root_home/.ssh/id_rsa.\$ts
    fi
    if [ -e \$root_home/.ssh/id_rsa ]
    then
        echo "Backing up \$root_home/.ssh/id_rsa.pub as \$root_home/.ssh/id_rsa.pub.\$ts"
        mv -f \$root_home/.ssh/id_rsa.pub \$root_home/.ssh/id_rsa.pub.\$ts
    fi
fi

# Should we create a new key or was one provided?
if \$create_new_rsa_key
then
    ssh-keygen -b 2048 -t rsa -C 'RSA key generated by puppet.linux.bootstrap' -N '' -f \$root_home/.ssh/id_rsa
    echo "A fresh key has been created for you.
Please use the following public RSA key when connecting to your git repository:
"
    cat \$root_home/.ssh/id_rsa.pub

    echo "
Hit return when you have copied the key above.
Your git checkout will not work until the key above has been installed by your git admin."
else
    # A key was provided, put it in the right place
    echo "\$rsa_key" >\$root_home/.ssh/id_rsa
fi
# No matter what, keep the key files secure
chmod 600 \$root_home/.ssh/id_rsa*


# Check out git repo
rm -fR /etc/puppet
export GIT_SSL_NO_VERIFY=true
echo "StrictHostKeyChecking=no" >>\$root_home/.ssh/config
chmod 600 \$root_home/.ssh/config
git clone \$git_url /etc/puppet

# Make a log file for puppet
puppet_log_dir=/var/log/puppet
puppet_log_file=\$puppet_log_dir/puppet.log
[ -d \$puppet_log_dir ] || mkdir \$puppet_log_dir
chmod 755 \$puppet_log_dir
touch \$puppet_log_file
chmod 644 \$puppet_log_file

# Hack to ensure that we on RH systems have access to ruby (for puppet)
if [ -e /usr/local/rvm/scripts/rvm ]
then
    source /usr/local/rvm/scripts/rvm
    echo "source /usr/local/rvm/scripts/rvm" >>/etc/bashrc
fi

# Run puppet
puppet apply --verbose --environment=production --modulepath /etc/puppet/modules --templatedir /etc/puppet/templates /etc/puppet/manifests/init.pp

EOF
chmod 755 $TMPDIR/bootstrap.sh
sudo bash -c $TMPDIR/bootstrap.sh
