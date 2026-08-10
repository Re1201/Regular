-- =============================================================
-- 01 清洗：基于抽样集 user_behavior_sample，构建带日期/小时的明细表
-- 业务问题：抽样集数据是否干净？时间字段能否转成可分析的日期/小时？
-- 说明：
--   * 全量表 user_behavior 只在抽样阶段用过，01 清洗及以后一律基于抽样集
--   * timestamp 为 Unix 秒级时间戳，转为 DATETIME 后拆出 date/hour 便于后续分析
--   * 坏数据剔除：无法解析时间 / 非法行为类型 / 非法类目 / 时间戳超出数据窗口(2017-11-25~12-03)
--     ⚠️ 抽样集中存在少量窗口外时间戳（负值/1970年代/2015等，共5570行），
--        会污染留存"注册日"与时段分布，一律剔除
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
