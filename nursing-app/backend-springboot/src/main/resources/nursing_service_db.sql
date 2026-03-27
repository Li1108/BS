-- ============================================================
-- 互联网+护理服务APP - 完善版数据库SQL（经过性能优化）
-- 数据库：MySQL 8.x
-- 文件存储：T:\static\uploads (数据库保存)
-- 包含：30个核心表 + 预设数据 + 外键约束 + 优化索引
-- ============================================================

DROP DATABASE IF EXISTS nursing_service_db;

CREATE DATABASE nursing_service_db
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE nursing_service_db;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 01. 角色表 role
-- ============================================================
DROP TABLE IF EXISTS role;
CREATE TABLE role (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  role_code VARCHAR(50) NOT NULL UNIQUE COMMENT '角色编码 USER/NURSE/ADMIN_SUPER',
  role_name VARCHAR(100) NOT NULL COMMENT '角色名称',
  status INT NOT NULL DEFAULT 1 COMMENT '状态 1启用 0禁用',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='系统角色表';

-- ============================================================
-- 02. 用户账户表 user_account
-- ============================================================
DROP TABLE IF EXISTS user_account;
CREATE TABLE user_account (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  phone VARCHAR(20) NOT NULL UNIQUE COMMENT '手机号',
  password VARCHAR(255) DEFAULT NULL COMMENT '预留密码（本项目验证码登录可为空）',
  nickname VARCHAR(100) DEFAULT NULL COMMENT '昵称',
  avatar_url VARCHAR(255) DEFAULT NULL COMMENT '头像相对路径 /uploads/avatar/xxx.jpg',
  gender INT DEFAULT 0 COMMENT '性别 0未知 1男 2女',
  status INT NOT NULL DEFAULT 1 COMMENT '账号状态 1正常 0禁用',
  last_login_time DATETIME DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='用户账户表（所有角色共用）';

-- ============================================================
-- 03. 用户角色关联 user_role
-- ============================================================
DROP TABLE IF EXISTS user_role;
CREATE TABLE user_role (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_role(user_id, role_id),
  INDEX idx_user_id(user_id),
  INDEX idx_role_id(role_id)
) ENGINE=InnoDB COMMENT='用户角色关联表';

-- ============================================================
-- 04. 验证码表 sms_code（无Redis验证码存储）
-- ============================================================
DROP TABLE IF EXISTS sms_code;
CREATE TABLE sms_code (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  phone VARCHAR(20) NOT NULL,
  code VARCHAR(10) NOT NULL COMMENT '验证码',
  expire_time DATETIME NOT NULL COMMENT '过期时间',
  used_flag INT NOT NULL DEFAULT 0 COMMENT '是否使用 0未使用 1已使用',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_phone(phone),
  INDEX idx_expire(expire_time)
) ENGINE=InnoDB COMMENT='短信验证码记录表';

-- ============================================================
-- 05. Token 黑名单表 token_blacklist（无Redis）
-- ============================================================
DROP TABLE IF EXISTS token_blacklist;
CREATE TABLE token_blacklist (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  token VARCHAR(512) NOT NULL COMMENT 'JWT token',
  expire_time DATETIME NOT NULL COMMENT 'token过期时间',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id(user_id),
  INDEX idx_expire_time(expire_time)
) ENGINE=InnoDB COMMENT='Token黑名单（退出登录/踢下线）';

-- ============================================================
-- 06. 用户资料表 user_profile
-- ============================================================
DROP TABLE IF EXISTS user_profile;
CREATE TABLE user_profile (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL UNIQUE,
  real_name VARCHAR(50) DEFAULT NULL COMMENT '真实姓名',
  id_card_no VARCHAR(50) DEFAULT NULL COMMENT '身份证号（可选）',
  birthday DATE DEFAULT NULL,
  emergency_contact VARCHAR(50) DEFAULT NULL COMMENT '紧急联系人',
  emergency_phone VARCHAR(20) DEFAULT NULL COMMENT '紧急联系电话',
  real_name_verified TINYINT NOT NULL DEFAULT 0 COMMENT '实名认证状态：0-未认证，1-已认证',
  real_name_verify_time DATETIME DEFAULT NULL COMMENT '实名认证时间',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id(user_id),
  INDEX idx_real_name(real_name), -- 优化添加
  INDEX idx_id_card(id_card_no)   -- 优化添加
) ENGINE=InnoDB COMMENT='普通用户扩展资料表';

-- ============================================================
-- 07. 用户地址表 user_address
-- ============================================================
DROP TABLE IF EXISTS user_address;
CREATE TABLE user_address (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  contact_name VARCHAR(50) NOT NULL COMMENT '联系人',
  contact_phone VARCHAR(20) NOT NULL COMMENT '联系电话',
  province VARCHAR(50) DEFAULT NULL,
  city VARCHAR(50) DEFAULT NULL,
  district VARCHAR(50) DEFAULT NULL,
  detail_address VARCHAR(255) NOT NULL COMMENT '详细地址',
  latitude DECIMAL(10,6) DEFAULT NULL COMMENT '纬度',
  longitude DECIMAL(10,6) DEFAULT NULL COMMENT '经度',
  is_default INT NOT NULL DEFAULT 0 COMMENT '是否默认 1是 0否',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id(user_id),
  INDEX idx_default(user_id, is_default), -- 优化添加 (复合索引)
  INDEX idx_location_geo(latitude, longitude) -- 优化添加
) ENGINE=InnoDB COMMENT='用户地址表';

-- ============================================================
-- 08. 护士资料表 nurse_profile
-- ============================================================
DROP TABLE IF EXISTS nurse_profile;
CREATE TABLE nurse_profile (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL UNIQUE COMMENT '对应 user_account.id',
  nurse_name VARCHAR(50) NOT NULL COMMENT '护士姓名',
  id_card_no VARCHAR(50) NOT NULL COMMENT '身份证号',
  id_card_front_url VARCHAR(255) NOT NULL COMMENT '身份证正面 /uploads/nurse/idcard/xxx.jpg',
  id_card_back_url VARCHAR(255) NOT NULL COMMENT '身份证反面 /uploads/nurse/idcard/xxx.jpg',
  license_no VARCHAR(100) NOT NULL COMMENT '护士执业证编号',
  license_url VARCHAR(255) NOT NULL COMMENT '护士证 /uploads/nurse/license/xxx.jpg',
  nurse_photo_url VARCHAR(255) NOT NULL COMMENT '护士头像/照片 /uploads/nurse/photo/xxx.jpg',
  hospital VARCHAR(100) DEFAULT NULL COMMENT '所属医院/机构',
  work_years INT DEFAULT 0 COMMENT '从业年限',
  skill_desc VARCHAR(500) DEFAULT NULL COMMENT '技能描述',
  audit_status INT NOT NULL DEFAULT 0 COMMENT '审核状态 0待审 1通过 2拒绝',
  audit_remark VARCHAR(255) DEFAULT NULL COMMENT '审核备注',
  accept_enabled INT NOT NULL DEFAULT 0 COMMENT '是否开启接单 1是 0否',
  work_mode INT DEFAULT 0 COMMENT '工作模式 0:自由接单 1:上班模式', -- 优化添加
  rating DECIMAL(2,1) DEFAULT 5.0 COMMENT '综合评分', -- 优化添加
  pending_hospital VARCHAR(100) DEFAULT NULL COMMENT '待审核的新关联医院',
  hospital_change_status INT DEFAULT NULL COMMENT '医院变更审核状态 0待审核 1通过 2拒绝',
  hospital_change_remark VARCHAR(255) DEFAULT NULL COMMENT '医院变更审核备注',
  hospital_change_apply_time DATETIME DEFAULT NULL COMMENT '医院变更申请时间',
  hospital_change_audit_time DATETIME DEFAULT NULL COMMENT '医院变更审核时间',
  reject_count_today INT NOT NULL DEFAULT 0 COMMENT '今日拒单次数（可选功能）',
  reject_date DATE DEFAULT NULL COMMENT '拒单次数统计日期',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id(user_id),
  INDEX idx_audit(audit_status),
  INDEX idx_accept(accept_enabled),
  INDEX idx_audit_create(audit_status, create_time), -- 优化添加
  INDEX idx_work_mode(work_mode, audit_status),      -- 优化添加
  INDEX idx_rating(rating DESC)                      -- 优化添加
) ENGINE=InnoDB COMMENT='护士资料表';

-- ============================================================
-- 09. 护士位置表 nurse_location（必做）
-- ============================================================
DROP TABLE IF EXISTS nurse_location;
CREATE TABLE nurse_location (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nurse_user_id BIGINT NOT NULL UNIQUE COMMENT '护士 user_account.id',
  latitude DECIMAL(10,6) NOT NULL COMMENT '纬度',
  longitude DECIMAL(10,6) NOT NULL COMMENT '经度',
  report_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上报时间',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_report_time(report_time)
) ENGINE=InnoDB COMMENT='护士位置上报表';

-- ============================================================
-- 10. 护士拒单记录表 nurse_reject_log（新增）
-- ============================================================
DROP TABLE IF EXISTS nurse_reject_log;
CREATE TABLE nurse_reject_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nurse_user_id BIGINT NOT NULL COMMENT '护士用户ID',
  order_id BIGINT NOT NULL COMMENT '订单ID',
  order_no VARCHAR(50) NOT NULL COMMENT '订单号',
  reject_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '拒单时间',
  reject_reason VARCHAR(255) DEFAULT NULL COMMENT '拒单原因',
  auto_flag INT NOT NULL DEFAULT 0 COMMENT '是否自动拒单 0手动 1自动',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_order(order_id),
  INDEX idx_time(reject_time)
) ENGINE=InnoDB COMMENT='护士拒单记录表';

-- ============================================================
-- 10. 服务分类 service_category
-- ============================================================
DROP TABLE IF EXISTS service_category;
CREATE TABLE service_category (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_name VARCHAR(100) NOT NULL COMMENT '分类名称',
  sort_no INT NOT NULL DEFAULT 0 COMMENT '排序',
  status INT NOT NULL DEFAULT 1 COMMENT '状态 1上架 0下架',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='服务分类表';

-- ============================================================
-- 11. 服务项目 service_item
-- ============================================================
DROP TABLE IF EXISTS service_item;
CREATE TABLE service_item (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id BIGINT NOT NULL,
  service_name VARCHAR(200) NOT NULL COMMENT '服务名称',
  service_desc VARCHAR(1000) DEFAULT NULL COMMENT '服务描述',
  cover_image_url VARCHAR(255) DEFAULT NULL COMMENT '封面图 /uploads/service/cover/xxx.jpg',
  price DECIMAL(10,2) NOT NULL COMMENT '基础价格',
  duration_minutes INT NOT NULL DEFAULT 60 COMMENT '服务时长(分钟)',
  status INT NOT NULL DEFAULT 1 COMMENT '状态 1上架 0下架',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_category(category_id),
  INDEX idx_status(status)
) ENGINE=InnoDB COMMENT='服务项目表';

-- ============================================================
-- 12. 服务可选项 service_item_option
-- ============================================================
DROP TABLE IF EXISTS service_item_option;
CREATE TABLE service_item_option (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  service_id BIGINT NOT NULL,
  option_name VARCHAR(200) NOT NULL COMMENT '可选项名称',
  option_price DECIMAL(10,2) NOT NULL COMMENT '可选项加价',
  status INT NOT NULL DEFAULT 1 COMMENT '状态 1启用 0禁用',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_service(service_id)
) ENGINE=InnoDB COMMENT='服务项目可选项表';

-- ============================================================
-- 13. 服务打卡照片表 service_checkin_photo（新增）
-- ============================================================
DROP TABLE IF EXISTS service_checkin_photo;
CREATE TABLE service_checkin_photo (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL COMMENT '订单ID',
  order_no VARCHAR(50) NOT NULL COMMENT '订单号',
  nurse_user_id BIGINT NOT NULL COMMENT '护士用户ID',
  checkin_type INT NOT NULL COMMENT '打卡类型 1到达现场 2开始服务 3完成服务',
  photo_url VARCHAR(255) NOT NULL COMMENT '照片路径 /uploads/checkin/xxx.jpg',
  photo_desc VARCHAR(255) DEFAULT NULL COMMENT '照片描述',
  latitude DECIMAL(10,6) DEFAULT NULL COMMENT '纬度',
  longitude DECIMAL(10,6) DEFAULT NULL COMMENT '经度',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_order(order_id),
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_type(checkin_type),
  UNIQUE KEY uk_order_type(order_id, checkin_type)
) ENGINE=InnoDB COMMENT='服务打卡照片表';

-- ============================================================
-- 14. 订单主表 order_main
-- ============================================================
DROP TABLE IF EXISTS order_main;
CREATE TABLE order_main (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no VARCHAR(50) NOT NULL UNIQUE COMMENT '订单号',
  user_id BIGINT NOT NULL COMMENT '下单用户ID',
  nurse_user_id BIGINT DEFAULT NULL COMMENT '护士用户ID（派单后填写）',

  service_id BIGINT NOT NULL COMMENT '服务项目ID',
  service_name_snapshot VARCHAR(200) NOT NULL COMMENT '服务名称快照',
  service_price_snapshot DECIMAL(10,2) NOT NULL COMMENT '服务价格快照',

  appointment_time DATETIME NOT NULL COMMENT '预约时间',
  remark VARCHAR(500) DEFAULT NULL COMMENT '备注',

  address_snapshot VARCHAR(500) NOT NULL COMMENT '地址快照（文本拼接）',
  address_latitude DECIMAL(10,6) DEFAULT NULL,
  address_longitude DECIMAL(10,6) DEFAULT NULL,

  option_total_price_snapshot DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '可选项总价快照',
  total_amount DECIMAL(10,2) NOT NULL COMMENT '订单总金额',

  pay_status INT NOT NULL DEFAULT 0 COMMENT '支付状态 0未支付 1已支付',
  pay_method INT DEFAULT 0 COMMENT '支付方式 1支付宝 2微信（可扩展）',
  pay_time DATETIME DEFAULT NULL,

  order_status INT NOT NULL DEFAULT 0 COMMENT '订单状态(0待支付 1待接单 2已派单 3已接单 4已到达 5服务中 6已完成 7已评价 8已取消 9退款中 10已退款)',

  assign_retry_count INT NOT NULL DEFAULT 0 COMMENT '派单重试次数',
  last_assign_time DATETIME DEFAULT NULL COMMENT '上次派单时间',
  assign_fail_reason VARCHAR(255) DEFAULT NULL COMMENT '派单失败原因',
  assign_version INT NOT NULL DEFAULT 0 COMMENT '派单乐观锁版本号',

  nurse_accept_time DATETIME DEFAULT NULL COMMENT '护士接单时间',
  arrive_time DATETIME DEFAULT NULL COMMENT '到达时间',
  start_time DATETIME DEFAULT NULL COMMENT '开始服务时间',
  finish_time DATETIME DEFAULT NULL COMMENT '完成服务时间',
  cancel_time DATETIME DEFAULT NULL COMMENT '取消时间',

  cancel_reason VARCHAR(255) DEFAULT NULL COMMENT '取消原因',
  refund_amount DECIMAL(10,2) DEFAULT NULL COMMENT '退款金额',

  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_user(user_id),
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_status(order_status),
  INDEX idx_pay(pay_status),
  INDEX idx_assign(order_status, assign_retry_count),
  INDEX idx_user_status(user_id, order_status),
  INDEX idx_nurse_status(nurse_user_id, order_status),
  INDEX idx_create_time(create_time),
  
  -- 优化建议新增索引
  INDEX idx_time_range(create_time, order_status),        -- 时间范围查询优化
  INDEX idx_payment(pay_status, pay_time),                -- 支付相关查询
  INDEX idx_assignment(order_status, assign_retry_count, last_assign_time), -- 派单查询优化
  INDEX idx_service_stats(service_id, order_status, create_time), -- 服务统计
  INDEX idx_amount_range(total_amount, order_status),     -- 金额范围查询
  INDEX idx_nurse_workload(nurse_user_id, finish_time, order_status) -- 护士工作量统计
) ENGINE=InnoDB COMMENT='订单主表';

-- ============================================================
-- 15. 订单可选项 order_option
-- ============================================================
DROP TABLE IF EXISTS order_option;
CREATE TABLE order_option (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  service_option_id BIGINT NOT NULL,
  option_name_snapshot VARCHAR(200) NOT NULL,
  option_price_snapshot DECIMAL(10,2) NOT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_order(order_id)
) ENGINE=InnoDB COMMENT='订单可选项快照表';

-- ============================================================
-- 16. 订单状态日志 order_status_log
-- ============================================================
DROP TABLE IF EXISTS order_status_log;
CREATE TABLE order_status_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  old_status INT NOT NULL,
  new_status INT NOT NULL,
  operator_user_id BIGINT DEFAULT NULL COMMENT '操作人（用户/护士/管理员）',
  operator_role VARCHAR(50) DEFAULT NULL COMMENT 'USER/NURSE/ADMIN_SUPER',
  remark VARCHAR(255) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_order(order_id),
  INDEX idx_order_no(order_no)
) ENGINE=InnoDB COMMENT='订单状态变更日志';

-- ============================================================
-- 17. 派单日志 order_assign_log（派单失败重试记录）
-- ============================================================
DROP TABLE IF EXISTS order_assign_log;
CREATE TABLE order_assign_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  try_no INT NOT NULL COMMENT '第几次派单',
  nurse_user_id BIGINT DEFAULT NULL COMMENT '匹配到的护士',
  distance_km DECIMAL(10,2) DEFAULT NULL COMMENT '距离（km）',
  success_flag INT NOT NULL DEFAULT 0 COMMENT '是否成功 1成功 0失败',
  fail_reason VARCHAR(255) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_order(order_id),
  INDEX idx_order_no(order_no)
) ENGINE=InnoDB COMMENT='派单记录表';

-- ============================================================
-- 18. 支付记录 payment_record
-- ============================================================
DROP TABLE IF EXISTS payment_record;
CREATE TABLE payment_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  pay_method INT NOT NULL COMMENT '1支付宝 2微信',
  pay_amount DECIMAL(10,2) NOT NULL,
  pay_status INT NOT NULL DEFAULT 0 COMMENT '0未支付 1成功 2失败',
  trade_no VARCHAR(100) DEFAULT NULL COMMENT '第三方交易号',
  callback_content TEXT DEFAULT NULL COMMENT '回调原文',
  pay_time DATETIME DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_trade_no(trade_no),
  INDEX idx_order_no(order_no),
  INDEX idx_status(pay_status)
) ENGINE=InnoDB COMMENT='支付记录表';

-- ============================================================
-- 19. 退款记录 refund_record
-- ============================================================
DROP TABLE IF EXISTS refund_record;
CREATE TABLE refund_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  refund_amount DECIMAL(10,2) NOT NULL,
  refund_status INT NOT NULL DEFAULT 0 COMMENT '0待处理 1退款成功 2退款失败',
  refund_reason VARCHAR(255) DEFAULT NULL,
  third_refund_no VARCHAR(100) DEFAULT NULL COMMENT '第三方退款号',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_order_refund(order_no),
  INDEX idx_status(refund_status)
) ENGINE=InnoDB COMMENT='退款记录表';

-- ============================================================
-- 20. 订单评价 evaluation
-- ============================================================
DROP TABLE IF EXISTS evaluation;
CREATE TABLE evaluation (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL UNIQUE,
  order_no VARCHAR(50) NOT NULL,
  user_id BIGINT NOT NULL,
  nurse_user_id BIGINT NOT NULL,
  rating INT NOT NULL COMMENT '评分 1-5',
  content VARCHAR(1000) DEFAULT NULL COMMENT '评价内容',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_user(user_id),
  INDEX idx_nurse_rating(nurse_user_id, rating, create_time) -- 优化添加
) ENGINE=InnoDB COMMENT='订单评价表';

-- ============================================================
-- 21. 护士钱包 nurse_wallet
-- ============================================================
DROP TABLE IF EXISTS nurse_wallet;
CREATE TABLE nurse_wallet (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nurse_user_id BIGINT NOT NULL UNIQUE,
  balance DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '余额',
  total_income DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '累计收入',
  total_withdraw DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '累计提现',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='护士钱包表';

-- ============================================================
-- 22. 护士钱包流水 nurse_wallet_log
-- ============================================================
DROP TABLE IF EXISTS nurse_wallet_log;
CREATE TABLE nurse_wallet_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nurse_user_id BIGINT NOT NULL,
  order_no VARCHAR(50) DEFAULT NULL COMMENT '关联订单号',
  change_type INT NOT NULL COMMENT '类型 1收入 2提现扣减 3退款扣减',
  change_amount DECIMAL(10,2) NOT NULL,
  balance_after DECIMAL(10,2) NOT NULL,
  remark VARCHAR(255) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_order(order_no),
  INDEX idx_balance_query(nurse_user_id, change_type, create_time) -- 优化添加
) ENGINE=InnoDB COMMENT='护士钱包流水表';

-- ============================================================
-- 23. 提现申请 withdrawal_record
-- ============================================================
DROP TABLE IF EXISTS withdrawal_record;
CREATE TABLE withdrawal_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nurse_user_id BIGINT NOT NULL,
  withdraw_amount DECIMAL(10,2) NOT NULL,
  bank_name VARCHAR(100) NOT NULL,
  bank_account VARCHAR(50) NOT NULL,
  account_holder VARCHAR(50) NOT NULL,
  status INT NOT NULL DEFAULT 0 COMMENT '0待审核 1通过 2拒绝 3已打款',
  audit_remark VARCHAR(255) DEFAULT NULL,
  audit_admin_id BIGINT DEFAULT NULL,
  audit_time DATETIME DEFAULT NULL,
  pay_time DATETIME DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_nurse(nurse_user_id),
  INDEX idx_status(status),
  INDEX idx_withdrawal_status(status, create_time), -- 优化添加
  INDEX idx_nurse_withdrawal(nurse_user_id, status, create_time) -- 优化添加
) ENGINE=InnoDB COMMENT='提现申请表';

-- ============================================================
-- 24. 通知 notification
-- ============================================================
DROP TABLE IF EXISTS notification;
CREATE TABLE notification (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  receiver_user_id BIGINT NOT NULL,
  receiver_role VARCHAR(50) NOT NULL COMMENT 'USER/NURSE/ADMIN_SUPER',
  title VARCHAR(200) NOT NULL,
  content VARCHAR(1000) NOT NULL,
  biz_type VARCHAR(100) DEFAULT NULL COMMENT '业务类型 ORDER/PAY/REFUND/WITHDRAW',
  biz_id VARCHAR(100) DEFAULT NULL COMMENT '业务ID，例如orderNo',
  read_flag INT NOT NULL DEFAULT 0 COMMENT '是否已读 0未读 1已读',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_receiver(receiver_user_id),
  INDEX idx_read(receiver_user_id, read_flag),
  INDEX idx_receiver_status(receiver_user_id, read_flag, create_time), -- 优化添加
  INDEX idx_biz_type(biz_type, biz_id) -- 优化添加
) ENGINE=InnoDB COMMENT='通知表';

-- ============================================================
-- 25. 系统配置 system_config
-- ============================================================
DROP TABLE IF EXISTS system_config;
CREATE TABLE system_config (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  config_key VARCHAR(100) NOT NULL UNIQUE,
  config_value VARCHAR(500) NOT NULL,
  remark VARCHAR(255) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT='系统配置表';

-- ============================================================
-- 26. 管理员操作日志 admin_action_log
-- ============================================================
DROP TABLE IF EXISTS admin_action_log;
CREATE TABLE admin_action_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  admin_user_id BIGINT NOT NULL,
  action_type VARCHAR(100) NOT NULL COMMENT '操作类型',
  action_desc VARCHAR(500) NOT NULL COMMENT '操作描述',
  request_path VARCHAR(200) DEFAULT NULL,
  request_method VARCHAR(20) DEFAULT NULL,
  request_params TEXT DEFAULT NULL,
  ip VARCHAR(50) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin(admin_user_id),
  INDEX idx_time(create_time)
) ENGINE=InnoDB COMMENT='管理员操作日志表';

-- ============================================================
-- 27. 文件附件表 file_attachment（统一文件管理）
-- ============================================================
DROP TABLE IF EXISTS file_attachment;
CREATE TABLE file_attachment (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  uploader_user_id BIGINT NOT NULL,
  uploader_role VARCHAR(50) NOT NULL COMMENT 'USER/NURSE/ADMIN_SUPER',
  biz_type VARCHAR(100) NOT NULL COMMENT '业务类型 ORDER/NURSE/SERVICE/AVATAR',
  biz_id VARCHAR(100) DEFAULT NULL COMMENT '业务ID，如 orderNo',
  file_name VARCHAR(255) NOT NULL,
  file_path VARCHAR(255) NOT NULL COMMENT '相对路径 /uploads/xxx/xxx.jpg',
  file_size BIGINT NOT NULL COMMENT '文件大小byte',
  file_type VARCHAR(50) DEFAULT NULL COMMENT 'image/jpeg等',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_biz(biz_type, biz_id),
  INDEX idx_uploader(uploader_user_id)
) ENGINE=InnoDB COMMENT='文件附件统一表';

-- ============================================================
-- 31. 分布式锁 distributed_lock（新增）
-- ============================================================
DROP TABLE IF EXISTS distributed_lock;
CREATE TABLE distributed_lock (
  lock_key VARCHAR(100) PRIMARY KEY,
  lock_value VARCHAR(100) NOT NULL,
  expire_time DATETIME NOT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_expire(expire_time)
) ENGINE=InnoDB COMMENT='分布式锁表';

-- ============================================================
-- 32. SOS紧急呼叫 emergency_call（新增）
-- ============================================================
DROP TABLE IF EXISTS emergency_call;
CREATE TABLE emergency_call (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  order_no VARCHAR(50) NOT NULL,
  user_id BIGINT NOT NULL,
  nurse_user_id BIGINT DEFAULT NULL,
  caller_user_id BIGINT NOT NULL,
  caller_role VARCHAR(50) NOT NULL COMMENT 'USER/NURSE',
  emergency_type INT NOT NULL DEFAULT 1 COMMENT '1服务风险 2身体不适 3其他',
  description VARCHAR(500) DEFAULT NULL,
  status INT NOT NULL DEFAULT 0 COMMENT '0待处理 1已处理',
  handled_by BIGINT DEFAULT NULL,
  handled_time DATETIME DEFAULT NULL,
  handle_remark VARCHAR(500) DEFAULT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_order(order_id),
  INDEX idx_status(status, create_time),
  INDEX idx_caller(caller_user_id, create_time)
) ENGINE=InnoDB COMMENT='SOS紧急呼叫记录表';

-- ============================================================
-- 33. 预设系统配置数据（新增）
-- ============================================================
INSERT INTO system_config (config_key, config_value, remark) VALUES
  ('service_fee_rate', '0.20', '服务费抽成比例'),
  ('assign_retry_interval', '60', '派单重试间隔秒数'),
  ('assign_max_retry', '10', '派单最大重试次数'),
  ('reject_limit_per_day', '5', '每日拒单次数限制'),
  ('nurse_online_threshold', '300', '护士在线判定阈值秒数'),
  ('photo_max_size_mb', '5', '照片最大大小(MB)'),
  ('upload_path', '/static/uploads/', '文件上传根路径'),
  ('aliyun_sms_access_key', '', '阿里云短信AccessKey'),
  ('aliyun_sms_access_key_id', '', '阿里云短信AccessKeyId（新键）'),
  ('aliyun_sms_secret', '', '阿里云短信Secret'),
  ('aliyun_sms_access_key_secret', '', '阿里云短信AccessKeySecret（新键）'),
  ('aliyun_sms_sign_name', '', '阿里云短信签名'),
  ('aliyun_sms_template_code', '', '阿里云短信模板Code'),
  ('aliyun_push_app_key', '', '阿里云推送AppKey'),
  ('aliyun_push_app_secret', '', '阿里云推送AppSecret'),
  ('aliyun_push_access_key_id', '', '阿里云推送AccessKeyId'),
  ('aliyun_push_access_key_secret', '', '阿里云推送AccessKeySecret'),
  ('gaode_map_key', '', '高德地图API Key');

-- ============================================================
-- 34. 预设角色数据（新增）
-- ============================================================
INSERT INTO role (role_code, role_name, status) VALUES
  ('USER', '普通用户', 1),
  ('NURSE', '护士', 1),
  ('ADMIN_SUPER', '超级管理员', 1);

-- ============================================================
-- 35. 外键约束（新增）
-- ============================================================
ALTER TABLE user_role 
  ADD CONSTRAINT fk_user_role_user FOREIGN KEY (user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_user_role_role FOREIGN KEY (role_id) REFERENCES role(id);

ALTER TABLE user_profile 
  ADD CONSTRAINT fk_user_profile_user FOREIGN KEY (user_id) REFERENCES user_account(id);

ALTER TABLE user_address 
  ADD CONSTRAINT fk_user_address_user FOREIGN KEY (user_id) REFERENCES user_account(id);

ALTER TABLE nurse_profile 
  ADD CONSTRAINT fk_nurse_profile_user FOREIGN KEY (user_id) REFERENCES user_account(id);

ALTER TABLE nurse_location 
  ADD CONSTRAINT fk_nurse_location_user FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE nurse_reject_log 
  ADD CONSTRAINT fk_nurse_reject_user FOREIGN KEY (nurse_user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_nurse_reject_order FOREIGN KEY (order_id) REFERENCES order_main(id);

ALTER TABLE service_checkin_photo 
  ADD CONSTRAINT fk_checkin_order FOREIGN KEY (order_id) REFERENCES order_main(id),
  ADD CONSTRAINT fk_checkin_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE order_main 
  ADD CONSTRAINT fk_order_user FOREIGN KEY (user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_order_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_order_service FOREIGN KEY (service_id) REFERENCES service_item(id);

ALTER TABLE order_option 
  ADD CONSTRAINT fk_order_option_order FOREIGN KEY (order_id) REFERENCES order_main(id),
  ADD CONSTRAINT fk_order_option_service FOREIGN KEY (service_option_id) REFERENCES service_item_option(id);

ALTER TABLE order_status_log 
  ADD CONSTRAINT fk_status_log_order FOREIGN KEY (order_id) REFERENCES order_main(id);

ALTER TABLE order_assign_log 
  ADD CONSTRAINT fk_assign_log_order FOREIGN KEY (order_id) REFERENCES order_main(id),
  ADD CONSTRAINT fk_assign_log_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE payment_record 
  ADD CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES order_main(id);

ALTER TABLE refund_record 
  ADD CONSTRAINT fk_refund_order FOREIGN KEY (order_id) REFERENCES order_main(id);

ALTER TABLE evaluation 
  ADD CONSTRAINT fk_evaluation_order FOREIGN KEY (order_id) REFERENCES order_main(id),
  ADD CONSTRAINT fk_evaluation_user FOREIGN KEY (user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_evaluation_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE nurse_wallet 
  ADD CONSTRAINT fk_wallet_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE nurse_wallet_log 
  ADD CONSTRAINT fk_wallet_log_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id);

ALTER TABLE withdrawal_record 
  ADD CONSTRAINT fk_withdrawal_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_withdrawal_admin FOREIGN KEY (audit_admin_id) REFERENCES user_account(id);

ALTER TABLE notification 
  ADD CONSTRAINT fk_notification_user FOREIGN KEY (receiver_user_id) REFERENCES user_account(id);

ALTER TABLE emergency_call
  ADD CONSTRAINT fk_emergency_order FOREIGN KEY (order_id) REFERENCES order_main(id),
  ADD CONSTRAINT fk_emergency_user FOREIGN KEY (user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_emergency_nurse FOREIGN KEY (nurse_user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_emergency_caller FOREIGN KEY (caller_user_id) REFERENCES user_account(id),
  ADD CONSTRAINT fk_emergency_handler FOREIGN KEY (handled_by) REFERENCES user_account(id);

-- ============================================================
-- 36. 索引维护说明（新增）
-- ============================================================
-- 建议定期执行：
-- ANALYZE TABLE order_main;
-- OPTIMIZE TABLE order_main;
