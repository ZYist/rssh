# 本地构建脚本(Windows 双击即用)

这几个 `.bat` 脚本封装了 RSSH(Tauri)在 Windows 上的本地构建流程,已内置 **NASM PATH 注入** 和 **Clash 代理**——双击即可,不用每次手敲环境变量。

> 脚本默认 `NASM_DIR=C:\Program Files\NASM`、代理 `http://127.0.0.1:7890`。若你的环境不同(NASM 装在别处、代理端口不一样),改各脚本顶部那两行即可。

## 前置依赖(一次性装好)

- **Node ≥20**、**Rust stable**、**MSVC C++ Build Tools**(VS 2022 BuildTools)
- **NASM**(winget `NASM.NASM`,默认装在 `C:\Program Files\NASM`,不加 PATH)
- npm 走 npmmirror、Rust crate 走 rsproxy.cn(国内加速)

## 脚本一览

| 脚本 | 实际命令 | 用途 | 大致耗时 |
|---|---|---|---|
| `build-frontend.bat` | `npm run build` | 只编译前端(Svelte/TS),最快确认没语法错 | ~3 秒 |
| `build-dev.bat` | `npm run tauri dev` | 热重载跑起来,改前端立刻看效果(常驻,Ctrl+C 退出) | 启动后常驻 |
| `build-exe.bat` | `npm run tauri build -- --no-bundle` | 只产出 `rssh.exe`,跳过安装包打包,拿来实测 | 增量 ~1–2 分钟 |
| `build-release.bat` | `npm run tauri build` | 完整打包:`rssh.exe` + `msi` + `nsis` 安装包 | 增量 ~1–2 分钟 + 打包 |

## 该用哪个?(按场景)

- **改了前端,想立刻看交互效果** → `build-dev`(热重载,边改边看)
- **改了前端,只想确认能编译** → `build-frontend`(3 秒,最快)
- **要一个 release 版 `rssh.exe` 自己跑 / 给作者测** → `build-exe`
- **改了 Rust,或要出安装包发布** → `build-release`
- **拿不准** → 先 `build-frontend` 快速排错,再 `build-exe` 出实测 exe

## 产物位置

```
src-tauri\target\release\
├─ rssh.exe                          ← build-exe / build-release 都出
└─ bundle\
   ├─ msi\RSSH_0.0.1_x64_en-US.msi   ← 仅 build-release
   └─ nsis\RSSH_0.0.1_x64-setup.exe  ← 仅 build-release
```

## 实例:本次 PR(#152)那几笔 commit 该用哪个

这三笔都是**纯前端改动**(没动 Rust),所以全程不需要 `build-release`:

| commit | 改了什么 | 推荐脚本 |
|---|---|---|
| `360ef69` | Alt+N 开关(状态 / UI / i18n) | `build-dev` 调试 → `build-exe` 出 exe 实测开关 |
| `4d85eb5` | Alt+N 改用 `e.code` | 同上(在 dev 里按 Alt+数字验证布局兼容) |
| `60aacb6` | 开关改名 + 简化描述 | `build-dev` 即可(纯文案改动) |

只有**改了 `src-tauri/` 下的 Rust 代码**,或**要发布安装包**时,才用 `build-release`。

## 常见坑

- **`NASM command not found`** → NASM 不在 PATH;脚本已注入,确认 `NASM_DIR` 路径正确。
- **`timeout: global`(打包阶段下载 WiX/NSIS)** → 代理没生效;确认 `PROXY` 端口和 Clash 正在运行。
- **首次全量编译很慢**(几分钟)→ 正常;后续增量会快很多(纯前端改动增量约 1–2 分钟,前端单独 `build-frontend` 仅 ~3 秒)。
