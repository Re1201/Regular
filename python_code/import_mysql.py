# -*- coding: utf-8 -*-
"""将抽样集 UserBehavior_sample.csv 导入 MySQL：建库 → 建表 → LOAD DATA → 核对行数 → 建索引。
目标表：taobao.user_behavior_sample，后续所有 SQL 均查此表。
"""
import pymysql
from pathlib import Path

from db_config import DB_CONFIG

SRC = Path(__file__).resolve().parent.parent / "data" / "UserBehavior_sample.csv"

CREATE_DB_SQL = "CREATE DATABASE IF NOT EXISTS taobao DEFAULT CHARACTER SET utf8mb4;"

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS user_behavior_sample (
    user_id     BIGINT       NOT NULL COMMENT '用户id',
    item_id     BIGINT       NOT NULL COMMENT '商品id',
    category_id BIGINT       NOT NULL COMMENT '商品类目id',
    behavior_type VARCHAR(10) NOT NULL COMMENT '行为类型: pv/fav/cart/buy',
    ts          BIGINT       NOT NULL COMMENT '行为时间戳(秒)',
    INDEX idx_user  (user_id),
    INDEX idx_type  (behavior_type),
    INDEX idx_user_type (user_id, behavior_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='淘宝用户行为抽样集(10%按用户抽样, seed=42)';
"""

INDEX_SQLS = [
    "ALTER TABLE user_behavior_sample ADD INDEX idx_behavior_type (behavior_type);",
    "ALTER TABLE user_behavior_sample ADD INDEX idx_user (user_id);",
]


def main():
    # LOAD DATA LOCAL INFILE 需要客户端开启 local_infile；先不带 database 连接，建库后再 USE
    cfg = {k: v for k, v in DB_CONFIG.items() if k != "database"}
    conn = pymysql.connect(**cfg, local_infile=True)
    try:
        cur = conn.cursor()

        # 1. 建库
        cur.execute(CREATE_DB_SQL)
        conn.select_db(DB_CONFIG["database"])
        print("[1/4] 建库完成: taobao")

        # 2. 建表（清空旧表，保证导入的就是本次抽样集）
        cur.execute("DROP TABLE IF EXISTS user_behavior_sample;")
        cur.execute(CREATE_TABLE_SQL)
        print("[2/4] 建表完成: user_behavior_sample")

        # 3. LOAD DATA（LOCAL: 从客户端文件读入；字段顺序与 CSV 列一致）
        load_sql = f"""
        LOAD DATA LOCAL INFILE '{SRC.as_posix()}'
        INTO TABLE user_behavior_sample
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\\n'
        (user_id, item_id, category_id, behavior_type, ts);
        """
        cur.execute(load_sql)
        print("[3/4] LOAD DATA 完成")

        # 4. 核对行数
        cur.execute("SELECT COUNT(*) FROM user_behavior_sample;")
        db_rows = cur.fetchone()[0]
        csv_lines = sum(1 for _ in open(SRC, encoding="utf-8"))
        print(f"[4/4] MySQL 行数: {db_rows}   CSV 数据行数(不含表头): {csv_lines-1}")

        conn.commit()

        # 5. 建索引
        cur.execute("SHOW INDEX FROM user_behavior_sample")
        existing = {row[2] for row in cur.fetchall()}
        for idx_sql in INDEX_SQLS:
            idx_name = idx_sql.split("INDEX ")[1].split(" ")[0]
            if idx_name not in existing:
                cur.execute(idx_sql)
                print(f"      索引 {idx_name} 已建")
            else:
                print(f"      索引 {idx_name} 已存在，跳过")
        conn.commit()

        print("\n===== 校验结果 =====")
        print(f"CSV 行数(含表头):  {csv_lines}")
        print(f"MySQL 表行数:      {db_rows}")
        ok = (db_rows == csv_lines - 1)
        print("状态: ", "OK 一致" if ok else "MISMATCH 不一致，需排查")
        if not ok:
            raise SystemExit("行数不一致，导入失败")

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
