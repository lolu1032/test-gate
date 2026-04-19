---
name: test-tauri
description: (deprecated alias) /test-desktop으로 대체됨 — 데스크톱앱 QA 테스트
user_invocable: true
---

# Test Tauri (Deprecated Alias)

이 스킬은 `/test-desktop`으로 이름이 변경되었습니다.

`/test-tauri` → `/test-desktop`

## 동작

사용자에게 알림:

> `/test-tauri`는 `/test-desktop`으로 이름이 변경되었습니다.
> 표면(surface) 기반 명명을 위한 변경이에요. Tauri는 데스크톱 앱의 한 구현일 뿐이니까요.
>
> 자동으로 `/test-desktop`을 실행할까요?

Options:
- A) 네, /test-desktop 실행
- B) 취소

A를 선택하면 `~/.claude/skills/test-desktop/SKILL.md`를 읽고 그 지시를 따른다.
