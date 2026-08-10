# -*- coding: utf-8 -*-
"""批量执行 sql_code/ 下 6 个 SQL 文件，每个结果集导出为 results/XX.csv。
文件名编号与 SQL 编号一一对应：results/01.csv ← 01清洗.sql ... results/06.csv ← 06类目.sql
一个 SQL 文件内可能有多个查询，均导出，用 _2/_3 后缀区分主结果。
"""
import re
import csv
import pymysql
from pathlib import Path

from db_config import DB_CONFIG

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql_code"
RESULT_DIR = ROOT / "results"
SQL_FILES = sorted(SQL_DIR.glob("*.sql"))


def split_statements(sql_text):
    """按分号拆分 SQL 语句（不识别字符串里的分号，本项目的 SQL 均不含）"""
    return [s.strip() for s in sql_text.split(";") if s.strip()]


def clean_filename(name):
    # 去掉可能干扰路径的字符
    return re.sub(r"[^\w\-一-鿿]+", "_", name)


def write_result(filepath, columns, rows):
    with open(filepath, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)


def main():
    RESULT_DIR.mkdir(exist_ok=True)
    conn = pymysql.connect(**DB_CONFIG)
    cur = conn.cursor()
    print(f"共发现 {len(SQL_FILES)} 个 SQL 文件")

    for sql_file in SQL_FILES:
        stem = sql_file.stem
        # 编号 = 文件名开头的两位数
        num = stem[:2] if stem[:2].isdigit() else stem
        sql_text = sql_file.read_text(encoding="utf-8")
        statements = split_statements(sql_text)
        print(f"\n=== {sql_file.name} ({len(statements)} 条语句) ===")
        out_idx = 0
        for stmt in statements:
            # 跳过 DDL（DROP/CREATE/ALTER 等不产出结果集）
            first_word = stmt.split(None, 1)[0].upper() if stmt.split() else ""
            if first_word in {"DROP", "CREATE", "ALTER", "TRUNCATE", "SET", "USE"}:
                cur.execute(stmt)
                print(f"  执行(DDL) {first_word}: OK")
                conn.commit()
                continue
            try:
                cur.execute(stmt)
                if cur.description is None:
                    # 无结果集（UPDATE/DELETE 等）
                    print(f"  执行 {stmt[:40]}...: 无结果集")
                    conn.commit()
                    continue
                columns = [d[0] for d in cur.description]
                rows = cur.fetchall()
                if rows:
                    out_idx += 1
                    suffix = "" if out_idx == 1 else f"_{out_idx}"
                    out = RESULT_DIR / f"{num}{suffix}.csv"
                    write_result(out, columns, rows)
                    print(f"  -> {out.name}  {len(rows)} 行 x {len(columns)} 列")
                else:
                    print(f"  查询无数据: {stmt[:40]}...")
            except Exception as e:
                print(f"  ✗ 执行失败: {e}\n    SQL: {stmt[:100]}...")
        conn.commit()

    cur.close()
    conn.close()
    print("\n导出完成。结果目录:", RESULT_DIR)


if __name__ == "__main__":
    main()
