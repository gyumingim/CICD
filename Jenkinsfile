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