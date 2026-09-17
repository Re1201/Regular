-- =============================================================
-- 06 类目分析
-- 业务问题：哪些类目流量最大？哪些类目高曝光但低转化（运营优化空间大）？
-- 口径：
--   * 基于清洗表 ub_clean，按 category_id 聚合
--   * PV转购买率 = 购买次数 / PV次数，是**事件级**口径（次数比次数），
--     与 02 漏斗的用户级口径（人数比人数）不同，两者不可互相换算、也不可混用
--   * "高曝光"阈值 = PV 次数 >= 100000（本数据集 PV 中位数约 900，10 万约为其 100 倍）
-- =============================================================

-- ① TOP 类目：按 PV 次数排序，看头部类目流量分布
SELECT category_id AS 类目,
    COUNT(CASE WHEN behavior_type = 'pv'   THEN 1 END)   AS PV次数,
    COUNT(CASE WHEN behavior_type = 'fav'  THEN 1 END)   AS 收藏次数,
    COUNT(CASE WHEN behavior_type = 'cart' THEN 1 END)   AS 加购次数,
    COUNT(CASE WHEN behavior_type = 'buy'  THEN 1 END)   AS 购买次数,
    ROUND(COUNT(CASE WHEN behavior_type = 'buy' THEN 1 END) * 100.0
          / NULLIF(COUNT(CASE WHEN behavior_type = 'pv' THEN 1 END), 0), 3) AS PV转购买率
FROM ub_clean
GROUP BY category_id
ORDER BY PV次数 DESC
LIMIT 20;

-- ② 高曝光低转化类目（PV 次数 >= 100000，按 PV→购买率升序，转化最差的排前面）
WITH cat AS (
    SELECT category_id,
        COUNT(CASE WHEN behavior_type = 'pv'  THEN 1 END) AS pv,
        COUNT(CASE WHEN behavior_type = 'buy' THEN 1 END) AS buy
    FROM ub_clean
    GROUP BY category_id
)
SELECT category_id AS 类目,
    pv AS PV次数,
    buy AS 购买次数,
    ROUND(buy * 100.0 / pv, 3) AS PV转购买率
FROM cat
WHERE pv >= 100000
ORDER BY buy * 100.0 / pv ASC
LIMIT 20;
