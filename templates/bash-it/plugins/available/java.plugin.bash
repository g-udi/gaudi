cite about-plugin
about-plugin 'Java and JAR helper functions'

function jar_manifest {
  about "extracts the specified JAR file's MANIFEST file and prints it to stdout"
  group 'java'
  param '1: JAR file to extract the MANIFEST from'
  example 'jar_manifest lib/foo.jar'

  unzip -c $1 META-INF/MANIFEST.MF
}

function setjdk() {
  about "Change the JAVA SDK http://www.jayway.com/2014/01/15/how-to-switch-jdk-version-on-mac-os-x-maverick/"
  group 'java'

  if [ $# -ne 0 ]; then
   removeFromPath '/System/Library/Frameworks/JavaVM.framework/Home/bin'
   if [ -n "${JAVA_HOME+x}" ]; then
    removeFromPath $JAVA_HOME
   fi
   export JAVA_HOME=`/usr/libexec/java_home -v $@`
   export PATH=$JAVA_HOME/bin:$PATH
  fi
 }
 function removeFromPath() {
  export PATH=$(echo $PATH | sed -E -e "s;:$1;;" -e "s;$1:?;;")
 }