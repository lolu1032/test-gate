# Test Gate — AI 에이전트 테스트 격리 하네스

> Claude Code용 AI 에이전트 QA 격리 하네스

**[English](README.md)**

코딩 에이전트와 **별도 세션**에서 Playwright MCP로 웹앱을 테스트하고 리포트를 생성합니다.
"이 정도면 됐지" 문제를 구조적으로 해결합니다.

## 빠른 시작

```bash
# 프로젝트 디렉토리에서
~/.claude/test-harness/test-now.sh
```

끝. macOS 알림이 오면 리포트를 확인하세요.

## 사용법

### 수동 테스트 (기본)

```bash
# 현재 프로젝트에서 실행
~/.claude/test-harness/test-now.sh

# 특정 프로젝트 지정
~/.claude/test-harness/test-now.sh ~/projects/workb
```

### 자동 테스트 (커밋마다 자동 실행)

`~/.claude/settings.json`에 hook 추가:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/test-harness/check-and-run.sh"
          }
        ]
      }
    ]
  }
}
```

### 특정 커밋 스킵 (자동 모드)

커밋 메시지에 `[skip-test]` 추가:

```bash
git commit -m "docs: README 수정 [skip-test]"
```

## 리포트 확인

| 방법 | 위치 |
|------|------|
| **macOS 알림** | 테스트 완료 시 자동 팝업 |
| **VSCode** | 리포트 `.md` 파일이 에디터에 자동 열림 |
| **파일** | `{프로젝트}/.claude/test-reports/{hash}-report.md` |
| **히스토리** | `{프로젝트}/.claude/test-reports/HISTORY.md` |

## 프로젝트별 커스텀

프로젝트 루트에 `.claude/test-scenarios.md`를 만들면 기본 프롬프트 대신 사용됩니다:

```markdown
# 테스트 시나리오

## 필수 테스트
1. localhost:3000 메인 페이지 로드 확인
2. /login 페이지에서 로그인 폼 동작 확인
3. /dashboard 페이지 데이터 로드 확인

## 중점 확인
- 사이드바 네비게이션이 모든 페이지에서 동작하는지
- API 에러 시 에러 메시지가 표시되는지
```

## 파일 구조

```
~/.claude/test-harness/
├── README.md              # 이 파일
├── test-now.sh            # 수동 실행 명령어
├── check-and-run.sh       # 자동 모드용 hook 스크립트
├── run-all-tests.sh       # 테스트 실행 (claude --print + Playwright MCP)
├── merge-reports.sh       # 리포트 합산 + 히스토리 업데이트
├── browser-test-prompt.md # 기본 테스트 프롬프트
├── browser-mcp.json       # Playwright MCP 설정
├── .last-tested-hash      # (자동 생성) 마지막 테스트한 커밋
├── .test-running           # (자동 생성) 실행 중 lock
└── .last-test.log          # (자동 생성) 마지막 테스트 로그

{프로젝트}/
└── .claude/
    ├── test-scenarios.md   # (선택) 프로젝트별 테스트 시나리오
    └── test-reports/
        ├── HISTORY.md      # 테스트 히스토리 테이블
        ├── {hash}-browser.md  # Playwright 테스트 결과
        └── {hash}-report.md   # 합산 리포트
```

## 동작 원리

1. `test-now.sh` 실행 (또는 hook이 자동 트리거)
2. `run-all-tests.sh`가 백그라운드에서 `claude --print` 실행
   - 모델: Haiku 4.5 (비용 절약)
   - MCP: Playwright (브라우저 자동화)
   - 권한: 읽기 + MCP만 허용 (코드 수정 불가)
3. 테스트 에이전트가 웹앱을 돌아다니며 검증
4. 리포트 생성 → macOS 알림 → VSCode에서 열기
5. HISTORY.md에 결과 기록 (PASS/FAIL/REGRESSION)

## 히스토리 활용

테스트 에이전트는 HISTORY.md를 읽고:
- 이전에 FAIL→PASS 된 항목을 **리그레션 민감** 영역으로 인식
- 이전 PASS가 FAIL이 되면 **[REGRESSION]** 표시
- 커밋 메시지에 fix:가 있으면 관련 FAIL 항목을 집중 검증

## 비용

- Max 20x 구독: 추가 비용 없음 (구독 사용량에 포함)
- API 과금: Haiku 4.5 기준 테스트 1회당 약 $0.01-0.05

## Phase 2 (예정)

- Tauri MCP 추가 (데스크톱 앱 테스트)
- 디바운스 (연속 커밋 시 마지막만 테스트)
- adversarial test agent (반복 실수 패턴 학습)
