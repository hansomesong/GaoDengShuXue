@echo off

:: 为了用中文显示输出信息，批处理文件需要用 gbk 编码

:: 下列命令将控制台变成 utf8 编码，但是编译 tex 时中文目录还是乱码
:: chcp 65001 

rem http://stackoverflow.com/a/12408045/1334431
rem 不管用 :: 还是用 rem，只要注释中包含 ％～ 将会出错，但 %%~ 没问题

set curdir=%cd%

%~d0
cd %~dp0
::echo %~dp0
cd ..
::echo %cd%

setlocal enabledelayedexpansion

::echo. & echo [1] 仅编译文档 [2] 仅打包文档 [3] 编译并打包文档 & echo.
::set /p task=########## 请输入所需要执行的任务编号：

::if "%task%"=="2" goto :makezip

:: for 循环将无法查找隐藏文件，可以改用 forfiles，但是对已经隐藏的文件就不应该处理
:: 实际上，用 forfiles 也不方便，因为它每次只能匹配一种文件类型

::forfiles -m *.aux -c "cmd /c attrib +S +H @file"
::forfiles -m *.bak -c "cmd /c attrib +S +H @file"
::forfiles -m *.log -c "cmd /c attrib +S +H @file"
::forfiles -m *.nav -c "cmd /c attrib +S +H @file"
::forfiles -m *.out -c "cmd /c attrib +S +H @file"
::forfiles -m *.sav -c "cmd /c attrib +S +H @file"
::forfiles -m *.snm -c "cmd /c attrib +S +H @file"
::forfiles -m *.synctex -c "cmd /c attrib +S +H @file"
::forfiles -m *.synctex.gz -c "cmd /c attrib +S +H @file"
::forfiles -m *.toc -c "cmd /c attrib +S +H @file"

::echo. & echo ---------- Hide all auxiliary files ----------

:: 隐藏的文件 xelatex 和 pdflatex 无法写入，因此此方法不可行
::for %%A in (*.aux,*.bak,*.log,*.nav,*.out,*.sav,*.snm,*.synctex,*.synctex.gz,*.toc) do (
::  echo ++++++++++ %%A
::  attrib +S +H %%A
::)

::goto :end

::set outdir=output

:: 若 auxiliary 和 output 目录不存在，创建它们

::if not exist auxiliary mkdir auxiliary
::if not exist %outdir% mkdir %outdir%

::set option=-aux-directory=auxiliary -output-directory=output -quiet
::set option=-aux-directory=auxiliary -output-directory=output
set option=-quiet -synctex=1

::pause

:: for 命令用于控制台时用 %i，用于脚本时用 %%i

:::: for 循环中用新变量需要注意，下面例子中输出结果都是最后一个文件名
::for %%i in (gdsx*.tex) do (
::  set test=%%~ni
::  echo test=%test%
::)
:::: 打开 enabledelayedexpansion 选项，然后用 !test! 就可以解决此问题，用 set /? 查看帮助
::setlocal enabledelayedexpansion
::for %%i in (gdsx*.tex) do (
::  set test=%%~ni
::  echo test=!test!
::)
::endlocal

:: forfiles 虽然可以显示文件修改时间的秒数，但月份小于10时会省略前面的零，导致用 gtr 不好比较
:: 因此，两者应该一并使用，先用 %%~ti，如果相等的话再用 forfiles 比较秒数 

:: 在 for 循环中不能用 goto，而应该 call 子程序然后用 exit /b 退回

for /d %%I in (%~n0*) do (
  echo.
  set texbase=%%I
  set texfile=%%I.tex
  set pdffile=%%I.pdf
  call :findfile
  REM if exist %%I\%%I-note.tex (
    REM set texfile=%%I-note.tex
    REM set pdffile=%%I-note.pdf
    REM call :findfile
  REM )
  REM if exist %%I\%%I-slide.tex (
    REM set texfile=%%I-slide.tex
    REM set pdffile=%%I-slide.pdf
    REM call :findfile
  REM )
  if exist %%I\%%I-print.tex (
    set texfile=%%I-print.tex
    set pdffile=%%I-print.pdf
    call :findfile
  )
  if exist %%I\%%I-i.tex (
    set texfile=%%I-i.tex
    set pdffile=%%I-i.pdf
    call :findfile
  )
  if exist %%I\%%I-print-i.tex (
    set texfile=%%I-print-i.tex
    set pdffile=%%I-print-i.pdf
    call :findfile
  )
  if exist %%I\%%I-o.tex (
    set texfile=%%I-o.tex
    set pdffile=%%I-o.pdf
    call :findfile
  )
  if exist %%I\%%I-print-o.tex (
    set texfile=%%I-print-o.tex
    set pdffile=%%I-print-o.pdf
    call :findfile
  )
)

goto :makezip

:findfile
if not exist !texbase!\!pdffile! (
  :: echo not exist !texbase!\!pdffile!
  call :build
) else (
  for %%J in (!texbase!\!pdffile!) do (
    set pdftime=%%~tJ
    ::echo !pdftime! for %%J
    call :compare
  )
)
exit /b

:: 1、for /f %%i in (文件名) do (??)
:: 2、for /f %%i in ('命令语句') do (??)
:: 3、for /f %%i in ("字符串") do (??)
:: 4、for /f "usebackq" %%i in ("文件名") do (??)
:: 5、for /f "usebackq" %%i in (`命令语句`) do (??)
:: 6、for /f "usebackq" %%i in ('字符串') do (??)

:compare
:: http://stackoverflow.com/a/16727927
for %%K in (!texbase!\*.tex) do (
  ::echo %%~tK for %%K
  if "!pdftime!" lss "%%~tK" (
    :: !pdffile! file is old
    call :build
    exit /b
  ) else if "!pdftime!" equ "%%~tK" (
    ::echo compare file time with second
    rem 用 | 管道符直接重定向控制台输出到字符串是不成功的：
    rem echo hello > set /p myvar=
    rem 因此这里改用 for /f 的方法
    rem http://stackoverflow.com/a/14965458/1334431
    for /f "tokens=*" %%L in ('forfiles /p !texbase! /m %%~nxK /c "cmd /c echo @fdate @ftime"') do (
      set texsec=%%L
    )
    for /f "tokens=*" %%L in ('forfiles /p !texbase! /m !pdffile! /c "cmd /c echo @fdate @ftime"') do (
      set pdfsec=%%L
    )
    rem 批处理中的 :: 实际不是标准的做法
    rem 例如下面两行改为 :: 会导致错误："系统找不到指定的驱动器"
    rem 将 :: 注释改为 rem 注释就能解决此问题
    rem 实际原始是 ( ) 中的连续两行 :: 注释就会导致问题
    rem http://stackoverflow.com/q/12407800/1334431
    rem http://stackoverflow.com/a/4006006/1334431
    rem echo !pdfsec:~-8! for !pdffile!
    rem echo !texsec:~-8! for %%~nxK
    if "!texsec:~-2!" gtr "!pdfsec:~-2!" (
      echo. need build 
      call :build
      exit /b
    )
  )
)
echo ---------- No changes in !texfile! ----------
exit /b

:build
echo ---------- Compiling new !texfile! ----------
:: xelatex -job-name=!texbase!-slide %option% !texfile!
:: xelatex -job-name=!texbase!-slide %option% !texfile!
:: xelatex -job-name=!texbase!-print %option% "\def\handout{}\input{!texfile!}"
:: xelatex -job-name=!texbase!-print %option% "\def\handout{}\input{!texfile!}"
cd !texbase!
echo ++++++++++ compile !texfile! once
:: http://stackoverflow.com/a/6817833/1334431
:: 用 && 和 || 比用 %errorlevel% 更方便
:: xelatex 1>nul %option% !texfile! && (echo success) || (echo error!)
:: 对很多命令，执行成功 %errorlevel% 等于 0，失败则等于 1
:: echo %errorlevel%
xelatex 1>nul %option% !texfile! || (
  echo ++++++++++ some errors in !texfile!
  set error=true
  exit /b
)
echo ++++++++++ compile !texfile! twice
xelatex 1>nul %option% !texfile!
cd ..
exit /b

:makezip

::if "%task%"=="1" goto :end
if "%error%"=="true" goto :end

if not exist backup mkdir backup

echo. & echo ---------- Make all files into zips ----------

:: 日期输出的格式可能与操作系统的语言有关
set curdate=%date:~2,2%%date:~5,2%%date:~8,2%

set filelist=binary\* common\*
for /d %%I in (%~n0*) do (
  for %%K in (%%I\*.tex,%%I\%%I.pdf,%%I\%%I-*.pdf,%%I\*.jpg,%%I\*.png,,%%I\*.gif) do (
    set filelist=!filelist! %%K
  )
)
::echo !filelist!

:: 在 EnableDelayedExpansion 中，! 是特殊字符，需要用 ^^! 转义
:: 见 http://www.robvanderwoude.com/escapechars.php

echo ++++++++++ packaging %~n0-%curdate%.zip
if exist backup\%~n0-%curdate%.zip del /q backup\%~n0-%curdate%.zip
binary\7z.exe 1>nul a -tzip -xr^^!*.bak backup\%~n0-%curdate%.zip !filelist!

echo ++++++++++ packaging %~n0-%curdate%-tex.zip
if exist backup\%~n0-%curdate%-tex.zip del /q backup\%~n0-%curdate%-tex.zip
binary\7z.exe 1>nul a -tzip -xr^^!*.bak -xr^^!*.pdf backup\%~n0-%curdate%-tex.zip !filelist!

:: 以点开头的文件，压缩时将不保持该目录
set filelist=
for /d %%I in (%~n0*) do (
  set filelist=!filelist! .\%%I\%%I.pdf .\%%I\%%I-*.pdf
)
::echo !filelist!

echo ++++++++++ packaging %~n0-%curdate%-pdf.zip
if exist backup\%~n0-%curdate%-pdf.zip del /q backup\%~n0-%curdate%-pdf.zip
binary\7z.exe 1>nul a -tzip backup\%~n0-%curdate%-pdf.zip !filelist!

::for /d %%I in (%~n0*) do (
::  copy 1>nul /y %%I\%%I.pdf %outdir%
::  copy 1>nul /y %%I\%%I-print.pdf %outdir%
::)
::cd !outdir!
::%~dp0common\7z.exe 1>nul a -tzip %~dp0backup\%~n0-%curdate%-pdf.zip *
::cd ..

:end

if "%error%"=="true" (
  echo. & echo ========== 任务执行出现错误，已中止 ==========
) else (
  echo. & echo ========== 所有的任务都已经执行完毕 ==========
)
set /p p=

::pause

endlocal

cd %curdir%

:: -synctex=1 似乎无效，但是 -synctex=-1 有效

:: -aux-directory=DIR              Use DIR as the directory to write auxiliary files to.
:: -include-directory=DIR          Prefix DIR to the input search path.
:: -job-name=NAME
:: -output-directory=DIR
