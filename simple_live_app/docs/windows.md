# Windows 本地运行

仓库路径较长时，`flutter_inappwebview_windows` 生成的中间文件会超过 Windows 260 字符限制（`MSB3491`），构建直接失败。用 `subst` 映射一个短盘符再编译即可。

## 前置

- Visual Studio 2022 Build Tools（含 C++ 桌面开发 / Windows SDK）
- [NuGet CLI](https://www.nuget.org/downloads) 在 PATH 里（`flutter_inappwebview_windows` 用它拉 WebView2 等依赖）。确认：`nuget help`
- Flutter 3.47（可用 fvm）

当前 PowerShell 若刚装过 NuGet、还找不到命令，先刷新 PATH：

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

## 运行

把 `<仓库根目录>` 换成本机 clone 路径，例如 `C:\Users\zeke\Desktop\work\dart_simple_live`：

```powershell
subst S: <仓库根目录>
cd S:\simple_live_app
fvm flutter clean
fvm flutter run -d windows
```

`subst` 只对当前会话有效，重启或新开终端后需要再执行一次。用完可取消映射：

```powershell
subst S: /d
```

不需要 `clean` 时，映射后直接 `fvm flutter run -d windows` 即可。

## 常见问题

| 报错 | 原因 | 处理 |
|---|---|---|
| `MSB3491` 路径超过 260 字符 | 工程路径太长 | 用上面的 `subst` |
| `NUGET-NOTFOUND` / 退出码 9009 | PATH 里没有 `nuget.exe` | 安装 NuGet CLI，刷新 PATH 后 `flutter clean` 再编 |
| `C4819` / `C2220` 警告当错误 | 中文 Windows 代码页 936 | 已在 `windows/CMakeLists.txt` 加了 `/utf-8` 和 `/wd4819` |
| CMake `CMP0175` / `DEPENDS` | `flutter_inappwebview_windows` 插件 CMake 写法不规范 | 可忽略，不影响构建 |
