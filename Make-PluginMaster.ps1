# 设置错误处理模式为静默，防止脚本因非致命错误中断
$ErrorActionPreference = 'SilentlyContinue'

# 初始化输出列表，用于存储所有插件信息
$output = New-Object Collections.Generic.List[object]

# 定义下载链接模板（稳定版和测试版）
$dlTemplateInstall = "https://raw.githubusercontent.com/yanmucorp/PluginDistD17/main/stable/{0}/latest.zip"
$dlTemplateTesting = "https://raw.githubusercontent.com/yanmucorp/PluginDistD17/main/testing-live/{0}/latest.zip"

# 当前API级别（用于过滤兼容插件）
$apiLevel = 12

# 获取当前工作目录路径
$thisPath = Get-Location

# 处理主插件目录（stable文件夹）
Get-ChildItem -Path stable -File -Recurse -Include *.json | ForEach-Object {
    # 读取插件元数据文件
    $content = Get-Content $_.FullName | ConvertFrom-Json
    
    # 标记为可见
    $content | Add-Member -Force -Name "IsHide" -Value "False" -MemberType NoteProperty

    # 仅处理符合当前API级别的插件
    if ($content.DalamudApiLevel -eq $apiLevel) {
        # 检查测试版路径是否存在
        $testingPath = Join-Path $thisPath -ChildPath "testing-live" | 
                       Join-Path -ChildPath $content.InternalName | 
                       Join-Path -ChildPath $_.Name
        if (Test-Path $testingPath) {
            # 注入测试版程序集版本
            $testingContent = Get-Content $testingPath | ConvertFrom-Json
            $content | Add-Member -Force -Name "TestingAssemblyVersion" -Value $testingContent.AssemblyVersion -MemberType NoteProperty
            $content | Add-Member -Force -Name "TestingDalamudApiLevel" -Value $apiLevel -MemberType NoteProperty
        }
        $content | Add-Member -Force -Name "IsTestingExclusive" -Value "False" -MemberType NoteProperty

        # 验证插件ZIP文件存在性
        $internalName = $content.InternalName
        $path = "stable/$internalName/latest.zip"
        if (-not (Test-Path $path)) { exit 1 }

        # 获取最后更新时间（通过Git提交记录）
        $updateDate = git log -1 --pretty="format:%ct" $path
        if ($null -eq $updateDate) { $updateDate = 0 }
        $content | Add-Member -Force -Name "LastUpdate" $updateDate -MemberType NoteProperty

        # 生成安装链接（稳定版和测试版）
        $installLink = $dlTemplateInstall -f $internalName
        $content | Add-Member -Force -Name "DownloadLinkInstall" $installLink -MemberType NoteProperty
        $installLink = $dlTemplateTesting -f $internalName
        $content | Add-Member -Force -Name "DownloadLinkTesting" $installLink -MemberType NoteProperty
        $content | Add-Member -Force -Name "DownloadLinkUpdate" $installLink -MemberType NoteProperty

        # 将处理后的插件对象加入输出列表
        $output.Add($content)
    }
}

# 处理测试版插件目录（testing-live文件夹）
Get-ChildItem -Path testing-live -File -Recurse -Include *.json | ForEach-Object {
    $content = Get-Content $_.FullName | ConvertFrom-Json

    # 标记为可见
    $content | Add-Member -Force -Name "IsHide" -Value "False" -MemberType NoteProperty

    # 如果主目录不存在该插件，标记为测试独占
    if (($output | Where-Object { $_.InternalName -eq $content.InternalName }).Count -eq 0) {
        $content | Add-Member -Force -Name "TestingAssemblyVersion" -Value $content.AssemblyVersion -MemberType NoteProperty
        $content | Add-Member -Force -Name "IsTestingExclusive" -Value "True" -MemberType NoteProperty
        $content | Add-Member -Force -Name "TestingDalamudApiLevel" -Value $apiLevel -MemberType NoteProperty

        # 验证测试版ZIP文件
        $internalName = $content.InternalName
        $path = "testing-live/$internalName/latest.zip"
        if (-not (Test-Path $path)) { exit 1 }

        # 获取更新时间（Git提交记录）
        $updateDate = git log -1 --pretty="format:%ct" $path
        if ($null -eq $updateDate) { $updateDate = 0 }
        $content | Add-Member -Force -Name "LastUpdate" $updateDate -MemberType NoteProperty

        # 生成测试版专属链接
        $installLink = $dlTemplateTesting -f $internalName
        $content | Add-Member -Force -Name "DownloadLinkInstall" $installLink -MemberType NoteProperty
        $content | Add-Member -Force -Name "DownloadLinkTesting" $installLink -MemberType NoteProperty
        $content | Add-Member -Force -Name "DownloadLinkUpdate" $installLink -MemberType NoteProperty

        $output.Add($content)
    }
}

# 生成最终JSON输出
$outputStr = $output | ConvertTo-Json -Depth 10  # 确保深层对象序列化
Out-File -FilePath .\pluginmaster.json -InputObject $outputStr -Encoding UTF8  # 强制UTF8编码
