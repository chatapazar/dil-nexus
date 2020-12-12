# dil-nexus
git clone this repo
cd dil-nexus

oc login with admin

./setup_nexus.sh

console --> openshift project "nexus"
login nexus with admin and password from nexus_password.txt
change password
set enable anonymous access

change camel-k-maven-setiings.xml --> search with route from previous step
example
route of nexus --> "https://nexus-nexus.apps.cluster-bkk-5214.bkk-5214.sandbox210.opentlc.com/"
replace <url>http://nexus:8081/repository/maven-public/</url>
with <url>https://nexus-nexus.apps.cluster-bkk-5214.bkk-5214.sandbox210.opentlc.com/repository/maven-public/</url>

oc create configmap -n nexus camel-k-maven-settings --from-file=settings.xml=camel-k-maven-settings.xml

oc -n nexus apply -f eda-sample.yaml

after camel-k start, use below command
oc patch -n nexus integration/test-events --patch $'spec:\n replicas: 0' --type merge

loop user1 --> userN
oc delete configmap -n user1 example-maven-settings
oc create configmap -n user1 example-maven-settings --from-file=settings.xml=camel-k-maven-settings.xml

COUNT=1
MAX=4
while [ $COUNT -lt $MAX ]
do
   oc delete configmap -n user${COUNT} example-maven-settings
   oc create configmap -n user${COUNT} example-maven-settings --from-file=settings.xml=camel-k-maven-settings.xml
   COUNT=$(expr $COUNT + 1)
done