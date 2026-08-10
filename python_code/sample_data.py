# -*- coding: utf-8 -*-
"""按用户等概率抽样：先收集全部去重 user_id，random.seed(42) + shuffle 取前 10%，
第二遍扫描写出抽样用户的全部行为行。

3.5GB 源文件必须分块读取（pd.read_csv chunksize），禁止一次性 read_csv 载入全量。
输出 data/UserBehavior_sample.csv，并打印实测统计供写进 README。
"""
import random
import time
import pandas as pd
from pathlib import Path

SEED = 42          # 固定种子：抽样可复现
RATE = 0.10        # 抽样比例 10%
CHUNK = 5_000_000  # 每块行数，控制峰值内存

SRC = Path(__file__).resolve().parent.parent / "data" / "UserBehavior.csv"
DST = Path(__file__).resolve().parent.parent / "data" / "UserBehavior_sample.csv"

COLUMNS = ["user_id", "item_id", "category_id", "behavior_type", "timestamp"]
DTYPES = {
    "user_id": "int64",
    "item_id": "int64",
    "category_id": "int64",
    "behavior_type": "str",
    "timestamp": "int64",
}


def scan_users():
    """第一遍：逐块扫描，收集全部去重 user_id。"""
    all_users = set()
    reader = pd.read_csv(SRC, header=None, names=COLUMNS, dtype=DTYPES, chunksize=CHUNK)
    for chunk in reader:
        all_users.update(chunk["user_id"].unique().tolist())
    return all_users


def write_sample(all_users, sample_users):
    """第二遍：逐块扫描，只写抽样用户的全部行为行。"""
    first = True
    reader = pd.read_csv(SRC, header=None, names=COLUMNS, dtype=DTYPES, chunksize=CHUNK)
    with open(DST, "w", newline="") as f:
        for chunk in reader:
            sub = chunk[chunk["user_id"].isin(sample_users)]
            sub.to_csv(f, header=first, index=False)
            first = False


def main():
    t0 = time.time()
    print("[1/3] 第一遍扫描：收集全量去重 user_id ...")
    all_users = scan_users()
    n_users = len(all_users)
    print(f"      全量去重用户数: {n_users}  (耗时 {time.time()-t0:.0f}s)")

    # 排序保证可复现，固定种子后 shuffle 取前 10%
    user_list = sorted(all_users)
    random.seed(SEED)
    random.shuffle(user_list)
    n_sample = int(len(user_list) * RATE)
    sample_users = set(user_list[:n_sample])
    actual_rate = len(sample_users) / len(user_list) * 100
    print(f"[2/3] 抽样用户数: {len(sample_users)}，实际占比: {actual_rate:.4f}%  (种子={SEED})")

    print("[3/3] 第二遍扫描：写出抽样用户的全部行为行 ...")
    t1 = time.time()
    write_sample(all_users, sample_users)
    print(f"      写出完成，耗时 {time.time()-t1:.0f}s")

    n_rows = sum(1 for _ in open(DST, encoding="utf-8"))
    print("\n===== 实测统计（写进 README） =====")
    print(f"全量用户数: {n_users}")
    print(f"抽样用户数: {len(sample_users)}")
    print(f"实际占比:   {actual_rate:.4f}%")
    print(f"抽样行数:   {n_rows} (含表头 1 行)")
    print(f"输出文件:   {DST}")
    print(f"总耗时:     {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
