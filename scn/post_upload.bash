#!/usr/bin/env bash

# post upload scanning (checksums and data movement)

echo "post_upload starting at " `date` 

LOCKFILE=/var/run/post_upload.pid

DEPOSIT=/deposit
#HOLD=/hold
HOLD=/nfs/biodv/
SRC=/usr/local/dcm/

# user to own uploaded datasets; change to production user after testing
DSETUSER=sbdg

if [ -e $LOCKFILE ]; then
	echo "post_upload scan still in progress at " `date` " , aborting"
	exit
fi
echo $$ > $LOCKFILE
trap "rm -f '$LOCKFILE'" EXIT

# scan for indicators
for indicator_file in `find $DEPOSIT -name files.sha`
do
	ddir=`dirname $indicator_file`
	ulid=`basename $ddir`
	echo $indicator_file " : " $ddir " : " $ulid

	# verify checksums prior to moving dataset
	cd ${DEPOSIT}/${ulid}/${ulid} 
	nl=`wc -l files.sha | awk '{print $1}'`
	shasum -s -c files.sha 
	err=$?
	if (( ( $err != 0 ) || ( $nl == 0 ) )); then
		# handle checksum failure
		mv files.sha files-`date '+%Y%m%d-%H:%M'`.sha # rename previous indicator file
		echo "checksum failure"
	else
		# handle checksum success
		echo "checksums verified"

		#move to HOLD location
		if [ ! -d ${HOLD}/${ulid} ]; then
			cp -a ${DEPOSIT}/${ulid}/${ulid} ${HOLD}/
			err=$?
			if (( $err != 0 )) ; then
				echo "dcm: file move $ulid" 
				break
			fi
			rm -rf ${DEPOSIT}/${ulid}/${ulid}
			chown -R $DSETUSER:$DSETGROUP ${HOLD}/${ulid}
			echo "data moved"
		else
			echo "handle error - duplicate upload id $ulid"
			echo "problem moving data; bailing out"
			break #FIXME - this breaks out of the loop; aborting the scan (instead of skipping this dataset)
		fi
		
		mv $DEPOSIT/processed/${ulid}.json $HOLD/stage/
		#de-activate key (still in id_dsa.pub if we need it)
		rm ${DEPOSIT}/${ulid}/.ssh/authorized_keys
	fi
	
done

