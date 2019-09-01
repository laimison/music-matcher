#!/bin/bash

# Do not continue a shell script if failed
# set -e

# Given playlist
TRACK_CANDIDATE_LIST=tmp/given.tracks
TRACK_CANDIDATE_LIST_CORRECTED=tmp/given.tracks.corrected

# Local music
SEARCH_FOR_MUSIC_DIR="${HOME}/Music"
TRACK_LOCAL_LIST=tmp/tracks.all
TRACK_LOCAL_LIST_TAGGED=tmp/tracks.all.tagged

# The final result what I don't have
TRACKS_THAT_DONT_EXIST_LOCALLY=tmp/tracks.that.dont.exist.locally

if ! ls music_matcher.sh 2>/dev/null | grep -q music_matcher.sh
then
  echo "You are probably not in the right directory"
  exit 1
fi

if ! which ffprobe
then
  echo "Cannot find ffprobe binary"
  exit 1
fi

open "http://www.playlist-converter.net"

echo "Click Spotify - Login with Spotify (or other playlist)"
echo "Choose a playlist"
echo "Convert to CSV and download"
echo "Drag the CSV here and press enter:"
read csv

if echo $csv | grep -q [a-zA-Z0-9]
then
  iconv -f utf-8 -t ascii "${csv}" > /tmp/tracks.converted.encoding.csv.tmp
  cat /tmp/tracks.converted.encoding.csv.tmp | tail -n +2 | tr '",' ' ' > $TRACK_CANDIDATE_LIST
fi

# Check if I have tracks file to start with
if ! ls $TRACK_CANDIDATE_LIST >/dev/null 2>/dev/null; then echo "Please create $TRACK_CANDIDATE_LIST with your tracks list, e.g. The Glitch Mob Animus Vox, The Glitch Mob - Animus Vox.mp3, etc."; fi

# Remove unwanted characters and make list unique
# Cut ' -', '[anything-here]', '&', '.', 'original mix'
cat $TRACK_CANDIDATE_LIST | sed -e "s| -||g" | sed -e "s|\[.*\]||g" | sed -e "s|\&||g" | sed -e "s|\.||g" | sed -e "s|[Oo]riginal [Mm]ix||g" | awk '!uniq[substr($0, 12, 8)]++' > $TRACK_CANDIDATE_LIST_CORRECTED

################################################# UPDATE DB ############################################
echo "Find all tracks - artist ||| title ||| file name"
echo "Update tracks list? Type in 'yes' for update, press enter if you have updated recently"
read input

if echo $input | grep -i ^yes$
then
  find "${SEARCH_FOR_MUSIC_DIR}" -name '*.mp3' > $TRACK_LOCAL_LIST

  > $TRACK_LOCAL_LIST_TAGGED
  while IFS= read -r track; do
    ffprobe "$track" 2> /tmp/tracks.ffprobe
    artist=`cat /tmp/tracks.ffprobe | grep '^[[:space:]]\+artist[[:space:]]\+\:[[:space:]]\+' | sed -e s/artist.*\://g | head -n 1`
    title=`cat /tmp/tracks.ffprobe | grep '^[[:space:]]\+title[[:space:]]\+\:[[:space:]]\+' | sed -e s/title.*\://g | head -n 1`

    # echo "$artist ||| $title ||| `basename \"$track\"` ||| $track" | tee -a $TRACK_LOCAL_LIST_TAGGED
    echo "$artist ||| $title ||| `basename \"$track\"`" | tee -a $TRACK_LOCAL_LIST_TAGGED
    if [ "$?" != "0" ]
    then
      echo "Issue with the script"
      exit 1
    fi
  done < $TRACK_LOCAL_LIST
fi

echo "In total found `wc -l $TRACK_LOCAL_LIST_TAGGED | awk -F ' ' '{print $1}'` tracks on your machine. You have given `wc -l $TRACK_CANDIDATE_LIST_CORRECTED | awk -F ' ' '{print $1}'` tracks. Continuing to find tracks that do not exist on your machine in 3 seconds ..."
sleep 3
#########################################################################################################

> /tmp/tracks.found
> $TRACKS_THAT_DONT_EXIST_LOCALLY
# Go through given track list
while IFS='' read -r track
do
  # Copy the file which contains all tracks to temporary file
  cat $TRACK_LOCAL_LIST_TAGGED > /tmp/tracks.temp
  > /tmp/tracks.temp.2

  for word in $track
  do
    if echo $word | grep -q -v -e '^[[:space:]]*$'
    then
      cat /tmp/tracks.temp | grep -i "$word" > /tmp/tracks.temp.2
      cat /tmp/tracks.temp.2 > /tmp/tracks.temp
    fi
  done

  # cat /tmp/tracks.temp

  if cat /tmp/tracks.temp | grep -q [a-zA-Z]
  then
    echo "Found: `cat /tmp/tracks.temp | head -n 1`" | tee -a /tmp/tracks.found
  else
    # From DOS to Linux
    echo "$track" | tr -d '\015' >> $TRACKS_THAT_DONT_EXIST_LOCALLY
  fi
done < $TRACK_CANDIDATE_LIST_CORRECTED

echo
echo "Tracks not found:"
cat $TRACKS_THAT_DONT_EXIST_LOCALLY
