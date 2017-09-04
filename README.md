# A Jenkins pipeline for openshift-tasks

This GitHub repository is my demo that exhibit the main features of OpenShift.
Feel free to use it to spread the word.

## Description

The demo is a simple application written in Java for JBoss EAP 7. It features
a task list plus nice REST APIs. See [original repo](https://github.com/OpenShiftDemos/openshift-tasks)
for more details.

Using this, you can exhibit :
 - Self-Healing
 - Scaling
 - Source-to-Image
 - CI/CD with Blue/Green Deployment

## Setup

```
oc new-project tasks-dev
oc new-app --name=tasks jboss-eap70-openshift~https://github.com/nmasse-itix/openshift-tasks.git
oc expose service tasks
```

To cleanup your environment, use :
```
oc delete all -l app=tasks
```

Then, once confident, you can setup a full CI/CD environment as described in the [Installation Guide](doc/INSTALL.md).

## Demo Scenario

Once your environment is setup, you can have a look at the [Demo Scenario](doc/SCENARIO.md).
