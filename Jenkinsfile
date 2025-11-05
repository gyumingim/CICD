pipeline {
    agent any
    
    environment {
        DOCKER_COMPOSE = 'docker-compose'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/gyumingim/CICD.git'
            }
        }
        
        stage('Build') {
            steps {
                script {
                    sh "${DOCKER_COMPOSE} build"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    sh "${DOCKER_COMPOSE} down"
                    sh "${DOCKER_COMPOSE} up -d"
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    sleep 5
                    sh 'curl -f http://localhost:80/ || exit 1'
                }
            }
        }
    }
    
    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
            sh "${DOCKER_COMPOSE} down"
        }
    }
}