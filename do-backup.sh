#!/bin/bash
#
# Perform periodic full and incremental system dumps
# Remove the oldest full backup and all dependent incrementals
# until there is at least $MINFREE MBytes free space on destination
# but preserve no less than $MINFULL full backups.
#
# usage: do-backup.sh [full|diff]
#


# Configuration

# Backups will be placed here
DSTDIR=/mnt/backup

# Name prefix
# Names look like $ARCHNAME.$DATE.(DIFF|FULL).dar(.[number])
ARCHNAME=homes

# Try to maintain this much free space, in MBytes
MINFREE=`expr 10 \* 1024`

# Keep at least this many complete backups
# Will exit with error if MINFREE and MINFULL can't be satisfied simultaneously
MINFULL=3

# Path to dar configuration file
DARRC=./darrc

#####################################################################


# Some internal vars

DARBIN=`which dar`
PIDFILE=$DSTDIR/pid
TYPE=$1


# Define some functions
warn () {
	HOSTNAME=`hostname`
	DATE=`date`
	echo "$DATE -- $1" | mail -s "$HOSTNAME backup" root@$HOSTNAME
}

usage () {
	cat<<END
usage: $0 [full|diff]
END
}

# Let's go

[ "$TYPE" != full ] && [ "$TYPE" != diff ] && usage && exit 1

[ ! -d $DSTDIR ] && warn "Backup failed, destination dir does not exist" && exit 4


# Clean old backups if needed

FREE=`df --block-size=1M $DSTDIR | tail -1 | awk '{print $4}'`
if [ $FREE -lt $MINFREE ]
then
	# Determine what to delete
	tsize_m=0				# Total size of files to be deleted, in MBytes
	lfull=0
	for f in `ls $DSTDIR/*`
	do
		# Skip files that are not our dumps
        [ "$f" == "${f/$ARCHNAME}" ] && [ "$f" == "${f/DIFF}" ] && [ "$f" == "${f/FULL}" ] && continue

		[ "$f" != "${f/FULL}" ] && lfull=`expr $lfull + 1`

		flist="$flist $f"
	done

	# If there are less than $MINFULL complete dumps present
	# we should reassign MINFULL; this way we can go on
	# if conditions are satisfiable without removing 
	# any complete dump
	[ $lfull -lt $MINFULL ] && MINFULL=$lfull

	for f in $flist
	do
		# Skip files that are not our dumps
        # >> left over from previous versions, might be dead code now... gotta check
		[ "$f" == "${f/$ARCHNAME}" ] && [ "$f" == "${f/DIFF}" ] && [ "$f" == "${f/FULL}" ] && continue

		if [ `expr $FREE + $tsize_m` -lt $MINFREE ]
		then
			if [ "$f" != "${f/FULL}" ]
			then
				lfull=`expr $lfull - 1`
			fi
				dlist="$dlist $f"
				fsize_b=`stat -c %s $f`
				tsize_m=`expr $fsize_b / 1024 / 1024 + $tsize_m`
		else
			break
		fi

	done

	if [ $lfull -lt $MINFULL ]
	then
		warn "MINFULL and MINFREE cannot be satisfied" && exit 6
	fi

	read -d '' -r msg <<-EOF
		Removing old dumps to free some space:
		`echo $dlist | sed 's/ /\n/g'`

		Total size: ${tsize_m}MB
	EOF

	warn "$msg"

	#echo "rm $dlist"
	rm $dlist

fi


# Some initial testing

if [ -f $PIDFILE ]
then
	_PID=`head -1 $PIDFILE`

	if [ "`ps -p $_PID -o comm=`" == "`basename $0`" ] 
	then
		warn "Previous backup hasn't finished yet, exiting"
		exit 2
	else
		rm -f $PIDFILE
		[ $? -ne 0 ] && warn "Could not delete stale pid file, aborting" && exit 5
	fi
fi

echo $$ > $PIDFILE
[ $? -ne 0 ] && warn "Can't write to destination dir, aborting" && exit 5

cd `dirname $0`


# Actual backup

DATE=`date +%Y-%m-%d-%H-%M`
case $TYPE in
	full) # This is a full backup
		$DARBIN -B $DARRC -c $DSTDIR/${ARCHNAME}.${DATE}.FULL
		#echo "$DARBIN -B $DARRC -c $DSTDIR/${ARCHNAME}.${DATE}.FULL"
	;;
	diff) # This is a differential backup
		# We need the name of last archive
		LAST="`ls $DSTDIR | grep -oE \"$ARCHNAME.*?FULL|$ARCHNAME.*?DIFF\" | tail -1`"

		$DARBIN -B $DARRC -A $DSTDIR/$LAST -c $DSTDIR/${ARCHNAME}.${DATE}.DIFF
		#echo "$DARBIN -B $DARRC -A $DSTDIR/$LAST -c $DSTDIR/${ARCHNAME}.${DATE}.DIFF"
	;;
	*) # Invalid arg, should never hapen
	;;
esac


# Clean up and exit

rm -r $PIDFILE

exit 0
