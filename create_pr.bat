@echo off
setlocal enabledelayedexpansion

REM Accept branch name and commit message as input arguments
set branchName=%1
set commitMessage=%2

REM Trim leading and trailing spaces from commitMessage
for /f "tokens=* delims=" %%A in ("%commitMessage%") do set commitMessage=%%A

if "%branchName%"=="" (
    echo Error: Branch name is required.
    exit /b 1
)

@REM if "%commitMessage%"=="" (
@REM     echo Error: Commit message is required.
@REM     exit /b 1
@REM )

REM Stash any uncommitted changes first with provided commit message
git stash push 
if %errorlevel% neq 0 (
    echo Error: Failed to stash changes.
    exit /b 1
)

REM Create a branch from jc-main
git checkout jc-main
git pull origin jc-main
git checkout -b %branchName%
if %errorlevel% neq 0 (
    echo Error: Failed to create or switch to branch %branchName%.
    exit /b 1
)

REM Apply stashed changes to the new branch
git stash pop
if %errorlevel% neq 0 (
    echo Error: Failed to apply stashed changes.
    exit /b 1
)

REM Commit the changes on the new branch
git add .
git commit -m "!commitMessage!"
if %errorlevel% neq 0 (
    echo Error: Commit failed.
    exit /b 1
)

REM Get the commit hash
for /f "delims=" %%i in ('git rev-parse HEAD') do set commitHash=%%i

REM Switch to qa-consumer branch and create a new branch
git checkout qa-consumer
git pull origin qa-consumer
set qaBranch=%branchName%-qa
git checkout -b %qaBranch%
if %errorlevel% neq 0 (
    echo Error: Failed to create or switch to QA branch.
    exit /b 1
)

REM Cherry-pick the commit to the QA branch
git cherry-pick %commitHash%
if %errorlevel% neq 0 (
    echo Error: Cherry-pick to QA branch failed.
    exit /b 1
)

REM Switch to jc-pre-prod branch and create a new branch
git checkout jc-pre-prod
git pull origin jc-pre-prod
set preProdBranch=%branchName%-pre-prod
git checkout -b %preProdBranch%
if %errorlevel% neq 0 (
    echo Error: Failed to create or switch to Pre-Prod branch.
    exit /b 1
)

REM Cherry-pick the commit to the Pre-Prod branch
git cherry-pick %commitHash%
if %errorlevel% neq 0 (
    echo Error: Cherry-pick to Pre-Prod branch failed.
    exit /b 1
)

REM Push all branches to remote
git push origin %branchName%
git push origin %qaBranch%
git push origin %preProdBranch%

REM Create a PR
set prTitle=JC-MAIN :: [JC-PRE-PROD] :: [ %commitMessage% ]
for /f "delims=" %%i in ('gh pr create --title "%prTitle%" --base jc-main --body "Auto-generated PR from script"') do set prLink=%%i

if "%prLink%"=="" (
    echo Error: Failed to create PR.
    exit /b 1
)

REM Print PR link
echo Pull Request created: %prLink%
exit /b 0
