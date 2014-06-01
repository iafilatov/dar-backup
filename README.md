dar-backup
==========

Backup script to use with [DAR](http://dar.linux.free.fr/) for full and incremental backups.



Configuration
-------------

1. Place the script somewhere you like and edit the configuration in the top of it:

        # Backups will be placed here
        DSTDIR=/mnt/backup

        # Name prefix
        ARCHNAME=homes

        # Try to maintain this much free space in DSTDIR, in MBytes
        MINFREE=`expr 10 \* 1024`

        # Keep at least this many complete backups
        # when trying to free up some space
        MINFULL=3

        # Path to dar configuration file
        DARRC=./darrc

1. After this edit `darrc` (dar configuration file) to suit your needs. Here's an example:

        # This is a simple darrc example that is configured to take backups
        # of (possibly) important stuff in users' home dirs.
        #
        # See dar man page for more options and their description.
        #
        # Suppress final report
        -q
        # Enable compression
        -z4
        # Do not overwrite any files
        -n
        # Set backup root to users' homes
        -R /home/
        # Switch to ordered selection mode, which means that the following
        # options will be considered top to bottom
        -am
        # Exclude everything in homes, other than config files
        -P home/*/[^.]*
        # Include complete homes of important users
        -g home/iafilatov
        -g home/vip
        # Exclude videos, because they take too much space
        -P home/vip/video

You are ready to go.


Usage
-----

Run the script like this

    ./do-backup.sh full

to get a complete backup, and like this

    ./do-backup.sh diff

for an incremental one.

The script will look for the last archive in destination directory and take it as a base. Naturally, you will need to have at least one full backup first. But next incremental backups can themselves be based on previous incremental backups.

For example, you can configure cron to take complete backups once a week and incremental backups daily.
