#!/bin/bash -e

VERSION=12
WORKDIR=out
ALLOW_SNAPSHOT=0

# create work directory
if [ ! -d $WORKDIR ] ; then
    mkdir -p $WORKDIR
fi

# get bundle list
if [ -f $WORKDIR/feature.json ] ; then
    echo "feature.json already present, not downloading";
else
    echo "Downloading bundle list for Sling $VERSION (oak-tar variant)"
    wget  https://repo1.maven.org/maven2/org/apache/sling/org.apache.sling.starter/$VERSION/org.apache.sling.starter-$VERSION-oak_tar.slingosgifeature -O $WORKDIR/feature.json
fi

# extract <artifactId>-<version> from feature file
artifacts=$(cat $WORKDIR/feature.json | jq -r '.bundles[].id | select(startswith("org.apache.sling"))' | awk -F ':' '{ print $2 ":" $3 }')

# add additional artifacts which are not part of the launchpad
# https://issues.apache.org/jira/browse/SLING-6766
artifacts+=" org.apache.sling.adapter.annotations:2.0.0"
artifacts+=" org.apache.sling.servlets.annotations:1.2.6"

# checkout tags
for artifact in $artifacts; do
    artifact_name=$(echo $artifact | sed 's/:.*//')
    artifact_version=$(echo $artifact | sed 's/.*://')
    branch_name="${artifact_name}-${artifact_version}"
    artifact_dir="sling-${artifact_name}-${artifact_version}"
    artifact_repo=$(echo $artifact_name | tr '.' '-')
    artifact_repo="sling-${artifact_repo}"

    # - don't document Slingshot sample or Sling Starter Content
    # - threaddump was renamed and tag history is lost
    # - exclude deprecated Sling Health Check bundles, which are only present for integration test of the support bundle
    if [[ ${artifact_name} == *slingshot
        || ${artifact_name} == "org.apache.sling.starter.content"
        || ${artifact_name} = "org.apache.sling.extensions.threaddump" 
        || ${artifact_name} = "org.apache.sling.hc.api" 
        || ${artifact_name} = "org.apache.sling.hc.support" ]]; then
        continue;
    fi

    if [ -d $WORKDIR/$artifact_dir ] ; then
        echo "Not checking out $artifact_dir, already present";
    else
        if [[ "$artifact_version" == *-SNAPSHOT ]]; then
            if [ $ALLOW_SNAPSHOT == 0 ] ; then
                echo "Failing build due to SNAPSHOT artifact $artifact";
                exit 1;
            else
                continue
            fi
        fi
        echo "Exporting $artifact from source control"
        git -c advice.detachedHead=false clone https://github.com/apache/${artifact_repo} --branch ${branch_name} ${WORKDIR}/${artifact_dir}
        if [ -f patches/$artifact ]; then
            echo "Applying patch"
            pushd $WORKDIR/$artifact_dir
            patch -p0 < ../../patches/$artifact_dir
            popd
        fi
    fi
done

# generate dummy pom.xml

echo "Generating pom.xml"
pushd $WORKDIR

POM=pom.xml
echo "<project>" > $POM
echo "  <modelVersion>4.0.0</modelVersion>" >> $POM
echo "  <groupId>org.apache.sling</groupId>" >> $POM
echo "  <artifactId>org.apache.sling.javadoc-builder</artifactId>" >> $POM
echo "  <packaging>pom</packaging>" >> $POM
echo "  <version>$VERSION</version>" >> $POM
echo >> $POM
echo "  <parent>" >> $POM
echo "    <groupId>org.apache</groupId>" >> $POM
echo "    <artifactId>apache</artifactId>" >> $POM
echo "    <version>33</version>" >> $POM
echo "  </parent>" >> $POM
echo >> $POM
echo "  <name>Apache Sling</name>" >> $POM
echo >> $POM
echo "  <properties>" >> $POM
echo "    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>" >> $POM
echo "    <maven.compiler.target>11</maven.compiler.target>" >> $POM
echo "  </properties>" >> $POM
echo >> $POM
echo " <modules> " >> $POM

for artifact_dir in $(find . -type d -maxdepth 1 -name '*sling*'); do
    echo "    <module>$artifact_dir</module>" >> $POM
done

echo "  </modules>" >> $POM
echo "</project>" >> $POM
popd

if [ ! -f $WORKDIR/src/main/javadoc/overview.html ] ; then
    echo "Downloading javadoc overview file"
    mkdir -p $WORKDIR/src/main/javadoc
    cp javadoc/overview.html $WORKDIR/src/main/javadoc/overview.html
fi

# generate javadoc

echo "Starting javadoc generation"

pushd $WORKDIR
mvn -DexcludePackageNames="*.impl:*.internal:*.jsp:sun.misc:*.juli:*.testservices:*.integrationtest:*.maven:javax.*:org.osgi.*" \
         org.apache.maven.plugins:maven-javadoc-plugin:3.11.2:aggregate -Dnotimestamp=true -Dignore.javadocjdk=true -Ddoclint=none
popd

echo "Generated Javadocs can be found in $WORKDIR/target/site/apidocs/"
