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