-- =============================================================
-- 04 留存分析（同期群 / Cohort）
-- 业务问题：新用户来了之后，第几天流失最严重？次日/3日/7日留存率是多少？
-- 口径：
--   * 注册日 = 用户首次出现日期（数据集无注册字段，用首次行为日近似）
--   * 留存率 = 注册日后第 N 天仍活跃的用户数 / 该日注册用户数
--   * 可观测性：第 N 日留存只有在 reg_date + N <= 2017-12-03 时才可观测。
--     超出窗口的档位输出 NULL（"观测不到"），不输出 0——0 的含义是"观测到了、但无人留存"，
--     两者不能混为一谈，图表也必须据此断线而不是掉到 0
--   * 基于清洗表 ub_clean
--   * 数据窗口仅 9 天：11-25/11-26 注册的用户可观测到 7 日留存，11-27 起 7 日留存不可观测；
--     11-29 起 3 日留存不可观测
-- =============================================================

WITH first_active AS (
    SELECT user_id, MIN(behavior_date) AS reg_date
    FROM ub_clean
    GROUP BY user_id
),
daily_active AS (
    SELECT DISTINCT user_id, behavior_date AS act_date
    FROM ub_clean
)
SELECT f.reg_date AS 注册日,
    COUNT(DISTINCT f.user_id) AS 注册用户数,
    ROUND(CASE WHEN DATE_ADD(f.reg_date, INTERVAL 1 DAY) <= '2017-12-03'
        THEN COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 1 THEN f.user_id END)
             * 100.0 / COUNT(DISTINCT f.user_id) END, 2) AS 次日留存率,
    ROUND(CASE WHEN DATE_ADD(f.reg_date, INTERVAL 3 DAY) <= '2017-12-03'
        THEN COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 3 THEN f.user_id END)
             * 100.0 / COUNT(DISTINCT f.user_id) END, 2) AS 3日留存率,
    ROUND(CASE WHEN DATE_ADD(f.reg_date, INTERVAL 7 DAY) <= '2017-12-03'
        THEN COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 7 THEN f.user_id END)
             * 100.0 / COUNT(DISTINCT f.user_id) END, 2) AS 7日留存率
FROM first_active f
LEFT JOIN daily_active d ON f.user_id = d.user_id
GROUP BY f.reg_date
ORDER BY f.reg_date;
