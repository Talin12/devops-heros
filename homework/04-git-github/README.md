# Git & GitHub: Homework (Session 5)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.

---

## Task 1: `git commit -m` vs `git commit -a -m`

### The difference

Git has three places a change can live:

```
 working directory  ──git add──▶  staging area (index)  ──git commit──▶  repository
   (your edits)                     (what will go in)                    (history)
```

| | `git commit -m "msg"` | `git commit -a -m "msg"` |
|---|---|---|
| What gets committed | only what is already staged with `git add` | staged changes + all modified/deleted TRACKED files, staged automatically |
| Modified tracked file, not `git add`-ed | ❌ not committed | ✅ committed |
| Deleted tracked file | ❌ not recorded | ✅ recorded |
| Brand-new untracked file | ❌ not committed | ❌ still not committed |
| Equivalent to | - | `git add -u && git commit -m "msg"` |
| When to use | normal work - you choose exactly what goes in each commit | quick commit when you want *everything you edited* in one go |

**The key point people get wrong:** `-a` does not mean "add everything". It means *"stage the files git is already tracking"*. A new file git has never seen still needs an explicit `git add`.

### Commands and output

```console
########## TASK 1 : git commit -m   vs   git commit -a -m ##########

$ git init -q -b main

$ git add notes.txt

$ git commit -m 'Initial commit: add notes.txt'
[main (root-commit) 6cdbffd] Initial commit: add notes.txt
 1 file changed, 1 insertion(+)
 create mode 100644 notes.txt

$ git status --short
 M notes.txt

$ git commit -m 'plain commit -m without git add'
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   notes.txt

no changes added to commit (use "git add" and/or "git commit -a")

$ git status --short
 M notes.txt

$ git commit -a -m 'commit -a -m auto-stages modified TRACKED files'
[main 89c4076] commit -a -m auto-stages modified TRACKED files
 1 file changed, 1 insertion(+)

$ git status --short

$ git commit -a -m 'does commit -a -m catch UNTRACKED files?'
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	new.txt

nothing added to commit but untracked files present (use "git add" to track)

$ git status --short
?? new.txt

$ git log --oneline
89c4076 commit -a -m auto-stages modified TRACKED files
6cdbffd Initial commit: add notes.txt
```

### Reading the output

1. After editing the tracked file `notes.txt`, `git status --short` shows ` M notes.txt` - M in the second column = modified in the working directory, not staged.
2. `git commit -m` refused: "no changes added to commit (use \"git add\" and/or \"git commit -a\")". Nothing was staged, so there was nothing to commit.
3. `git commit -a -m` worked immediately - it staged the modified tracked file itself and produced commit `89c4076`.
4. Then a new, untracked file `new.txt` was created and `git commit -a -m` was run again: "nothing added to commit but untracked files present". This is the proof that `-a` ignores untracked files.
5. `git status --short` now shows `?? new.txt` - `??` = untracked, still waiting for a `git add`.

---

## Task 2: Git Cherry-Pick

### What cherry-pick is

`git cherry-pick <commit>` takes the changes introduced by one specific commit and replays them on top of the branch you are currently on. It is the answer to *"I need only that one bug fix from the feature branch on main - not the whole branch."*

A merge brings all commits of a branch. A cherry-pick brings exactly one (or a chosen few).

The replayed commit gets a new SHA because its parent is different - it is a copy of the change, not the same commit object.

### The steps performed

1. Created 3 commits on `main`
2. Viewed them with `git log --oneline`
3. Created a `feature` branch
4. Made 3 commits on `feature` (one of them the "important bugfix")
5. Used `git log` to identify that specific commit
6. Switched back to `main` and cherry-picked only that commit
7. Verified the change is now on `main`

### Commands and output

```console
########## TASK 2 : GIT CHERRY-PICK ##########

$ git init -q -b main

--- Step 1: create 3 commits on main ---

$ git add README.md && git commit -m 'main: commit 1 - add README'
[main (root-commit) a152116] main: commit 1 - add README
 1 file changed, 1 insertion(+)
 create mode 100644 README.md

$ git add app.txt && git commit -m 'main: commit 2 - add app.txt'
[main bab90bf] main: commit 2 - add app.txt
 1 file changed, 1 insertion(+)
 create mode 100644 app.txt

$ git add LICENSE.txt && git commit -m 'main: commit 3 - add LICENSE'
[main d5b01de] main: commit 3 - add LICENSE
 1 file changed, 1 insertion(+)
 create mode 100644 LICENSE.txt

--- Step 2: view commits with git log ---

$ git log --oneline
d5b01de main: commit 3 - add LICENSE
bab90bf main: commit 2 - add app.txt
a152116 main: commit 1 - add README

--- Step 3: create a new branch and make 3 commits on it ---

$ git checkout -b feature
Switched to a new branch 'feature'

$ git add login.txt && git commit -m 'feature: commit A - add login page'
[feature e9e0997] feature: commit A - add login page
 1 file changed, 1 insertion(+)
 create mode 100644 login.txt

$ git add bugfix.txt && git commit -m 'feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)'
[feature 7097a29] feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)
 1 file changed, 1 insertion(+)
 create mode 100644 bugfix.txt

$ git add darkmode.txt && git commit -m 'feature: commit C - experimental dark mode'
[feature 395ad52] feature: commit C - experimental dark mode
 1 file changed, 1 insertion(+)
 create mode 100644 darkmode.txt

--- Step 4: identify the specific commit to cherry-pick ---

$ git log --oneline
395ad52 feature: commit C - experimental dark mode
7097a29 feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)
e9e0997 feature: commit A - add login page
d5b01de main: commit 3 - add LICENSE
bab90bf main: commit 2 - add app.txt
a152116 main: commit 1 - add README

Commit chosen for cherry-pick : 7097a29

--- Step 5: switch to main and cherry-pick ONLY that commit ---

$ git checkout main
Switched to branch 'main'

$ git log --oneline
d5b01de main: commit 3 - add LICENSE
bab90bf main: commit 2 - add app.txt
a152116 main: commit 1 - add README

$ ls
app.txt
LICENSE.txt
README.md

$ git cherry-pick 7097a29
[main f304d19] feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)
 Date: Thu Sep 3 14:57:36 2026 +0530
 1 file changed, 1 insertion(+)
 create mode 100644 bugfix.txt

--- Step 6: verify the change is now on main ---

$ git log --oneline
f304d19 feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)
d5b01de main: commit 3 - add LICENSE
bab90bf main: commit 2 - add app.txt
a152116 main: commit 1 - add README

$ ls
app.txt
bugfix.txt
LICENSE.txt
README.md

$ cat bugfix.txt
feature: BUGFIX - fix null pointer on logout

$ git branch -v
  feature 395ad52 feature: commit C - experimental dark mode
* main    f304d19 feature: commit B - IMPORTANT bugfix (this one will be cherry-picked)
```

### Reading the output

* On `main` before the cherry-pick, `ls` showed only `app.txt LICENSE.txt README.md` and the log had 3 commits.
* The commit chosen was `7097a29` - "feature: commit B - IMPORTANT bugfix".
* `git cherry-pick 7097a29` created a new commit `f304d19` on `main` with the same message and the same change.
  The SHA is different (`7097a29` -> `f304d19`) because the parent commit is different - this is the single most important thing to understand about cherry-pick.
* After it: `ls` on `main` now includes `bugfix.txt`, and `cat bugfix.txt` shows the fix - but `login.txt` and `darkmode.txt` from the feature branch are not there. Only the one selected commit came across.
* `git branch -v` confirms `feature` still has all 3 of its commits; nothing was moved or lost.

### Useful cherry-pick options

| Command | What it does |
|---|---|
| `git cherry-pick <sha>` | apply one commit |
| `git cherry-pick <sha1> <sha2>` | apply several specific commits |
| `git cherry-pick A..B` | apply a range (excluding A) |
| `git cherry-pick -n <sha>` | apply the change but don't commit - leaves it staged |
| `git cherry-pick -x <sha>` | adds "(cherry picked from commit ...)" to the message - good practice on shared branches |
| `git cherry-pick --continue` | after resolving a conflict |
| `git cherry-pick --abort` | undo the whole thing and go back |

### When cherry-pick conflicts

If the same lines changed on both branches, git stops mid-cherry-pick:

```bash
# fix the conflicted files, then
git add <fixed-files>
git cherry-pick --continue

# or give up entirely
git cherry-pick --abort
```

---

## Interview notes

Q. Is `git commit -a -m` safe to use all the time?
It's convenient but blunt - it sweeps up every tracked file you happened to edit, including debug prints and unrelated changes, into one commit. For clean, reviewable history, `git add` the specific files and then `git commit -m`.

Q. Cherry-pick vs merge vs rebase?
`merge` brings a whole branch's history across and creates a merge commit. `rebase` replays your commits on top of another branch to keep history linear. `cherry-pick` copies selected individual commits - mainly used for hotfixes that need to go into a release branch without dragging in the rest of the feature work.

Q. Why does the cherry-picked commit have a different hash?
A commit's SHA is a hash of its content plus its parent and metadata. Replaying it on a different parent produces a different hash, so it is a new commit object carrying the same diff.

Q. What does `git status --short` output mean?
Two columns: staging area, then working directory. ` M` = modified but unstaged, `M ` = staged, `MM` = staged *and* modified again since, `??` = untracked, `A ` = newly added/staged, ` D` = deleted but unstaged.
