package com.nursing.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nursing.entity.DistributedLock;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface DistributedLockMapper extends BaseMapper<DistributedLock> {
}
