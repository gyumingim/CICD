# FastAPI CI/CD 구축 가이드 (NAS + Jenkins)

## 📋 필요한 파일 구조
```
CICD/
├── main.py
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
└── Jenkinsfile
```

## 🚀 NAS 초기 설정

### 1. Docker 설치 (NAS에서)
```bash
# Synology NAS의 경우 패키지 센터에서 Docker 설치
# QNAP의 경우 Container Station 설치
```

### 2. Jenkins 컨테이너 실행
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  jenkins/jenkins:lts
```

### 3. Jenkins 초기 비밀번호 확인
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## ⚙️ Jenkins 설정

### 1. Jenkins 접속
- 브라우저에서 `http://NAS_IP:8080` 접속
- 초기 비밀번호 입력
- 추천 플러그인 설치

### 2. 필수 플러그인 설치
- Jenkins 관리 → 플러그인 관리
- 설치할 플러그인:
  - Git plugin
  - Docker plugin
  - Pipeline plugin (기본 설치됨)

### 3. 새 Pipeline Job 생성
1. 새로운 Item → Pipeline 선택
2. 이름: `fastapi-cicd`
3. Pipeline 섹션에서:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/gyumingim/CICD.git`
   - **Branch**: `*/main`
   - **Script Path**: `Jenkinsfile`

### 4. GitHub Webhook 설정 (자동 배포)
1. GitHub 저장소 → Settings → Webhooks → Add webhook
2. Payload URL: `http://NAS_IP:8080/github-webhook/`
3. Content type: `application/json`
4. Events: `Just the push event`

Jenkins Job 설정:
- Build Triggers → GitHub hook trigger for GITScm polling 체크

## 🏃 배포 실행

### 수동 배포
1. Jenkins에서 `fastapi-cicd` Job 클릭
2. "Build Now" 클릭

### 자동 배포
- GitHub에 push하면 자동으로 배포됨

## 🔍 확인

### 애플리케이션 접속
```bash
curl http://NAS_IP/
# 또는 브라우저에서 http://NAS_IP/
```

예상 응답:
```json
{"Hello": "World"}
```

### 컨테이너 상태 확인
```bash
docker ps
docker logs fastapi-app
docker logs nginx-proxy
```

## 🛠️ 유용한 명령어

### 로그 확인
```bash
# FastAPI 로그
docker logs -f fastapi-app

# Nginx 로그
docker logs -f nginx-proxy

# Jenkins 로그
docker logs -f jenkins
```

### 재시작
```bash
docker-compose restart
```

### 중지 및 제거
```bash
docker-compose down
```

### 완전 재배포
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 🔒 보안 권장사항

1. **방화벽 설정**: NAS 방화벽에서 필요한 포트만 개방
   - 80 (HTTP)
   - 8080 (Jenkins, 필요시 내부망만 허용)

2. **Jenkins 보안**:
   - 강력한 관리자 비밀번호 설정
   - CSRF 보호 활성화
   - 가능하면 HTTPS 설정

3. **Docker 보안**:
   - 정기적인 이미지 업데이트
   - 불필요한 포트 노출 금지

## ❓ 문제 해결

### 포트 충돌
```bash
# 사용중인 포트 확인
netstat -tulpn | grep :80
# docker-compose.yml에서 포트 변경 (예: 8080:80)
```

### Docker 권한 오류
```bash
# Jenkins 컨테이너에 Docker 권한 부여
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

### 빌드 실패
```bash
# Jenkins 로그 확인
docker logs jenkins
# 워크스페이스 정리 후 재시도
```