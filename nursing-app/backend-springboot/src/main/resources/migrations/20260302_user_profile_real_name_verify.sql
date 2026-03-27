-- ============================================================
-- Migration: user_profile 新增实名认证字段
-- Date: 2026-03-02
-- Target: MySQL 8+
-- ============================================================

-- 1) 新增 real_name_verified（若不存在）
SET @db_name := DATABASE();
SET @has_real_name_verified := (
  SELECT COUNT(1)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'user_profile'
    AND COLUMN_NAME = 'real_name_verified'
);

SET @sql_add_real_name_verified := IF(
  @has_real_name_verified = 0,
  'ALTER TABLE user_profile ADD COLUMN real_name_verified TINYINT NOT NULL DEFAULT 0 COMMENT ''实名认证状态：0-未认证，1-已认证'' AFTER emergency_phone',
  'SELECT ''column real_name_verified already exists'''
);

PREPARE stmt_add_real_name_verified FROM @sql_add_real_name_verified;
EXECUTE stmt_add_real_name_verified;
DEALLOCATE PREPARE stmt_add_real_name_verified;

-- 2) 新增 real_name_verify_time（若不存在）
SET @has_real_name_verify_time := (
  SELECT COUNT(1)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db_name
    AND TABLE_NAME = 'user_profile'
    AND COLUMN_NAME = 'real_name_verify_time'
);

SET @sql_add_real_name_verify_time := IF(
  @has_real_name_verify_time = 0,
  'ALTER TABLE user_profile ADD COLUMN real_name_verify_time DATETIME NULL COMMENT ''实名认证时间'' AFTER real_name_verified',
  'SELECT ''column real_name_verify_time already exists'''
);

PREPARE stmt_add_real_name_verify_time FROM @sql_add_real_name_verify_time;
EXECUTE stmt_add_real_name_verify_time;
DEALLOCATE PREPARE stmt_add_real_name_verify_time;

-- 3) 统一字段定义（避免历史环境字段类型/注释不一致）
ALTER TABLE user_profile
  MODIFY COLUMN real_name_verified TINYINT NOT NULL DEFAULT 0 COMMENT '实名认证状态：0-未认证，1-已认证',
  MODIFY COLUMN real_name_verify_time DATETIME NULL COMMENT '实名认证时间';

-- 4) 数据回填：已有实名信息的历史用户标记为已认证
UPDATE user_profile
SET
  real_name_verified = 1,
  real_name_verify_time = COALESCE(real_name_verify_time, update_time, create_time, NOW())
WHERE COALESCE(real_name_verified, 0) = 0
  AND COALESCE(TRIM(real_name), '') <> ''
  AND COALESCE(TRIM(id_card_no), '') <> '';

-- 5) 验证
SELECT
  COUNT(1) AS total_users,
  SUM(CASE WHEN real_name_verified = 1 THEN 1 ELSE 0 END) AS verified_users
FROM user_profile;

-- ============================================================
-- 回滚（按需手动执行）
-- ALTER TABLE user_profile DROP COLUMN real_name_verify_time;
-- ALTER TABLE user_profile DROP COLUMN real_name_verified;
-- ============================================================
