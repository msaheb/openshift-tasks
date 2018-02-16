#!groovy
/*
 * This Jenkins Pipeline depends on the following plugins :
 *  - Pipeline Utility Steps (https://plugins.jenkins.io/pipeline-utility-steps)
 *  - Credentials Binding (https://plugins.jenkins.io/credentials-binding)
 *
 * This pipeline accepts the following parameters :
 *  - OPENSHIFT_IMAGE_STREAM: The ImageStream name to use to tag the built images
 *  - OPENSHIFT_BUILD_CONFIG: The BuildConfig name to use
 *  - OPENSHIFT_SERVICE: The Service object to update (either green or blue)
 *  - OPENSHIFT_DEPLOYMENT_CONFIG: The DeploymentConfig name to use
 *  - OPENSHIFT_BUILD_PROJECT: The OpenShift project in which builds are run
 *  - OPENSHIFT_TEST_ENVIRONMENT: The OpenShift project in which we will deploy the test version
 *  - OPENSHIFT_PROD_ENVIRONMENT: The OpenShift project in which we will deploy the prod version
 *  - OPENSHIFT_TEST_URL: The App URL in the test environment (to run the integration tests)
 *  - NEXUS_REPO_URL: The URL of your Nexus repository. Something like http://<nexushostname>/repository/maven-snapshots/
 *  - NEXUS_MIRROR_URL: The URL of your Nexus public mirror. Something like http://<nexushostname>/repository/maven-all-public/
 *  - NEXUS_USER: A nexus user allowed to push your software. Usually 'admin'.
 *  - NEXUS_PASSWORD: The password of the nexus user. Usually 'admin123'.
 */

// Run this node on a Maven Slave
// Maven Slaves have JDK and Maven already installed
node('maven') {
  def mvn = "mvn -s mvn-settings.xml"

  stage('Checkout Source') {
    // Get Source Code from SCM (Git) as configured in the Jenkins Project
    // Next line for inline script, "checkout scm" for Jenkinsfile from GIT
    //git url: "https://github.com/nmasse-itix/openshift-tasks.git"
    checkout scm

    // Generate the maven settings file from parameters
    writeFile file: 'mvn-settings.xml', text: """
<?xml version="1.0"?>
<settings>
  <mirrors>
    <mirror>
      <id>Nexus</id>
      <name>Nexus Public Mirror</name>
      <url>${params.NEXUS_MIRROR_URL}</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
  <servers>
    <server>
      <id>nexus</id>
      <username>${params.NEXUS_USER}</username>
      <password>${params.NEXUS_PASSWORD}</password>
    </server>
  </servers>
</settings>
"""
  }

  // The following variables need to be defined at the top level and not inside
  // the scope of a stage - otherwise they would not be accessible from other stages.
  // Extract version and other properties from the pom.xml
  def pom            = readMavenPom file: 'pom.xml'
  def packageName    = pom.name
  def version        = pom.version
  def newVersion     = "${version}-${BUILD_NUMBER}"
  def artifactId     = pom.artifactId
  def groupId        = pom.groupId

  // Using Maven build the war file
  // Do not run tests in this step
  stage('Build war') {
    sh "${mvn} clean install -DskipTests=true"
  }

  // Using Maven run the unit tests
  stage('Unit Tests') {
    sh "${mvn} test"
  }

  // Publish the latest war file to Nexus. This needs to go into <nexusurl>/repository/releases.
  // Using the properties from the pom.xml file construct a filename that includes the version number from the pom.xml file
  stage('Publish to Nexus') {
    sh "${mvn} deploy -DskipTests=true -DaltDeploymentRepository=nexus::default::${params.NEXUS_REPO_URL}"
  }

  // Build the OpenShift Image in OpenShift using the artifacts from Nexus
  // Also tag the image
  stage('Build OpenShift Image') {
    // Determine the war filename that we need to use later in the process
    String warFileName = "${groupId}.${artifactId}"
    warFileName = warFileName.replace('.', '/')
    def WAR_FILE_URL = "${params.NEXUS_REPO_URL}/${warFileName}/${version}/${artifactId}-${version}.war"
    echo "Will use WAR at ${WAR_FILE_URL}"

    // Trigger an OpenShift build in the build environment
    openshiftBuild bldCfg: params.OPENSHIFT_BUILD_CONFIG, checkForTriggeredDeployments: 'false',
                   namespace: params.OPENSHIFT_BUILD_PROJECT, showBuildLogs: 'true',
                   verbose: 'false', waitTime: '', waitUnit: 'sec',
                   env: [ [ name: 'WAR_FILE_URL', value: "${WAR_FILE_URL}" ] ]


    // Tag the new build
    openshiftTag alias: 'false', destStream: params.OPENSHIFT_IMAGE_STREAM, destTag: "${newVersion}",
                 destinationNamespace: params.OPENSHIFT_BUILD_PROJECT, namespace: params.OPENSHIFT_BUILD_PROJECT,
                 srcStream: params.OPENSHIFT_IMAGE_STREAM, srcTag: 'latest', verbose: 'false'
  }


  // Deploy the built image to the Test Environment.
  stage('Deploy to Test') {
    // Tag the new build as "ready-for-testing"
    openshiftTag alias: 'false', destStream: params.OPENSHIFT_IMAGE_STREAM, srcTag: "${newVersion}",
                 destinationNamespace: params.OPENSHIFT_TEST_ENVIRONMENT, namespace: params.OPENSHIFT_BUILD_PROJECT,
                 srcStream: params.OPENSHIFT_IMAGE_STREAM, destTag: 'ready-for-testing', verbose: 'false'

    // Trigger a new deployment
    openshiftDeploy deploymentConfig: params.OPENSHIFT_DEPLOYMENT_CONFIG, namespace: params.OPENSHIFT_TEST_ENVIRONMENT
  }


  // Run some integration tests.
  // Once the tests succeed tag the image
  stage('Integration Test') {
    // Run integration tests that are in the GIT repo
    sh "tests/run-integration-tests.sh '${params.OPENSHIFT_TEST_URL}'"

    // Tag the new build as "ready-for-prod"
    openshiftTag alias: 'false', destStream: params.OPENSHIFT_IMAGE_STREAM, srcTag: "${newVersion}",
                 destinationNamespace: params.OPENSHIFT_PROD_ENVIRONMENT, namespace: params.OPENSHIFT_BUILD_PROJECT,
                 srcStream: params.OPENSHIFT_IMAGE_STREAM, destTag: 'ready-for-prod', verbose: 'false'
  }

  // Blue/Green Deployment into Production
  // First step : deploy the new version but do not activate it !
  stage('Deploy to Production') {
    // Yes, this is mandatory for the next command to succeed. Don't know why...
    sh "oc project ${params.OPENSHIFT_PROD_ENVIRONMENT}"

    // Extract the route target (xxx-green or xxx-blue)
    // This will be used by getCurrentTarget and getNewTarget methods
    sh "oc get service ${params.OPENSHIFT_SERVICE} -n ${params.OPENSHIFT_PROD_ENVIRONMENT} -o template --template='{{ .spec.selector.color }}' > route-target"

    // Flip/flop target (green goes blue and vice versa)
    def newTarget = getNewTarget()

    // Trigger a new deployment
    openshiftDeploy deploymentConfig: "${params.OPENSHIFT_DEPLOYMENT_CONFIG}-${newTarget}", namespace: params.OPENSHIFT_PROD_ENVIRONMENT
    openshiftVerifyDeployment deploymentConfig: "${params.OPENSHIFT_DEPLOYMENT_CONFIG}-${newTarget}", namespace: params.OPENSHIFT_PROD_ENVIRONMENT
  }

  // Once approved (input step) switch production over to the new version.
  stage('Switch over to new Version') {
    // Determine which is of green or blue is active
    def newTarget = getNewTarget()
    def currentTarget = getCurrentTarget()

    // Wait for administrator confirmation
    input "Switch Production from ${currentTarget} to ${newTarget} ?"

    // Switch blue/green
    sh "oc patch -n ${params.OPENSHIFT_PROD_ENVIRONMENT} service/${params.OPENSHIFT_SERVICE} --patch '{\"spec\":{\"selector\":{\"color\":\"${newTarget}\"}}}'"
  }

}

// Get the current target of the OpenShift production route
// Note: the route-target file is created earlier by the "oc get route" command
def getCurrentTarget() {
  def currentTarget = readFile 'route-target'
  return currentTarget
}

// Flip/flop target (green goes blue and vice versa)
def getNewTarget() {
  def currentTarget = getCurrentTarget()
  def newTarget = ""
  if (currentTarget == "blue") {
      newTarget = "green"
  } else if (currentTarget == "green") {
      newTarget = "blue"
  } else {
    echo "OOPS, wrong target"
  }
  return newTarget
}
