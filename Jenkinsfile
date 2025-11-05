pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'fastapi-app'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        COMPOSE_FILE = 'docker-compose.yml'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Environment Check') {
            steps {
                echo 'Checking environment...'
                sh '''
                    echo "Current directory: $(pwd)"
                    echo "Files in directory:"
                    ls -la
                    echo "Docker version:"
                    docker --version
                    echo "Docker Compose version:"
                    docker-compose --version
                '''
            }
        }
        
        stage('Stop Old Containers') {
            steps {
                echo 'Stopping old containers...'
                sh '''
                    docker-compose down || true
                    docker stop fastapi-app nginx-proxy || true
                    docker rm fastapi-app nginx-proxy || true
                '''
            }
        }
        
        stage('Clean Old Images') {
            steps {
                echo 'Cleaning up old Docker images...'
                sh '''
                    docker rmi $(docker images -q ${DOCKER_IMAGE}) || true
                    docker system prune -f || true
                '''
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building Docker image...'
                sh '''
                    docker-compose build --no-cache
                '''
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                sh '''
                    docker-compose up -d
                    echo "Waiting for services to start..."
                    sleep 10
                '''
            }
        }
        
        stage('Health Check') {
            steps {
                echo 'Performing health check...'
                script {
                    retry(5) {
                        sh '''
                            echo "Checking FastAPI container..."
                            docker ps | grep fastapi-app
                            
                            echo "Checking Nginx container..."
                            docker ps | grep nginx-proxy
                            
                            echo "Testing FastAPI health endpoint..."
                            curl -f http://localhost:80/health || exit 1
                            
                            echo "Testing root endpoint..."
                            curl -f http://localhost:80/ || exit 1
                        '''
                        sleep 5
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    echo "=== Docker Containers Status ==="
                    docker ps
                    
                    echo "=== FastAPI Logs ==="
                    docker logs --tail 20 fastapi-app
                    
                    echo "=== Nginx Logs ==="
                    docker logs --tail 20 nginx-proxy
                    
                    echo "=== Network Status ==="
                    docker network ls
                    
                    echo "=== Final Health Check ==="
                    curl -s http://localhost:80/ | jq .
                '''
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded! Application deployed successfully.'
            sh '''
                echo "Deployment completed at $(date)"
                echo "Application is running at: http://$(hostname -I | awk '{print $1}')"
            '''
        }
        
        failure {
            echo 'Pipeline failed! Rolling back...'
            sh '''
                echo "Collecting logs for debugging..."
                docker-compose logs --tail 50 || true
                
                echo "Stopping failed containers..."
                docker-compose down || true
            '''
        }
        
        always {
            echo 'Cleaning up workspace...'
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                disableDeferredWipeout: true,
                notFailBuild: true
            )
        }
    }
}