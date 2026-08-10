-- =============================================================
-- 02 主转化漏斗 + 收藏平行对比
-- 业务问题：用户从浏览到购买，每一步流失多少？哪一步是最大卡点？
--           收藏用户 vs 未收藏用户，购买转化是否有差异（收藏是不是强信号）？
-- 口径：
--   * 主漏斗：浏览(pv) → 加购(cart) → 购买(buy) 三环节（收藏为平行信号，不进主路径）
--   * 全部按用户去重（运营关心"多少人流失"，分母是用户数而非行为次数）
--   * 基于清洗表 ub_clean（01 清洗已剔除窗口外脏数据）
-- =============================================================

-- ① 三环节用户数（去重）
SELECT '浏览' AS 环节, COUNT(DISTINCT user_id) AS 用户数 FROM ub_clean WHERE behavior_type = 'pv'
UNION ALL
SELECT '加购', COUNT(DISTINCT user_id) FROM ub_clean WHERE behavior_type = 'cart'
UNION ALL
SELECT '购买', COUNT(DISTINCT user_id) FROM ub_clean WHERE behavior_type = 'buy'
ORDER BY 用户数 DESC;

-- ② 各环节转化率 + 流失率（按用户去重；MAX(CASE) 等价 COUNT(DISTINCT) 但性能更好）
WITH user_stages AS (
    SELECT user_id,
        MAX(CASE WHEN behavior_type = 'pv'   THEN 1 ELSE 0 END) AS has_pv,
        MAX(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN behavior_type = 'buy'  THEN 1 ELSE 0 END) AS has_buy
    FROM ub_clean
    GROUP BY user_id
)
SELECT
    SUM(has_pv)   AS 浏览用户数,
    SUM(has_cart) AS 加购用户数,
    SUM(has_buy)  AS 购买用户数,
    ROUND(SUM(has_cart) * 100.0 / SUM(has_pv), 2)   AS 浏览到加购转化率,
    ROUND(SUM(has_buy)  * 100.0 / SUM(has_cart), 2) AS 加购到购买转化率,
    ROUND(SUM(has_buy)  * 100.0 / SUM(has_pv), 2)   AS 全链路转化率,
    ROUND((1 - SUM(has_cart) * 1.0 / SUM(has_pv)) * 100, 2)   AS 浏览到加购流失率,
    ROUND((1 - SUM(has_buy)  * 1.0 / SUM(has_cart)) * 100, 2) AS 加购到购买流失率
FROM user_stages;

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

-- ④ 各环节转换率明细（PV/加购/购买 各自的用户与次数，供看板展示）
SELECT behavior_type, COUNT(*) AS 行为次数, COUNT(DISTINCT user_id) AS 去重用户数
FROM ub_clean
WHERE behavior_type IN ('pv', 'cart', 'buy')
GROUP BY behavior_type
ORDER BY FIELD(behavior_type, 'pv', 'cart', 'buy');
