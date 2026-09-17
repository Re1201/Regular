-- =============================================================
-- 05 时段分析（24 小时 × 7 天活跃分布）
-- 业务问题：用户每天几点最活跃？一周哪天最活跃？运营黄金时段是哪段？
-- 口径：
--   * 基于清洗表 ub_clean（含 behavior_date / behavior_hour / behavior_weekday）
--   * 星期维度必须按"日均"比较：窗口 9 天里周六/周日各出现 2 次、周一至周五各出现 1 次，
--     直接比 PV 合计会把周末放大到约 2 倍（纯天数效应，不是行为差异）
--   * 因此 ② ③ 同时输出 天数 与 日均，比较一律用日均
-- =============================================================

-- ① 24 小时活跃分布（PV 次数 + 去重用户数）
SELECT behavior_hour AS 小时,
    COUNT(*) AS PV次数,
    COUNT(DISTINCT user_id) AS 去重用户数
FROM ub_clean
WHERE behavior_type = 'pv'
GROUP BY behavior_hour
ORDER BY behavior_hour;

-- ② 一周七天活跃分布（含出现天数与日均；日均 = 该星期的逐日值取平均，不是合计/天数）
WITH daily AS (
    SELECT behavior_weekday,
           behavior_date,
           COUNT(*) AS pv,
           COUNT(DISTINCT user_id) AS uv
    FROM ub_clean
    WHERE behavior_type = 'pv'
    GROUP BY behavior_weekday, behavior_date
)
SELECT behavior_weekday AS 星期,
    COUNT(*) AS 出现天数,
    SUM(pv) AS PV次数,
    ROUND(AVG(pv), 0) AS 日均PV,
    ROUND(AVG(uv), 0) AS 日均UV
FROM daily
GROUP BY behavior_weekday
ORDER BY MIN(behavior_date);

-- ③ 24 小时 × 7 天 交叉（PV 次数 + 日均 PV，供热力图按日均着色）
WITH daily AS (
    SELECT behavior_weekday,
           behavior_hour,
           behavior_date,
           COUNT(*) AS pv
    FROM ub_clean
    WHERE behavior_type = 'pv'
    GROUP BY behavior_weekday, behavior_hour, behavior_date
)
SELECT behavior_weekday AS 星期,
    behavior_hour AS 小时,
    SUM(pv) AS PV次数,
    ROUND(AVG(pv), 0) AS 日均PV
FROM daily
GROUP BY behavior_weekday, behavior_hour
ORDER BY MIN(behavior_date), behavior_hour;
