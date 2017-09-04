# Full CI/CD Setup

This section describe how to setup a complete CI/CD environment using Jenkins.

Create the four environments :
```
oc new-project tasks-dev
oc new-project tasks-build
oc new-project tasks-test
oc new-project tasks-prod
```

Deploy a Jenkins in the BUILD project :
```
oc new-app -n tasks-build --template=jenkins-persistent --name=jenkins -p MEMORY_LIMIT=1Gi
```

__Note :__ The `jenkins-persistent` Template requires you to provision a PersistentVolume.
If there is no available PersistentVolume, the deployment will fail. In this case, have a look to
my other project : the [OpenShift-Hostpath-Provisioner](https://github.com/nmasse-itix/OpenShift-HostPath-Provisioner).

Create all other objects using the template :
```
oc process -f setup/all-in-one-template.yaml TEST_ROUTE_HOSTNAME=tasks.test.app.openshift.test PROD_ROUTE_HOSTNAME=tasks.prod.app.openshift.test > objects.json
oc create -f objects.json
```

__Notes :__
 - Keep the `objects.json` in a safe place since you will need it to cleanup the
   platform (`oc delete -f objects.json`).
 - Replace the `demo.test.app.openshift.test` and `demo.prod.app.openshift.test`
   by meaningful values for your environment. It will be your routes in
   TEST and PROD environments.

All parameters are documented here :

| Parameter Name | Required ? | Default Value | Description |
| --- | --- | --- | --- |
| TEST_ROUTE_HOSTNAME | Yes | - | The route to create in the TEST environment and which we will use to run the integration tests |
| PROD_ROUTE_HOSTNAME | Yes | - | The route to create in the PROD environment |
| GIT_REPO | No | https://github.com/nmasse-itix/openshift-tasks.git | The GIT repository to use. This will be useful if you clone this repo. |
| JBOSS_EAP_IMAGE_STREAM_TAG | No | jboss-eap70-openshift:latest | Name of the ImageStreamTag to be used for the JBoss EAP image. Change this if you plan to use your own JBoss EAP S2I image. |
| JBOSS_EAP_IMAGE_STREAM_NAMESPACE | No | openshift | The OpenShift Namespace where the Jboss EAP ImageStream resides. |
| DEV_PROJECT | No | tasks-dev | The name of the OpenShift Project to that holds the dev environment |
| BUILD_PROJECT | No | tasks-build | The name of the OpenShift Project to that holds the build environment |
| TEST_PROJECT | No | tasks-test | The name of the OpenShift Project to that holds the test environment |
| PROD_PROJECT | No | tasks-prod | The name of the OpenShift Project to that holds the prod environment |

**Then, configure Jenkins [as described here](CONFIGURE_JENKINS.md).**
