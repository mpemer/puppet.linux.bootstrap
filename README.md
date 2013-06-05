# Puppet Bootstrap Script
Run this script when you have a clean installation of Linux and you wish to manage it under puppet. You will need to have a puppet manifest already defined in a git repository somewhere. You will need to either have the private RSA key necessary to connect to the git repository, or you will need to deploy one that will be created for you.

The script does the bare minimum to get puppet up and running, with the intent of letting puppet manage the rest.

You are best off starting with a completely clean system.

You need to log in with a user account that has sudo privileges.

