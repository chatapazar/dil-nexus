#!/bin/sh
START_BUILD=$(date +%s)
#NEXUS_VERSION=3.18.1
export NEXUS_VERSION=latest
export CICD_PROJECT=nexus
NEXUS_PVC_SIZE="8Gi"
function check_pod(){
    sleep 15
    READY="NO"
    while [ $READY = "NO" ];
    do
        clear
        #echo "Wait for $1 pod to sucessfully start"
        MESSAGE=$(oc get pods  -n ${CICD_PROJECT}| grep $1 | grep -v deploy)
        STATUS=$(echo ${MESSAGE}| awk '{print $2}')
        if [ $(echo -n ${MESSAGE} | wc -c) -gt 0 ];
            then
            if [ ${STATUS} = "1/1" ];
            then
                READY="YES"
            else 
                echo "Current Status: ${MESSAGE}"
                cat $1.txt
                sleep 3
                clear
                echo "Current Status: ${MESSAGE}"
                cat wait.txt
                sleep 2

            fi
        else
            oc get pods -n ${CICD_PROJECT} | grep $1
            sleep 5
        fi
    done
}
oc new-project ${CICD_PROJECT}  --display-name="Nexus"
oc new-app sonatype/nexus3:${NEXUS_VERSION} --name=nexus -n ${CICD_PROJECT} 
oc create route edge nexus --service=nexus --port=8081
oc rollout pause dc nexus -n ${CICD_PROJECT}
oc patch dc nexus --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${CICD_PROJECT}
oc set resources dc nexus --limits=memory=4Gi,cpu=4 --requests=memory=4Gi,cpu=4 -n ${CICD_PROJECT}
oc set volume dc/nexus --remove --confirm -n ${CICD_PROJECT}
oc set volume dc/nexus --add --overwrite --name=nexus-pv-1 \
--mount-path=/nexus-data/ --type persistentVolumeClaim \
--claim-name=nexus-pvc --claim-size=${NEXUS_PVC_SIZE} -n ${CICD_PROJECT}
oc set probe dc/nexus --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok -n ${CICD_PROJECT}
oc set probe dc/nexus --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/ -n ${CICD_PROJECT}
oc label dc nexus app.kubernetes.io/part-of=Registry -n ${CICD_PROJECT}
oc rollout resume dc nexus -n ${CICD_PROJECT}
check_pod "nexus"
export NEXUS_POD=$(oc get pods | grep nexus | grep -v deploy | awk '{print $1}')
oc cp $NEXUS_POD:/nexus-data/etc/nexus.properties nexus.properties
echo nexus.scripts.allowCreation=true >>  nexus.properties
oc cp nexus.properties $NEXUS_POD:/nexus-data/etc/nexus.properties
rm -f nexus.properties
oc delete pod $NEXUS_POD
echo "Wait 10 sec..."
sleep 10
check_pod "nexus"
export NEXUS_POD=$(oc get pods | grep nexus | grep -v deploy | awk '{print $1}')
export NEXUS_PASSWORD=$(oc exec $NEXUS_POD -- cat /nexus-data/admin.password)
END_BUILD=$(date +%s)
BUILD_TIME=$(expr ${END_BUILD} - ${START_BUILD})
clear
echo "NEXUS URL = $(oc get route nexus -n ${CICD_PROJECT} -o jsonpath='{.spec.host}') "
echo "NEXUS Password = ${NEXUS_PASSWORD}"
echo "Nexus password is stored at nexus_password.txt"
echo ${NEXUS_PASSWORD} > nexus_password.txt
echo "Record this password and change it via web console"
echo "Elasped time to build is $(expr ${BUILD_TIME} / 60 ) minutes"