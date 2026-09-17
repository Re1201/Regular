-- =============================================================
-- 02 主转化漏斗 + 收藏平行对比
-- 业务问题：用户从浏览到购买，每一步流失多少？哪一步是最大卡点？
--           收藏用户 vs 未收藏用户，购买转化是否有差异（收藏是不是强信号）？
-- 口径：
--   * 序列漏斗：三环节 浏览(pv) → 加购(cart) → 购买(buy)，要求时序依次发生。
--     判定以各行为的"最早发生时间"为准，条件为 t_pv < t_cart < t_buy：
--     第 N 环节成立的前提是第 N-1 环节已成立、且发生时间在它之前。
--     这样才能反映"路径上的流失"，而不是"多少人分别做过这几件事"。
--   * 全部按用户去重（运营关心"多少人流失"，分母是用户数而非行为次数）
--   * 收藏为平行信号，不进主路径
--   * 基于清洗表 ub_clean（01 清洗已剔除窗口外脏数据）
-- =============================================================

-- ① 序列漏斗三环节用户数
WITH first_act AS (
    SELECT user_id,
        MIN(CASE WHEN behavior_type = 'pv'   THEN ts END) AS t_pv,
        MIN(CASE WHEN behavior_type = 'cart' THEN ts END) AS t_cart,
        MIN(CASE WHEN behavior_type = 'buy'  THEN ts END) AS t_buy
    FROM ub_clean
    GROUP BY user_id
),
stages AS (
    SELECT
        CASE WHEN t_pv IS NOT NULL
             THEN 1 ELSE 0 END AS s1_浏览,
        CASE WHEN t_cart IS NOT NULL AND t_pv IS NOT NULL AND t_cart > t_pv
             THEN 1 ELSE 0 END AS s2_加购,
        CASE WHEN t_buy IS NOT NULL AND t_cart IS NOT NULL AND t_pv IS NOT NULL
                  AND t_cart > t_pv AND t_buy > t_cart
             THEN 1 ELSE 0 END AS s3_购买
    FROM first_act
)
SELECT '浏览' AS 环节, SUM(s1_浏览) AS 用户数 FROM stages
UNION ALL
SELECT '加购', SUM(s2_加购) FROM stages
UNION ALL
SELECT '购买', SUM(s3_购买) FROM stages
ORDER BY 用户数 DESC;

-- ② 各环节转化率 + 流失率（序列口径，按用户去重）
WITH first_act AS (
    SELECT user_id,
        MIN(CASE WHEN behavior_type = 'pv'   THEN ts END) AS t_pv,
        MIN(CASE WHEN behavior_type = 'cart' THEN ts END) AS t_cart,
        MIN(CASE WHEN behavior_type = 'buy'  THEN ts END) AS t_buy
    FROM ub_clean
    GROUP BY user_id
),
stages AS (
    SELECT
        CASE WHEN t_pv IS NOT NULL
             THEN 1 ELSE 0 END AS s1_浏览,
        CASE WHEN t_cart IS NOT NULL AND t_pv IS NOT NULL AND t_cart > t_pv
             THEN 1 ELSE 0 END AS s2_加购,
        CASE WHEN t_buy IS NOT NULL AND t_cart IS NOT NULL AND t_pv IS NOT NULL
                  AND t_cart > t_pv AND t_buy > t_cart
             THEN 1 ELSE 0 END AS s3_购买
    FROM first_act
)
SELECT
    SUM(s1_浏览) AS 浏览用户数,
    SUM(s2_加购) AS 加购用户数,
    SUM(s3_购买) AS 购买用户数,
    ROUND(SUM(s2_加购) * 100.0 / SUM(s1_浏览), 2) AS 浏览到加购转化率,
    ROUND(SUM(s3_购买) * 100.0 / SUM(s2_加购), 2) AS 加购到购买转化率,
    ROUND(SUM(s3_购买) * 100.0 / SUM(s1_浏览), 2) AS 全链路转化率,
    ROUND((1 - SUM(s2_加购) * 1.0 / SUM(s1_浏览)) * 100, 2) AS 浏览到加购流失率,
    ROUND((1 - SUM(s3_购买) * 1.0 / SUM(s2_加购)) * 100, 2) AS 加购到购买流失率
FROM stages;

-- ③ 收藏作为平行信号：收藏用户 vs 未收藏用户的购买转化率
WITH u AS (
    SELECT user_id,
        MAX(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS has_fav,
        MAX(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS has_buy
    FROM ub_clean
    GROUP BY user_id
)
SELECT CASE WHEN has_fav = 1 THEN '收藏用户' ELSE '未收藏用户' END AS 类型,
    COUNT(*) AS 用户数,
    ROUND(SUM(has_buy) * 100.0 / COUNT(*), 2) AS 购买转化率
FROM u
GROUP BY 类型;

-- ④ 各环节行为明细（PV/加购/购买 各自的次数与去重用户数，供看板展示规模）
SELECT behavior_type, COUNT(*) AS 行为次数, COUNT(DISTINCT user_id) AS 去重用户数
FROM ub_clean
WHERE behavior_type IN ('pv', 'cart', 'buy')
GROUP BY behavior_type
ORDER BY FIELD(behavior_type, 'pv', 'cart', 'buy');
