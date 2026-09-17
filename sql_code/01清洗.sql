-- =============================================================
-- 01 清洗：基于抽样集 user_behavior_sample，构建带日期/小时的明细表
-- 业务问题：抽样集数据是否干净？时间字段能否转成可分析的日期/小时？
-- 说明：
--   * 全量表 user_behavior 只在抽样阶段用过，01 清洗及以后一律基于抽样集
--   * timestamp 为 Unix 秒级时间戳，转为 DATETIME 后拆出 date/hour 便于后续分析
--   * 窗口裁切：只保留 2017-11-25 00:00:00 ~ 12-03 23:59:59（北京时区）内的记录。
--     实测被剔除 5,569 行，按日期互斥分段如下（合计 = 5,569）：
--       时间戳为负                                        14 行
--       早于 2017-11-07（含 1979、2017-04 等离群日期）      227 行
--       2017-11-07 ~ 11-24（窗口前）                    5,120 行（其中 11-24 当天 4,162 行）
--       2017-12-04（窗口后当天）                           116 行
--       2017-12-05 及以后（含 2018、2025 离群日期）          92 行
--     窗口外记录会把用户首次行为日错算到 11-25，污染留存"注册日"，一律剔除
--   * 非法行为类型与非法类目实测均为 0 行（抽样集未出现），条件保留作校验
-- =============================================================

DROP TABLE IF EXISTS ub_clean;

CREATE TABLE ub_clean AS
SELECT
    user_id,
    item_id,
    category_id,
    behavior_type,
    ts,
    FROM_UNIXTIME(ts)                                    AS behavior_dt,
    DATE(FROM_UNIXTIME(ts))                              AS behavior_date,
    HOUR(FROM_UNIXTIME(ts))                              AS behavior_hour,
    DAYNAME(FROM_UNIXTIME(ts))                           AS behavior_weekday
FROM user_behavior_sample
WHERE behavior_type IN ('pv', 'fav', 'cart', 'buy')
  AND ts BETWEEN UNIX_TIMESTAMP('2017-11-25 00:00:00')
             AND UNIX_TIMESTAMP('2017-12-03 23:59:59')
  AND category_id > 0;

-- 留档：坏数据行数（被 01 清洗剔除的记录）
SELECT '被剔除行数' AS 检查项, (SELECT COUNT(*) FROM user_behavior_sample) - (SELECT COUNT(*) FROM ub_clean) AS 行数;

-- 校验：清洗后明细数、用户数、日期范围、行为类型分布
SELECT '清洗后明细行数' AS 检查项, COUNT(*) AS 值 FROM ub_clean
UNION ALL
SELECT '去重用户数', COUNT(DISTINCT user_id) FROM ub_clean
UNION ALL
SELECT '日期范围', COUNT(DISTINCT behavior_date) FROM ub_clean
UNION ALL
SELECT '行为类型种数', COUNT(DISTINCT behavior_type) FROM ub_clean;

SELECT behavior_type, COUNT(*) AS 行为数, COUNT(DISTINCT user_id) AS 用户数
FROM ub_clean GROUP BY behavior_type ORDER BY 行为数 DESC;
