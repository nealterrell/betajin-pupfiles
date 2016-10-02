#!/bin/bash

if [ ! "$(whoami)" == "jinteki" ]; then
  echo "This script needs to be run as 'jinteki' user. (use the sudo, Luke!)" >&2
  exit 1
fi

ROOT_DIR='/opt/jinteki'
REPO_DIR="${ROOT_DIR}/netrunner"
LOG_DIR="${ROOT_DIR}/logs"

LOG_FILE="${LOG_DIR}/$(date +%Y%m%d_%H%M)_build_log.txt"
START_TIME=`date +%s`

# for commands that don't respect the "no colors in piped output" rule
function stripcolors {
  sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g'
}

function logmsg {
  echo "${1}"
  echo -en "\n\n${1}\n\n" >> $LOG_FILE
}

cd $REPO_DIR

logmsg "Pulling fresh changes from GitHub..."
git fetch &>> $LOG_FILE
NEW_COMMITS=`git rev-list HEAD...origin/dev --count`

if (( $NEW_COMMITS == 0 )); do
  logmsg "No new commits in GitHub dev branch, exiting."
  exit 0
done

git pull origin dev &>> $LOG_FILE

logmsg "Updating npm packages..."
npm update &>> $LOG_FILE
npm prune &>> $LOG_FILE

logmsg "Updating bower packages..."
bower update &>> $LOG_FILE
bower prune &>> $LOG_FILE

logmsg "Pulling new cards from NRDB..."
coffee "data/fetch.coffee" &>> $LOG_FILE

logmsg "Cleaning up previous build..."
lein clean &>> $LOG_FILE

logmsg "Compiling Stylus files..."
stylus src/css/ -o resources/public/css/ 2>&1 | stripcolors >> $LOG_FILE

logmsg "Compiling ClojureScript..."
lein cljsbuild once prod 2>&1 | stripcolors >> $LOG_FILE

logmsg "Compiling Clojure..."
lein uberjar &>> $LOG_FILE

logmsg "Restarting servers..."
sudo systemctl restart jinteki-site.service
sudo systemctl restart jinteki-game.service

let TIME_TAKEN=(`date +%s`-$START_TIME)
logmsg "Build finished at $(date) in ${TIME_TAKEN} seconds"
exit 0