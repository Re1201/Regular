-- =============================================================
-- 05 时段分析（24 小时 × 7 天活跃分布）
-- 业务问题：用户每天几点最活跃？一周哪天最活跃？运营黄金时段是哪段？
-- 口径：基于清洗表 ub_clean（含 behavior_date / behavior_hour / behavior_weekday）
-- =============================================================

-- ① 24 小时活跃分布（PV 次数 + 去重用户数）
SELECT behavior_hour AS 小时,
    COUNT(*) AS PV次数,
    COUNT(DISTINCT user_id) AS 去重用户数
FROM ub_clean
WHERE behavior_type = 'pv'
GROUP BY behavior_hour
ORDER BY behavior_hour;

-- ② 一周七天活跃分布
SELECT behavior_weekday AS 星期,
    COUNT(*) AS PV次数,
    COUNT(DISTINCT user_id) AS 去重用户数
FROM ub_clean
WHERE behavior_type = 'pv'
GROUP BY behavior_weekday
ORDER BY MIN(behavior_date);

-- ③ 24 小时 × 7 天 交叉热力图（PV 次数）
SELECT behavior_weekday AS 星期,
    behavior_hour AS 小时,
    COUNT(*) AS PV次数
FROM ub_clean
WHERE behavior_type = 'pv'
GROUP BY behavior_weekday, behavior_hour
ORDER BY MIN(behavior_date), behavior_hour;
