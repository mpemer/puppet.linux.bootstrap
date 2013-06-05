# License
    mpemer/puppet.linux.bootstrap: A bash script for bootstrapping linux systems for use with git-backed puppet repository
    
    Copyright 2013 Marcus Pemer
    Author: Marcus Pemer <mpemer@gmail.com>
    
    mpemer/puppet.linux.bootstrap is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    mpemer/puppet.linux.bootstrap is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with mpemer/puppet.linux.bootstrap.  If not, see <http://www.gnu.org/licenses/>.

# puppet.linux.bootstrap

## bootstrapping a linux system with puppet
Run this script when you have a clean installation of Linux and you wish to manage it under puppet.

## How to Use
After you have logged in to a freshly-built linux system, you can run the script with the following command:

    curl -k https://raw.github.com/mpemer/puppet.linux.bootstrap/master/bootstrap.sh | bash

## Supported Systems
The script has been tested on:

* Ubuntu 13.04 as well as 
* CentOS 5.9

If you have a different system and find that the script is not working, feel free to suggest changes to the script via pull requests.

## Notes    
You will need to have a puppet manifest already defined in a git repository somewhere.

You will need to either have the private RSA key necessary to connect to the git repository, or you will need to deploy one that will be created for you.

The script does the bare minimum to get puppet up and running, with the intent of letting puppet manage the rest.

You are best off starting with a completely clean system.

You need to log in with a user account that has sudo privileges (the script elevates itself to root when executed).


