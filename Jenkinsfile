@Library('jenkins-pipeline-library') _
import groovy.json.*

// Set the registry globally
env.REGISTRY = "europe-north1-docker.pkg.dev/iconik-infra-nonprod/iconik-nonprod-registry-docker"
env.FFMPEG_LIC_TYPE = "gpl"
env.FFMPEG_VERSION = "6.1"

def clean_workspace() {
  // Make sure we have a clean environment
    sh 'sudo chown -R jenkins: .'
    sh 'git clean -x -d -f'

  try {
    step([
      $class: 'CopyArtifact',
      projectName: env.JOB_BASE_NAME,
      fingerprintArtifacts: true,
      target: '.',
      selector: lastWithArtifacts(),
      filter: '.cache/downloads/**'
    ])
  } catch(Exception ex) {}
}

pipeline {
    agent none
    environment {
        CLOUDSDK_CONFIG = "/tmp/${env.JOB_NAME}/.gcloud"
    }
    stages {
        stage('Build') {
            failFast true
            stages {
                stage('BuildFfmpegCross') {
                    agent {
                        label 'docker'
                    }
                    steps {
                        clean_workspace()
                        sh "./makeimage.sh linux64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        sh "./makeimage.sh win64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        stash(name: "ffmpeg-sources", includes: ".cache/downloads/*")
                        sh "./build.sh linux64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        sh "./build.sh win64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        archiveArtifacts '.cache/downloads/**'
                        archiveArtifacts 'artifacts/**'
                    }
                    post {
                        cleanup {
                            sh "sudo chown -R jenkins: ${env.WORKSPACE} || /bin/true"
                            deleteDir() /* clean up our workspace */
                        }
                    }
                }
                stage('BuildMacOS') {
                    agent {
                        label 'osx-m1'
                    }
                    steps {
                        unstash(name: "ffmpeg-sources")
                        sh "./generate_deps.sh darwinarm64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        sh "./build_macos.sh darwinarm64 ${env.FFMPEG_LIC_TYPE} ${env.FFMPEG_VERSION}"
                        archiveArtifacts 'artifacts/**'
                    }
                    post {
                        cleanup {
                            sh "sudo chown -R jenkins: ${env.WORKSPACE} || /bin/true"
                            deleteDir() /* clean up our workspace */
                        }
                    }
                }
            }
        }
    }
}