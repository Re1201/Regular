-- =============================================================
-- 04 留存分析
-- 业务问题：新用户来了之后，第几天流失最严重？次日/3日/7日留存率是多少？
-- 口径：
--   * 注册日 = 用户首次出现日期（数据集无注册字段，用首次行为日近似）
--   * 留存率 = 注册日后第 N 天仍活跃的用户数 / 该日注册用户数
--   * 基于清洗表 ub_clean（已剔除窗口外时间戳，注册日均为 2017-11-25~12-03）
--   * ⚠️ 数据窗口仅 9 天（11-25 ~ 12-03）：
--     - 11-25/11-26 注册的用户可观测到 7 日留存（12-02/12-03）
--     - 11-27 之后注册的用户 7 日留存超出窗口，观测不到 → 显示 0
--     - 故 7 日留存样本偏小，重点看次日/3日趋势
-- =============================================================

WITH first_active AS (
    SELECT user_id, MIN(behavior_date) AS reg_date
    FROM ub_clean
    GROUP BY user_id
),
daily_active AS (
    SELECT user_id, behavior_date AS act_date
    FROM ub_clean
    GROUP BY user_id, behavior_date
)
SELECT f.reg_date AS 注册日,
    COUNT(DISTINCT f.user_id) AS 注册用户数,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 1 THEN f.user_id END)
          * 100.0 / COUNT(DISTINCT f.user_id), 2) AS 次日留存率,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 3 THEN f.user_id END)
          * 100.0 / COUNT(DISTINCT f.user_id), 2) AS 3日留存率,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(d.act_date, f.reg_date) = 7 THEN f.user_id END)
          * 100.0 / COUNT(DISTINCT f.user_id), 2) AS 7日留存率
FROM first_active f
LEFT JOIN daily_active d ON f.user_id = d.user_id
GROUP BY f.reg_date
ORDER BY f.reg_date;
