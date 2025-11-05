# 🚀 초간단 Jenkins 시작 가이드

## 1단계: Jenkins 설치 (Docker 사용 - 가장 쉬움!)

```bash
# Jenkins를 Docker로 실행 (설치 필요 없음!)
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  --name jenkins \
  jenkins/jenkins:lts
```

## 2단계: Jenkins 접속

1. 브라우저에서 `http://localhost:8080` 접속
2. 초기 비밀번호 확인:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
3. 위 비밀번호 복사해서 입력
4. "Install suggested plugins" 선택 (추천 플러그인 자동 설치)
5. 관리자 계정 생성 (아이디/비밀번호 설정)

## 3단계: 초간단 테스트 프로젝트 만들기

### 프로젝트 파일 구조
```
my-first-jenkins-project/
├── app.js          # 간단한 Node.js 앱
├── test.js         # 테스트 파일
├── package.json    # 프로젝트 설정
└── Jenkinsfile     # Jenkins 설정 파일
```

### app.js
```javascript
function add(a, b) {
  return a + b;
}

function greet(name) {
  return `Hello, ${name}!`;
}

module.exports = { add, greet };
```

### test.js
```javascript
const { add, greet } = require('./app');

console.log('🧪 테스트 시작...');

// 테스트 1: 덧셈
if (add(2, 3) === 5) {
  console.log('✅ 덧셈 테스트 통과!');
} else {
  console.log('❌ 덧셈 테스트 실패!');
  process.exit(1);
}

// 테스트 2: 인사
if (greet('Jenkins') === 'Hello, Jenkins!') {
  console.log('✅ 인사 테스트 통과!');
} else {
  console.log('❌ 인사 테스트 실패!');
  process.exit(1);
}

console.log('🎉 모든 테스트 통과!');
```

### package.json
```json
{
  "name": "my-first-jenkins-project",
  "version": "1.0.0",
  "description": "Jenkins 연습용 초간단 프로젝트",
  "main": "app.js",
  "scripts": {
    "test": "node test.js"
  }
}
```

### Jenkinsfile (Jenkins 설정) - 초간단 버전
```groovy
pipeline {
    agent any
    
    stages {
        stage('준비') {
            steps {
                echo '📦 프로젝트 준비 중...'
                echo '프로젝트 이름: my-first-project'
                echo '빌드 번호: ${BUILD_NUMBER}'
            }
        }
        
        stage('코드 체크') {
            steps {
                echo '🔍 코드 확인 중...'
                sh 'ls -la'
                sh 'pwd'
            }
        }
        
        stage('간단한 테스트') {
            steps {
                echo '🧪 간단한 테스트 실행 중...'
                sh '''
                    echo "덧셈 테스트: 2 + 3 = 5"
                    result=$((2 + 3))
                    if [ $result -eq 5 ]; then
                        echo "✅ 테스트 통과!"
                    else
                        echo "❌ 테스트 실패!"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('완료') {
            steps {
                echo '🎉 빌드 성공!'
                echo '모든 단계가 정상적으로 완료되었습니다!'
            }
        }
    }
    
    post {
        success {
            echo '✅ 전체 파이프라인 성공!'
            echo '빌드 시간: ${currentBuild.durationString}'
        }
        failure {
            echo '❌ 빌드 실패!'
            echo '에러를 확인해주세요.'
        }
    }
}
```

## 4단계: Jenkins에서 프로젝트 생성

1. Jenkins 대시보드에서 **"새로운 Item"** 클릭
2. 이름 입력: `my-first-project`
3. **"Pipeline"** 선택 후 OK
4. 아래로 스크롤해서 **"Pipeline"** 섹션 찾기
5. Definition: **"Pipeline script"** 선택
6. 위의 Jenkinsfile 내용을 복사해서 붙여넣기
7. **"저장"** 클릭

## 5단계: 실행!

1. **"Build Now"** 클릭
2. 왼쪽 **"Build History"**에서 빌드 번호 클릭 (예: #1)
3. **"Console Output"** 클릭해서 실행 과정 보기
4. 성공 메시지 확인! 🎉

## 🎯 이제 뭘 해볼까?

### 쉬운 실험들:
1. **test.js를 일부러 실패하게 만들기**: `add(2, 3) === 5`를 `add(2, 3) === 6`으로 바꾸고 다시 빌드
2. **새로운 stage 추가**: Jenkinsfile에 배포 단계 추가
3. **자동 실행 설정**: GitHub와 연결해서 코드 푸시할 때마다 자동 실행

### GitHub 연결하기 (선택사항):
1. GitHub에 위 프로젝트 푸시
2. Jenkins에서 Pipeline script 대신 **"Pipeline script from SCM"** 선택
3. SCM: Git 선택
4. Repository URL 입력
5. 저장 후 빌드!

## 💡 팁

- **Console Output**: 빌드가 왜 실패했는지 여기서 확인
- **재실행**: "Build Now" 버튼 누르면 언제든 다시 실행
- **수정**: 프로젝트 설정 바꾸려면 "구성" 메뉴 클릭

## 🆘 문제 해결

**Jenkins가 node를 못 찾는다고 하면:**
```groovy
// Jenkinsfile 맨 위에 추가
agent {
    docker {
        image 'node:18'
    }
}
```

**권한 오류가 나면:**
```bash
# Jenkins 컨테이너 재시작
docker restart jenkins
```

## 다음 단계

이 기본 프로젝트가 성공하면:
- ✅ 실제 프로젝트에 적용
- ✅ 자동 배포 추가
- ✅ Slack 알림 연동
- ✅ 여러 브랜치 테스트

**축하합니다! 이제 Jenkins를 사용할 수 있습니다! 🎉**