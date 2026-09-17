# -*- coding: utf-8 -*-
"""回归对撞：独立从 data/UserBehavior_sample.csv 重算全部指标，逐项与 results/*.csv 比对。

用途：任何对 sql_code/ 的改动，重跑 run_sql.py 之后跑本脚本，即可确认 15 个结果文件
      的数字仍与"从原始抽样集独立重算"的结果一致。它是"结果可溯源、可复现"的守门人。

口径（与 sql_code/ 保持一致）：
  * 漏斗 = 序列口径（t_pv < t_cart < t_buy）
  * R    = 最近一次"购买"距 2017-12-03 的天数
  * 留存 = 窗口外不可观测，输出 NULL（CSV 空值）
  * 时段 = 星期维度按"逐日值取平均"计算日均

依赖：需要 data/UserBehavior_sample.csv 已生成（先跑 sample_data.py）。
用法：python python_code/regression_check.py
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "results"
SRC = ROOT / "data" / "UserBehavior_sample.csv"
LO, HI = 1511539200, 1512316799          # 2017-11-25 00:00:00 ~ 12-03 23:59:59 (UTC+8)
END = pd.Timestamp("2017-12-03 23:59:59", tz="Asia/Shanghai").timestamp()

ok_all = True


def check(name, mine, theirs, tol=0.0):
    global ok_all
    if mine is None and theirs is None:
        good = True
    elif mine is None or theirs is None:
        good = False
    elif isinstance(mine, float) or isinstance(theirs, float):
        good = abs(float(mine) - float(theirs)) <= tol
    else:
        good = int(mine) == int(theirs)
    if not good:
        ok_all = False
    print(f"  [{'PASS' if good else 'FAIL'}] {name}: 重算={mine} 结果文件={theirs}")


df = pd.read_csv(SRC, dtype={"user_id": "int64", "item_id": "int64", "category_id": "int64",
                            "behavior_type": "object", "timestamp": "int64"})
c = df[df.behavior_type.isin(["pv", "fav", "cart", "buy"]) &
       (df.timestamp >= LO) & (df.timestamp <= HI) & (df.category_id > 0)].copy()
dt = pd.to_datetime(c.timestamp, unit="s", utc=True).dt.tz_convert("Asia/Shanghai")
c["date"] = dt.dt.strftime("%Y-%m-%d")
c["hour"] = dt.dt.hour
c["wd"] = dt.dt.day_name()

print("=== 01 清洗 ===")
check("清洗后行数", len(c), int(pd.read_csv(RES / "01_2.csv", encoding="utf-8-sig").iloc[0, 1]))
check("剔除行数", len(df) - len(c), int(pd.read_csv(RES / "01.csv", encoding="utf-8-sig").iloc[0, 1]))
b3 = pd.read_csv(RES / "01_3.csv", encoding="utf-8-sig").set_index("behavior_type")
for b in ["pv", "cart", "fav", "buy"]:
    check(f"{b} 行为数", (c.behavior_type == b).sum(), int(b3.loc[b, "行为数"]))
    check(f"{b} 用户数", c.loc[c.behavior_type == b, "user_id"].nunique(), int(b3.loc[b, "用户数"]))

print()
print("=== 02 序列漏斗 ===")
p = c.pivot_table(index="user_id", columns="behavior_type", values="timestamp", aggfunc="min")
for b in ["pv", "cart", "buy", "fav"]:
    if b not in p:
        p[b] = np.nan
s1 = p.pv.notna()
s2 = p.cart.notna() & p.pv.notna() & (p.cart > p.pv)
s3 = p.buy.notna() & p.cart.notna() & p.pv.notna() & (p.cart > p.pv) & (p.buy > p.cart)
n1, n2, n3 = int(s1.sum()), int(s2.sum()), int(s3.sum())
f1 = pd.read_csv(RES / "02.csv", encoding="utf-8-sig").set_index("环节")["用户数"]
check("浏览用户", n1, int(f1["浏览"]))
check("加购用户", n2, int(f1["加购"]))
check("购买用户", n3, int(f1["购买"]))
f2 = pd.read_csv(RES / "02_2.csv", encoding="utf-8-sig").iloc[0]
check("浏览到加购转化率", round(n2 * 100.0 / n1, 2), float(f2["浏览到加购转化率"]), 0.01)
check("加购到购买转化率", round(n3 * 100.0 / n2, 2), float(f2["加购到购买转化率"]), 0.01)
check("全链路转化率", round(n3 * 100.0 / n1, 2), float(f2["全链路转化率"]), 0.01)
check("浏览到加购流失率", round((1 - n2 / n1) * 100, 2), float(f2["浏览到加购流失率"]), 0.01)
check("加购到购买流失率", round((1 - n3 / n2) * 100, 2), float(f2["加购到购买流失率"]), 0.01)
f3 = pd.read_csv(RES / "02_3.csv", encoding="utf-8-sig").set_index("类型")
fav = p.fav.notna()
buy = p.buy.notna()
check("收藏用户转化率", round(buy[fav].mean() * 100, 2), float(f3.loc["收藏用户", "购买转化率"]), 0.01)
check("未收藏用户转化率", round(buy[~fav].mean() * 100, 2), float(f3.loc["未收藏用户", "购买转化率"]), 0.01)

print()
print("=== 03 RF 分层（R = 最近购买） ===")
last_buy = c[c.behavior_type == "buy"].groupby("user_id")["timestamp"].max()
F = c[c.behavior_type == "buy"].groupby("user_id").size()
u = pd.DataFrame({"R": ((END - last_buy) // 86400).astype(int), "F": F})
u["Rs"] = np.select([u.R <= 1, u.R <= 3, u.R <= 7, u.R <= 15], [5, 4, 3, 2], default=1)
u["Fs"] = np.select([u.F >= 5, u.F >= 3, u.F >= 2, u.F >= 1], [5, 4, 3, 2], default=1)
u["分层"] = np.select([(u.Rs >= 4) & (u.Fs >= 4), (u.Rs >= 3) & (u.Fs >= 3)], ["高价值", "潜力"], default="普通")
g = u.groupby("分层").agg(用户数=("F", "size"), 贡献=("F", "sum"))
g["用户占比"] = (g.用户数 / g.用户数.sum() * 100).round(2)
g["购买贡献占比"] = (g.贡献 / g.贡献.sum() * 100).round(2)
r3 = pd.read_csv(RES / "03.csv", encoding="utf-8-sig").set_index("分层")
for lay in ["高价值", "潜力", "普通"]:
    check(f"{lay} 用户数", g.loc[lay, "用户数"], int(r3.loc[lay, "用户数"]))
    check(f"{lay} 用户占比", g.loc[lay, "用户占比"], float(r3.loc[lay, "用户占比"]), 0.01)
    check(f"{lay} 购买贡献占比", g.loc[lay, "购买贡献占比"], float(r3.loc[lay, "购买贡献占比"]), 0.01)
r32 = pd.read_csv(RES / "03_2.csv", encoding="utf-8-sig")
names = {5: "5档(≤1天)", 4: "4档(≤3天)", 3: "3档(≤7天)", 2: "2档(≤15天)", 1: "1档(>15天)"}
mine_r = u.Rs.value_counts()
for k, v in r32.set_index("R档位")["用户数"].items():
    kk = [n for n, nm in names.items() if nm == k][0]
    check(f"R档 {k}", int(mine_r.get(kk, 0)), int(v))

print()
print("=== 04 留存（窗口外应为空） ===")
first = c.groupby("user_id")["date"].min()
act = c[["user_id", "date"]].drop_duplicates().merge(first.rename("reg"), on="user_id")
act["off"] = (pd.to_datetime(act.date) - pd.to_datetime(act.reg)).dt.days
r4 = pd.read_csv(RES / "04.csv", encoding="utf-8-sig").set_index("注册日")
den = first.value_counts()
last_day = pd.Timestamp("2017-12-03")
for reg in r4.index:
    d = pd.Timestamp(reg)
    check(f"{reg} 注册用户数", int(den.loc[reg]), int(r4.loc[reg, "注册用户数"]))
    for n, col in [(1, "次日留存率"), (3, "3日留存率"), (7, "7日留存率")]:
        sub = act[(act.off == n) & (act.reg == reg)]["user_id"].nunique()
        observable = (d + pd.Timedelta(days=n)) <= last_day
        mine = round(sub * 100.0 / den.loc[reg], 2) if observable else None
        theirs = r4.loc[reg, col]
        theirs = None if pd.isna(theirs) else float(theirs)
        check(f"{reg} {col}", mine, theirs, 0.01)

print()
print("=== 05 时段 ===")
pv = c[c.behavior_type == "pv"]
h = pv.groupby("hour").size()
r5 = pd.read_csv(RES / "05.csv", encoding="utf-8-sig").set_index("小时")
check("21点 PV", int(h.loc[21]), int(r5.loc[21, "PV次数"]))
check("21点 UV", pv[pv.hour == 21].user_id.nunique(), int(r5.loc[21, "去重用户数"]))
daily = pv.groupby(["wd", "date"]).agg(pv=("user_id", "size"), uv=("user_id", "nunique"))
r52 = pd.read_csv(RES / "05_2.csv", encoding="utf-8-sig").set_index("星期")
for wd in r52.index:
    sub = daily.loc[wd]
    check(f"{wd} 出现天数", len(sub), int(r52.loc[wd, "出现天数"]))
    check(f"{wd} 日均PV", int(round(sub.pv.mean())), int(r52.loc[wd, "日均PV"]))
    check(f"{wd} 日均UV", int(round(sub.uv.mean())), int(r52.loc[wd, "日均UV"]))

print()
print("=== 06 类目 ===")
cat = c.groupby("category_id").apply(
    lambda x: pd.Series({"pv": (x.behavior_type == "pv").sum(), "buy": (x.behavior_type == "buy").sum()}))
r6 = pd.read_csv(RES / "06.csv", encoding="utf-8-sig").set_index("类目")
for cid in r6.index:
    check(f"类目 {cid} PV", int(cat.loc[cid, "pv"]), int(r6.loc[cid, "PV次数"]))
    check(f"类目 {cid} 购买", int(cat.loc[cid, "buy"]), int(r6.loc[cid, "购买次数"]))

print()
print("=" * 50)
print("总判定:", "全部通过 [OK]" if ok_all else "存在不一致 [FAIL]")
sys.exit(0 if ok_all else 1)
