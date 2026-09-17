-- =============================================================
-- 03 RF 用户分层（5 档评分设计；因数据集无金额字段，M 用 F 购买次数近似 → 术语"RF 分层"）
-- 业务问题：识别高价值用户，验证"少数用户贡献多数购买"（二八法则）
-- 口径：
--   * 仅统计发生过购买的用户（高价值/潜力的定义依赖购买行为）
--   * R（近度）：最近一次**购买**距分析末日 2017-12-03 的天数。
--     ≤1天=5档 ≤3天=4档 ≤7天=3档 ≤15天=2档 >15天=1档
--     数据窗口仅 9 天，R 最大到 8 → 15 天以上的档位窗口内无用户，实际观测 5/4/3/2 四档
--   * F（频次）：9 天内购买次数。≥5次=5档 3-4次=4档 2次=3档 1次=2档 0次=1档
--   * 分层：高价值 = R≥4 且 F≥4；潜力 = R≥3 且 F≥3；其余 = 普通
--   * 基于清洗表 ub_clean
-- =============================================================

-- ① RF 分层结果：高价值 / 潜力 / 普通（占比 + 购买贡献占比）
WITH user_rf AS (
    SELECT user_id,
        DATEDIFF('2017-12-03', MAX(behavior_date)) AS R_days,
        COUNT(*) AS F_count
    FROM ub_clean
    WHERE behavior_type = 'buy'
    GROUP BY user_id
),
user_score AS (
    SELECT user_id, R_days, F_count,
        CASE WHEN R_days <= 1  THEN 5
             WHEN R_days <= 3  THEN 4
             WHEN R_days <= 7  THEN 3
             WHEN R_days <= 15 THEN 2
             ELSE 1 END AS R_score,
        CASE WHEN F_count >= 5 THEN 5
             WHEN F_count >= 3 THEN 4
             WHEN F_count >= 2 THEN 3
             WHEN F_count >= 1 THEN 2
             ELSE 1 END AS F_score
    FROM user_rf
)
SELECT
    CASE WHEN R_score >= 4 AND F_score >= 4 THEN '高价值'
         WHEN R_score >= 3 AND F_score >= 3 THEN '潜力'
         ELSE '普通' END AS 分层,
    COUNT(*) AS 用户数,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS 用户占比,
    ROUND(SUM(F_count) * 100.0 / SUM(SUM(F_count)) OVER(), 2) AS 购买贡献占比
FROM user_score
GROUP BY 分层
ORDER BY 用户数 DESC;

-- ② R 档位分布明细（与 ① 同一 R 口径：最近一次购买距末日天数）
SELECT
    CASE WHEN R_days <= 1  THEN '5档(≤1天)'
         WHEN R_days <= 3  THEN '4档(≤3天)'
         WHEN R_days <= 7  THEN '3档(≤7天)'
         WHEN R_days <= 15 THEN '2档(≤15天)'
         ELSE '1档(>15天)' END AS R档位,
    COUNT(*) AS 用户数
FROM (
    SELECT user_id,
        DATEDIFF('2017-12-03', MAX(behavior_date)) AS R_days
    FROM ub_clean
    WHERE behavior_type = 'buy'
    GROUP BY user_id
) t
GROUP BY R档位
ORDER BY R档位 DESC;
