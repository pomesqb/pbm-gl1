# Latency Benchmark — 合規架構延遲量化

## 量測說明

- **量測環境**：Hardhat（in-process EVM）。本實驗量測合規架構引入的執行時間，**不含區塊確認時間**——區塊時間屬底層鏈特性（Ethereum L1 ~12s、L2 ~2s），與本研究探討的合規架構設計無關，且對所有路徑為共同常數，不影響相對比較。
- **指標**：`performance.now()` 量 wall-clock，從 tx 提交到 receipt 完整時間。鏈下路徑（M5/M6）額外包含 HTTP roundtrip + server AML 比對 + ECDSA 簽章。
- **統計方法**：每個 case 預熱 1 次後跑 N=100 次，報中位數 (median) 與 IQR (P25–P75)。採中位數而非平均，避免 GC、OS scheduler 偶發 outlier 污染。
- **架構分層**：M1 量測底層靜態合規（ERC-3643）；M2/M3/M4 量測純鏈上動態合規（規則鏈執行）；M5/M6 量測鏈下檢驗（ProofSet 機制）。
- **與 Gas Benchmark 對應**：M0↔L0（純 ERC-20）、M1↔L1（ERC-3643）、M2↔L2、M3↔L3、M4↔L4；M5/M6 為鏈下路徑，gas benchmark 無對應 case。

| Case | Description | N | Median (ms) | P25 | P75 | Min | Max | Mean | vs M0 |
|------|-------------|--:|------------:|----:|----:|----:|----:|-----:|------:|
| M0 | ERC-20 transfer — 無合規基線 | 100 | 2.09 | 1.78 | 2.66 | 1.47 | 6.44 | 2.34 | 0.00% |
| M1 | ERC-3643 transfer — 底層靜態合規（凍結/暫停/身份/合規模組） | 100 | 2.72 | 2.45 | 3.59 | 1.95 | 20.05 | 3.39 | 30.42% |
| M2 | PBM safeTransferFrom — 純鏈上 (rules=1, WhitelistRule) | 100 | 4.02 | 3.63 | 4.91 | 2.83 | 16.50 | 4.65 | 92.20% |
| M3 | PBM safeTransferFrom — 純鏈上 (rules=5) | 100 | 6.67 | 5.60 | 7.79 | 4.64 | 30.39 | 7.57 | 219.24% |
| M4 | PBM safeTransferFrom — 純鏈上 (rules=100) | 100 | 64.96 | 53.73 | 93.26 | 39.83 | 438.66 | 82.89 | 3009.15% |
| M5 | safeTransferFromWithProof — 鏈下檢驗 (AML 名單=1,000) | 100 | 9.00 | 7.31 | 10.76 | 5.73 | 30.83 | 9.54 | 330.92% |
| M6 | safeTransferFromWithProof — 鏈下檢驗 (AML 名單=1,000,000) | 100 | 22.20 | 20.17 | 25.52 | 15.94 | 61.38 | 23.31 | 962.65% |

## 觀察重點

- **M2 → M3 → M4**：純鏈上路徑隨規則數成長（線性 / 近線性），規則越多延遲越大。
- **M5 ≈ M6**：鏈下路徑不論 AML 名單從 1k 放大到 1M，鏈上仍只 `_verifyProofSet()` 驗一次章，鏈上耗時近乎不變；HTTP + server 計算為主要成本。
- **Crossover 點**：當鏈上規則數超過某門檻，純鏈上延遲 > 鏈下延遲。此即論文 §2-8 「鏈下與鏈上驗證權衡」 的定量支持點。
