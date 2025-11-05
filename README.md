# FastAPI CI/CD 설정 가이드

## 📋 목차
1. [사전 요구사항](#사전-요구사항)
2. [Jenkins 설치](#jenkins-설치)
3. [Jenkins 설정](#jenkins-설정)
4. [파이프라인 생성](#파이프라인-생성)
5. [테스트 및 배포](#테스트-및-배포)
6. [문제 해결](#문제-해결)

---

## 🔧 사전 요구사항

### 필수 설치 항목
- Docker 20.10 이상
- Docker Compose 2.0 이상
- Git

### 포트 확인
```bash
# 사용할 포트가 비어있는지 확인
netstat -tuln | grep -E ':(80|8080|50000)'
```

---

## 🚀 Jenkins 설치

### 1. Jenkins 컨테이너 실행

```bash
docker run -d \
  --name jenkins \
  --restart=unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  -v $(which docker-compose):/usr/bin/docker-compose \
  jenkins/jenkins:lts
```

### 2. Jenkins 컨테이너에 Docker 권한 부여

```bash
# Docker 소켓 권한 설정
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Docker 명령어 실행 가능하도록 설정
docker exec -u root jenkins chown jenkins:jenkins /usr/bin/docker
docker exec -u root jenkins chown jenkins:jenkins /usr/bin/docker-compose
```

### 3. 초기 비밀번호 확인

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

출력된 비밀번호를 복사해둡니다.

---

## ⚙️ Jenkins 설정

### 1. Jenkins 초기 설정

1. 브라우저에서 `http://localhost:8080` 또는 `http://서버IP:8080` 접속
2. 복사한 초기 비밀번호 입력
3. **Install suggested plugins** 선택
4. 관리자 계정 생성
5. Jenkins URL 확인 (기본값 사용)

### 2. 필수 플러그인 설치

**Jenkins 관리 → Plugins → Available plugins** 에서 다음 플러그인 설치:

- ✅ Git plugin (보통 기본 설치됨)
- ✅ Pipeline plugin (보통 기본 설치됨)
- ✅ Docker Pipeline
- ✅ GitHub Integration Plugin (선택사항)

설치 후 Jenkins 재시작:
```bash
docker restart jenkins
```

### 3. Docker 권한 재확인

```bash
# Jenkins 컨테이너 내부에서 Docker 실행 테스트
docker exec jenkins docker ps
docker exec jenkins docker-compose version
```

---

## 🔨 파이프라인 생성

### 1. 새 Pipeline Job 생성

1. Jenkins 대시보드에서 **새로운 Item** 클릭
2. 이름 입력: `fastapi-cicd`
3. **Pipeline** 선택 → **OK**

### 2. Pipeline 설정

**Pipeline 섹션 설정:**

- **Definition:** `Pipeline script from SCM`
- **SCM:** `Git`
- **Repository URL:** `https://github.com/gyumingim/CICD.git`
- **Credentials:** 공개 저장소면 None
- **Branch Specifier:** `*/main` (또는 `*/master`)
- **Script Path:** `Jenkinsfile`

**Build Triggers 설정 (선택사항):**

- ✅ **Poll SCM** 체크
- Schedule에 입력: `H/5 * * * *` (5분마다 체크)

또는

- ✅ **GitHub hook trigger for GITScm polling** (Webhook 사용시)

### 3. 저장

**Save** 버튼 클릭

---

## 🧪 테스트 및 배포

### 1. 수동 빌드 테스트

1. `fastapi-cicd` Job 클릭
2. **Build Now** 클릭
3. Build History에서 진행 상황 확인
4. Console Output에서 로그 확인

### 2. 배포 확인

```bash
# 컨테이너 상태 확인
docker ps

# 애플리케이션 테스트
curl http://localhost/
curl http://localhost/health
curl http://localhost/api/version

# 로그 확인
docker logs fastapi-app
docker logs nginx-proxy
```

### 3. 예상 응답

```json
// http://localhost/
{
  "message": "Hello World",
  "status": "running"
}

// http://localhost/health
{
  "status": "healthy"
}

// http://localhost/api/version
{
  "version": "1.0.0",
  "environment": "production"
}
```

---

## 🐛 문제 해결

### 문제 1: Jenkins에서 Docker 명령어를 찾을 수 없음

**증상:**
```
docker: command not found
```

**해결:**
```bash
# Docker 바이너리 다시 마운트
docker exec -u root jenkins ln -s /usr/bin/docker /usr/local/bin/docker
docker exec -u root jenkins ln -s /usr/bin/docker-compose /usr/local/bin/docker-compose
```

### 문제 2: Permission denied (Docker 소켓)

**증상:**
```
permission denied while trying to connect to the Docker daemon socket
```

**해결:**
```bash
# Docker 소켓 권한 부여
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# 또는 jenkins 사용자를 docker 그룹에 추가
docker exec -u root jenkins usermod -aG docker jenkins
docker restart jenkins
```

### 문제 3: 포트가 이미 사용중

**증상:**
```
Bind for 0.0.0.0:80 failed: port is already allocated
```

**해결:**
```bash
# 포트 사용 프로세스 확인
sudo lsof -i :80
# 또는
sudo netstat -tuln | grep :80

# docker-compose.yml에서 포트 변경
# ports:
#   - "8000:80"  # 외부 8000번 포트 사용
```

### 문제 4: Health Check 실패

**증상:**
```
Health check failed
```

**해결:**
```bash
# 애플리케이션 로그 확인
docker logs fastapi-app

# 컨테이너 내부에서 직접 테스트
docker exec fastapi-app curl http://localhost:8000/health

# 네트워크 확인
docker network inspect cicd_app-network
```

### 문제 5: Build 실패 - 이미지 빌드 오류

**해결:**
```bash
# 캐시 없이 다시 빌드
docker-compose build --no-cache

# 오래된 이미지 정리
docker system prune -a -f

# Jenkins에서 다시 빌드
```

### 문제 6: Git 저장소 접근 오류

**해결:**
```bash
# Jenkins 컨테이너에서 Git 설정 확인
docker exec jenkins git config --global --list

# SSH 키 사용시 (비공개 저장소)
# Jenkins 관리 → Credentials 에서 SSH 키 등록
```

---

## 📊 모니터링

### 컨테이너 상태 확인
```bash
# 실시간 로그 보기
docker-compose logs -f

# 리소스 사용량 확인
docker stats

# 네트워크 상태
docker network ls
docker network inspect cicd_app-network
```

### 헬스 체크
```bash
# 자동 헬스 체크 스크립트
watch -n 5 'curl -s http://localhost/health | jq'
```

---

## 🔄 업데이트 및 재배포

### 코드 변경 후 재배포

1. 코드 수정 후 Git에 push
```bash
git add .
git commit -m "Update application"
git push origin main
```

2. Jenkins가 자동으로 감지하거나 수동으로 **Build Now**

### 수동 재배포
```bash
# 컨테이너 중지 및 제거
docker-compose down

# 새로 빌드 및 실행
docker-compose up -d --build

# 로그 확인
docker-compose logs -f
```

---

## 🎯 성능 최적화 팁

1. **Nginx 캐싱 활성화** (정적 파일 있을 경우)
2. **Docker 이미지 크기 최적화** (multi-stage build)
3. **로그 로테이션 설정**
4. **리소스 제한 설정** (docker-compose.yml에 추가)

```yaml
services:
  fastapi-app:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

---

## 📞 추가 도움말

- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)
- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- [Docker 공식 문서](https://docs.docker.com/)
- [Nginx 공식 문서](https://nginx.org/en/docs/)

---

## ✅ 체크리스트

- [ ] Docker 및 Docker Compose 설치 완료
- [ ] Jenkins 컨테이너 실행 중
- [ ] Jenkins Docker 권한 설정 완료
- [ ] 필수 플러그인 설치 완료
- [ ] Pipeline Job 생성 완료
- [ ] 첫 빌드 성공
- [ ] 애플리케이션 정상 작동 확인 (`curl http://localhost/`)
- [ ] 헬스 체크 통과

모든 항목이 체크되었다면 CI/CD 파이프라인이 성공적으로 구축된 것입니다! 🎉