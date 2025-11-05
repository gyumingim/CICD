# Jenkins CI/CD 최소 설정 프로젝트

노트북 Jenkins → Docker Hub → 원격 서버 배포 플로우

## 📁 프로젝트 구조

```
project/
├── frontend/
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
├── backend/
│   ├── Dockerfile
│   ├── app.js
│   └── package.json
├── server/
│   └── docker-compose.yml
├── Jenkinsfile-frontend
├── Jenkinsfile-backend
└── README.md
```

---

## 🚀 1단계: 로컬(노트북) Jenkins 설치

### Docker로 Jenkins 실행

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### 초기 비밀번호 확인

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

브라우저에서 `http://localhost:8080` 접속 후 초기 설정 완료

### 필수 플러그인 설치

Jenkins 관리 → 플러그인 관리에서 설치:
- **Docker Pipeline**
- **SSH Agent**
- **Git**

---

## 🔑 2단계: Jenkins Credentials 설정

Jenkins 관리 → Credentials → System → Global credentials 추가

### 1) Docker Hub 로그인 정보

- Kind: `Username with password`
- ID: `dockerhub-credentials`
- Username: Docker Hub 아이디
- Password: Docker Hub 비밀번호

### 2) 서버 SSH 키

- Kind: `SSH Username with private key`
- ID: `server-ssh-key`
- Username: 서버 SSH 유저명 (예: ubuntu)
- Private Key: 노트북의 `~/.ssh/id_rsa` 내용 복사

---

## 📦 3단계: 프로젝트 파일 생성

### frontend/Dockerfile

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

### frontend/index.html

```html
<!DOCTYPE html>
<html>
<head>
    <title>Frontend</title>
</head>
<body>
    <h1>Hello from Frontend v1.0</h1>
</body>
</html>
```

### frontend/nginx.conf

```nginx
events {}
http {
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        location /api {
            proxy_pass http://backend:3000;
        }
    }
}
```

### backend/Dockerfile

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY app.js .
EXPOSE 3000
CMD ["node", "app.js"]
```

### backend/package.json

```json
{
  "name": "backend",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

### backend/app.js

```javascript
const express = require('express');
const app = express();

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', version: '1.0' });
});

app.listen(3000, () => {
    console.log('Backend running on port 3000');
});
```

### Jenkinsfile-frontend

```groovy
pipeline {
    agent any
    
    environment {
        DOCKERHUB_REPO = 'your-dockerhub-username/frontend'
        IMAGE_TAG = "${BUILD_NUMBER}"
        SERVER_HOST = 'your-server-ip'
    }
    
    stages {
        stage('Test') {
            steps {
                echo 'Running frontend tests...'
                // 실제 테스트 명령어 추가 (예: npm test)
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dir('frontend') {
                        docker.build("${DOCKERHUB_REPO}:${IMAGE_TAG}")
                        docker.build("${DOCKERHUB_REPO}:latest")
                    }
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        docker.image("${DOCKERHUB_REPO}:${IMAGE_TAG}").push()
                        docker.image("${DOCKERHUB_REPO}:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to Server') {
            steps {
                sshagent(['server-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_HOST} '
                            cd /home/ubuntu/app &&
                            docker pull ${DOCKERHUB_REPO}:latest &&
                            docker-compose up -d frontend
                        '
                    """
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f'
        }
    }
}
```

### Jenkinsfile-backend

```groovy
pipeline {
    agent any
    
    environment {
        DOCKERHUB_REPO = 'your-dockerhub-username/backend'
        IMAGE_TAG = "${BUILD_NUMBER}"
        SERVER_HOST = 'your-server-ip'
    }
    
    stages {
        stage('Test') {
            steps {
                echo 'Running backend tests...'
                // 실제 테스트 명령어 추가
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    dir('backend') {
                        docker.build("${DOCKERHUB_REPO}:${IMAGE_TAG}")
                        docker.build("${DOCKERHUB_REPO}:latest")
                    }
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        docker.image("${DOCKERHUB_REPO}:${IMAGE_TAG}").push()
                        docker.image("${DOCKERHUB_REPO}:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to Server') {
            steps {
                sshagent(['server-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ubuntu@${SERVER_HOST} '
                            cd /home/ubuntu/app &&
                            docker pull ${DOCKERHUB_REPO}:latest &&
                            docker-compose up -d backend
                        '
                    """
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f'
        }
    }
}
```

### server/docker-compose.yml

```yaml
version: '3.8'

services:
  frontend:
    image: your-dockerhub-username/frontend:latest
    container_name: frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    restart: unless-stopped

  backend:
    image: your-dockerhub-username/backend:latest
    container_name: backend
    ports:
      - "3000:3000"
    restart: unless-stopped
```

---

## 🖥️ 4단계: 서버 설정

### 서버에 Docker 설치

```bash
# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Docker Compose 설치
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 프로젝트 디렉토리 생성

```bash
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
```

### docker-compose.yml 업로드

위의 `server/docker-compose.yml` 파일을 서버의 `/home/ubuntu/app/docker-compose.yml`로 복사

### Docker Hub 로그인

```bash
docker login
# Docker Hub 아이디/비밀번호 입력
```

---

## 🔧 5단계: Jenkins 파이프라인 생성

### 프론트엔드 파이프라인

1. Jenkins 대시보드 → "새로운 Item"
2. 이름: `frontend-pipeline`
3. 타입: `Pipeline` 선택
4. Pipeline 섹션에서:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: GitHub 레포 URL
   - Script Path: `Jenkinsfile-frontend`

### 백엔드 파이프라인

동일하게 `backend-pipeline` 생성, Script Path만 `Jenkinsfile-backend`로 변경

---

## ✅ 6단계: 실행 테스트

### 1) Jenkinsfile 수정

각 Jenkinsfile에서 다음 값 변경:
- `your-dockerhub-username` → 실제 Docker Hub 아이디
- `your-server-ip` → 실제 서버 IP

### 2) GitHub에 푸시

```bash
git add .
git commit -m "Initial setup"
git push origin main
```

### 3) Jenkins에서 빌드 실행

- 프론트엔드 파이프라인: "Build Now" 클릭
- 백엔드 파이프라인: "Build Now" 클릭

### 4) 서버 확인

```bash
# 서버에서
docker ps
curl http://localhost
curl http://localhost:3000/api/health
```

---

## 🎯 전체 플로우 요약

```
1. 노트북에서 코드 수정 후 git push
2. Jenkins에서 수동으로 "Build Now" 클릭
3. Jenkins가 테스트 실행
4. Docker 이미지 빌드
5. Docker Hub에 push
6. SSH로 서버 접속
7. 서버에서 docker pull
8. docker-compose up -d로 재시작
```

---

## 🔍 트러블슈팅

### Jenkins에서 Docker 명령어 실패 시

```bash
# Jenkins 컨테이너 내부에 Docker CLI 설치
docker exec -u root jenkins apk add docker-cli
```

### SSH 연결 실패 시

```bash
# 서버에서 SSH 키 등록 확인
cat ~/.ssh/authorized_keys

# 노트북에서 SSH 테스트
ssh ubuntu@your-server-ip
```

### Docker Hub push 실패 시

- Docker Hub credentials ID 확인
- Docker Hub에 repository 미리 생성되어 있는지 확인

---

## 🎨 선택사항: GitHub Webhook 자동화

수동 빌드 대신 커밋 시 자동 빌드하려면:

1. Jenkins 관리 → 시스템 설정 → GitHub 서버 추가
2. GitHub 레포 → Settings → Webhooks
3. Payload URL: `http://your-jenkins-url:8080/github-webhook/`
4. Jenkins 파이프라인 설정에서 "GitHub hook trigger for GITScm polling" 체크

---

## 📝 다음 단계

- [ ] Nginx reverse proxy 추가 (80 포트로 프론트/백엔드 모두 서빙)
- [ ] SSL 인증서 적용 (Let's Encrypt)
- [ ] 환경변수 관리 (.env 파일)
- [ ] 로깅/모니터링 추가

끝! 🎉