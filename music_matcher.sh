#!/bin/bash

# Do not continue a shell script if failed
# set -e

SEARCH_FOR_MUSIC_DIR="${HOME}/Music"

open "http://www.playlist-converter.net"

echo "Click Spotify - Login with Spotify (or other playlist)"
echo "Choose a playlist"
echo "Convert to CSV and download"
echo "Drag the CSV here and press enter:"
read csv

if echo $csv | grep -q [a-zA-Z0-9]
then
  iconv -f utf-8 -t ascii ~/Downloads/Liked\ from\ Radio.csv > /tmp/tracks.converted.encoding.csv
  cat /tmp/tracks.converted.encoding.csv | tail -n +2 | tr '",' ' ' > /tmp/tracks
fi

# Check if I have tracks file to start with
if ! ls /tmp/tracks >/dev/null 2>/dev/null; then echo "Please create /tmp/tracks with your tracks list, e.g. The Glitch Mob Animus Vox, The Glitch Mob - Animus Vox.mp3, etc."; fi

# Remove unwanted characters and make list unique
# Cut ' -', '[anything-here]', '&', '.', 'original mix'
cat /tmp/tracks | sed -e "s| -||g" | sed -e "s|\[.*\]||g" | sed -e "s|\&||g" | sed -e "s|\.||g" | sed -e "s|[Oo]riginal [Mm]ix||g" | awk '!uniq[substr($0, 12, 8)]++' > /tmp/tracks.corrected

echo "Find all tracks - artist ||| title ||| file name"
echo "Update tracks list? Type in 'yes' for update, press enter if you have updated recently"
read input

if echo $input | grep -i ^yes$
then
  find "${SEARCH_FOR_MUSIC_DIR}" -name '*.mp3' > /tmp/tracks.all.untagged

  > /tmp/tracks.all
  while IFS= read -r track; do
    ffprobe "$track" 2> /tmp/tracks.ffprobe
    artist=`cat /tmp/tracks.ffprobe | grep '^[[:space:]]\+artist[[:space:]]\+\:[[:space:]]\+' | sed -e s/artist.*\://g | head -n 1`
    title=`cat /tmp/tracks.ffprobe | grep '^[[:space:]]\+title[[:space:]]\+\:[[:space:]]\+' | sed -e s/title.*\://g | head -n 1`

    # echo "$artist ||| $title ||| `basename \"$track\"` ||| $track" | tee -a /tmp/tracks.all
    echo "$artist ||| $title ||| `basename \"$track\"`" | tee -a /tmp/tracks.all
    if [ "$?" != "0" ]
    then
      echo "Issue with the script"
      exit 1
    fi
  done < /tmp/tracks.all.untagged
fi

echo "In total found `wc -l /tmp/tracks.all | awk -F ' ' '{print $1}'` tracks on your machine. You have given `wc -l /tmp/tracks.corrected | awk -F ' ' '{print $1}'` tracks. Continuing to find tracks that do not exist on your machine in 3 seconds ..."
sleep 3

> /tmp/tracks.found
> /tmp/tracks.not.found

# Go through given track list
while IFS='' read -r track
do
  # Copy the file which contains all tracks to temporary file
  cat /tmp/tracks.all > /tmp/tracks.temp
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
    echo "$track" | tr -d '\015' >> /tmp/tracks.not.found
  fi
done < /tmp/tracks.corrected

echo
echo "Tracks not found:"
cat /tmp/tracks.not.found
