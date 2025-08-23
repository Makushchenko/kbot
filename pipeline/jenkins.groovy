pipeline {

    agent {
        label 'github-codespace'
    }

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
            defaultValue: true,
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
            when {
                expression { return !params.SKIP_TESTS }
            }            
            steps {
                echo 'TEST EXECUTION STARTED'
                sh 'make test'
            }
        }
        stage('lint') {
            when {
                expression { return !params.SKIP_LINT }
            }            
            steps {
                echo 'LINT EXECUTION STARTED'
                sh 'make lint'
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