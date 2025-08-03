@echo off
setlocal enabledelayedexpansion

:: 设置Git仓库路径（根据实际情况修改）
set REPO_PATH=F:\GitRepository\GitHub\scripts

:: 确保仓库目录正确
if not exist "%REPO_PATH%\.git" (
    echo Error: .git directory not found! Please check if the repository path is correct.
    pause
    exit /b 1
)
:: 提示输入commit消息
set /p commit_msg="Please input commit message (Press Enter to use default 'update'): "
:: 如果用户没有输入，使用默认值
if "!commit_msg!"=="" (
    set commit_msg=update
)
:: 检查是否有文件更改需要提交
for /f %%i in ('git -C "%REPO_PATH%" status --porcelain') do (
    goto :has_changes
)
echo No changes to commit.
pause
exit /b 0
:has_changes
:: 执行git add
echo Adding files to staging area...
git -C "%REPO_PATH%" add .
if errorlevel 1 (
    echo Error: Git add failed!
    pause
    exit /b 1
)
:: 执行git commit
echo Committing changes...
git -C "%REPO_PATH%" commit -m "!commit_msg!"
if errorlevel 1 (
    echo Error: Git commit failed!
    pause
    exit /b 1
)
:: 执行git push（默认 master branch）
echo Pushing to remote repository...
git -C "%REPO_PATH%" push origin master
if errorlevel 1 (
    echo Error: Git push failed!
    pause
    exit /b 1
)
echo Push completed successfully!
pause
