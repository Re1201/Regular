# -*- coding: utf-8 -*-
"""运营看板：4 张图（Pyecharts 生成可交互 HTML，放 charts/）
1. 用户转化漏斗图（浏览/加购/购买 + 流失标注）
2. RF 用户分层图（高价值/潜力/普通 + 购买贡献占比）
3. 24 小时活跃热力图（24h × 7d）
4. 每日留存曲线（次日/3日/7日）

数据源：results/01.csv ~ 06.csv（run_sql.py 导出）
"""
import pandas as pd
from pathlib import Path

from pyecharts import options as opts
from pyecharts.charts import Funnel, Bar, HeatMap, Line

ROOT = Path(__file__).resolve().parent.parent
RESULT_DIR = ROOT / "results"
CHART_DIR = ROOT / "charts"
CHART_DIR.mkdir(exist_ok=True)


def read_result(name):
    return pd.read_csv(RESULT_DIR / name, encoding="utf-8-sig")


# ---------------- 1. 漏斗图 ----------------
def make_funnel():
    df = read_result("02_2.csv")  # 02 文件第 2 个查询：三环节转化率+流失率
    row = df.iloc[0]
    pv, cart, buy = int(row["浏览用户数"]), int(row["加购用户数"]), int(row["购买用户数"])
    data = [("浏览", pv), ("加购", cart), ("购买", buy)]

    chart = (
        Funnel(init_opts=opts.InitOpts(width="900px", height="600px"))
        .add(
            "环节",
            data,
            label_opts=opts.LabelOpts(formatter="{b}: {c} ({d}%)"),
            tooltip_opts=opts.TooltipOpts(trigger="item", formatter="{b}: {c}"),
        )
        .set_global_opts(
            title_opts=opts.TitleOpts(title="用户转化漏斗（浏览→加购→购买）", subtitle="序列口径：三环节按时序依次发生 · 抽样 10% 用户"),
            legend_opts=opts.LegendOpts(pos_top="5%"),
        )
        .set_series_opts(label_opts=opts.LabelOpts(position="inside"))
    )
    out = CHART_DIR / "01_funnel.html"
    chart.render(out)
    print("已生成:", out)


# ---------------- 2. RF 分层图 ----------------
def make_rf():
    df = read_result("03.csv")  # 03 文件第 1 个查询：分层结果
    # 按"高价值 → 潜力 → 普通"的价值降序展示，不跟随 CSV 的用户数排序
    df = df.set_index("分层").reindex(["高价值", "潜力", "普通"]).reset_index()
    layers = df["分层"].tolist()
    users = df["用户数"].tolist()
    contrib = df["购买贡献占比"].tolist()

    chart = (
        Bar(init_opts=opts.InitOpts(width="900px", height="600px"))
        .add_xaxis(layers)
        .add_yaxis("用户占比(%)", [round(u / df["用户数"].sum() * 100, 2) for u in users])
        .add_yaxis("购买贡献占比(%)", contrib)
        .set_global_opts(
            title_opts=opts.TitleOpts(title="RF 用户分层：占比 vs 购买贡献"),
            legend_opts=opts.LegendOpts(pos_top="5%"),
            yaxis_opts=opts.AxisOpts(name="百分比 %"),
            tooltip_opts=opts.TooltipOpts(trigger="axis"),
        )
    )
    out = CHART_DIR / "02_rf_tiers.html"
    chart.render(out)
    print("已生成:", out)


# ---------------- 3. 时段热力图（24h × 7d） ----------------
def make_heatmap():
    df = read_result("05_3.csv")  # 05 文件第 3 个查询：星期×小时×日均PV
    day_map = {"Monday": "周一", "Tuesday": "周二", "Wednesday": "周三",
               "Thursday": "周四", "Friday": "周五", "Saturday": "周六", "Sunday": "周日"}
    df["星期"] = df["星期"].map(day_map)
    days = df["星期"].unique().tolist()  # 按首次出现顺序

    # 按"日均 PV"着色：窗口内周六/周日各出现 2 次、周一至周五各 1 次，
    # 用 PV 合计会让周末整行天然亮约 2 倍（纯天数效应），并非行为差异
    value = [[d, int(h), int(v)] for d, h, v in zip(df["星期"], df["小时"], df["日均PV"])]
    maxv = df["日均PV"].max()

    chart = (
        HeatMap(init_opts=opts.InitOpts(width="1200px", height="600px"))
        .add_xaxis([f"{h}时" for h in range(24)])
        .add_yaxis("星期", days, value,
                   label_opts=opts.LabelOpts(is_show=False))
        .set_global_opts(
            title_opts=opts.TitleOpts(title="24 小时 × 7 天 日均 PV 活跃热力图"),
            visualmap_opts=opts.VisualMapOpts(max_=maxv, is_calculable=True),
            yaxis_opts=opts.AxisOpts(name="星期"),
            xaxis_opts=opts.AxisOpts(name="小时", axislabel_opts=opts.LabelOpts(rotate=45)),
        )
    )
    out = CHART_DIR / "03_hour_heatmap.html"
    chart.render(out)
    print("已生成:", out)


# ---------------- 4. 留存曲线 ----------------
def make_retention():
    df = read_result("04.csv")  # 04 留存：注册日×次日/3日/7日留存率
    dates = df["注册日"].tolist()
    d1 = df["次日留存率"].tolist()
    d3 = df["3日留存率"].tolist()
    d7 = df["7日留存率"].tolist()

    chart = (
        Line(init_opts=opts.InitOpts(width="1000px", height="600px"))
        .add_xaxis(dates)
        .add_yaxis("次日留存率", d1, is_smooth=True, label_opts=opts.LabelOpts(is_show=True))
        .add_yaxis("3日留存率", d3, is_smooth=True, label_opts=opts.LabelOpts(is_show=True))
        .add_yaxis("7日留存率", d7, is_smooth=True, label_opts=opts.LabelOpts(is_show=True))
        .set_global_opts(
            title_opts=opts.TitleOpts(title="每日注册用户留存曲线（首次行为=注册日）", subtitle="超出 9 天窗口的档位不可观测，曲线中断（非 0）"),
            legend_opts=opts.LegendOpts(pos_top="5%"),
            yaxis_opts=opts.AxisOpts(name="留存率 %"),
            xaxis_opts=opts.AxisOpts(name="注册日"),
            tooltip_opts=opts.TooltipOpts(trigger="axis"),
        )
    )
    out = CHART_DIR / "04_retention.html"
    chart.render(out)
    print("已生成:", out)


if __name__ == "__main__":
    make_funnel()
    make_rf()
    make_heatmap()
    make_retention()
    print("看板生成完毕，目录:", CHART_DIR)
