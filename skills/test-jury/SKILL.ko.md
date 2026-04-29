---
name: test-jury
description: 멀티 에이전트 합의 QA — Claude Opus + Codex GPT가 병렬로 리뷰하고, 서로의 리포트를 본 뒤 재실행, 최종 평결 합성
user_invocable: true
---

# Test Jury (배심원단)

> 두 명의 판사. 독립 평결. 교차 검증. 최종 판결.

정말 확신해야 할 때 — **두 AI 모델**이 같은 대상을 병렬로 리뷰하고, 서로의 리포트를 본 뒤 재평가합니다. 오케스트레이터(이 세션의 Claude Opus)가 최종 평결을 합성.

## `/test-web`이나 `/test-review`랑 뭐가 다른가?

- 모델마다 blind spot이 다름. Claude가 놓친 걸 Codex가 잡고, 반대도 마찬가지.
- 서로의 리포트를 본 뒤 push back하거나 confirm — 약한 판단을 노출.
- 최종 리포트에 confirmed / one-sided / disputed 구분.
- **실행당 4 세션** (2 에이전트 × 2 라운드). 비싸요. 틀리면 큰일나는 경우만.

## 비용 현실

- Round 1: Claude Opus + Codex GPT 병렬
- Round 2: 둘 다 peer 리포트를 컨텍스트로 받고 재실행 (프롬프트 길어짐)
- Synthesis: 오케스트레이터(Claude Opus)가 리포트 4개 읽고 합성
- **총 ~5 모델 호출** (4 × QA + 1 × synthesis)
- 시간: 보통 3–6분
- 절약해서 사용 — 중요한 PR 코드 리뷰에만, 매 커밋엔 X.

## 동작

Codex 미설치 시:

> Codex CLI가 필요합니다 (배심원 중 하나).
> 설치: https://github.com/openai/codex

설치되어 있으면 AskUserQuestion:

> **Test Jury** — {프로젝트명}
> 커밋: {hash} {message}
>
> 4개 모델 세션 실행 (Claude Opus + Codex, 각 2 라운드), 후 합성.
> 비용: 일반 /test-review 대비 ~4×. 시간: 3–6분.
>
> 어떤 모드?

Options:
- A) 코드 리뷰 (가장 안전 — 둘 다 git diff 읽음, 외부 상태 없음)
- B) 웹 QA (실험적 — Codex의 Playwright MCP 지원이 제한적, 관점이 비대칭일 수 있음)
- C) 취소

### A) 코드 리뷰

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
HASH=$(git rev-parse HEAD)
nohup ~/.claude/test-harness/run-jury.sh "$HASH" "$PROJECT_ROOT" review \
    > /dev/null 2>&1 &
echo "PID: $!"
```

### B) 웹 QA

A와 동일하되 mode = `web`. Codex의 Playwright MCP 통합 수준에 따라 코드 레벨 발견에 치우칠 수 있음.

```bash
nohup ~/.claude/test-harness/run-jury.sh "$HASH" "$PROJECT_ROOT" web \
    > /dev/null 2>&1 &
```

실행 후:

> 배심원단이 백그라운드에서 심의 중.
> 평결 준비되면 macOS 알림.
> 최종 리포트: {PROJECT_ROOT}/.claude/jury-reports/{hash}-jury.md
> 작업 파일: {PROJECT_ROOT}/.claude/jury-reports/.work-{hash}/

## 출력 구조

```
{프로젝트}/.claude/jury-reports/
├── HISTORY.md              # 모든 jury 실행 기록
├── {hash}-jury.md          # 최종 합성 평결
└── .work-{hash}/
    ├── round1_claude.md    # Claude 1차 독립
    ├── round1_codex.md     # Codex 1차 독립
    ├── round2_claude.md    # Claude (Codex 라운드 1 본 뒤)
    ├── round2_codex.md     # Codex (Claude 라운드 1 본 뒤)
    └── artifacts/          # 스크린샷 등
```

## 언제 어느 거 쓸까

| 필요 | 사용 |
|------|------|
| 빠른 스모크 | `/test-web` |
| 빠른 코드 리뷰 | `/test-review` |
| 머지 전 중요 PR | `/test-jury review` |
| 프로덕션 릴리즈 | `/test-jury web` |
| AI가 합리화하는 거 같음 | `/test-jury` (어느 모드든) |

## 최종 평결 섹션

오케스트레이터의 리포트는 이렇게 구성:

- **Verdict**: 총 발견 수, 합의 카운트, 분쟁, 신뢰도
- **Confirmed Findings**: 양쪽 합의 → 고신뢰
- **One-Sided Findings**: 한쪽만 — 오케스트레이터가 어느 쪽이 맞을 확률 높은지 평가
- **Disagreements**: 명시적 충돌 — 오케스트레이터가 reasoning과 함께 한쪽 선택
- **Action Required**: YES/NO + 한 줄 근거
- **Round Evolution**: peer 리포트 본 뒤 수렴했는지

투명성을 위해 4개 raw 리포트 모두 embedded.
