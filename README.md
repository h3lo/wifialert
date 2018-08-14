# wifialert
dd-wrt busybox script to push notifications when wireless clients associate/disconnect

Most of the description is in the header for the script... so I just copied it here for now. Set a cron job on your DD-WRT router in order to kick off the script every minute. On the Administration tab, under Cron, add the following to the text box:
* * * * * root /jffs/alertwifi.sh >/tmp/pushover.out 2>&1

 This script was written for DD-WRT to send push notifications whenever wifi
  clients connect or disconnect. It sends a single push notification with
  the changes since the last run. Although this can probably be modified to
  send notifications in some other way, this version requres Pushover.net.

 Set the variables in the top section to include your Pushover.net tokens,
  as well as a few other configurables. For the rest of the variables, see
  the comments immediately preceeding them for instructions on how to set
  them.

 In addition to the variables set here, the KNOWNMAC file should contain
  a list of MAC addresses, and descriptions. This version can't handle
  descriptions with spaces, so use _ or some other alternative. See the
  knownmac-example file in the repo for an example. If you have no known MAC
  addresses, you still must create the file, but it can be empty.

 Written by Danny Mann
