# puppet.linux.bootstrap

## bootstrapping a linux system with puppet
Run this script when you have a clean installation of Linux and you wish to manage it under puppet.

## How to Use
After you have logged in to a freshly-built linux system, you can run the script with the following command:

    bash <(curl -k https://raw.github.com/puppet.linux.bootstrap/master/bootstrap.sh)

Note that you need to have sudo abilities to run this script. You can test whether you have sudo rights with the following command:

    sudo id

You should be prompted for a password and then some information should be displayed, indicating your uid as root (0). If you do not see this information, you probably don't have sudo on the machine you are bootstrapping.

On some systems, you may add yourself to sudo by enabling the wheel group as sudoers and then adding yourself to the wheel group, like so:

    su - -c "sed -ie 's/^#\(.*wheel.*NOPASSWD.*\)/\1/' /etc/sudoers && usermod -G wheel $USER"

If you run the above command and provide the password for root, chances are you will be ready to run the first bootstrap command.

## Warning ##
This bootstrap script will run as root, install a puppet repo under /etc/puppet - replacing whatever was already there - and then run puppet on this repo for you. This may damage your system and you should only run this script if you actually intend for this system to be bootstrapped with puppet pointing at a git repo. The author of this script assumes no responsibility for any way your system may be damaged by running this script.

## Supported Systems
The script has been tested on:

* Ubuntu 13.04
* CentOS 5.9

If you have a different system and find that the script is not working, feel free to suggest changes to the script via pull requests.

## Notes
* You will need to have a puppet manifest already defined in a git repository somewhere.
* You will need to either have the private RSA key necessary to connect to the git repository, or you will need to deploy one that will be created for you.
* The script does the bare minimum to get puppet up and running, with the intent of letting puppet manage the rest.
* You are best off starting with a completely clean system.
* You need to log in with a user account that has sudo privileges (the script elevates itself to root when executed).
* Aside from sudo rights you should make sure the curl command is available (or else not much will happen when you issue the command above)

# License
#### puppet.linux.bootstrap: A bash script for bootstrapping linux systems for use with git-backed puppet repository

*Copyright 2013 Marcus Pemer, Iteego
Author: Marcus Pemer <mpemer@gmail.com>*

* puppet.linux.bootstrap is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
* puppet.linux.bootstrap is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with puppet.linux.bootstrap.  If not, see <http://www.gnu.org/licenses/>.