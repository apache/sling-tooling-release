#!/bin/sh

STAGING=${1}
DOWNLOAD=${2:-/tmp/sling-staging}
mkdir ${DOWNLOAD} 2>/dev/null

if [ -z "${STAGING}" -o ! -d "${DOWNLOAD}" ]
then
 echo "Usage: check_staged_release.sh <staging-number> [temp-directory]"
 exit
fi

if [ ! -e "${DOWNLOAD}/${STAGING}" ]
then
 echo "################################################################################"
 echo "                           DOWNLOAD STAGED REPOSITORY                           "
 echo "################################################################################"

 wget -e "robots=off" --wait 1 -nv -r -np "--reject=html,index.html.tmp" "--follow-tags=" \
  -P "${DOWNLOAD}/${STAGING}" -nH "--cut-dirs=3" \
  "https://repository.apache.org/content/repositories/orgapachesling-${STAGING}/org/apache/sling/"

else
 echo "################################################################################"
 echo "                       USING EXISTING STAGED REPOSITORY                         "
 echo "################################################################################"
 echo "${DOWNLOAD}/${STAGING}"
fi

echo "################################################################################"
echo "                          CHECK SIGNATURES AND DIGESTS                          "
echo "################################################################################"

for i in `find "${DOWNLOAD}/${STAGING}" -type f | grep -v '\.\(asc\|sha1\|md5\|log\)$'`
do
 f=`echo $i | sed 's/\.asc$//'`
 echo "$f"
 VERIFY_RESULT_FILE="$f.asc.verify-result.log"
 gpg --verify $f.asc 2> $VERIFY_RESULT_FILE
 VERIFY_RESULT=$?
 if grep -q "Can't check signature: No public key" "$VERIFY_RESULT_FILE"; then
   KEYID=$(cat $VERIFY_RESULT_FILE | tr '\n' ' ' | sed 's/.*using RSA key \([A-Z0-9]\{1,\}\).*/\1/') 
   KEYSERVER="pool.sks-keyservers.net"
   echo "Retrieving key $KEYID from $KEYSERVER"
   gpg --keyserver $KEYSERVER --recv-keys $KEYID
   echo "Retesting $f.asc"
   gpg --verify $f.asc 2> $VERIFY_RESULT_FILE
   VERIFY_RESULT=$?
 fi
 if [ "$VERIFY_RESULT" = "0" ]; then CHKSUM="GOOD"; else CHKSUM="BAD!!!!!!!!"; fi
 if [ ! -f "$f.asc" ]; then CHKSUM="----"; fi
 echo "  gpg:  ${CHKSUM}"

 for tp in md5 sha1
 do
   if [ ! -f "$f.$tp" ]
   then
     CHKSUM="----"
   else
     A="`cat $f.$tp 2>/dev/null`"
     B="`openssl $tp < $f 2>/dev/null | sed 's/.*= *//' `"
     if [ "$A" = "$B" ]; then CHKSUM="GOOD (`cat $f.$tp`)"; else CHKSUM="BAD!! : $A not equal to $B"; fi
   fi
   echo "  $tp : ${CHKSUM}"
 done

done

if [ -z "${CHKSUM}" ]; then echo "WARNING: no files found!"; fi

echo "################################################################################"


