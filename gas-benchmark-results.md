# Gas Benchmark — 雙層合規架構成本量化

## 量測說明

- **量測環境**：Hardhat EVM（確定性執行環境）。給定相同 calldata 與 storage 狀態，gas 必然相同，故每個 case 先做一次預熱轉帳消除 SSTORE 0→非0 開戶成本，後測一次即為穩態 gas。
- **轉帳函數選擇**：L0/L1 使用 `transfer(to, amount)`（ERC-20 / ERC-3643 規範的主要轉帳入口）；L2/L3/L4 使用 `safeTransferFrom(from, to, id, amount, data)`（ERC-1155 規範本身未定義 `transfer()`，`safeTransferFrom` 為 ERC-1155 規範的主要轉帳入口）。兩者皆為各自代幣標準的最低成本轉帳路徑，符合公平比較原則。
- **架構分層**：L1 量測**底層靜態合規**（ERC-3643 身份/凍結/暫停）；L2/L3/L4 量測**外層動態合規**（PBM Wrapper → PolicyManager → Rules）。雙層在實務上於不同時機觸發——靜態合規於 wrap/unwrap 邊界攤銷，動態合規於每筆 PBM 轉帳付費。
- **同質規則設計**：L2/L3/L4 均使用同一種規則類型（`WhitelistRule`），但每條規則都是**獨立部署**的合約實例（不同地址、獨立 storage）。每次 `evaluate()` 在單筆 tx 內均為首次存取對應合約與 slot，皆觸發 EIP-2929 cold access。此設計排除「不同規則 evaluate() 內部成本不同」的變因，使邊際成本恆定，便於驗證架構的線性可擴展性。

> ETH 成本採用 5 gwei（反映 post-Dencun 升級後 Ethereum L1 平均 gas price 水準）；USD 換算採用 ETH = $2,355 假設。

| Level | Description | Gas | ETH @ 5 gwei | USD @ $2355/ETH | vs L0 | vs Previous |
|-------|-------------|----:|--------------:|----------------:|------:|------------:|
| L0 | ERC-20 transfer() — 無合規基線 | 34,137 | 0.0001707 | $0.4020 | 0.00% | — |
| L1 | ERC-3643 transfer() — 底層靜態合規（暫停/凍結/未凍結餘額/身份驗證/合規模組） | 93,027 | 0.0004651 | $1.0954 | 172.51% | 172.51% |
| L2 | PBM safeTransferFrom() — 外層動態合規 (rules=1, WHITELIST) | 217,209 | 0.0010860 | $2.5576 | 536.29% | 133.49% |
| L3 | PBM safeTransferFrom() — 外層動態合規 (rules=5, 同質: 5×WhitelistRule) | 353,243 | 0.0017662 | $4.1594 | 934.78% | 62.63% |
| L4 | PBM safeTransferFrom() — 外層動態合規 (rules=100, 同質: 100×WhitelistRule) | 3,592,008 | 0.0179600 | $42.2959 | 10422.33% | 916.87% |
