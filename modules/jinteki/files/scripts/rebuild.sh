#!/bin/bash

if [ "$(whoami)" != "jinteki" ]; then
  echo "This script needs to be run as 'jinteki' user. (use the sudo, Luke!)" >&2
  exit 1
fi

root_dir='/opt/jinteki'
repo_dir="${root_dir}/netrunner"
log_dir="${root_dir}/logs"
pidfile_path="${root_dir}/rebuild.pid"

log_file="${log_dir}/$(date +%Y%m%d_%H%M)_build_log.txt"
start_time=`date +%s`

function print_help {
  echo -e "$0 - pull latest code changes for jinteki.net locally and recompile it if needed"
  echo -e "     Must be run as the user 'jinteki'."
  echo -e "  Syntax: $0 [OPTIONS]"
  echo -e "  Options:"
  echo -e "    -h, --help - print this message and exit"
  echo -e "    -u, --update - update the dependencies instead of just making sure they're installed"
  echo -e "    -f, --full - force full recompilation even if the binaries and/or code seems up-to-date"
  echo -e "    -k, --kill - if another rebuild is running in the background, don't stop, kill it instead"
}

full_rebuild=false
kill_process=false
update_deps=false

while [[ $# -gt 1 ]]; do
  case $1 in
    '-f'|'--full')
      full_rebuild=true
      ;;
    '-k'|'--kill')
      kill_process=true
      ;;
    '-h'|'--help')
      print_help
      exit 0
      ;;
    '-u'|'--update')
      update_deps=true
      ;;
    *)
      break
      ;;
  esac
  shift
done

# for commands that don't respect the "no colors in piped output" rule
function stripcolors {
  sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g'
}

function logmsg {
  echo "${1}"
  echo -en "\n\n${1}\n\n" >> $log_file
}

if [ -f $pidfile_path ]; then
  previous_pid=$(cat $pidfile_path)
  if [ "${kill_process}" = true ]; then
    logmsg "Process already running, with pid ${previous_pid}, killing..."
    kill $previous_pid
    rm $pidfile_path
  else
    logmsg "Process already running with pid ${previous_pid}, exiting..."
    exit 1
  fi
fi

# from that point on we have to delete our own pidfile on exit
function cleanup_pidfile {
  rm $pidfile_path
}

echo $$ > $pidfile_path
trap cleanup_pidfile EXIT

cd $repo_dir

logmsg "Pulling fresh changes from GitHub..."
git fetch &>> $log_file
new_commits=`git rev-list HEAD...origin/dev --count`

if (( $new_commits == 0 )) && [ "${full_rebuild}" != true ]; then
  logmsg "No new commits in GitHub dev branch, exiting."
  exit 0
fi

git pull origin dev &>> $log_file
logmsg "Current commit:"
git log -1 &>> $log_file

if [ "${update_deps}" = true ]; then
  logmsg "Updating npm and bower packages..."
  npm update &>> $log_file
  bower update &>> $log_file
else
  logmsg "Installing npm and bower packages..."
  npm install &>> $log_file
  bower install &>> $log_file
fi
# prune only for full rebuild
if [ "${full_rebuild}" = true ]; then
  logmsg "Pruning npm and bower packages..."
  npm prune &>> $log_file
  bower prune &>> $log_file
fi

logmsg "Pulling new cards from NRDB..."
coffee "data/fetch.coffee" &>> $log_file

if [ "${full_rebuild}" ]; then
  logmsg "Cleaning up previous build..."
  lein clean &>> $log_file
fi

logmsg "Compiling Stylus files..."
stylus src/css/ -o resources/public/css/ 2>&1 | stripcolors >> $log_file

logmsg "Compiling ClojureScript..."
lein cljsbuild once prod 2>&1 | stripcolors >> $log_file

logmsg "Compiling Clojure..."
lein uberjar &>> $log_file

logmsg "Restarting servers..."
sudo systemctl restart jinteki-site.service
sudo systemctl restart jinteki-game.service

let time_taken=(`date +%s`-$start_time)
logmsg "Build finished at $(date) in ${time_taken} seconds"
rm $pidfile_path
exit 0
