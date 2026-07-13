# mgb-vul.ps1

MGB FEP 專案原始碼複製工具，用於產生僅含來源碼的副本以供弱點掃描使用。

## 功能說明

此腳本將 MGB FEP 專案的原始碼從來源目錄複製到本地輸出資料夾，過程中會：

1. **排除 .gitignore 中標示的目錄** — 讀取指定的 `.gitignore` 檔案，解析其中的目錄規則，跳過符合條件的資料夾。
2. **排除特定資料夾** — 固定排除 `fep-suipConnect` 與 `fep-bpm` 兩個目錄。
3. **過濾測試檔案** — 移除 `src/test/` 路徑下的檔案，但保留檔名包含下列關鍵字的例外檔案：
   - `BatchTaskUtil`
   - `AssemblyPropFileGenerator`
   - `ReleaseNoteGenerator`
   - `RemoveVersion`
4. **清除空目錄** — 複製完成後自動刪除目的地中所有空資料夾。

## 參數

| 參數 | 預設值 | 說明 |
|------|--------|------|
| `-SourceRoot` | `$MgbFepRepo/source/fep` | 來源目錄路徑 |
| `-DestinationRoot` | `<腳本目錄>/output/fep` | 輸出目錄路徑（必須位於腳本目錄之下） |
| `-GitIgnoreFiles` | `$MgbFepRepo/.gitignore`、`$MgbFepRepo/source/.gitignore` | 要解析的 .gitignore 檔案清單 |
| `-ExtraExcludedDirectories` | `fep-suipConnect`、`fep-bpm` | 額外排除的目錄名稱 |
| `-KeepTestNameParts` | `BatchTaskUtil`、`AssemblyPropFileGenerator`、`ReleaseNoteGenerator`、`RemoveVersion` | 即使在 `src/test/` 下也要保留的檔名關鍵字 |

## 使用方式

### 基本執行

```powershell
./mgb-vul.ps1
```

### 自訂來源與目的地

```powershell
./mgb-vul.ps1 -SourceRoot "/path/to/source" -DestinationRoot "/path/to/output"
```

### 預覽模式（不實際執行）

```powershell
./mgb-vul.ps1 -WhatIf
```

## 執行結果輸出

腳本結束後會顯示以下統計資訊：

```
Source: <來源路徑>
Destination: <輸出路徑>
Copied files: <已複製檔案數>
Skipped by gitignore directories: <因 gitignore 跳過的檔案數>
Skipped src/test files: <因測試目錄跳過的檔案數>
Kept src/test file name parts: BatchTaskUtil, AssemblyPropFileGenerator, ReleaseNoteGenerator, RemoveVersion
```

## 注意事項

- 每次執行會**完整清除並重建**目的地目錄。
- 目的地路徑不可設定在來源路徑之內，且必須位於腳本所在目錄之下。
- 支援 `-WhatIf` 與 `-Verbose` 等 PowerShell 標準參數。
- **腳本不指定 branch**，複製內容取決於執行當下來源 repo（`mgbfep`）所 checkout 的 branch。執行前請先確認來源 repo 已切換至正確的 branch。
- **來源 repo 路徑**統一由腳本開頭的 `$MgbFepRepo` 變數控制（預設 `$HOME/Repo/idea_clone/mgbfep`），若本機路徑不同只需修改此一變數，或透過 `-SourceRoot` / `-GitIgnoreFiles` 參數覆寫。
