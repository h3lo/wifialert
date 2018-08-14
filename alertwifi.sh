#!/bin/sh

#=============================================================================+
# This script was written for DD-WRT to send push notifications whenever wifi |
#  clients connect or disconnect. It sends a single push notification with    |
#  the changes since the last run. Although this can probably be modified to  |
#  send notifications in some other way, this version requres Pushover.net.   |
#                                                                             |
# Set the variables in the top section to include your Pushover.net tokens,   |
#  as well as a few other configurables. For the rest of the variables, see   |
#  the comments immediately preceeding them for instructions on how to set    |
#  them.                                                                      |
#                                                                             |
# In addition to the variables set here, the KNOWNMAC file should contain     |
#  a list of MAC addresses, and descriptions. This version can't handle       |
#  descriptions with spaces, so use _ or some other alternative. See the      |
#  knownmac-example file in the repo for an example. If you have no known MAC |
#  addresses, you still must create the file, but it can be empty.            |
#-----------------------------------------------------------------------------+
# Written by Danny Mann                                                       |
# Revision 1.0                                                                |
#=============================================================================+

# Pushover Variables:
API_TOKEN=
USER_TOKEN=
TITLE=
POST_URL=https://api.pushover.net/1/messages.json
# You can set the pushover priority for known vs unknown MACs individually
knownPriority=-1
unknownPriority=0

# CA Bundle file for SSL verification
# If this file is wrong, alerts don't get sent... You need the CA cert for pushover's API.
#   I just used the entire Mozilla CA Cert bundle to make things simple.
CACERT=/jffs/cacert.pem
if [[ ! -f $CACERT ]]; then
  echo "$CACERT doesn't exist"
  exit
fi

# Local files for storing scan values and known devices:
# This file contains a mapping of MAC addresses to descriptive names.
#   It should be stored on permanent storage so it can be loaded through reboots.
KNOWNMAC=/jffs/.known-macs
# These files are for storing the current state and recognizing changes.
#   Since these get written over ever run, they should be stored on ramdisk to avoid
#   excessive flash wear.
LASTSCAN=/tmp/.lastwifiscanmac
CURRSCAN=/tmp/.currwifiscanmac

# I wanted to make arrays here, but busybox doesn't really support them...
#   The wierdness here is all a kind of hack to mimic arrays.
# If you remove or change an interface name, you should remove the $CURRSCAN file or
#   things may break when a client from a no longer existing interface disconnects.
# For each interface, add a line like below with the interface name after the =
#   ifTot=$((ifTot+1)) ; eval if$ifTot=
# Don't change this, initialize the total number of interfaces counter
ifTot=-1
# Set interfaces names here:
ifTot=$((ifTot+1)) ; eval if$ifTot=eth1
#ifTot=$((ifTot+1)) ; eval if$ifTot=eth2
#ifTot=$((ifTot+1)) ; eval if$ifTot=wl0.1
#ifTot=$((ifTot+1)) ; eval if$ifTot=wl1.1

# And a matching array of descriptions (same wierd hack as above)
# Don't change this counter initialization
ifDescTot=-1
# Add descriptions here, they MUST be in the same order as defined above
# IMPORTANT: Because we have to use eval to get the array-like behavior,
#   you must escape ALL special characters in your description text.
#   For example, " ' are all special and need to be escaped like \" \'
#   The opening and closing quotes of your description must be escaped.
ifDescTot=$((ifDescTot+1)) ; eval ifDesc$ifDescTot=\"2.4 GHz\"
#ifDescTot=$((ifDescTot+1)) ; eval ifDesc$ifDescTot=\"5 GHz\"
#ifDescTot=$((ifDescTot+1)) ; eval ifDesc$ifDescTot=\"2.4 GHz VAP\"
#ifDescTot=$((ifDescTot+1)) ; eval ifDesc$ifDescTot=\"5 GHz VAP\"

#=============================================================================+
#========== Script logic begins here, do not edit below this line! ===========|
#=============================================================================+

# Rotate the scan output from last run
if [[ -f $CURRSCAN ]]; then
  mv $CURRSCAN $LASTSCAN
fi
touch $CURRSCAN

if [[ ! -f $LASTSCAN ]]; then
  touch $LASTSCAN
fi

# Initialize some variables
message=""
priority=-3
newline="
"

# Iterate over the "array" of interfaces and check them for associated clients
# This step needs to be separate from both the checks below because it runs in a
#   subshell. The message, and priority variables end up being local to the sub-
#   shell, which breaks the logic below.
for ifNum in $(seq 0 $ifTot); do
  eval interface=\"\$if$ifNum\"
  eval description=\"\$ifDesc$ifNum\"

  wl -i "$interface" assoclist | awk '{print $2}' | while read line ; do
    echo "$line $interface" >> $CURRSCAN
  done
done

# Check the current scan to see if any of the MACs are new since the last scan
while read line; do
  if [[ $(grep -c "$line" $LASTSCAN) -eq 0 ]]; then
    MAC="$(echo "$line" | awk '{print $1}')"
    INT="$(echo "$line" | awk '{print $2}')"
    # If we want to use the descriptive name in the associate message, we need to map it first
    for ifNum in $(seq 0 $ifTot); do
      eval interface=\"\$if$ifNum\"
      eval description=\"\$ifDesc$ifNum\"
      if [[ "$INT" == "$interface" ]]; then
        INT="$description"
      fi
    done

    if [[ $(grep -c "$MAC" $KNOWNMAC) -eq 0 ]]; then
      if [[ "$message" != "" ]]; then
        message="${message}${newline}Unknown MAC $MAC associated with $INT"
      else
        message="Unknown MAC $MAC associated with $INT"
      fi
      priority=$unknownPriority
    else
      if [[ "$message" != "" ]]; then
        message="${message}${newline}$(grep "$MAC" $KNOWNMAC | awk '{print $2}') associated with $INT"
      else
        message="$(grep "$MAC" $KNOWNMAC | awk '{print $2}') associated with $INT"
        priority=$knownPriority
      fi
    fi
  fi
done < $CURRSCAN

# Check the current scan to see if any of the MACs from the last scan don't exist anymore
while read line; do
  if [[ $(grep -c "$line" $CURRSCAN) -eq 0 ]]; then
    MAC="$(echo "$line" | awk '{print $1}')"
    INT="$(echo "$line" | awk '{print $2}')"
    # If we want to use the descriptive name in the disconnect message, we need to map it first
    for ifNum in $(seq 0 $ifTot); do
      eval interface=\"\$if$ifNum\"
      eval description=\"\$ifDesc$ifNum\"
      if [[ "$INT" == "$interface" ]]; then
        INT="$description"
      fi
    done

    if [[ $(grep -c "$MAC" $KNOWNMAC) -eq 0 ]]; then
      if [[ "$message" != "" ]]; then
        message="${message}${newline}Unknown MAC $MAC disconnected from $INT"
      else
        message="Unknown MAC $MAC disconnected from $INT"
      fi
      priority=$unknownPriority
    else
      if [[ "$message" != "" ]]; then
        message="${message}${newline}$(grep "$MAC" $KNOWNMAC | awk '{print $2}') disconnected from $INT"
      else
        message="$(grep "$MAC" $KNOWNMAC | awk '{print $2}') disconnected from $INT"
        priority=$knownPriority
      fi
    fi
  fi
done < $LASTSCAN

# Send a push notification if there's something to report
if [[ $priority -ge -2 ]]; then
  curl -s --cacert $CACERT \
    -F "token=$API_TOKEN" \
    -F "user=$USER_TOKEN" \
    -F "title=$TITLE" \
    -F "priority=$priority" \
    -F "message=$message" \
    $POST_URL
fi
