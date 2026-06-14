# Contributing to the Goldilocks Tutorial

Thank you for contributing! This tutorial is an educational resource for Kubernetes administrators. Quality and accuracy matter more than quantity.

## The #1 Rule: Validate Everything

**Every shell command, kubectl command, and YAML manifest in a lesson must be tested before submitting.** A learner following this tutorial will run these commands exactly as written. Untested content breaks trust.

### Validation Checklist

Before submitting a PR that adds or modifies lesson content:

- [ ] All shell commands run without error on macOS (k3d, kubectl, helm)
- [ ] All YAML manifests pass `kubectl --dry-run=client` validation
- [ ] All kubectl commands produce output matching what is documented
- [ ] The lesson is completable from start to finish following only the documented steps
- [ ] QUIZ.md answers are factually correct

## Lesson Structure

Each lesson lives in `NN-kebab-case/` with exactly three files:

```
NN-lesson-name/
├── index.html    # Docsify loader (copy from existing lesson, update title/name)
├── README.md     # Lesson content
└── QUIZ.md       # 4-5 practical questions
```

### README.md Template

```markdown
# Lesson NN: Title

> **Duration**: ~X minutes | **Level**: Beginner/Intermediate | [← Previous](../NN-1/) | [Next →](../NN+1/)

## Overview

One paragraph introducing what this lesson covers and why it matters.

## Learning Objectives

By the end of this lesson you will:
- Know how to ...
- Be able to ...

## Prerequisites

- Completed [Lesson NN-1: Title](../NN-1/)
- Running goldilocks-demo k3d cluster

## [Main Content Sections]

...

## Verification

```bash
# Commands learners run to confirm the lesson worked
kubectl get pods -n goldilocks
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
goldilocks-controller-...               1/1     Running   0          2m
goldilocks-dashboard-...                1/1     Running   0          2m
```

## What's Next

In the next lesson, [Lesson NN+1: Title](../NN+1/), you will ...
```

### QUIZ.md Template

```markdown
# Quiz — Lesson NN: Title

Test your understanding with these questions.

## Question 1

**What happens when a pod exceeds its memory limit?**

- A. The pod is throttled
- B. The pod is OOMKilled and restarted
- C. The pod is moved to another node
- D. The pod pauses until memory is available

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | B | Memory limits are enforced by the Linux OOM killer. When a container exceeds its memory limit, the kernel kills the process and Kubernetes restarts the pod. |
```

## Reporting Issues

If you find a command that doesn't work, a concept that is explained incorrectly, or a broken link — please open an issue with:

1. The lesson number and title
2. The specific command or content that is wrong
3. The error you received or the correct information
4. Your OS and tool versions (`k3d version`, `kubectl version --client`, `helm version`)

## Style Guide

- Write for a Kubernetes administrator who is new to resource optimization — assume kubectl familiarity, not VPA expertise
- Short paragraphs. One idea per paragraph.
- Every code block must be runnable or clearly labeled as illustrative
- Use the legend symbols: 🎯 💡 ⚠️ ✅
- Never use "simple", "just", or "easy" — what's easy for the author may not be easy for the learner
