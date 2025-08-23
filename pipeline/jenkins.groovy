pipeline {
    agent any
    environment {
        REPO = 'https://github.com/Makushchenko/kbot.git'
        BRANCH = 'main'
    }
    
    parameters {
        choice(
            name: 'TARGETOS',
            choices: ['linux', 'darwin', 'windows'],
            description: 'Target operating system'
        )
        choice(
            name: 'ARCH',
            choices: ['amd64', 'arm64'],
            description: 'Target architecture'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'SKIP_LINT',
            defaultValue: false,
            description: 'Skip running linter'
        )
    }    

    stages {
        stage('clone') {
            steps {
                echo 'CLONE REPOSITORY'
                git branch: "${BRANCH}", url: "${REPO}"
            }
        }
        stage('test') {
            steps {
                echo 'TEST EXECUTION STARTED'
                sh 'make test'
            }
        }
        stage('build') {
            steps {
                echo 'ARTIFACT BUILD EXECUTION STARTED'
                sh 'make build'
            }
        }
        stage('image') {
            steps {
                echo 'IMAGE BUILD EXECUTION STARTED'
                sh 'make image'
            }
        }
        stage("push") {
          steps {
            script {
              docker.withRegistry('https://ghcr.io', 'ghcr-creds') {
                sh 'make push'
              }
            }
          }
        }
    }
}