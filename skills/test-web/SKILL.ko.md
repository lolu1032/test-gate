---
name: test-web
description: 별도 세션에서 Playwright MCP로 웹앱 QA 테스트 실행
user_invocable: true
---

# Test Web

별도 Claude 세션에서 Playwright MCP로 웹앱을 테스트하고 리포트를 생성한다.

## 실행

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
echo "PROJECT: $PROJECT_ROOT"
echo "COMMIT: $(git -C "$PROJECT_ROOT" log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"

# 하네스 설치 확인
if [ -x "$HOME/.claude/test-harness/test-now.sh" ]; then
  echo "HARNESS: installed"
else
  echo "HARNESS: NOT INSTALLED"
fi

# 시나리오 감지 (우선순위: 신규 폴더 → 구 폴더 → 구 단일 파일)
SCENARIOS_NEW="$PROJECT_ROOT/.claude/test-scenarios/web"
SCENARIOS_OLD_DIR="$PROJECT_ROOT/.claude/test-scenarios"
SCENARIOS_FILE="$PROJECT_ROOT/.claude/test-scenarios.md"
setopt +o nomatch 2>/dev/null

if [ -d "$SCENARIOS_NEW" ]; then
  echo "SCENARIOS: folder (.claude/test-scenarios/web/)"
  for f in "$SCENARIOS_NEW"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "  - $(basename "$f") ($lines lines)"
  done
elif [ -d "$SCENARIOS_OLD_DIR" ] && find "$SCENARIOS_OLD_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | grep -q .; then
  echo "SCENARIOS: legacy folder (.claude/test-scenarios/) — consider migrating to test-scenarios/web/"
  for f in "$SCENARIOS_OLD_DIR"/*.md; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "  - $(basename "$f") ($lines lines)"
  done
elif [ -f "$SCENARIOS_FILE" ]; then
  echo "SCENARIOS: legacy single file (.claude/test-scenarios.md, $(wc -l < "$SCENARIOS_FILE" | tr -d ' ') lines) — consider migrating"
else
  echo "SCENARIOS: none"
fi

# 포트 감지
PORT=$(grep -oE '\-\-port[= ]+([0-9]+)' "$PROJECT_ROOT/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT=$(grep -oE 'PORT[= ]+([0-9]+)' "$PROJECT_ROOT/.env" 2>/dev/null | grep -oE '[0-9]+' | head -1)
[ -z "$PORT" ] && PORT="3000"
echo "PORT: $PORT"

# dev 서버 실행 중인지 확인
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -qE "^[23]"; then
  echo "SERVER: running on :$PORT"
else
  echo "SERVER: NOT RUNNING on :$PORT"
fi

# 히스토리 확인
if [ -f "$PROJECT_ROOT/.claude/test-reports/HISTORY.md" ]; then
  echo "HISTORY:"
  head -9 "$PROJECT_ROOT/.claude/test-reports/HISTORY.md"
fi
```

## 동작

하네스가 설치되어 있지 않으면:

> Test Gate 하네스가 설치되어 있지 않습니다.
> 설치: `git clone https://github.com/lolu1032/test-gate.git && cd test-gate && ./install.sh`

서버가 실행 중이지 않으면 AskUserQuestion:

> localhost:{PORT}에 서버가 떠있지 않습니다.

Options:
- A) 내가 직접 띄울게 — 기다려
- B) 다른 포트 지정
- C) 취소

### 시나리오 상태별 분기

**모든 경우 항상 사용자에게 먼저 묻는다. 자동으로 진행하지 않는다.**

**시나리오가 폴더인 경우** — 파일 목록 보여주고 AskUserQuestion:

> **웹 테스트** — {프로젝트명} (localhost:{PORT})
> 커밋: {hash} {message}
> 시나리오 폴더: .claude/test-scenarios/ ({N}개 파일)
>
> 파일: _always.md, auth.md, posts.md, ... 등

Options:
- A) 그대로 실행 — 모든 시나리오 파일 합쳐서 테스트
- B) 시나리오 파일 추가 — 사용자가 직접 내용 작성
- C) 시나리오 관리 — 편집/삭제/이름변경
- D) 취소

**시나리오가 단일 파일인 경우** — 파일 전체 미리보기 + AskUserQuestion:

> **웹 테스트** — {프로젝트명} (localhost:{PORT})
> 커밋: {hash} {message}
> 시나리오 파일: .claude/test-scenarios.md ({N}줄)
>
> --- 미리보기 ---
> {파일 내용 전체 또는 앞 30줄}

Options:
- A) 그대로 실행
- B) 시나리오 추가 — 사용자가 직접 내용 작성
- C) 시나리오 수정 — 사용자가 직접 재작성
- D) 폴더 방식으로 분할 — 사용자가 기능별로 직접 분할
- E) 삭제 후 다시 시작 — 백업 후 시나리오 없는 상태로
- F) 취소

**시나리오가 없는 경우** — 반드시 사용자에게 먼저 묻는다. 자동으로 기본 프롬프트 실행 금지:

> **웹 테스트** — {프로젝트명} (localhost:{PORT})
> 커밋: {hash} {message}
> 시나리오: 없음
>
> 시나리오 없이 기본 프롬프트로 돌리면 에이전트가 무작위로 페이지를 돌아봅니다.
> 테스트 품질을 위해 시나리오를 직접 작성하는 것을 권장해요.

Options:
- A) 시나리오 직접 작성 — 단일 파일 (.claude/test-scenarios.md)
- B) 시나리오 폴더 만들기 — 기능별 분할 (.claude/test-scenarios/)
- C) 기본 프롬프트로 그냥 돌리기 — 시나리오 없이 (비추천)
- D) 취소

## 실행 로직

### A) 그대로 실행

**자동 생성 없이** 현재 상태 그대로 실행:

```bash
~/.claude/test-harness/test-now.sh "$PROJECT_ROOT"
```

실행 후:

> 테스트가 백그라운드에서 실행 중입니다.
> 완료되면 macOS 알림이 옵니다.
> 리포트: {PROJECT_ROOT}/.claude/test-reports/{hash}-report.md

### B/C) 시나리오 작성 또는 추가

**반드시 사용자에게 물어본다. 자동 작성 금지.**

사용자에게 AskUserQuestion 또는 자유 입력으로 질문:

1. **어떤 URL/페이지를 테스트할지?** (예: localhost:3001, /admin, /dashboard)
2. **로그인이 필요한가? 계정 정보는?** (예: admin@admin.com / 1234)
3. **구체적으로 무엇을 확인할 기능/동작?** (사용자가 자유 기술)
4. **에러/엣지 케이스로 무엇을 볼까?** (사용자가 자유 기술)

사용자 답변을 받아 아래 템플릿으로 파일 작성:

```markdown
# {Feature Name} Tests

## URL & Auth
- URL: {user-provided}
- 계정: {user-provided or "없음"}

## 시나리오
{user-provided list}

## 에러/엣지 케이스
{user-provided list}
```

**폴더 상태**: 새 파일 이름을 먼저 물어본다 (예: `auth.md`, `posts.md`), 그다음 위 질문 → `.claude/test-scenarios/{name}.md` 생성.

**단일 파일 상태**: 기존 파일에 새 섹션을 append.

작성 후 "테스트 시작할까요?"로 돌아간다.

### C) 시나리오 관리 (폴더)

폴더 내 파일 목록 보여주고 AskUserQuestion:

> 어떤 파일을 관리할까요?
> - A) _always.md 편집
> - B) auth.md 편집
> - C) posts.md 편집
> - D) 파일 삭제
> - E) 이름 변경
> - F) 돌아가기

선택에 따라 해당 파일을 읽어서 보여주고 수정/삭제 진행.

### 시나리오 수정 (단일 파일)

현재 시나리오 전체를 보여주고 사용자에게 어떻게 바꿀지 묻는다. 부분 수정은 사용자의 텍스트 지시를 받아 Edit tool로 적용.

### 단일 파일 → 폴더 마이그레이션

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$PROJECT_ROOT/.claude/test-scenarios"
mv "$PROJECT_ROOT/.claude/test-scenarios.md" "$PROJECT_ROOT/.claude/test-scenarios/_always.md"
echo "Migrated to folder structure. Now you can add feature-specific files like auth.md, posts.md, etc."
```

사용자에게 어떤 기능별로 분할할지 물어보고 Edit tool로 `_always.md`를 분할.

## 시나리오 폴더 구조 (권장)

```
.claude/test-scenarios/
├── _always.md        # 항상 실행 (로그인, 기본 네비게이션)
├── auth.md           # 인증 관련 변경 시
├── posts.md          # 게시물 관련
├── dashboard.md      # 대시보드
└── performance.md    # 성능 측정
```

실행 시 폴더 내 모든 `.md` 파일이 `_always.md` 먼저, 나머지는 알파벳 순으로 합쳐져 프롬프트로 전달된다.
