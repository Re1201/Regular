# Taobao — 电商用户行为运营分析项目


## 目录说明

| 目录/文件 | 内容 |
|---|---|
| `data/` | 源数据 `UserBehavior.csv`（3.67GB，1亿行，无表头，逗号分隔，字段：user_id,item_id,category_id,behavior_type,timestamp）。抽样后产出 `UserBehavior_sample.csv` |
| `python_code/` | Python 脚本：数据抽样、看板可视化 |
| `sql_code/` | 重写后的分析 SQL（01 清洗 → 02 漏斗 → 03 分层 → 04 留存 → 05 时段 → 06 类目） |

## 数据抽样约定（重要）

- **方法**：按用户等概率简单随机抽样（抽人不抽行），`random.seed(42)` 固定种子，shuffle 取前 10%（精确比例）
- **产出**：`data/UserBehavior_sample.csv`，约 10% 用户（预估约 10 万用户、1000 万行，以实测为准）
- **口径**：导入 MySQL 的就是抽样后的数据，建表 `user_behavior_sample`，后续所有 SQL 查此表
- **可复现**：种子 42 + 实际抽样用户数 + 实际占比记录在 README

## 数据来源

阿里云天池 · 淘宝用户购物行为数据集（dataset 649）
https://tianchi.aliyun.com/dataset/649
2017-11-25 至 2017-12-03，9 天窗口，用户全链路行为（pv/fav/cart/buy）
