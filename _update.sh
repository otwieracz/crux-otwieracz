#!/bin/bash

REMOTEFILE="REMOTE"
REMOTELOCKFILE="REMOTE.lock"
REMOTELOCKFILETMP="REMOTE.lock.tmp"
LOGFILE="REMOTE.log"

# utilsa
# from http://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#12973694
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    echo -n "$var"
}

# Extract dependenceis from Pkgfile
dependencies () {
	pkg=${1}
	pkgfile="${1}/Pkgfile"
	[[ -f "${pkgfile}" ]] && {
		deps=$(cat "${pkgfile}" | grep -i Depend | egrep -o ':.*$' | tr -d ':.')
		echo $deps
	} || {
		return 1
	}
}

fetch_httpup () {
	pkg=${1}
	url=${2}
	httpup sync "${url}#${pkg}" "${pkg}" &> "${LOGFILE}" && test -f "${pkg}/Pkgfile" || (rm -rf "${pkg}" && return 1) 
}

fetch_rsync () {
	pkg=${1}
	url=${2}
	rsync -aqz "${url}/${pkg}/" "${pkg}" &> "${LOGFILE}" && test -f "${pkg}/Pkgfile" || (rm -rf "${pkg}" && return 1) 
}

fetch () {
	kind=$(trim ${1})
	pkg=$(trim ${2})
	remote=$(trim ${3})
	[[ -n ${kind} ]] && [[ -n ${pkg} ]] && [[ -n ${remote} ]] && {
		echo -n "=====> fetching remote ${pkg}... "
		[[ -d ${pkg} ]] && ! egrep -q "^${pkg}" ${REMOTELOCKFILETMP} && isremote="false" || isremote="true"
		[[ ${isremote} == "true" ]] && {
			fetch_${kind} "${pkg}" "${remote}" && {
                echo "${pkg} <- ${kind} <- ${remote}" >> "${REMOTELOCKFILE}" 
            } || {
                echo -n "not found... "
            }
		} || {
			echo -n "local... "
		}
		deps=$(dependencies ${2})
		[[ -n "${deps}" ]] && echo "depends on ${deps}" && (for dep in ${deps}; do fetch "${kind}" "${dep}" "${remote}"; done) || echo "done."
	}
}

fetch_remote () {
	cmd=$1
	pkg=$(echo "${1}" | awk -F '<-' '{ print $1 }' | tr -d ' ')
	kind=$(echo "${1}" | awk -F '<-' '{ print $2 }' | tr -d ' ')
	remote=$(trim $(echo "${1}" | awk -F '<-' '{ print $3 }'))

	fetch "${kind}" "${pkg}" "${remote}"
}

echo "===> fetching remotes"
cp -f ${REMOTELOCKFILE} ${REMOTELOCKFILETMP}
echo "# Remote dependencies" > "${REMOTELOCKFILE}"
while IFS= read -r cmd; do
	fetch_remote "${cmd}"
done < "${REMOTEFILE}"
echo
echo "===> done"
rm ${REMOTELOCKFILETMP}

echo "===> refreshing local"
for pkgdir in */; do
	pkg=$(trim $(basename ${pkgdir}))
	echo -n "=====> refreshing ${pkg}... "
	egrep -q "^${pkg}" "${REMOTELOCKFILE}" && echo "is remote" || ((cd "${pkgdir}"; /usr/local/bin/pkgmk -d &>/dev/null && echo -n "$i ok... ") && (cd "${pkgdir}"; /usr/local/bin/pkgmk -us) && prtverify -m clean-repo "${pkgdir}" || echo "${pkg} failed!")
done

httpup-repgen

