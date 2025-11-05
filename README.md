# Jenkins CI/CD 완전 가이드 (라즈베리파이 버전)

노트북 Jenkins → Docker Hub → 라즈베리파이 서버 배포 플로우

## 📁 프로젝트 구조

```
cicd-project/
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

## 🚀 1단계: 노트북에 Jenkins 설치

### Docker로 Jenkins 실행

```powershell
docker run -d `
  --name jenkins `
  -p 8080:8080 `
  -v jenkins_home:/var/jenkins_home `
  -v /var/run/docker.sock:/var/run/docker.sock `
  jenkins/jenkins:lts
```

### 초기 비밀번호 확인

```powershell
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

브라우저에서 `http://localhost:8080` 접속 후 초기 설정 완료

### 필수 플러그인 설치

Jenkins 관리 → 플러그인 관리에서 설치:
- **Docker Pipeline**
- **Git**

---

## 🔑 2단계: Jenkins Credentials 설정

Jenkins 관리 → Credentials → System → Global credentials

### 1) Docker Hub 로그인 정보

**"+ Add Credentials"** 클릭:

- Kind: `Username with password`
- ID: `dockerhub-credentials`
- Username: Docker Hub 아이디
- Password: Docker Hub 비밀번호
- Description: `Docker Hub Login`
- **Create**

### 2) 라즈베리파이 SSH 비밀번호

**"+ Add Credentials"** 다시 클릭:

- Kind: `Username with password`
- ID: `pi-ssh-password`
- Username: `pi`
- Password: 라즈베리파이 비밀번호
- Description: `Raspberry Pi SSH Password`
- **Create**

완료하면 2개가 보여야 함:
```
dockerhub-credentials  (Username with password)
pi-ssh-password       (Username with password)
```

---

## 📦 3단계: 프로젝트 파일 생성

노트북에서 작업:

```powershell
# 프로젝트 폴더 생성
mkdir cicd-project
cd cicd-project

# 서브 폴더 생성
mkdir frontend, backend, server
```

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
    <p>Deployed via Jenkins CI/CD!</p>
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
    res.json({ 
        status: 'ok', 
        version: '1.0',
        message: 'Backend is running!'
    });
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
        SERVER_HOST = '192.168.1.45'
    }
    
    stages {
        stage('Test') {
            steps {
                echo 'Running frontend tests...'
                // 실제 테스트 명령어 추가 가능
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
        
        stage('Deploy to Raspberry Pi') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'pi-ssh-password',
                    usernameVariable: 'SSH_USER',
                    passwordVariable: 'SSH_PASS'
                )]) {
                    sh """
                        sshpass -p "\${SSH_PASS}" ssh -o StrictHostKeyChecking=no \${SSH_USER}@${SERVER_HOST} '
                            cd ~/app &&
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
        success {
            echo 'Frontend deployment successful!'
        }
        failure {
            echo 'Frontend deployment failed!'
        }
    }
}
```

**⚠️ 수정 필요:**
- `your-dockerhub-username` → 본인 Docker Hub 아이디로 변경

### Jenkinsfile-backend

```groovy
pipeline {
    agent any
    
    environment {
        DOCKERHUB_REPO = 'your-dockerhub-username/backend'
        IMAGE_TAG = "${BUILD_NUMBER}"
        SERVER_HOST = '192.168.1.45'
    }
    
    stages {
        stage('Test') {
            steps {
                echo 'Running backend tests...'
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
        
        stage('Deploy to Raspberry Pi') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'pi-ssh-password',
                    usernameVariable: 'SSH_USER',
                    passwordVariable: 'SSH_PASS'
                )]) {
                    sh """
                        sshpass -p "\${SSH_PASS}" ssh -o StrictHostKeyChecking=no \${SSH_USER}@${SERVER_HOST} '
                            cd ~/app &&
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
        success {
            echo 'Backend deployment successful!'
        }
        failure {
            echo 'Backend deployment failed!'
        }
    }
}
```

**⚠️ 수정 필요:**
- `your-dockerhub-username` → 본인 Docker Hub 아이디로 변경

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

**⚠️ 수정 필요:**
- `your-dockerhub-username` → 본인 Docker Hub 아이디로 변경

---

## 🖥️ 4단계: 라즈베리파이 설정

### 1) SSH 접속

```powershell
ssh pi@192.168.1.45
```

### 2) Docker 설치

```bash
# Docker 설치 스크립트 실행
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# pi 유저에게 Docker 권한 부여
sudo usermod -aG docker pi

# 재로그인 필요
exit
```

다시 접속:
```powershell
ssh pi@192.168.1.45
```

### 3) Docker Compose 설치

```bash
# Docker Compose 설치
sudo apt update
sudo apt install -y docker-compose

# 버전 확인
docker-compose --version
```

### 4) 프로젝트 디렉토리 생성

```bash
# 홈 디렉토리에 app 폴더 생성
mkdir -p ~/app
cd ~/app
```

### 5) docker-compose.yml 업로드

**방법 A: 직접 파일 생성 (추천)**

라즈베리파이에서:
```bash
nano ~/app/docker-compose.yml
```

위에 작성한 `server/docker-compose.yml` 내용 복사 → 붙여넣기
- Ctrl+O (저장) → Enter → Ctrl+X (종료)

**방법 B: scp로 전송**

노트북에서:
```powershell
scp server/docker-compose.yml pi@192.168.1.45:~/app/
```

### 6) Docker Hub 로그인 (Public 이미지면 스킵 가능)

라즈베리파이에서:
```bash
docker login
# Username: (Docker Hub 아이디)
# Password: (비밀번호)
```

**만약 로그인 안 되면:** Docker Hub에서 이미지를 **Public**으로 설정

---

## 🔧 5단계: 노트북 Jenkins에 sshpass 설치

노트북 터미널에서:

```powershell
docker exec -u root jenkins apk add sshpass
```

---

## 📤 6단계: GitHub에 푸시

```powershell
cd cicd-project

# Git 초기화
git init
git add .
git commit -m "Initial CI/CD setup"

# GitHub 레포 생성 후 연결
git remote add origin https://github.com/your-username/cicd-project.git
git branch -M main
git push -u origin main
```

---

## 🔧 7단계: Jenkins 파이프라인 생성

### 프론트엔드 파이프라인

1. Jenkins 대시보드 → **"새로운 Item"**
2. 이름: `frontend-pipeline`
3. 타입: **Pipeline** 선택 → **OK**
4. 설정 화면에서:
   - **Pipeline** 섹션으로 스크롤
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/your-username/cicd-project.git`
   - Branch Specifier: `*/main`
   - Script Path: `Jenkinsfile-frontend`
5. **저장**

### 백엔드 파이프라인

동일하게 반복, 이름만 `backend-pipeline`, Script Path만 `Jenkinsfile-backend`

---

## ✅ 8단계: 배포 테스트!

### 1) 프론트엔드 빌드

Jenkins 대시보드:
- `frontend-pipeline` 클릭
- **"Build Now"** 클릭
- 왼쪽 Build History에서 진행 상황 확인
- 성공하면 파란 공 ✅

### 2) 백엔드 빌드

- `backend-pipeline` 클릭
- **"Build Now"** 클릭

### 3) 라즈베리파이에서 확인

```bash
ssh pi@192.168.1.45

# 컨테이너 확인
docker ps

# 프론트엔드 테스트
curl http://localhost

# 백엔드 테스트
curl http://localhost:3000/api/health
```

### 4) 브라우저에서 확인

- 프론트엔드: `http://192.168.1.45`
- 백엔드 API: `http://192.168.1.45:3000/api/health`

---

## 🎯 전체 플로우 정리

```
1. 노트북에서 코드 수정
2. git push origin main
3. Jenkins 대시보드에서 "Build Now" 클릭
4. Jenkins가:
   - 테스트 실행
   - Docker 이미지 빌드
   - Docker Hub에 push
   - SSH로 라즈베리파이 접속
   - docker pull 실행
   - docker-compose up -d로 재시작
5. 배포 완료! 🎉
```

---

## 🔍 트러블슈팅

### Jenkins에서 "docker: command not found"

```powershell
docker exec -u root jenkins apk add docker-cli
```

### sshpass 오류

```powershell
docker exec -u root jenkins apk add sshpass
```

### 라즈베리파이에서 "permission denied"

```bash
ssh pi@192.168.1.45
sudo usermod -aG docker pi
exit
# 다시 로그인
ssh pi@192.168.1.45
docker ps  # 이제 sudo 없이 작동
```

### Docker Hub push 실패

- Docker Hub credentials ID가 `dockerhub-credentials`인지 확인
- Docker Hub에 레포지토리가 미리 생성되어 있는지 확인

### 라즈베리파이 포트 충돌

다른 서비스가 80 포트 사용 중이면:
```yaml
# docker-compose.yml
services:
  frontend:
    ports:
      - "8080:80"  # 80 대신 8080
```

---

## 🎨 다음 단계

- [ ] GitHub Webhook으로 자동 빌드 (커밋하면 자동으로 배포)
- [ ] Nginx로 도메인 연결
- [ ] SSL 인증서 적용
- [ ] 환경변수 관리 (.env)
- [ ] 로그 모니터링

---

## 📝 체크리스트

배포 전 확인사항:

- [ ] Jenkinsfile에서 `your-dockerhub-username` 변경
- [ ] docker-compose.yml에서 `your-dockerhub-username` 변경
- [ ] Docker Hub에 레포지토리 생성
- [ ] 라즈베리파이에 Docker 설치 완료
- [ ] 라즈베리파이에 `~/app/docker-compose.yml` 업로드
- [ ] Jenkins에 sshpass 설치
- [ ] Jenkins Credentials 2개 등록

끝! 🚀